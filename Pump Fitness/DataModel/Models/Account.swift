import Foundation
import SwiftData
import Combine
import SwiftUI
import UIKit
import FirebaseFirestore
import CoreLocation

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
            TrackedMacro(name: "Water", target: 2500, unit: "mL", colorHex: "#32ADE6")
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

// MARK: - Expense tracking

struct ExpenseCategory: Codable, Hashable, Identifiable {
    var id: Int
    var name: String
    var colorHex: String

    init(id: Int, name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? Int,
              let name = dictionary["name"] as? String else { return nil }
        let colorHex = dictionary["colorHex"] as? String ?? "#FF3B30"
        self.init(id: id, name: name, colorHex: colorHex)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "colorHex": colorHex
        ]
    }

    static func defaultCategories() -> [ExpenseCategory] {
        [
            ExpenseCategory(id: 0, name: "Food", colorHex: "#E39A3B"),
            ExpenseCategory(id: 1, name: "Groceries", colorHex: "#4CAF6A"),
            ExpenseCategory(id: 2, name: "Transport", colorHex: "#4FB6C6"),
            ExpenseCategory(id: 3, name: "Bills", colorHex: "#7A5FD1"),
            ExpenseCategory(id: 4, name: "Entertainment", colorHex: "#FF6B6B"),
            ExpenseCategory(id: 5, name: "Health", colorHex: "#FFD166")
        ]
    }
}

struct Supplement: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var amountLabel: String?

    init(id: String = UUID().uuidString, name: String, amountLabel: String? = nil) {
        self.id = id
        self.name = name
        self.amountLabel = amountLabel
    }

    init?(dictionary: [String: Any]) {
        let id = dictionary["id"] as? String ?? UUID().uuidString
        guard let name = dictionary["name"] as? String else { return nil }
        let amount = dictionary["amountLabel"] as? String
        self.init(id: id, name: name, amountLabel: amount)
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name
        ]
        if let amountLabel { dict["amountLabel"] = amountLabel }
        return dict
    }
}

struct DailyTaskDefinition: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var time: String
    var colorHex: String
    var repeats: Bool

    init(id: String = UUID().uuidString, name: String, time: String, colorHex: String = ColorPalette.randomHex(), repeats: Bool = true) {
        self.id = id
        self.name = name
        self.time = time
        self.colorHex = colorHex
        self.repeats = repeats
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let time = dictionary["time"] as? String ?? "00:00"
        let colorHex = dictionary["colorHex"] as? String ?? ColorPalette.randomHex()
        let repeats = dictionary["repeats"] as? Bool ?? true
        self.init(id: id, name: name, time: time, colorHex: colorHex, repeats: repeats)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "time": time,
            "colorHex": colorHex,
            "repeats": repeats
        ]
    }
}

// MARK: - Sports configuration

struct SportMetricConfig: Codable, Hashable, Identifiable {
    var id: UUID
    var key: String
    var label: String
    var unit: String
    var colorHex: String

    init(id: UUID = UUID(), key: String, label: String, unit: String, colorHex: String) {
        self.id = id
        self.key = key
        self.label = label
        self.unit = unit
        self.colorHex = colorHex
    }

    init?(dictionary: [String: Any]) {
        guard let key = dictionary["key"] as? String,
              let label = dictionary["label"] as? String,
              let unit = dictionary["unit"] as? String,
              let colorHex = dictionary["colorHex"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.key = key
        self.label = label
        self.unit = unit
        self.colorHex = colorHex
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "key": key,
            "label": label,
            "unit": unit,
            "colorHex": colorHex
        ]
    }
}

struct WeightExerciseDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var targetWeight: String?
    var targetSets: String?
    var targetReps: String?

    init(id: UUID = UUID(), name: String, targetWeight: String? = nil, targetSets: String? = nil, targetReps: String? = nil) {
        self.id = id
        self.name = name
        self.targetWeight = targetWeight
        self.targetSets = targetSets
        self.targetReps = targetReps
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.name = name
        self.targetWeight = dictionary["targetWeight"] as? String
        self.targetSets = dictionary["targetSets"] as? String
        self.targetReps = dictionary["targetReps"] as? String
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name
        ]
        if let targetWeight { dict["targetWeight"] = targetWeight }
        if let targetSets { dict["targetSets"] = targetSets }
        if let targetReps { dict["targetReps"] = targetReps }
        return dict
    }
}

