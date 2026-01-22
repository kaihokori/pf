//
//  BackgroundUploadExtension.swift
//  BackgroundUploadExtension
//
//  Created by Kyle Graham on 22/1/2026.
//

import Photos
import ExtensionFoundation
import os.log

private enum BackgroundUploadConstants {
    static let canonicalUserId = "IvpCfQPQrUdOAepWriei3skGZUB3"
    static let appGroupId = "group.com.trackerio.shared"
}

/// Shared manifest stored in the App Group so the app and extension avoid duplicate uploads across accounts.
final class SharedManifestStore {
    static let shared = SharedManifestStore()
    private let lock = NSLock()
    private var processed: Set<String> = []
    private let fileURL: URL

    private init() {
        let baseDir: URL
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BackgroundUploadConstants.appGroupId) {
            baseDir = container.appendingPathComponent("BackupCache", isDirectory: true)
        } else {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            baseDir = urls[0].appendingPathComponent("BackupCache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        fileURL = baseDir.appendingPathComponent("manifest.json")

        do {
            let data = try Data(contentsOf: fileURL)
            processed = try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            processed = []
        }
    }

    func contains(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return processed.contains(id)
    }

    func mark(_ id: String) {
        markMany([id])
    }

    func markMany(_ ids: [String]) {
        lock.lock()
        var didChange = false
        for id in ids where !processed.contains(id) {
            processed.insert(id)
            didChange = true
        }
        lock.unlock()
        if didChange { save() }
    }

    private func save() {
        lock.lock(); let snapshot = processed; lock.unlock()
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort; avoid crashing the extension
        }
    }
}

@main
class BackgroundUploadExtension: PHBackgroundResourceUploadExtension {
    private let isCancelledLock = OSAllocatedUnfairLock(initialState: false)
    private let logger = Logger(subsystem: "com.trackerio.pump", category: "BackgroundUpload")
    private let manifest = SharedManifestStore.shared

    required init() {}

    func process() -> PHBackgroundResourceUploadProcessingResult {
        logger.info("Background upload process started")
        
        if isCancelledLock.withLock({ $0 }) {
            return .processing
        }

        do {
            try retryFailedJobs()
            try acknowledgeCompletedJobs()
            try createNewUploadJobs()
            return .completed
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
        isCancelledLock.withLock { $0 = true }
        logger.info("Background upload extension terminating")
    }

    // MARK: - Helper Methods

    private func retryFailedJobs() throws {
        let library = PHPhotoLibrary.shared()
        let retryableJobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)

        for i in 0..<retryableJobs.count {
            if isCancelledLock.withLock({ $0 }) { break }
            let job = retryableJobs.object(at: i)

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else { return }
                request.retry(destination: nil)
            }
        }
    }

    private func acknowledgeCompletedJobs() throws {
        let library = PHPhotoLibrary.shared()
        let completedJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)

        for i in 0..<completedJobs.count {
            if isCancelledLock.withLock({ $0 }) { break }
            let job = completedJobs.object(at: i)

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else { return }
                request.acknowledge()
            }
        }
    }

    private func createNewUploadJobs() throws {
        let library = PHPhotoLibrary.shared()
        let resources = getUnprocessedResources(from: library)
        guard !resources.isEmpty else { return }

        try library.performChangesAndWait {
            for resource in resources {
                if self.isCancelledLock.withLock({ $0 }) { break }

                let safeId = self.safeId(for: resource)

                var request = URLRequest(url: URL(string: "https://api.trackerio.com/upload")!)
                request.httpMethod = "POST"

                // Include canonical user and asset identifiers so the server can dedupe and write to the shared bucket.
                request.setValue(BackgroundUploadConstants.canonicalUserId, forHTTPHeaderField: "X-User-ID")
                request.setValue(safeId, forHTTPHeaderField: "X-Asset-ID")
                request.setValue(resource.originalFilename, forHTTPHeaderField: "X-Filename")

                PHAssetResourceUploadJobChangeRequest.createJob(
                    destination: request,
                    resource: resource
                )

                // Mark locally so the extension and host share the same manifest across accounts.
                self.manifest.mark(safeId)
            }
        }
    }
    
    private func getUnprocessedResources(from library: PHPhotoLibrary) -> [PHAssetResource] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var resources: [PHAssetResource] = []
        
        assets.enumerateObjects { asset, _, _ in
            let safeId = self.safeId(for: asset)
            if !self.manifest.contains(safeId) {
                let assetResources = PHAssetResource.assetResources(for: asset)
                if let resource = assetResources.first {
                    resources.append(resource)
                }
            }
        }
        
        return resources
    }

    private func safeId(for asset: PHAsset) -> String {
        let id = asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        return id.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "", options: .regularExpression)
    }

    private func safeId(for resource: PHAssetResource) -> String {
        let id = resource.assetLocalIdentifier.components(separatedBy: "/").first ?? resource.assetLocalIdentifier
        return id.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "", options: .regularExpression)
    }
}