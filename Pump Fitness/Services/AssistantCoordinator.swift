import Foundation
import SwiftData

final class AssistantCoordinator {
    static let shared = AssistantCoordinator()
    private var observer: NSObjectProtocol?

    func startListening(context: ModelContext) {
        stopListening()
        observer = NotificationCenter.default.addObserver(forName: .assistantActionRequested, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo as? [String: Any] else { return }
            Task { @MainActor in
                await self?.handle(actionPayload: info, context: context)
            }
        }
    }

    func stopListening() {
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
    }

    @MainActor
    private func handle(actionPayload: [String: Any], context: ModelContext) async {
        guard let action = actionPayload["action"] as? String,
              let entity = actionPayload["entity"] as? String else { return }

        let id = actionPayload["id"] as? String
        let title = actionPayload["title"] as? String
        let details = actionPayload["details"] as? String

        func complete(success: Bool, result: Any? = nil) {
            var info: [String: Any] = ["success": success, "action": action, "entity": entity]
            if let id { info["id"] = id }
            if let result = result { info["result"] = result }
            NotificationCenter.default.post(name: Notification.Name("assistantActionCompleted"), object: nil, userInfo: info)
        }

        switch (action.lowercased(), entity.lowercased()) {
        // MARK: - Nutrition / Meals
        case ("create", let e) where ["nutrition","meal","mealintake","food"].contains(e):
            let itemName = title ?? parseName(from: details) ?? "Food"
            let calories = parseCalories(from: details)
            let mealType = parseMealType(from: actionPayload["mealType"] as? String) ?? .snack
            let meal = MealIntakeEntry(mealType: mealType, itemName: itemName, quantityPerServing: "1", calories: calories, macros: [])
            let day = Day.fetchOrCreate(for: Date(), in: context)
            day.mealIntakes.append(meal)
            try? context.save()
            complete(success: true, result: meal.asDictionary)

        case ("read", let e) where ["nutrition","meal","mealintake","food"].contains(e):
            let day = Day.fetchOrCreate(for: Date(), in: context)
            let meals = day.mealIntakes.map { $0.asDictionary }
            complete(success: true, result: meals)

        case ("update", let e) where ["nutrition","meal","mealintake","food"].contains(e):
            guard let targetId = id else { complete(success: false); return }
            let day = Day.fetchOrCreate(for: Date(), in: context)
            if let idx = day.mealIntakes.firstIndex(where: { $0.id == targetId }) {
                if let name = title { day.mealIntakes[idx].itemName = name }
                if let details = details { day.mealIntakes[idx].calories = parseCalories(from: details) }
                try? context.save()
                complete(success: true, result: day.mealIntakes[idx].asDictionary)
            } else { complete(success: false) }

        case ("delete", let e) where ["nutrition","meal","mealintake","food"].contains(e):
            guard let targetId = id else { complete(success: false); return }
            let day = Day.fetchOrCreate(for: Date(), in: context)
            day.mealIntakes.removeAll(where: { $0.id == targetId })
            try? context.save()
            complete(success: true)

        // MARK: - Tasks / DailyTaskDefinition
        case ("create", let e) where ["task","dailytask","dailytaskdefinition"].contains(e):
            let taskName = title ?? parseName(from: details) ?? "Task"
            let time = actionPayload["time"] as? String ?? "00:00"
            let newTask = DailyTaskDefinition(name: taskName, time: time)
            if let acct = fetchAccount(in: context) {
                acct.dailyTasks.append(newTask)
                try? context.save()
                complete(success: true, result: newTask.asDictionary)
            } else { complete(success: false) }

        case ("read", let e) where ["task","dailytask","dailytaskdefinition"].contains(e):
            if let acct = fetchAccount(in: context) {
                let tasks = acct.dailyTasks.map { $0.asDictionary }
                complete(success: true, result: tasks)
            } else { complete(success: false) }

        case ("update", let e) where ["task","dailytask","dailytaskdefinition"].contains(e):
            guard let targetId = id else { complete(success: false); return }
            if let acct = fetchAccount(in: context) {
                if let idx = acct.dailyTasks.firstIndex(where: { $0.id == targetId }) {
                    if let name = title { acct.dailyTasks[idx].name = name }
                    if let time = actionPayload["time"] as? String { acct.dailyTasks[idx].time = time }
                    try? context.save()
                    complete(success: true, result: acct.dailyTasks[idx].asDictionary)
                } else { complete(success: false) }
            }

        case ("delete", let e) where ["task","dailytask","dailytaskdefinition"].contains(e):
            guard let targetId = id else { complete(success: false); return }
            if let acct = fetchAccount(in: context) {
                acct.dailyTasks.removeAll(where: { $0.id == targetId })
                try? context.save()
                complete(success: true)
            }

        // MARK: - Goals
        case ("create", "goal"):
            let titleText = title ?? parseName(from: details) ?? "Goal"
            let note = details ?? ""
            let dueDate = parseDate(from: actionPayload["dueDate"] as? String) ?? Date()
            let goal = GoalItem(title: titleText, note: note, dueDate: dueDate)
            if let acct = fetchAccount(in: context) {
                acct.goals.append(goal)
                try? context.save()
                complete(success: true, result: goal.asDictionary)
            } else { complete(success: false) }

        case ("read", "goal"):
            if let acct = fetchAccount(in: context) {
                complete(success: true, result: acct.goals.map { $0.asDictionary })
            } else { complete(success: false) }

        case ("update", "goal"):
            guard let targetId = id, let acct = fetchAccount(in: context) else { complete(success: false); return }
            if let idx = acct.goals.firstIndex(where: { $0.id.uuidString == targetId }) {
                if let name = title { acct.goals[idx].title = name }
                if let note = details { acct.goals[idx].note = note }
                if let dueDateStr = actionPayload["dueDate"] as? String, let d = parseDate(from: dueDateStr) { acct.goals[idx].dueDate = d }
                try? context.save()
                complete(success: true, result: acct.goals[idx].asDictionary)
            } else { complete(success: false) }

        case ("delete", "goal"):
            guard let targetId = id, let acct = fetchAccount(in: context) else { complete(success: false); return }
            acct.goals.removeAll(where: { $0.id.uuidString == targetId })
            try? context.save()
            complete(success: true)

        // MARK: - Account CRUD
        case ("read", "account"):
            if let acct = fetchAccount(in: context) {
                var dict: [String: Any] = ["id": acct.id as Any, "name": acct.name as Any, "calorieGoal": acct.calorieGoal]
                dict["trackedMacros"] = acct.trackedMacros.map { $0.asDictionary }
                complete(success: true, result: dict)
            } else { complete(success: false) }

        case ("update", "account"):
            if let acct = fetchAccount(in: context) {
                if let name = title { acct.name = name }
                if let calorie = actionPayload["calorieGoal"] as? Int { acct.calorieGoal = calorie }
                if let weight = actionPayload["weight"] as? Double { acct.weight = weight }
                try? context.save()
                complete(success: true)
            } else { complete(success: false) }

        // MARK: - Day-level reads/updates
        case ("read", "day"):
            let day = Day.fetchOrCreate(for: Date(), in: context)
            var dayDict: [String: Any] = ["id": day.id as Any, "date": day.dayString, "caloriesConsumed": day.caloriesConsumed, "calorieGoal": day.calorieGoal]
            dayDict["mealIntakes"] = day.mealIntakes.map { $0.asDictionary }
            dayDict["stepsTaken"] = day.stepsTaken
            complete(success: true, result: dayDict)

        case ("update", "day"):
            let day = Day.fetchOrCreate(for: Date(), in: context)
            if let calories = actionPayload["caloriesConsumed"] as? Int { day.caloriesConsumed = calories }
            if let steps = actionPayload["stepsTaken"] as? Double { day.stepsTaken = steps }
            try? context.save()
            complete(success: true)

        // MARK: - Expenses
        case ("create", "expense"):
            guard let name = title ?? parseName(from: details) else { complete(success: false); return }
            let amount = parseDouble(from: details) ?? (actionPayload["amount"] as? Double ?? 0)
            let categoryId = actionPayload["categoryId"] as? Int ?? 0
            let entry = ExpenseEntry(date: Date(), name: name, amount: amount, categoryId: categoryId)
            let day = Day.fetchOrCreate(for: Date(), in: context)
            day.expenses.append(entry)
            try? context.save()
            complete(success: true, result: entry.asDictionary)

        // MARK: - Simple fallback
        default:
            // Not handled specifically
            complete(success: false)
        }
    }