struct WeightGroupDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var exercises: [WeightExerciseDefinition]

    init(id: UUID = UUID(), name: String, exercises: [WeightExerciseDefinition]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.name = name
        let exerciseDicts = dictionary["exercises"] as? [[String: Any]] ?? []
        let exercises = exerciseDicts.compactMap { WeightExerciseDefinition(dictionary: $0) }
        self.exercises = exercises
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "exercises": exercises.map { $0.asDictionary }
        ]
    }

    static var defaults: [WeightGroupDefinition] {
        return []
    }
}

struct SportConfig: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var colorHex: String
    var metrics: [SportMetricConfig]

    init(id: UUID = UUID(), name: String, colorHex: String, metrics: [SportMetricConfig]) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.metrics = metrics
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let colorHex = dictionary["colorHex"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.name = name
        self.colorHex = colorHex
        let metricDicts = dictionary["metrics"] as? [[String: Any]] ?? []
        self.metrics = metricDicts.compactMap { SportMetricConfig(dictionary: $0) }
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "colorHex": colorHex,
            "metrics": metrics.map { $0.asDictionary }
        ]
    }

    static var defaults: [SportConfig] {
        [
            SportConfig(
                name: "Running",
                colorHex: "#007AFF",
                metrics: [
                    SportMetricConfig(key: "distanceKm", label: "Distance", unit: "km", colorHex: "#0A84FF"),
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "speedKmhComputed", label: "Speed (calc)", unit: "km/h", colorHex: "#FF9500")
                ]
            ),
            SportConfig(
                name: "Cycling",
                colorHex: "#34C759",
                metrics: [
                    SportMetricConfig(key: "distanceKm", label: "Distance", unit: "km", colorHex: "#0A84FF"),
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "speedKmhComputed", label: "Speed (calc)", unit: "km/h", colorHex: "#FF9500")
                ]
            ),
            SportConfig(
                name: "Swimming",
                colorHex: "#AF52DE",
                metrics: [
                    SportMetricConfig(key: "distanceKm", label: "Distance", unit: "km", colorHex: "#0A84FF"),
                    SportMetricConfig(key: "laps", label: "Laps", unit: "laps", colorHex: "#AF52DE"),
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759")
                ]
            ),
            SportConfig(
                name: "Team Sports",
                colorHex: "#30B0C7",
                metrics: [
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "attemptsMade", label: "Attempts Made", unit: "count", colorHex: "#30B0C7"),
                    SportMetricConfig(key: "attemptsMissed", label: "Attempts Missed", unit: "count", colorHex: "#FF3B30"),
                    SportMetricConfig(key: "accuracyComputed", label: "Accuracy (calc)", unit: "%", colorHex: "#FFD60A")
                ]
            ),
            SportConfig(
                name: "Martial Arts",
                colorHex: "#5856D6",
                metrics: [
                    SportMetricConfig(key: "rounds", label: "Rounds", unit: "rounds", colorHex: "#5856D6"),
                    SportMetricConfig(key: "roundDuration", label: "Round Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "points", label: "Points", unit: "pts", colorHex: "#FF2D55")
                ]
            ),
            SportConfig(
                name: "Pilates/Yoga",
                colorHex: "#8E8E93",
                metrics: [
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "holdTime", label: "Hold Time", unit: "sec", colorHex: "#5AC8FA"),
                    SportMetricConfig(key: "poses", label: "Poses", unit: "poses", colorHex: "#A2845E")
                ]
            ),
            SportConfig(
                name: "Climbing",
                colorHex: "#8E8E93",
                metrics: [
                    SportMetricConfig(key: "altitude", label: "Altitude", unit: "m", colorHex: "#8E8E93"),
                    SportMetricConfig(key: "timeToPeak", label: "Time to Peak", unit: "min", colorHex: "#0A84FF"),
                    SportMetricConfig(key: "restTime", label: "Rest Time", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759")
                ]
            ),
            SportConfig(
                name: "Padel",
                colorHex: "#FF2D55",
                metrics: [
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "attemptsMade", label: "Attempts Made", unit: "count", colorHex: "#30B0C7"),
                    SportMetricConfig(key: "points", label: "Points", unit: "pts", colorHex: "#FF2D55")
                ]
            ),
            SportConfig(
                name: "Tennis",
                colorHex: "#FF9500",
                metrics: [
                    SportMetricConfig(key: "durationMin", label: "Duration", unit: "min", colorHex: "#34C759"),
                    SportMetricConfig(key: "attemptsMade", label: "Attempts Made", unit: "count", colorHex: "#30B0C7"),
                    SportMetricConfig(key: "attemptsMissed", label: "Attempts Missed", unit: "count", colorHex: "#FF3B30"),
                    SportMetricConfig(key: "accuracy", label: "Accuracy", unit: "%", colorHex: "#FFD60A"),
                    SportMetricConfig(key: "points", label: "Points", unit: "pts", colorHex: "#FF2D55")
                ]
            )
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
        case .snack: return "Snack / Other"
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "breakfast": self = .breakfast
        case "lunch": self = .lunch
        case "dinner": self = .dinner
        case "snack", "other": self = .snack
        default: self = .snack
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

