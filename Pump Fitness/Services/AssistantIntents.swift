#if canImport(AppIntents)
import Foundation
import AppIntents

extension Notification.Name {
    static let assistantActionRequested = Notification.Name("assistantActionRequested")
}

enum AssistantActionType: String, AppEnum, CaseIterable {
    case create = "Create"
    case read = "Read"
    case update = "Update"
    case delete = "Delete"
    case execute = "Execute"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
}

enum AssistantEntity: String, AppEnum, CaseIterable {
    case nutrition = "Nutrition"
    case workout = "Workout"
    case routine = "Routine"
    case goal = "Goal"
    case trip = "Trip"
    case grocery = "Grocery"
    case sleep = "Sleep"
    case recovery = "Recovery"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entity")
}

struct AssistantActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Assistant Action"

    @Parameter(title: "Action")
    var action: AssistantActionType

    @Parameter(title: "Entity")
    var entity: AssistantEntity

    @Parameter(title: "Identifier", default: nil)
    var identifier: String?

    @Parameter(title: "Title", default: nil)
    var titleText: String?

    @Parameter(title: "Details", default: nil)
    var details: String?

    func perform() async throws -> some IntentResult {
        let payload: [String: Any] = [
            "action": action.rawValue,
            "entity": entity.rawValue,
            "id": identifier ?? "",
            "title": titleText ?? "",
            "details": details ?? ""
        ]
        NotificationCenter.default.post(name: .assistantActionRequested, object: nil, userInfo: payload)
        return .result(value: true)
    }
}
#endif
