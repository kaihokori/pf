import Foundation

struct CravingItem: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var calories: Int
    var isChecked: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        calories: Int,
        isChecked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.isChecked = isChecked
    }

    init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let caloriesValue = (dictionary["calories"] as? NSNumber)?.intValue ?? dictionary["calories"] as? Int ?? 0
        let isCheckedValue = dictionary["isChecked"] as? Bool ?? false
        self.init(id: id, name: name, calories: caloriesValue, isChecked: isCheckedValue)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "calories": calories,
            "isChecked": isChecked
        ]
    }
}
