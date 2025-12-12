import Foundation
import SwiftData
import Combine
import SwiftUI
import UIKit

struct TrackedMacro: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var target: Double
    var unit: String
    var colorHex: String

    init(
        id: String = UUID().uuidString,
        name: String,
        target: Double,
        unit: String = "g",
        colorHex: String = "#FF3B30"
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.unit = unit
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    static var defaults: [TrackedMacro] {
        [
            TrackedMacro(name: "Protein", target: 150, unit: "g", colorHex: "#FF3B30"),
            TrackedMacro(name: "Carbs", target: 200, unit: "g", colorHex: "#34C759"),
            TrackedMacro(name: "Fats", target: 70, unit: "g", colorHex: "#FF9500"),
            TrackedMacro(name: "Water", target: 2.5, unit: "L", colorHex: "#32ADE6")
        ]
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let target = (dictionary["target"] as? NSNumber)?.doubleValue ?? 0
        let unit = dictionary["unit"] as? String ?? "g"
        let colorHex = dictionary["colorHex"] as? String ?? "#FF3B30"
        self.init(id: id, name: name, target: target, unit: unit, colorHex: colorHex)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "target": target,
            "unit": unit,
            "colorHex": colorHex
        ]
    }
}

@Model
class Account: ObservableObject {
        // MARK: - Avatar Helpers
        var avatarGradient: LinearGradient {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.18),
                    Color.blue.opacity(0.14),
                    Color.indigo.opacity(0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        var avatarImage: Image? {
            guard let data = profileImage, let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        }

        var avatarInitials: String {
            let components = (name ?? "").components(separatedBy: " ")
            let initials = components.prefix(2).compactMap { $0.first }.map { String($0) }
            return initials.joined().uppercased()
        }
    var id: String? = UUID().uuidString
    @Attribute(.externalStorage) var profileImage: Data? = nil
    var profileAvatar: String? = nil
    var name: String? = nil
    var gender: String? = nil
    var dateOfBirth: Date? = nil
    var height: Double? = nil
    var weight: Double? = nil
    var maintenanceCalories: Int = 0
    var theme: String? = nil
    var unitSystem: String? = nil
    var activityLevel: String? = nil
    var startWeekOn: String? = nil
    var trackedMacros: [TrackedMacro] = []
    var cravings: [CravingItem] = []

    init(
        id: String? = UUID().uuidString,
        profileImage: Data? = nil,
        profileAvatar: String? = nil,
        name: String? = nil,
        gender: String? = nil,
        dateOfBirth: Date? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        maintenanceCalories: Int = 0,
        theme: String? = nil,
        unitSystem: String? = nil,
        activityLevel: String? = nil,
        startWeekOn: String? = nil,
        trackedMacros: [TrackedMacro] = [],
        cravings: [CravingItem] = []
    ) {
        self.id = id
        self.profileImage = profileImage
        self.profileAvatar = profileAvatar
        self.name = name
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.height = height
        self.weight = weight
        self.maintenanceCalories = maintenanceCalories
        self.theme = theme
        self.unitSystem = unitSystem
        self.activityLevel = activityLevel
        self.startWeekOn = startWeekOn
        self.trackedMacros = trackedMacros
        self.cravings = cravings
        
    }
}

// MARK: - Color helpers
extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1
        )
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let rInt = Int(round(r * 255))
        let gInt = Int(round(g * 255))
        let bInt = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
}