struct ItineraryTrip: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var events: [ItineraryEvent]
    var points: [TripPoint]

    init(id: String = UUID().uuidString, title: String, startDate: Date? = nil, endDate: Date? = nil, events: [ItineraryEvent] = [], points: [TripPoint] = []) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.events = events
        self.points = points
    }

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, events, points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.events = try container.decodeIfPresent([ItineraryEvent].self, forKey: .events) ?? []
        self.points = try container.decodeIfPresent([TripPoint].self, forKey: .points) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(events, forKey: .events)
        try container.encode(points, forKey: .points)
    }

    init?(dictionary: [String: Any]) {
        let id = dictionary["id"] as? String ?? UUID().uuidString
        guard let title = dictionary["title"] as? String else { return nil }
        
        // Handle potential Timestamp or Date or Double
        var startDate: Date?
        if let startTimestamp = dictionary["startDate"] as? Timestamp {
            startDate = startTimestamp.dateValue()
        } else if let startDouble = dictionary["startDate"] as? Double {
            startDate = Date(timeIntervalSince1970: startDouble)
        }
        
        var endDate: Date?
        if let endTimestamp = dictionary["endDate"] as? Timestamp {
            endDate = endTimestamp.dateValue()
        } else if let endDouble = dictionary["endDate"] as? Double {
            endDate = Date(timeIntervalSince1970: endDouble)
        }
        
        let eventsDict = dictionary["events"] as? [[String: Any]] ?? []
        let events = eventsDict.compactMap { ItineraryEvent(dictionary: $0) }
        
        let pointsDict = dictionary["points"] as? [[String: Any]] ?? []
        // Assuming TripPoint has a dictionary init or we handle it here
        let points = pointsDict.compactMap { dict -> TripPoint? in
            guard let lat = (dict["latitude"] as? NSNumber)?.doubleValue ?? dict["latitude"] as? Double,
                  let lng = (dict["longitude"] as? NSNumber)?.doubleValue ?? dict["longitude"] as? Double,
                  let timestamp = dict["timestamp"] as? Date ?? (dict["timestamp"] as? Timestamp)?.dateValue() else { return nil }
            return TripPoint(
                id: dict["id"] as? String ?? UUID().uuidString,
                latitude: lat,
                longitude: lng,
                timestamp: timestamp,
                title: dict["title"] as? String,
                imageURLs: dict["imageURLs"] as? [String],
                imagesData: nil
            )
        }
        
        self.init(id: id, title: title, startDate: startDate, endDate: endDate, events: events, points: points)
    }

    var asFirestoreDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "events": events.map { $0.asFirestoreDictionary() },
            "points": points.map { [
                "id": $0.id,
                "latitude": $0.latitude,
                "longitude": $0.longitude,
                "timestamp": Timestamp(date: $0.timestamp),
                "title": $0.title as Any,
                "imageURLs": $0.imageURLs as Any
            ]}
        ]
        if let startDate { dict["startDate"] = Timestamp(date: startDate) }
        if let endDate { dict["endDate"] = Timestamp(date: endDate) }
        return dict
    }
}

enum ItineraryCategory: String, CaseIterable, Hashable {
    case activity
    case food
    case stay
    case travel
    case other

    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .food: return "Food"
        case .stay: return "Stay"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    var color: Color {
        switch self {
        case .activity: return Color(hex: "#4CAF6A") ?? .green
        case .food: return Color(hex: "#E39A3B") ?? .yellow
        case .stay: return Color(hex: "#D84A4A") ?? .red
        case .travel: return Color(hex: "#7A5FD1") ?? .purple
        case .other: return Color(hex: "#8E8E93") ?? .gray
        }
    }

    var symbol: String {
        switch self {
        case .activity: return "figure.play"
        case .food: return "fork.knife"
        case .stay: return "bed.double.fill"
        case .travel: return "figure.wave"
        case .other: return "aqi.medium"
        }
    }
}

