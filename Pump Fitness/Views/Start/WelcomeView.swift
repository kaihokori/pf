import SwiftUI
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn

struct WelcomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var startOnboarding: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var useDarkButtonBackground: Bool {
        switch colorScheme {
        case .light:
            return true
        case .dark:
            return false
        @unknown default:
            return true
        }
    }

    var body: some View {
        ZStack {
            GradientBackground(theme: .other)
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "bolt.heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    Text("Welcome to Pump Fitness")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                Spacer()
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
                    .padding(.horizontal)

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
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Button(action: {}) {
                        HStack(spacing: 12) {
                            Text("Continue with Email")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                Spacer()
                Link("Privacy Policy", destination: URL(string: "https://pumpfitness.app/privacy")!)
                    .font(.footnote)
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.bottom, 24)
                    .underline()
            }
            .padding()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WelcomeView(startOnboarding: {})
}
