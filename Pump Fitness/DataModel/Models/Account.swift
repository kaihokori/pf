import Foundation
import SwiftData
import Combine
import SwiftUI
import UIKit
import FirebaseFirestore

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

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
}

struct MealReminder: Codable, Hashable, Identifiable {
    var id: String
    var mealType: MealType
    var hour: Int
    var minute: Int

    init(id: String = UUID().uuidString, mealType: MealType, hour: Int, minute: Int) {
        self.id = id
        self.mealType = mealType
        self.hour = hour
        self.minute = minute
    }

    var displayTime: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var dateForToday: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "mealType": mealType.rawValue,
            "hour": hour,
            "minute": minute
        ]
    }

    init?(dictionary: [String: Any]) {
        guard
            let rawType = dictionary["mealType"] as? String,
            let mealType = MealType(rawValue: rawType)
        else { return nil }

        let id = dictionary["id"] as? String ?? UUID().uuidString
        let hour = (dictionary["hour"] as? NSNumber)?.intValue ?? dictionary["hour"] as? Int ?? 7
        let minute = (dictionary["minute"] as? NSNumber)?.intValue ?? dictionary["minute"] as? Int ?? 30

        self.init(id: id, mealType: mealType, hour: hour, minute: minute)
    }

    static var defaults: [MealReminder] {
        [
            MealReminder(mealType: .breakfast, hour: 7, minute: 30),
            MealReminder(mealType: .lunch, hour: 12, minute: 30),
            MealReminder(mealType: .dinner, hour: 19, minute: 0),
            MealReminder(mealType: .snack, hour: 15, minute: 30)
        ]
    }
}

struct WeeklyProgressRecord: Codable, Hashable, Identifiable {
    var id: String
    var date: Date
    var weight: Double
    var waterPercent: Double?
    var bodyFatPercent: Double?
    var photoData: Data?

    init(
        id: String = UUID().uuidString,
        date: Date,
        weight: Double,
        waterPercent: Double? = nil,
        bodyFatPercent: Double? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.waterPercent = waterPercent
        self.bodyFatPercent = bodyFatPercent
        self.photoData = photoData
    }

    init?(dictionary: [String: Any]) {
        guard let timestamp = dictionary["date"] as? Date ?? (dictionary["date"] as? Timestamp)?.dateValue(),
              let weight = (dictionary["weight"] as? NSNumber)?.doubleValue ?? dictionary["weight"] as? Double else { return nil }

        let id = dictionary["id"] as? String ?? UUID().uuidString
        let waterPercent = (dictionary["waterPercent"] as? NSNumber)?.doubleValue ?? dictionary["waterPercent"] as? Double
        let bodyFatPercent = (dictionary["bodyFatPercent"] as? NSNumber)?.doubleValue ?? dictionary["bodyFatPercent"] as? Double

        var decodedPhoto: Data? = nil
        if let rawData = dictionary["photoData"] as? Data {
            decodedPhoto = rawData
        } else if let base64 = dictionary["photoData"] as? String {
            decodedPhoto = Data(base64Encoded: base64)
        }

        self.init(id: id, date: timestamp, weight: weight, waterPercent: waterPercent, bodyFatPercent: bodyFatPercent, photoData: decodedPhoto)
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "date": date,
            "weight": weight
        ]

        if let waterPercent { dict["waterPercent"] = waterPercent }
        if let bodyFatPercent { dict["bodyFatPercent"] = bodyFatPercent }
        if let photoData {
            // Firestore can store Data directly; this keeps the image as inline bytes.
            dict["photoData"] = photoData
        }
        return dict
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
    var intermittentFastingMinutes: Int = 16 * 60
    var theme: String? = nil
    var unitSystem: String? = nil
    var activityLevel: String? = nil
    var startWeekOn: String? = nil
    var trackedMacros: [TrackedMacro] = []
    var cravings: [CravingItem] = []
    var mealReminders: [MealReminder] = MealReminder.defaults
    var weeklyProgress: [WeeklyProgressRecord] = []

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
        intermittentFastingMinutes: Int = 16 * 60,
        theme: String? = nil,
        unitSystem: String? = nil,
        activityLevel: String? = nil,
        startWeekOn: String? = nil,
        trackedMacros: [TrackedMacro] = [],
        cravings: [CravingItem] = [],
        mealReminders: [MealReminder] = MealReminder.defaults,
        weeklyProgress: [WeeklyProgressRecord] = []
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
        self.intermittentFastingMinutes = intermittentFastingMinutes
        self.theme = theme
        self.unitSystem = unitSystem
        self.activityLevel = activityLevel
        self.startWeekOn = startWeekOn
        self.trackedMacros = trackedMacros
        self.cravings = cravings
        self.mealReminders = mealReminders
        self.weeklyProgress = weeklyProgress
        
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