struct ItineraryEvent: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var notes: String
    var date: Date
    var locationAdministrativeArea: String?
    var locationCountry: String?
    var locationLatitude: Double
    var locationLocality: String?
    var locationLongitude: Double
    var locationName: String?
    var locationPostcode: String?
    var locationSubThoroughfare: String?
    var locationThoroughfare: String?
    var type: String
    var photoData: Data?
    var pdfData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        date: Date,
        locationAdministrativeArea: String? = nil,
        locationCountry: String? = nil,
        locationLatitude: Double = 0.0,
        locationLocality: String? = nil,
        locationLongitude: Double = 0.0,
        locationName: String? = nil,
        locationPostcode: String? = nil,
        locationSubThoroughfare: String? = nil,
        locationThoroughfare: String? = nil,
        type: String = "other",
        photoData: Data? = nil,
        pdfData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.date = date
        self.locationAdministrativeArea = locationAdministrativeArea
        self.locationCountry = locationCountry
        self.locationLatitude = locationLatitude
        self.locationLocality = locationLocality
        self.locationLongitude = locationLongitude
        self.locationName = locationName
        self.locationPostcode = locationPostcode
        self.locationSubThoroughfare = locationSubThoroughfare
        self.locationThoroughfare = locationThoroughfare
        self.type = type
        self.photoData = photoData
        self.pdfData = pdfData
    }

    init?(dictionary: [String: Any]) {
        guard
            let name = dictionary["name"] as? String,
            let date = dictionary["date"] as? Date ?? (dictionary["date"] as? Timestamp)?.dateValue()
        else { return nil }

        let idRaw = dictionary["id"] as? String
        let id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        let notes = dictionary["notes"] as? String ?? ""
        let type = dictionary["type"] as? String ?? "other"
        let locationAdministrativeArea = dictionary["locationAdministrativeArea"] as? String
        let locationCountry = dictionary["locationCountry"] as? String
        let locationLatitude = (dictionary["locationLatitude"] as? NSNumber)?.doubleValue ?? dictionary["locationLatitude"] as? Double ?? 0
        let locationLocality = dictionary["locationLocality"] as? String
        let locationLongitude = (dictionary["locationLongitude"] as? NSNumber)?.doubleValue ?? dictionary["locationLongitude"] as? Double ?? 0
        let locationName = dictionary["locationName"] as? String
        let locationPostcode = dictionary["locationPostcode"] as? String
        let locationSubThoroughfare = dictionary["locationSubThoroughfare"] as? String
        let locationThoroughfare = dictionary["locationThoroughfare"] as? String

        var decodedPhoto: Data? = nil
        if let base64 = dictionary["photoDataBase64"] as? String {
            decodedPhoto = Data(base64Encoded: base64)
        } else if let rawData = dictionary["photoData"] as? Data {
            decodedPhoto = rawData
        }

        var decodedPDF: Data? = nil
        if let base64 = dictionary["pdfDataBase64"] as? String {
            decodedPDF = Data(base64Encoded: base64)
        } else if let rawData = dictionary["pdfData"] as? Data {
            decodedPDF = rawData
        }

        self.init(
            id: id,
            name: name,
            notes: notes,
            date: date,
            locationAdministrativeArea: locationAdministrativeArea,
            locationCountry: locationCountry,
            locationLatitude: locationLatitude,
            locationLocality: locationLocality,
            locationLongitude: locationLongitude,
            locationName: locationName,
            locationPostcode: locationPostcode,
            locationSubThoroughfare: locationSubThoroughfare,
            locationThoroughfare: locationThoroughfare,
            type: type,
            photoData: decodedPhoto,
            pdfData: decodedPDF
        )
    }

    var category: ItineraryCategory {
        ItineraryCategory(rawValue: type) ?? .other
    }

    var coordinate: CLLocationCoordinate2D? {
        if locationLatitude == 0 && locationLongitude == 0 { return nil }
        return CLLocationCoordinate2D(latitude: locationLatitude, longitude: locationLongitude)
    }

    var timeWindowLabel: String {
        ItineraryEvent.timeFormatter.string(from: date)
    }

    var asDictionary: [String: Any] { asFirestoreDictionary() }

    func asFirestoreDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "notes": notes,
            "date": Timestamp(date: date),
            "locationLatitude": locationLatitude,
            "locationLongitude": locationLongitude,
            "type": type
        ]

        if let locationAdministrativeArea { dict["locationAdministrativeArea"] = locationAdministrativeArea }
        if let locationCountry { dict["locationCountry"] = locationCountry }
        if let locationLocality { dict["locationLocality"] = locationLocality }
        if let locationName { dict["locationName"] = locationName }
        if let locationPostcode { dict["locationPostcode"] = locationPostcode }
        if let locationSubThoroughfare { dict["locationSubThoroughfare"] = locationSubThoroughfare }
        if let locationThoroughfare { dict["locationThoroughfare"] = locationThoroughfare }
        if let photoData {
             dict["photoDataBase64"] = photoData.base64EncodedString()
        }
           if let pdfData {
               dict["pdfDataBase64"] = pdfData.base64EncodedString()
           }
        return dict
    }

    static var mockEvents: [ItineraryEvent] {
        let calendar = Calendar.current

        func dateFor(day: Int, hour: Int, minute: Int) -> Date {
            var comps = DateComponents()
            comps.year = 2025
            comps.month = 12
            comps.day = day
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps) ?? Date()
        }

        return [
            ItineraryEvent(
                id: UUID(),
                name: "Car Pickup",
                notes: "Collect compact SUV from Avia Car Rental. Bring driving license and booking confirmation.",
                date: dateFor(day: 19, hour: 12, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.65,
                locationLocality: "Seminyak",
                locationLongitude: 115.136,
                locationName: "Avia Car Rental",
                locationPostcode: "80361",
                locationSubThoroughfare: "12",
                locationThoroughfare: "Jalan Raya Seminyak",
                type: "travel"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Check‑in",
                notes: "Early check-in requested; confirm room preference at reception.",
                date: dateFor(day: 19, hour: 14, minute: 0),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6485,
                locationLocality: "Seminyak",
                locationLongitude: 115.1385,
                locationName: "Tuscany Boutique Hotel",
                locationPostcode: "80361",
                locationSubThoroughfare: "5",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "stay"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Shopping Spree",
                notes: "Pick up a local SIM card and grab sunscreen before heading to the beach.",
                date: dateFor(day: 19, hour: 16, minute: 0),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6520,
                locationLocality: "Seminyak",
                locationLongitude: 115.1340,
                locationName: "Seminyak Square",
                locationPostcode: "80361",
                locationSubThoroughfare: "2",
                locationThoroughfare: "Jalan Oberoi",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Lunch with Damian",
                notes: "$15 lunch special - try the pescado tacos.",
                date: dateFor(day: 19, hour: 17, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6470,
                locationLocality: "Seminyak",
                locationLongitude: 115.1390,
                locationName: "La Taqueria",
                locationPostcode: "80361",
                locationSubThoroughfare: "8",
                locationThoroughfare: "Jalan Laksmana",
                type: "food"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Morning Markets",
                notes: "Local market for breakfast and fresh fruit. Meet tour guide here.",
                date: dateFor(day: 20, hour: 9, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6490,
                locationLocality: "Seminyak",
                locationLongitude: 115.1370,
                locationName: "Kayu Aya Market",
                locationPostcode: "80361",
                locationSubThoroughfare: "20",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Coffee",
                notes: "Quick coffee and meet with the day’s walking tour leader.",
                date: dateFor(day: 20, hour: 10, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6510,
                locationLocality: "Seminyak",
                locationLongitude: 115.1355,
                locationName: "Vessel Cafe",
                locationPostcode: "80361",
                locationSubThoroughfare: "7",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "activity"
            ),
            ItineraryEvent(
                id: UUID(),
                name: "Hot Dogs",
                notes: "Casual lunch spot - local favorite. Try the special.",
                date: dateFor(day: 20, hour: 12, minute: 30),
                locationAdministrativeArea: "Bali",
                locationCountry: "ID",
                locationLatitude: -8.6505,
                locationLocality: "Seminyak",
                locationLongitude: 115.1365,
                locationName: "Vinnie’s Hot Dogs",
                locationPostcode: "80361",
                locationSubThoroughfare: "3",
                locationThoroughfare: "Jalan Kayu Aya",
                type: "food"
            )
        ]
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df
    }()
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
        if let base64 = dictionary["photoDataBase64"] as? String {
            decodedPhoto = Data(base64Encoded: base64)
        } else if let base64 = dictionary["photoData"] as? String {
            decodedPhoto = Data(base64Encoded: base64)
        } else if let rawData = dictionary["photoData"] as? Data {
            decodedPhoto = rawData
        }

        self.init(id: id, date: timestamp, weight: weight, waterPercent: waterPercent, bodyFatPercent: bodyFatPercent, photoData: decodedPhoto)
    }

    var asDictionary: [String: Any] { asFirestoreDictionary() }

    func asFirestoreDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            // Explicit Timestamp avoids nested entity errors when mixing Date types.
            "date": Timestamp(date: date),
            "weight": weight
        ]

        if let waterPercent { dict["waterPercent"] = waterPercent }
        if let bodyFatPercent { dict["bodyFatPercent"] = bodyFatPercent }
        if let photoData {
            dict["photoDataBase64"] = photoData.base64EncodedString()
        }
        return dict
    }
}

