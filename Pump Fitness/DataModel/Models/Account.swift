import Foundation
import SwiftData
import Combine
import SwiftUI

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
    var theme: String? = nil
    var unitSystem: String? = nil
    var startWeekOn: String? = nil

    init(
        id: String? = UUID().uuidString,
        profileImage: Data? = nil,
        profileAvatar: String? = nil,
        name: String? = nil,
        gender: String? = nil,
        dateOfBirth: Date? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        theme: String? = nil,
        unitSystem: String? = nil,
        startWeekOn: String? = nil
    ) {
        self.id = id
        self.profileImage = profileImage
        self.profileAvatar = profileAvatar
        self.name = name
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.height = height
        self.weight = weight
        self.theme = theme
        self.unitSystem = unitSystem
        self.startWeekOn = startWeekOn
    }
}
