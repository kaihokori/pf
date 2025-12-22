import Foundation
import FirebaseFirestore

struct HabitDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let colorHex = dictionary["colorHex"] as? String ?? ""
        self.id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        self.name = name
        self.colorHex = colorHex
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "colorHex": colorHex
        ]
    }

    static var defaults: [HabitDefinition] {
        [
            HabitDefinition(name: "Morning Stretch", colorHex: "#7A5FD1"),
            HabitDefinition(name: "Meditation", colorHex: "#4FB6C6"),
            HabitDefinition(name: "Read", colorHex: "#E39A3B")
        ]
    }
}

struct HabitCompletion: Codable, Hashable, Identifiable {
    var id: String
    var habitId: UUID
    var isCompleted: Bool

    init(id: String = UUID().uuidString, habitId: UUID, isCompleted: Bool) {
        self.id = id
        self.habitId = habitId
        self.isCompleted = isCompleted
    }

    init?(dictionary: [String: Any]) {
        guard let habitIdRaw = dictionary["habitId"] as? String else { return nil }
        let isCompleted = dictionary["isCompleted"] as? Bool ?? false
        self.habitId = UUID(uuidString: habitIdRaw) ?? UUID()
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.isCompleted = isCompleted
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "habitId": habitId.uuidString,
            "isCompleted": isCompleted
        ]
    }
}