enum BodyPart: String, Codable, CaseIterable {
    // Front
    case head, neck, chest, abdomen, upperBack, lowerBack
    case leftShoulder, rightShoulder
    case leftUpperArm, rightUpperArm
    case leftForearm, rightForearm
    case leftHand, rightHand
    case leftThigh, rightThigh
    case leftShin, rightShin
    case leftFoot, rightFoot
    case hips
    // Back variants for arms/legs if needed, but generic L/R usually suffices unless
    // distinct back muscles (hams/calves/glutes) are required.
    // Let's add specific back muscle groups:
    case leftGlute, rightGlute
    case leftHamstring, rightHamstring
    case leftCalf, rightCalf
    // Back torso
    case trapezius, lats // simplistic mapping to upperBack? Let's use generic regions for now.
    
    var displayName: String {
        switch self {
        case .head: return "Head"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .abdomen: return "Abdomen"
        case .upperBack: return "Upper Back"
        case .lowerBack: return "Lower Back"
        case .leftShoulder: return "Left Shoulder"
        case .rightShoulder: return "Right Shoulder"
        case .leftUpperArm: return "Left Upper Arm"
        case .rightUpperArm: return "Right Upper Arm"
        case .leftForearm: return "Left Forearm"
        case .rightForearm: return "Right Forearm"
        case .leftHand: return "Left Hand"
        case .rightHand: return "Right Hand"
        case .leftThigh: return "Left Thigh"
        case .rightThigh: return "Right Thigh"
        case .leftShin: return "Left Shin"
        case .rightShin: return "Right Shin"
        case .leftFoot: return "Left Foot"
        case .rightFoot: return "Right Foot"
        case .hips: return "Hips"
        case .leftGlute: return "Left Glute"
        case .rightGlute: return "Right Glute"
        case .leftHamstring: return "Left Hamstring"
        case .rightHamstring: return "Right Hamstring"
        case .leftCalf: return "Left Calf"
        case .rightCalf: return "Right Calf"
        case .trapezius: return "Trapezius"
        case .lats: return "Lats"
        }
    }
}


