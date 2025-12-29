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

    var body: some View {
        ZStack {
            baseBackground.ignoresSafeArea()

            // Video Background
            GeometryReader { geo in
                LoopingPlayerView(videoName: "welcome", colorScheme: colorScheme)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
            }
            
            VStack {
                // Top Section
                VStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    Text("Trackerio")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, -8)
                }
                .padding(.top, 80)
                
                Spacer()
                
                // Bottom Section
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
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
                        }
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
                                Text("Continue with Google")
                                    .font(.headline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Link("Terms, Conditions & Privacy Policy", destination: URL(string: "https://kaihokori.github.io/trackerio-legal/")!)
                        .font(.footnote)
                        .foregroundColor(footerTextColor)
                        .underline()
                }
                .padding(32)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
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
