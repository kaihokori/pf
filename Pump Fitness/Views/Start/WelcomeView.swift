import SwiftUI
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import AVKit

struct WelcomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var startOnboarding: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var footerTextColor: Color {
        colorScheme == .light ? Color.black.opacity(0.7) : Color.white.opacity(0.8)
    }

    private var baseBackground: Color {
        colorScheme == .light ? .white : .black
    }

    private var googleButtonBackground: Color {
        colorScheme == .light ? Color.white : Color.black
    }

    private var googleButtonForeground: Color {
        colorScheme == .light ? Color.black : Color.white
    }

    var body: some View {
        ZStack {
            baseBackground.ignoresSafeArea()

            // Video Background
            LoopingPlayerView(videoName: "welcome", colorScheme: colorScheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            VStack {
                // Top Section
                VStack {
                    Image("logo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                    Text("Trackerio")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, -8)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Bottom Section
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        AppleSignInButton(colorScheme: colorScheme,
                                          onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        }, onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                    authViewModel.signInWithApple(credential: credential) { success in
                                        if success {
                                            startOnboarding()
                                        }
                                    }
                                }
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                        })
                        .frame(height: 50)
                        .cornerRadius(12)

                        Button(action: {
                            if let windowScene = UIApplication.shared.connectedScenes
                                .compactMap({ $0 as? UIWindowScene })
                                .first,
                               let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                                authViewModel.signInWithGoogle(presenting: rootVC) { success in
                                    if success {
                                        startOnboarding()
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image("google")
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                    .frame(width: 25, height: 25)
                                    .padding(.trailing, -4)

                                Text("Sign in with Google")
                                    .font(.headline)
                            }
                               .foregroundColor(googleButtonForeground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                               .background(googleButtonBackground)
                            .cornerRadius(12)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Link("Terms of Use (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.footnote)
                            .foregroundColor(footerTextColor)
                            .underline()
                        
                        Link("Privacy Policy", destination: URL(string: "https://ambreon.com/trackerio-privacy")!)
                          .font(.footnote)
                          .foregroundColor(footerTextColor)
                          .underline()
                    }
                }
                .padding(32)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 24)
            }
        }
    }
}

#Preview {
    WelcomeView(startOnboarding: {})
}

// MARK: - Helper Views

struct LoopingPlayerView: UIViewRepresentable {
    var videoName: String
    var colorScheme: ColorScheme

    func makeUIView(context: Context) -> UIView {
        return LoopingPlayerUIView(videoName: videoName, colorScheme: colorScheme)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let loopingView = uiView as? LoopingPlayerUIView else { return }
        loopingView.updateBackground(colorScheme)
    }
}

class LoopingPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLooper: AVPlayerLooper?
    private var currentColorScheme: ColorScheme
    private let player: AVQueuePlayer

    private var playerLayer: AVPlayerLayer {
        // Force-cast is safe because layerClass is AVPlayerLayer
        layer as! AVPlayerLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(videoName: String, colorScheme: ColorScheme) {
        self.currentColorScheme = colorScheme

        if let fileUrl = Bundle.main.url(forResource: videoName, withExtension: "mov") {
            let item = AVPlayerItem(url: fileUrl)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            self.player = queuePlayer
            super.init(frame: .zero)

            playerLayer.player = queuePlayer
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.needsDisplayOnBoundsChange = true
            playerLayer.masksToBounds = true
            playerLayer.isOpaque = true
            applyBackground(for: colorScheme)

            playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            queuePlayer.play()
        } else {
            self.player = AVQueuePlayer()
            super.init(frame: .zero)
            applyBackground(for: colorScheme)
        }
    }

    func updateBackground(_ colorScheme: ColorScheme) {
        guard colorScheme != currentColorScheme else { return }
        currentColorScheme = colorScheme
        applyBackground(for: colorScheme)
    }

    private func applyBackground(for colorScheme: ColorScheme) {
        let uiColor = colorScheme == .light ? UIColor.white : UIColor.black
        backgroundColor = uiColor
        layer.backgroundColor = uiColor.cgColor
        playerLayer.backgroundColor = uiColor.cgColor
        playerLayer.isOpaque = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Apple Sign In Button Wrapper

struct AppleSignInButton: UIViewRepresentable {
    var colorScheme: ColorScheme
    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRequest: onRequest, onCompletion: onCompletion)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let button = makeButton(for: colorScheme)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap(_:)), for: .touchUpInside)
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.currentButton = button
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // If color scheme changed, replace the inner button so the ASAuthorizationAppleIDButton style matches.
        if let existing = context.coordinator.currentButton {
            let desiredStyleIsLight = (colorScheme == .light)
            // Determine current style by inspecting backgroundColor heuristic (can't read 'style' directly)
            let isCurrentlyLight = (existing.backgroundColor == UIColor.white)
            if isCurrentlyLight != desiredStyleIsLight {
                existing.removeTarget(context.coordinator, action: #selector(Coordinator.handleTap(_:)), for: .touchUpInside)
                existing.removeFromSuperview()
                let newButton = makeButton(for: colorScheme)
                newButton.translatesAutoresizingMaskIntoConstraints = false
                newButton.addTarget(context.coordinator, action: #selector(Coordinator.handleTap(_:)), for: .touchUpInside)
                uiView.addSubview(newButton)
                NSLayoutConstraint.activate([
                    newButton.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                    newButton.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                    newButton.topAnchor.constraint(equalTo: uiView.topAnchor),
                    newButton.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
                ])
                context.coordinator.currentButton = newButton
            }
        }
    }

    private func makeButton(for scheme: ColorScheme) -> ASAuthorizationAppleIDButton {
        let style: ASAuthorizationAppleIDButton.Style = (scheme == .light) ? .white : .black
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: style)
        button.cornerRadius = 12
        return button
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void
        weak var currentButton: ASAuthorizationAppleIDButton?

        init(onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void, onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onRequest = onRequest
            self.onCompletion = onCompletion
        }

        @objc func handleTap(_ sender: Any) {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            onRequest(request)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            // Prefer the active foreground UIWindowScene's key window
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                if let key = scene.windows.first(where: { $0.isKeyWindow }) {
                    return key
                }
                if let first = scene.windows.first {
                    return first
                }
                // Create a hidden window attached to the scene as a last resort for this scene
                return UIWindow(windowScene: scene)
            }
            // Fallback: use any available UIWindowScene (non-foreground if necessary)
            if let anyScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                if let key = anyScene.windows.first(where: { $0.isKeyWindow }) {
                    return key
                }
                if let first = anyScene.windows.first {
                    return first
                }
                return UIWindow(windowScene: anyScene)
            }

            // Extremely unlikely: no UIWindowScene available. Crash so we notice the issue during development.
            fatalError("No UIWindowScene available for presentationAnchor")
        }
    }
}