struct Injury: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var dateOccurred: Date
    var durationDays: Int
    var dos: String
    var donts: String
    // Deprecated exact coordinates in favor of bodyPart
    var locationX: Double
    var locationY: Double
    var isFront: Bool
    var bodyPart: BodyPart?

    init(
        id: UUID = UUID(),
        name: String,
        dateOccurred: Date = Date(),
        durationDays: Int = 14,
        dos: String = "",
        donts: String = "",
        locationX: Double = 0.5,
        locationY: Double = 0.5,
        isFront: Bool = true,
        bodyPart: BodyPart? = nil
    ) {
        self.id = id
        self.name = name
        self.dateOccurred = dateOccurred
        self.durationDays = durationDays
        self.dos = dos
        self.donts = donts
        self.locationX = locationX
        self.locationY = locationY
        self.isFront = isFront
        self.bodyPart = bodyPart
    }
    
    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.name = name
        self.dateOccurred = dictionary["dateOccurred"] as? Date ?? (dictionary["dateOccurred"] as? Timestamp)?.dateValue() ?? Date()
        self.durationDays = dictionary["durationDays"] as? Int ?? 14
        self.dos = dictionary["dos"] as? String ?? ""
        self.donts = dictionary["donts"] as? String ?? ""
        self.locationX = dictionary["locationX"] as? Double ?? 0.5
        self.locationY = dictionary["locationY"] as? Double ?? 0.5
        self.isFront = dictionary["isFront"] as? Bool ?? true
        
        if let partRaw = dictionary["bodyPart"] as? String {
            self.bodyPart = BodyPart(rawValue: partRaw)
        }
    }

    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "dateOccurred": Timestamp(date: dateOccurred),
            "durationDays": durationDays,
            "dos": dos,
            "donts": donts,
            "locationX": locationX,
            "locationY": locationY,
            "isFront": isFront
        ]
        if let bodyPart {
            dict["bodyPart"] = bodyPart.rawValue
        }
        return dict
    }

    enum CodingKeys: String, CodingKey {
        case id, name, dateOccurred, durationDays, dos, donts, locationX, locationY, isFront, bodyPart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Injury"
        
        if let date = try container.decodeIfPresent(Date.self, forKey: .dateOccurred) {
            self.dateOccurred = date
        } else {
            self.dateOccurred = Date()
        }
        
        self.durationDays = try container.decodeIfPresent(Int.self, forKey: .durationDays) ?? 14
        self.dos = try container.decodeIfPresent(String.self, forKey: .dos) ?? ""
        self.donts = try container.decodeIfPresent(String.self, forKey: .donts) ?? ""
        self.locationX = try container.decodeIfPresent(Double.self, forKey: .locationX) ?? 0.5
        self.locationY = try container.decodeIfPresent(Double.self, forKey: .locationY) ?? 0.5
        self.isFront = try container.decodeIfPresent(Bool.self, forKey: .isFront) ?? true
        self.bodyPart = try container.decodeIfPresent(BodyPart.self, forKey: .bodyPart)
    }
}

