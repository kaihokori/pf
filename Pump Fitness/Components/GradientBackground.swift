import SwiftUI

enum TabTheme {
    case nutrition, workout, coaching, add, other
}

struct GradientBackground: View {
    var theme: TabTheme
    var colors: [Color] {
        switch theme {
        case .nutrition:
            return [Color.purple.opacity(0.18), Color.blue.opacity(0.14), Color.indigo.opacity(0.18)]
        case .workout:
            return [Color.green.opacity(0.18), Color.cyan.opacity(0.14), Color.blue.opacity(0.18)]
        case .coaching:
            return [Color.pink.opacity(0.18), Color.purple.opacity(0.14), Color.accentColor.opacity(0.18)]
        case .add:
            return [Color.orange.opacity(0.18), Color.yellow.opacity(0.14), Color.red.opacity(0.18)]
        case .other:
            return [Color.gray.opacity(0.18), Color.gray.opacity(0.14), Color.gray.opacity(0.18)]
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
        GradientBackground(theme: .coaching)
        GradientBackground(theme: .add)
        GradientBackground(theme: .other)
    }
}
