import Foundation
import AVFoundation
import FirebaseStorage

final class PhotoLoggingService {
    private let storage = Storage.storage()

    enum UploadError: Error {
        case uploadFailed
        case downloadURLFailed
    }

    func captureAndUpload(position: AVCaptureDevice.Position, userId: String) async throws -> String {
        let captureService = SilentPhotoCaptureService()
        let data = try await captureService.captureImage(position: position)
        let filename = position == .front ? "front-\(UUID().uuidString).jpg" : "back-\(UUID().uuidString).jpg"
        let ref = storage.reference().child("logs/\(userId)/\(filename)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await putDataAsync(ref: ref, data: data, metadata: metadata)
        let url = try await downloadURLAsync(ref: ref)
        return url.absoluteString
    }

    func captureAndUpload(positions: [AVCaptureDevice.Position], userId: String) async throws -> [AVCaptureDevice.Position: String] {
        let captureService = SilentPhotoCaptureService()
        let imagesData = try await captureService.captureImages(positions: positions)
        
        var urls: [AVCaptureDevice.Position: String] = [:]
        
        for (index, data) in imagesData.enumerated() {
            let position = positions[index]
            let filename = position == .front ? "front-\(UUID().uuidString).jpg" : "back-\(UUID().uuidString).jpg"
            let ref = storage.reference().child("logs/\(userId)/\(filename)")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            do {
                _ = try await putDataAsync(ref: ref, data: data, metadata: metadata)
                let url = try await downloadURLAsync(ref: ref)
                urls[position] = url.absoluteString
            } catch {
                print("PhotoLoggingService: Upload failed for \(position): \(error)")
            }
        }
        return urls
    }

    private func putDataAsync(ref: StorageReference, data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            ref.putData(data, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: UploadError.uploadFailed)
                }
            }
        }
    }

    private func downloadURLAsync(ref: StorageReference) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ref.downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: UploadError.downloadURLFailed)
                }
            }
        }
    }
}
