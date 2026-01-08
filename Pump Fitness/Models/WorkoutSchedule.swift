import Foundation

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var hour: Int
    var minute: Int
    var description: String
    var linkedWeightGroupIds: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "",
        hour: Int = 9,
        minute: Int = 0,
        description: String = "",
        linkedWeightGroupIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.hour = hour
        self.minute = minute
        self.description = description
        self.linkedWeightGroupIds = linkedWeightGroupIds
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let colorHex = dictionary["colorHex"] as? String ?? ""
        let hour = (dictionary["hour"] as? NSNumber)?.intValue ?? 9
        let minute = (dictionary["minute"] as? NSNumber)?.intValue ?? 0
        let description = dictionary["description"] as? String ?? ""
        let linkedIdsRaw = dictionary["linkedWeightGroupIds"] as? [String] ?? []
        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            name: name,
            colorHex: colorHex,
            hour: hour,
            minute: minute,
            description: description,
            linkedWeightGroupIds: linkedIdsRaw.compactMap(UUID.init(uuidString:))
        )
    }

    // Manual Codable decoding for backward compatibility with older persisted data
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, hour, minute, description, linkedWeightGroupIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        // Handle optional/missing fields for backward compatibility
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        linkedWeightGroupIds = try container.decodeIfPresent([UUID].self, forKey: .linkedWeightGroupIds) ?? []
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "colorHex": colorHex,
            "hour": hour,
            "minute": minute,
            "description": description,
            "linkedWeightGroupIds": linkedWeightGroupIds.map { $0.uuidString }
        ]
    }

    var dateForToday: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    var formattedTime: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        let formatter = WorkoutSession.timeFormatter
        return formatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

struct WorkoutScheduleItem: Identifiable, Codable, Hashable {
    var id: UUID
    var day: String
    var sessions: [WorkoutSession]

    init(id: UUID = UUID(), day: String, sessions: [WorkoutSession]) {
        self.id = id
        self.day = day
        self.sessions = sessions
    }

    init?(dictionary: [String: Any]) {
        guard let day = dictionary["day"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let sessionDicts = dictionary["sessions"] as? [[String: Any]] ?? []
        let sessions = sessionDicts.compactMap { WorkoutSession(dictionary: $0) }
        self.init(
            id: idRaw.flatMap(UUID.init(uuidString:)) ?? UUID(),
            day: day,
            sessions: sessions
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "day": day,
            "sessions": sessions.map { $0.asDictionary }
        ]
    }

    static var defaults: [WorkoutScheduleItem] {
        [
            .init(day: "Mon", sessions: [.init(name: "Chest", colorHex: "#D84A4A", hour: 9, minute: 0)]),
            .init(day: "Tue", sessions: [
                .init(name: "Back", colorHex: "#4FB6C6", hour: 10, minute: 0),
                .init(name: "Run", hour: 18, minute: 0)
            ]),
            .init(day: "Wed", sessions: []),
            .init(day: "Thu", sessions: [.init(name: "Legs", colorHex: "#7A5FD1", hour: 9, minute: 0)]),
            .init(day: "Fri", sessions: [.init(name: "Shoulders", colorHex: "#E6C84F", hour: 8, minute: 0)]),
            .init(day: "Sat", sessions: [.init(name: "Abs", colorHex: "#4CAF6A", hour: 10, minute: 0)]),
            .init(day: "Sun", sessions: [])
        ]
    }
}

extension Weekday {
    /// Convenience initializer to map common three-letter labels back to Weekday indices.
    static func from(label: String) -> Weekday? {
        let key = label.prefix(3).lowercased()
        let indexMap: [String: Int] = [
            "mon": 0,
            "tue": 1,
            "wed": 2,
            "thu": 3,
            "fri": 4,
            "sat": 5,
            "sun": 6
        ]
        guard let idx = indexMap[key] else { return nil }
        return Weekday.allCases.first(where: { $0.id == idx })
    }
}
