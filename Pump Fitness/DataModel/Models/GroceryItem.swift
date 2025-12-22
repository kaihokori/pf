import Foundation
import SwiftUI

struct GroceryItem: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var note: String
    var isChecked: Bool

    init(id: UUID = UUID(), title: String, note: String = "", isChecked: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.isChecked = isChecked
    }

    init?(dictionary: [String: Any]) {
        guard let title = dictionary["title"] as? String else { return nil }
        let idRaw = dictionary["id"] as? String
        let id = idRaw.flatMap(UUID.init(uuidString:)) ?? UUID()
        let note = dictionary["note"] as? String ?? ""
        let isChecked = dictionary["isChecked"] as? Bool ?? false
        self.init(id: id, title: title, note: note, isChecked: isChecked)
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "title": title,
            "note": note,
            "isChecked": isChecked
        ]
    }

    static func sampleItems() -> [GroceryItem] {
        [
            GroceryItem(title: "Apples", note: "6 ct"),
            GroceryItem(title: "Bananas", note: "6 ct"),
            GroceryItem(title: "Chicken Breast", note: "2 lbs"),
            GroceryItem(title: "Spinach", note: "1 bag"),
            GroceryItem(title: "Oats", note: "1 canister"),
            GroceryItem(title: "Almond Milk", note: "2 cartons")
        ]
    }
}
