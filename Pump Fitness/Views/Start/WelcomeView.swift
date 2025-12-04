import SwiftUI

struct WelcomeView: View {
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
                    Button(action: {}) {
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
                            Text("Continue with Facebook")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 59/255, green: 89/255, blue: 152/255))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Button(action: startOnboarding) {
                        HStack(spacing: 12) {
                            Image(systemName: "applelogo")
                                .font(.headline)
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(useDarkButtonBackground ? Color.white : Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(useDarkButtonBackground ? Color.black : Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Text("or sign in with email")
                        .font(.footnote)
                        .foregroundColor(.primary.opacity(0.8))
                        .underline()
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
