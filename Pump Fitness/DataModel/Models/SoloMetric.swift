import Foundation

struct SoloMetric: Codable, Identifiable, Hashable {
    var id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }

    static var defaultMetrics: [SoloMetric] {
        [
            SoloMetric(name: "Distance"),
            SoloMetric(name: "Laps"),
            SoloMetric(name: "Speed"),
            SoloMetric(name: "Rounds")
        ]
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        self.init(id: id, name: name)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name
        ]
    }
}
