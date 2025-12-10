import Foundation
import SwiftData
import SwiftUI

@Model

class Day {
    // normalized day id (optional string id like other models)
    var id: String? = UUID().uuidString

    // the date representing this day (stored as start of day)
    var date: Date

    // calories consumed for this day
    var caloriesConsumed: Int

    // the user's calorie goal for this day (mirrors UI goal)
    var calorieGoal: Int

    // macro focus stored as rawValue (e.g. "highProtein", "balanced", "lowCarb", "custom")
    var macroFocusRaw: String?

    // human friendly representation useful in previews / logs
    var dayString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    init(id: String? = UUID().uuidString, date: Date = Date(), caloriesConsumed: Int = 0, calorieGoal: Int = 0, macroFocusRaw: String? = nil) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.caloriesConsumed = caloriesConsumed
        self.calorieGoal = calorieGoal
        self.macroFocusRaw = macroFocusRaw
    }

    /// Fetch an existing `Day` for the provided date or create/insert one if missing.
    /// - Parameters:
    ///   - date: the date to find (normalizes to start-of-day)
    ///   - context: the active `ModelContext` to perform fetch/insert
    /// - Returns: an existing or newly created `Day` instance (inserted into `context` when created)
    static func fetchOrCreate(for date: Date, in context: ModelContext) -> Day {
        let dayStart = Calendar.current.startOfDay(for: date)

        // Use a FetchDescriptor with a SwiftData predicate to find an exact match on the day date.
        let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == dayStart })
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        } catch {
            // If fetch fails, fall through to creating a new Day locally
            print("Failed to fetch Day from context: \(error)")
        }

        // If creating a new Day, attempt to inherit the last-known calorie goal and macro focus
        var inheritedCalorieGoal: Int = 0
        var inheritedMacroFocusRaw: String? = nil
        do {
            let allRequest = FetchDescriptor<Day>()
            let allDays = try context.fetch(allRequest)
            if let last = allDays.sorted(by: { $0.date < $1.date }).last {
                inheritedCalorieGoal = last.calorieGoal
                inheritedMacroFocusRaw = last.macroFocusRaw
            }
        } catch {
            // ignore — defaults will be used
        }

        let newDay = Day(id: UUID().uuidString, date: dayStart, caloriesConsumed: 0, calorieGoal: inheritedCalorieGoal, macroFocusRaw: inheritedMacroFocusRaw)
        context.insert(newDay)
        return newDay
    }
}
