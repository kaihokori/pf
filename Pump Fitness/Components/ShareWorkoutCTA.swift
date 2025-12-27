import SwiftUI

public struct ShareWorkoutCTA: View {
    var accentColor: Color
    var action: () -> Void

    private var gradientColors: [Color] {
        [
            accentColor,
            accentColor.opacity(0.75),
            accentColor.opacity(0.35)
        ]
    }

    private var glowColor: Color {
        accentColor.opacity(0.45)
    }

    public var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Share Workout Stats")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Inspire others with your grind!")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(accentColor.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(16)
            .background(
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle pattern overlay
                    GeometryReader { geo in
                        Path { path in
                            let width = geo.size.width
                            let height = geo.size.height
                            path.move(to: CGPoint(x: 0, y: height))
                            path.addCurve(
                                to: CGPoint(x: width, y: 0),
                                control1: CGPoint(x: width * 0.4, y: height * 0.8),
                                control2: CGPoint(x: width * 0.7, y: height * 0.2)
                            )
                        }
                        .stroke(Color.white.opacity(0.1), lineWidth: 40)
                        .blur(radius: 10)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: glowColor, radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
