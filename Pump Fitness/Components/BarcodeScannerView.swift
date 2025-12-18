import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCodeFound: (String) -> Void
    var onError: (String) -> Void
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController(onCodeFound: onCodeFound, onError: onError)
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// SwiftUI wrapper that adds a leading return button in the navigation toolbar
struct BarcodeScannerWithToolbar: View {
    @Environment(\.dismiss) private var dismiss
    var onCodeFound: (String) -> Void
    var onError: (String) -> Void

    var body: some View {
        NavigationStack {
            BarcodeScannerView(onCodeFound: onCodeFound, onError: onError)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
struct BarcodeScannerWithToolbar_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerWithToolbar(onCodeFound: { _ in }, onError: { _ in })
    }
}
#endif

private final class ScannerMetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    weak var parent: ScannerViewController?

    init(parent: ScannerViewController) {
        self.parent = parent
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let code = object.stringValue else { return }

        DispatchQueue.main.async { [weak self] in
            guard let parent = self?.parent else { return }
            parent.stopCaptureFromDelegate()
            parent.onCodeFound(code)
        }
    }
}

final class ScannerViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.pumpfitness.scanner")
    private var metadataDelegate: ScannerMetadataDelegate?

    fileprivate let onCodeFound: (String) -> Void
    private let onError: (String) -> Void
    var onDismiss: (() -> Void)?

    init(onCodeFound: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onCodeFound = onCodeFound
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissions()
        addCloseButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSession() : self?.onError("Camera permission denied")
                }
            }
        default:
            onError("Camera permission denied")
        }
    }

    private func configureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            onError("Camera unavailable")
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                let output = AVCaptureMetadataOutput()
                if self.captureSession.canAddOutput(output) {
                    self.captureSession.addOutput(output)
                    let delegate = ScannerMetadataDelegate(parent: self)
                    self.metadataDelegate = delegate
                    DispatchQueue.main.async {
                        output.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
                        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .code93]
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Camera setup failed")
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.commitConfiguration()
            self.setupPreview()
            self.captureSession.startRunning()
        }
    }

    private func setupPreview() {
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            preview.frame = self.view.layer.bounds
            self.view.layer.addSublayer(preview)
            self.previewLayer = preview
            self.addOverlay()
        }
    }

    private func addCloseButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let button = UIButton(type: .system)
            let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            let image = UIImage(systemName: "chevron.left", withConfiguration: cfg)
            button.setImage(image, for: .normal)
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.25)
            button.layer.cornerRadius = 20
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(self.closeTapped), for: .touchUpInside)
            self.view.addSubview(button)

            let guide = self.view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
                button.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
                button.widthAnchor.constraint(equalToConstant: 40),
                button.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }

    @objc private func closeTapped() {
        // Prefer SwiftUI-driven dismiss if provided, otherwise try typical UIViewController dismiss/pop
        if let onDismiss = onDismiss {
            onDismiss()
            return
        }

        if let nav = navigationController {
            nav.popViewController(animated: true)
            return
        }

        if presentingViewController != nil {
            dismiss(animated: true)
            return
        }
    }

    private func addOverlay() {
        let overlay = CAShapeLayer()
        overlay.fillColor = UIColor.black.withAlphaComponent(0.35).cgColor

        let rectWidth: CGFloat = 260
        let rectHeight: CGFloat = 140
        let rect = CGRect(
            x: (view.bounds.width - rectWidth) / 2,
            y: (view.bounds.height - rectHeight) / 2,
            width: rectWidth,
            height: rectHeight
        )

        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(roundedRect: rect, cornerRadius: 12).reversing())
        overlay.path = path.cgPath
        view.layer.addSublayer(overlay)

        let label = UILabel()
        label.text = "Align the barcode"
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: rectHeight / 2 + 36)
        ])
    }

    fileprivate func stopCaptureFromDelegate() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}
