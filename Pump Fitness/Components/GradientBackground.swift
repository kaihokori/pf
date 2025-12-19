import SwiftUI

enum TabTheme {
    case nutrition, workout, routine, travel, sports, other
}

struct GradientBackground: View {
    var theme: TabTheme
    var colors: [Color] {
        switch theme {
        case .nutrition:
            return [Color.purple.opacity(0.18), Color.blue.opacity(0.14), Color.indigo.opacity(0.18)]
        case .workout:
            return [Color.indigo.opacity(0.18), Color.blue.opacity(0.14), Color.red.opacity(0.18)]
        case .routine:
            return [Color.blue.opacity(0.18), Color.white.opacity(0.14), Color.red.opacity(0.18)]
        case .travel:
            return [Color.indigo.opacity(0.18), Color.red.opacity(0.14), Color.yellow.opacity(0.18)]
        case .sports:
            return [Color.purple.opacity(0.18), Color.white.opacity(0.14), Color.pink.opacity(0.18)]
        case .other:
            return [Color.purple.opacity(0.18), Color.blue.opacity(0.14), Color.indigo.opacity(0.18)]
        }
    }
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    VStack(spacing: 0) {
        GradientBackground(theme: .nutrition)
        GradientBackground(theme: .workout)
        GradientBackground(theme: .routine)
        GradientBackground(theme: .travel)
        GradientBackground(theme: .sports)
        GradientBackground(theme: .other)
    }
}
