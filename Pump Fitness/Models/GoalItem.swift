import Foundation
import FirebaseFirestore

enum GoalBucket: String, Codable, Hashable {
    case today
    case thisWeek
    case thisMonth
    case farFuture
}

struct GoalItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var note: String
    var isCompleted: Bool
    var dueDate: Date

    init(id: UUID = UUID(), title: String, note: String = "", isCompleted: Bool = false, dueDate: Date = Date()) {
        self.id = id
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }

    var bucket: GoalBucket {
        let cal = Calendar.current
        if cal.isDateInToday(dueDate) { return .today }
        if cal.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear) { return .thisWeek }
        if cal.isDate(dueDate, equalTo: Date(), toGranularity: .month) { return .thisMonth }
        return .farFuture
    }

    init?(dictionary: [String: Any]) {
        guard let title = dictionary["title"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        let note = dictionary["note"] as? String ?? ""
        let isCompleted = dictionary["isCompleted"] as? Bool ?? false

        if let ts = dictionary["dueDate"] as? Timestamp {
            self.dueDate = ts.dateValue()
        } else if let seconds = dictionary["dueDate"] as? TimeInterval {
            self.dueDate = Date(timeIntervalSince1970: seconds)
        } else if let number = dictionary["dueDate"] as? NSNumber {
            self.dueDate = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            self.dueDate = Date()
        }

        self.id = id
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "title": title,
            "note": note,
            "isCompleted": isCompleted,
            "dueDate": Timestamp(date: dueDate)
        ]
    }

    static func sampleDefaults() -> [GoalItem] {
        let cal = Calendar.current
        let today = Date()
        let weekAhead = cal.date(byAdding: .day, value: 3, to: today) ?? today
        let monthAhead = cal.date(byAdding: .day, value: 15, to: today) ?? today
        let future = cal.date(byAdding: .day, value: 45, to: today) ?? today
        return [
            GoalItem(title: "10 min Walk", note: "Post-breakfast", dueDate: today),
            GoalItem(title: "Drink 2L water/day", note: "Hydration", dueDate: weekAhead),
            GoalItem(title: "Lose 2 lbs", note: "Weight target", dueDate: monthAhead),
            GoalItem(title: "Run 50 km", note: "Cumulative", dueDate: monthAhead),
            GoalItem(title: "Achieve 10% bodyfat", note: "Long term", dueDate: future)
        ]
    }
}
