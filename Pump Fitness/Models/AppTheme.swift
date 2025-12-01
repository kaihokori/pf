import SwiftUI
import Combine
import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case multiColour
    case aurora
    case midnight
    case solarFlare
    case obsidian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .multiColour: return "Multicolour"
        case .aurora: return "Aurora"
        case .midnight: return "Midnight"
        case .solarFlare: return "Solar Flare"
        case .obsidian: return "Obsidian"
        }
    }

    func background(for colorScheme: ColorScheme) -> LinearGradient {
        let variant = palette(for: colorScheme)
        return LinearGradient(
            gradient: Gradient(colors: variant.backgroundColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func accent(for colorScheme: ColorScheme) -> Color {
        palette(for: colorScheme).accent
    }

    func previewBackground(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .multiColour:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.99, green: 0.39, blue: 0.37),
                    Color(red: 1.00, green: 0.60, blue: 0.00),
                    Color(red: 0.99, green: 0.84, blue: 0.00),
                    Color(red: 0.24, green: 0.80, blue: 0.44),
                    Color(red: 0.24, green: 0.64, blue: 1.00),
                    Color(red: 0.54, green: 0.36, blue: 0.96)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return background(for: colorScheme)
        }
    }

    private func palette(for colorScheme: ColorScheme) -> ThemePalette {
        let isDark = colorScheme == .dark
        switch self {
        case .multiColour:
            let colors = isDark ?
                [Color(red: 0.22, green: 0.25, blue: 0.36), Color(red: 0.34, green: 0.38, blue: 0.52)] :
                [Color(red: 0.92, green: 0.95, blue: 1.00), Color(red: 0.78, green: 0.86, blue: 0.99)]
            return ThemePalette(backgroundColors: colors, accent: .accentColor)
        case .aurora:
            if isDark {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.05, green: 0.10, blue: 0.24),
                        Color(red: 0.15, green: 0.28, blue: 0.53)
                    ],
                    accent: Color(red: 0.40, green: 0.90, blue: 0.86)
                )
            } else {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.78, green: 0.93, blue: 0.97),
                        Color(red: 0.60, green: 0.82, blue: 0.90)
                    ],
                    accent: Color(red: 0.18, green: 0.54, blue: 0.63)
                )
            }
        case .midnight:
            if isDark {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.05, green: 0.04, blue: 0.15),
                        Color(red: 0.18, green: 0.11, blue: 0.36)
                    ],
                    accent: Color(red: 0.70, green: 0.52, blue: 1.00)
                )
            } else {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.83, green: 0.79, blue: 0.99),
                        Color(red: 0.64, green: 0.63, blue: 0.94)
                    ],
                    accent: Color(red: 0.42, green: 0.32, blue: 0.78)
                )
            }
        case .solarFlare:
            if isDark {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.24, green: 0.08, blue: 0.05),
                        Color(red: 0.40, green: 0.13, blue: 0.07)
                    ],
                    accent: Color(red: 1.00, green: 0.63, blue: 0.38)
                )
            } else {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.99, green: 0.90, blue: 0.82),
                        Color(red: 0.97, green: 0.77, blue: 0.63)
                    ],
                    accent: Color(red: 0.79, green: 0.38, blue: 0.19)
                )
            }
        case .obsidian:
            if isDark {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.09, green: 0.11, blue: 0.18),
                        Color(red: 0.18, green: 0.20, blue: 0.29)
                    ],
                    accent: Color(red: 0.47, green: 0.63, blue: 0.97)
                )
            } else {
                return ThemePalette(
                    backgroundColors: [
                        Color(red: 0.90, green: 0.94, blue: 1.00),
                        Color(red: 0.74, green: 0.82, blue: 0.94)
                    ],
                    accent: Color(red: 0.24, green: 0.42, blue: 0.78)
                )
            }
        }
    }
}

private struct ThemePalette {
    let backgroundColors: [Color]
    let accent: Color
}

final class ThemeManager: ObservableObject {
    static let defaultsKey = "selectedTheme"
    private let defaults: UserDefaults
    private var cancellable: AnyCancellable?

    @Published private(set) var selectedTheme: AppTheme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedValue = defaults.string(forKey: Self.defaultsKey)
        selectedTheme = AppTheme(rawValue: storedValue ?? "") ?? .multiColour
        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncFromDefaults()
            }
    }

    deinit {
        cancellable?.cancel()
    }

    func setTheme(_ theme: AppTheme) {
        guard selectedTheme != theme else { return }
        selectedTheme = theme
        defaults.set(theme.rawValue, forKey: Self.defaultsKey)
    }

    private func syncFromDefaults() {
        guard let rawValue = defaults.string(forKey: Self.defaultsKey),
              let theme = AppTheme(rawValue: rawValue),
              theme != selectedTheme else { return }
        selectedTheme = theme
    }
}
