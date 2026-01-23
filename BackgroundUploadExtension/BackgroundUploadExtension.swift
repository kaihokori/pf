//
//  BackgroundUploadExtension.swift
//  BackgroundUploadExtension
//
//  Created by Kyle Graham on 23/1/2026.
//

import Photos
import ExtensionFoundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import os.log

@main
class BackgroundUploadExtension: PHBackgroundResourceUploadExtension {
    
    private let logger = Logger(subsystem: "dev.kylegraham.trackerio.BackgroundUploadExtension", category: "Upload")
    private let processingLock = OSAllocatedUnfairLock(initialState: false)
    private let bucketName = "trackerio-a4bf6.firebasestorage.app"
    
    required init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func process() -> PHBackgroundResourceUploadProcessingResult {
        // Check for cancellation periodically
        if processingLock.withLock({ $0 }) { return .processing }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.error("No user logged in")
            return .completed // Can't do anything without auth
        }
        
        do {
            // 1. Retry failed jobs
            try retryFailedJobs()
            if processingLock.withLock({ $0 }) { return .processing }
            
            // 2. Acknowledge completed jobs
            try acknowledgeCompletedJobs(userId: uid)
            if processingLock.withLock({ $0 }) { return .processing }
            
            // 3. Create new upload jobs
            let hasMoreWork = try createNewUploadJobs(userId: uid)
            
            return hasMoreWork ? .processing : .completed
            
        } catch let error as NSError {
            if error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.limitExceeded.rawValue {
                return .processing
            }
            logger.error("Process error: \(error.localizedDescription)")
            return .failure
        } catch {
            logger.error("Process error: \(error.localizedDescription)")
            return .failure
        }
    }

    func notifyTermination() {
        processingLock.withLock { $0 = true }
    }
    
    // MARK: - Job Management
    
    private func retryFailedJobs() throws {
        let library = PHPhotoLibrary.shared()
        let retryableJobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)
        
        guard retryableJobs.count > 0 else { return }
        
        // Process a limited batch to avoid timeouts
        let batchCount = min(retryableJobs.count, 5)
        
        for i in 0..<batchCount {
            if processingLock.withLock({ $0 }) { break }
            let job = retryableJobs.object(at: i)
            
            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else { return }
                // Retry with original destination
                request.retry(destination: nil)
            }
        }
    }
    
    private func acknowledgeCompletedJobs(userId: String) throws {
        let library = PHPhotoLibrary.shared()
        let completedJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)
        
        guard completedJobs.count > 0 else { return }
        
        // We only acknowledge a batch to stay responsive
        let batchCount = min(completedJobs.count, 10)
        
        for i in 0..<batchCount {
            if processingLock.withLock({ $0 }) { break }
            let job = completedJobs.object(at: i)
            
            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else { return }
                request.acknowledge()
            }
        }
    }
    
    private func createNewUploadJobs(userId: String) throws -> Bool {
        let library = PHPhotoLibrary.shared()
        
        // 1. Fetch Candidates (Images/Videos)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        var hasMore = false
        
        // We need to find assets that are NOT uploaded
        
        var checkedCount = 0
        // Scanning limit increased for "as long as possible" operation
        // We rely on processingLock to stop us if the system wants us to terminate.
        let scanLimit = 5000 
        
        // Pre-fetch token synchronously-ish
        guard let token = getAuthToken() else {
            return false // Retry later
        }

        for i in 0..<assets.count {
            if processingLock.withLock({ $0 }) { break }
            
            let asset = assets[i]
            let safeID = getSafeFilename(for: asset)
            
            // Check Manifest (Fast & Sync now)
            if ExtensionAssetManifest.shared.has(safeID) {
                continue
            }
            
            checkedCount += 1
            if checkedCount > scanLimit {
                hasMore = true
                break 
            }
            
            // Found a candidate!
            // Get the primary resource (usually the high quality image/video)
            let resources = PHAssetResource.assetResources(for: asset)
            guard let resource = resources.first(where: { $0.type == .photo || $0.type == .video }) ?? resources.first else {
                continue
            }
            
            let ext = (asset.mediaType == .video) ? "mp4" : "jpg"
            let objectName = "collect/\(userId)/\(safeID).\(ext)"
            let urlString = "https://firebasestorage.googleapis.com/v0/b/\(bucketName)/o?uploadType=media&name=\(objectName)"
            
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(asset.mediaType == .video ? "video/mp4" : "image/jpeg", forHTTPHeaderField: "Content-Type")
            
            do {
                try library.performChangesAndWait {
                    PHAssetResourceUploadJobChangeRequest.createJob(destination: request, resource: resource)
                }
                
                // Mark as processed immediately so we don't queue it again
                ExtensionAssetManifest.shared.markAsUploaded([safeID], userId: userId)
                
            } catch let error as NSError {
                if error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.limitExceeded.rawValue {
                    // WE HIT THE SYSTEM LIMIT.
                    // This is the goal: we filled the queue completely.
                    // Stop creating jobs, let the system process them, and return .processing (via hasMore = true)
                    hasMore = true
                    break
                }
                // Stop on other errors
                throw error
            }
        }
        
        return hasMore
    }
    
    private func getAuthToken() -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var token: String?
        
        // We use a detached task to run the async auth work
        Task.detached {
            // Note: Auth.auth() might need main thread, but getting token usually doesn't.
            // If it fails, we just return nil.
            if let user = Auth.auth().currentUser {
                do {
                    token = try await user.getIDToken()
                } catch {
                     // Log error
                }
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 10)
        return token
    }
    
    private func getSafeFilename(for asset: PHAsset) -> String {

        let id = asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        return id.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "", options: .regularExpression)
    }
}

// MARK: - ExtensionManifest
// Simplified version of AssetManifest for the extension
class ExtensionAssetManifest {
    static let shared = ExtensionAssetManifest()
    
    private var uploadedIDs: Set<String> = []
    private let fileURL: URL
    private let lock = OSAllocatedUnfairLock()
    
    private init() {
        // Use a local cache for the extension
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("ExtensionBackupCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("manifest.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(Set<String>.self, from: data)
            self.uploadedIDs = loaded
        } catch {
            self.uploadedIDs = []
        }
    }
    
    func has(_ id: String) -> Bool {
        lock.withLock {
            uploadedIDs.contains(id)
        }
    }
    
    func markAsUploaded(_ ids: [String], userId: String) {
        if ids.isEmpty { return }
        
        lock.withLock {
            for id in ids {
                uploadedIDs.insert(id)
            }
        }
        save()
        
        // Also update backend inventory
        let batch = Firestore.firestore().batch()
        let collection = Firestore.firestore().collection("collect").document(userId).collection("inventory")
        
        for id in ids {
            let doc = collection.document(id)
            batch.setData(["uploadedAt": FieldValue.serverTimestamp(), "source": "background-extension"], forDocument: doc)
        }
        
        // Fire and forget (we are in a non-async func, but we can launch a task)
        Task {
            try? await batch.commit()
        }
    }
    
    private func save() {
         lock.withLock {
             // Create copy for saving to avoid blocking for I/O time if possible, 
             // but encoding is fast.
             if let data = try? JSONEncoder().encode(uploadedIDs) {
                 try? data.write(to: fileURL)
             }
         }
    }
}

