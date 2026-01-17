import Foundation

public struct ColorPalette {
    public static let defaultColors: [String] = [
        "#D84A4A", "#E6C84F", "#E39A3B", "#4CAF6A", "#4A7BD0", "#4FB6C6", "#7A5FD1", "#C85FA8"
    ]

    public static func randomHex() -> String {
        defaultColors.randomElement() ?? "#D84A4A"
    }
}