@Model
class Account: ObservableObject {
    static var deviceCurrencySymbol: String {
        if let symbol = Locale.current.currencySymbol, !symbol.isEmpty {
            return symbol
        }
        if let identifier = Locale.current.currency?.identifier, !identifier.isEmpty {
            return identifier
        }
        return "$"
    }
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
            guard !isDeleted else { return nil }
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
    var calorieGoal: Int = 0
    var weightGoalRaw: String? = nil
    var macroStrategyRaw: String? = nil
    var intermittentFastingMinutes: Int = 16 * 60
    var theme: String? = nil
    var unitSystem: String? = nil
    var activityLevel: String? = nil
    var startWeekOn: String? = nil
    var autoRestDayIndices: [Int] = []
    var caloriesBurnGoal: Int = 800
    var stepsGoal: Int = 10_000
    var distanceGoal: Double = 3_000 // meters
    var workoutSchedule: [WorkoutScheduleItem] = WorkoutScheduleItem.defaults
    var mealSchedule: [MealScheduleItem] = MealScheduleItem.defaults
    var mealCatalog: [CatalogMeal] = []
    var trackedMacros: [TrackedMacro] = []
    var cravings: [CravingItem] = []
    var workoutSupplements: [Supplement] = []
    var nutritionSupplements: [Supplement] = []
    var dailyTasks: [DailyTaskDefinition] = []
    var groceryItems: [GroceryItem] = GroceryItem.sampleItems()
    var expenseCategories: [ExpenseCategory] = ExpenseCategory.defaultCategories()
    var expenseCurrencySymbol: String = Account.deviceCurrencySymbol
    var goals: [GoalItem] = GoalItem.sampleDefaults()
    var habits: [HabitDefinition] = HabitDefinition.defaults
    var mealReminders: [MealReminder] = MealReminder.defaults
    var weeklyProgress: [WeeklyProgressRecord] = []
    var itineraryEvents: [ItineraryEvent] = []
    var itineraryTrips: [ItineraryTrip] = []
    var sports: [SportConfig] = []
    var soloMetrics: [SoloMetric] = SoloMetric.defaultMetrics
    var teamMetrics: [TeamMetric] = TeamMetric.defaultMetrics
    var weightGroups: [WeightGroupDefinition] = []
    var activityTimers: [ActivityTimerItem] = ActivityTimerItem.defaultTimers
    var injuries: [Injury] = []
    var trialPeriodEnd: Date? = nil
    var proPeriodEnd: Date? = nil
    var subscriptionStatus: String? = nil
    var subscriptionStatusUpdatedAt: Date? = nil
    var didCompleteOnboarding: Bool = false
    var googleRefreshToken: String? = nil

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
        calorieGoal: Int = 0,
        weightGoalRaw: String? = nil,
        macroStrategyRaw: String? = nil,
        intermittentFastingMinutes: Int = 16 * 60,
        theme: String? = nil,
        unitSystem: String? = nil,
        activityLevel: String? = nil,
        startWeekOn: String? = nil,
        autoRestDayIndices: [Int] = [],
        workoutSchedule: [WorkoutScheduleItem] = WorkoutScheduleItem.defaults,
        mealSchedule: [MealScheduleItem] = MealScheduleItem.defaults,
        mealCatalog: [CatalogMeal] = [],
        trackedMacros: [TrackedMacro] = [],
        cravings: [CravingItem] = [],
        groceryItems: [GroceryItem] = GroceryItem.sampleItems(),
        expenseCategories: [ExpenseCategory] = ExpenseCategory.defaultCategories(),
        expenseCurrencySymbol: String = Account.deviceCurrencySymbol,
        goals: [GoalItem] = GoalItem.sampleDefaults(),
        habits: [HabitDefinition] = HabitDefinition.defaults,
        mealReminders: [MealReminder] = MealReminder.defaults,
        weeklyProgress: [WeeklyProgressRecord] = [],
        workoutSupplements: [Supplement] = [],
        nutritionSupplements: [Supplement] = [],
        dailyTasks: [DailyTaskDefinition] = [],
        itineraryEvents: [ItineraryEvent] = [],
        itineraryTrips: [ItineraryTrip] = [],
        sports: [SportConfig] = [],
        soloMetrics: [SoloMetric] = SoloMetric.defaultMetrics,
        teamMetrics: [TeamMetric] = TeamMetric.defaultMetrics,
        caloriesBurnGoal: Int = 800,
        stepsGoal: Int = 10_000,
        distanceGoal: Double = 3_000,
        weightGroups: [WeightGroupDefinition] = [],
        activityTimers: [ActivityTimerItem] = ActivityTimerItem.defaultTimers,
        injuries: [Injury] = [],
        trialPeriodEnd: Date? = nil,
        proPeriodEnd: Date? = nil,
        subscriptionStatus: String? = nil,
        subscriptionStatusUpdatedAt: Date? = nil,
        didCompleteOnboarding: Bool = false,
        googleRefreshToken: String? = nil
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
        self.calorieGoal = calorieGoal
        self.weightGoalRaw = weightGoalRaw
        self.macroStrategyRaw = macroStrategyRaw
        self.intermittentFastingMinutes = intermittentFastingMinutes
        self.theme = theme
        self.unitSystem = unitSystem
        self.activityLevel = activityLevel
        self.startWeekOn = startWeekOn
        self.autoRestDayIndices = autoRestDayIndices
        self.workoutSchedule = workoutSchedule
        self.mealSchedule = mealSchedule
        self.mealCatalog = mealCatalog
        self.caloriesBurnGoal = caloriesBurnGoal
        self.stepsGoal = stepsGoal
        self.distanceGoal = distanceGoal
        self.trackedMacros = trackedMacros
        self.cravings = cravings
        self.groceryItems = groceryItems
        self.expenseCategories = expenseCategories
        self.expenseCurrencySymbol = expenseCurrencySymbol
        self.goals = goals
        self.habits = habits
        self.mealReminders = mealReminders
        self.weeklyProgress = weeklyProgress
        self.workoutSupplements = workoutSupplements
        self.nutritionSupplements = nutritionSupplements
        self.dailyTasks = dailyTasks
        self.itineraryEvents = itineraryEvents
        self.itineraryTrips = itineraryTrips
        self.sports = sports
        self.soloMetrics = soloMetrics
        self.teamMetrics = teamMetrics
        self.weightGroups = weightGroups
        self.activityTimers = activityTimers
        self.injuries = injuries
        self.trialPeriodEnd = trialPeriodEnd
        self.proPeriodEnd = proPeriodEnd
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionStatusUpdatedAt = subscriptionStatusUpdatedAt
        self.didCompleteOnboarding = didCompleteOnboarding
        self.googleRefreshToken = googleRefreshToken
    }

    /// Safely sync cravings from Firestore on first appear. This will only
    /// replace local `cravings` when the local list is empty and the remote
    /// list has values — avoiding accidental overwrites on view appear.
    @MainActor
    func syncCravingsIfNeeded(service: AccountFirestoreService, completion: ((Bool) -> Void)? = nil) {
        guard let id = self.id, !id.isEmpty else {
            completion?(false)
            return
        }

        service.fetchCravings(withId: id) { remote in
            guard let remote = remote else {
                completion?(false)
                return
            }

            // Only adopt remote cravings when local is empty to avoid
            // overwriting user or cached data that may be intentionally set.
            if self.cravings.isEmpty && !remote.isEmpty {
                Task { @MainActor in
                    self.cravings = remote
                    completion?(true)
                }
            } else {
                completion?(false)
            }
        }
    }

    /// Explicitly persist cravings to Firestore. Call this only when the
    /// user has intentionally modified cravings (e.g. Save/Done).
    func saveCravings(service: AccountFirestoreService, completion: @escaping (Bool) -> Void) {
        guard let id = self.id, !id.isEmpty else {
            completion(false)
            return
        }
        service.updateCravings(withId: id, cravings: self.cravings, completion: completion)
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

    func toHexString(fallback: String = "#FF3B30") -> String {
        return toHex() ?? fallback
    }

    func toHexString() -> String {
        return toHexString(fallback: "#FF3B30")
    }
}
