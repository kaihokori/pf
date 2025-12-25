import Foundation
import AudioToolbox
@preconcurrency import AVFoundation

final class SilentPhotoCaptureService: NSObject, AVCapturePhotoCaptureDelegate {
    /// When `true` the service will attempt to suppress the camera shutter sound.
    /// You can toggle this from callers that instantiate the service.
    var isSilentModeOn: Bool = true
    private var continuation: CheckedContinuation<Data, Error>?
    private var session: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private let sessionQueue = DispatchQueue(label: "SilentPhotoCaptureService.session")

    // Wraps AVFoundation objects to hop across Sendable closures safely.
    private struct CaptureContext: @unchecked Sendable {
        let session: AVCaptureSession
        let output: AVCapturePhotoOutput
        let settings: AVCapturePhotoSettings
    }

    enum CaptureError: Error {
        case noCamera
        case authorizationDenied
        case captureFailed
    }

    static func requestCameraAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            return true
        }
        if status == .denied || status == .restricted {
            return false
        }
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func captureImage(position: AVCaptureDevice.Position) async throws -> Data {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CaptureError.noCamera
        }

        let authorized = await Self.requestCameraAuthorization()
        guard authorized else { throw CaptureError.authorizationDenied }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])

        self.session = session
        self.photoOutput = output

        let context = CaptureContext(session: session, output: output, settings: settings)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.continuation = continuation
            sessionQueue.async { [weak self, context] in
                guard let strongSelf = self else { return }
                context.session.startRunning()
                Task { @MainActor in
                    context.output.capturePhoto(with: context.settings, delegate: strongSelf)
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if isSilentModeOn {
            print("[Camera]: Silent sound activated")
            AudioServicesDisposeSystemSoundID(1108)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if isSilentModeOn {
            AudioServicesDisposeSystemSoundID(1108)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            sessionQueue.async {
                self.session?.stopRunning()
                self.session = nil
                self.photoOutput = nil
            }
        }

        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CaptureError.captureFailed)
            continuation = nil
            return
        }

        continuation?.resume(returning: data)
        continuation = nil
    }
}
