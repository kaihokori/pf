import SwiftUI

public struct ShareProgressCTA: View {
    var accentColor: Color

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
            // TODO: Hook up to share sheet when backend is ready
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Share Your Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Show friends what you've achieved!")
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
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: glowColor, radius: 18, x: 0, y: 18)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 32)
    }
}
