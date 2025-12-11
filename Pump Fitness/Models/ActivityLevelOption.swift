import Foundation
import SwiftUI

enum ActivityLevelOption: String, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extraActive: return "Extra Active"
        }
    }

    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }

    var explanation: String {
        switch self {
        case .sedentary:
            return "Little or no exercise"
        case .lightlyActive:
            return "Light exercise (1-3 days per week)"
        case .moderatelyActive:
            return "Moderate exercise (4-5 days per week)"
        case .veryActive:
            return "Intense exercise (6-7 days per week)"
        case .extraActive:
            return "Very intense exercise (physical job or training twice a day)"
        }
    }
}