    // Helpers
    private func fetchAccount(in context: ModelContext) -> Account? {
        let req = FetchDescriptor<Account>()
        return (try? context.fetch(req))?.first
    }

    private func parseCalories(from text: String?) -> Int {
        guard let text = text else { return 0 }
        let lowered = text.lowercased()
        if let range = lowered.range(of: "(\\d{2,4})\\s*(kcal|cal)", options: .regularExpression) {
            let match = String(lowered[range])
            if let numRange = match.range(of: "\\d{2,4}", options: .regularExpression) {
                return Int(match[numRange]) ?? 0
            }
        }
        if let numRange = lowered.range(of: "\\d+", options: .regularExpression) {
            return Int(String(lowered[numRange])) ?? 0
        }
        return 0
    }

    private func parseName(from details: String?) -> String? {
        guard let details = details, !details.isEmpty else { return nil }
        return details.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first.map(String.init)
    }

    private func parseMealType(from raw: String?) -> MealType? {
        guard let raw = raw else { return nil }
        switch raw.lowercased() {
        case "breakfast": return .breakfast
        case "lunch": return .lunch
        case "dinner": return .dinner
        case "snack", "other": return .snack
        default: return nil
        }
    }

    private func parseDate(from iso: String?) -> Date? {
        guard let iso = iso else { return nil }
        let fmt = ISO8601DateFormatter()
        return fmt.date(from: iso)
    }

    private func parseDouble(from text: String?) -> Double? {
        guard let text = text else { return nil }
        if let range = text.range(of: "\\d+(\\.\\d+)?", options: .regularExpression) {
            return Double(text[range])
        }
        return nil
    }
}
