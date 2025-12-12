import Foundation
import SwiftData
import SwiftUI

struct MacroConsumption: Codable, Hashable, Identifiable {
    var id: String
    var trackedMacroId: String
    var name: String
    var unit: String
    var consumed: Double

    init(
        id: String = UUID().uuidString,
        trackedMacroId: String,
        name: String,
        unit: String,
        consumed: Double = 0
    ) {
        self.id = id
        self.trackedMacroId = trackedMacroId
        self.name = name
        self.unit = unit
        self.consumed = consumed
    }
}

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

    // the user's estimated maintenance calories for this day (RMR * activity)
    var maintenanceCalories: Int

    // macro focus stored as rawValue (e.g. "highProtein", "balanced", "lowCarb", "custom")
    var macroFocusRaw: String?

    // per-macro consumption for this day (mirrors tracked macros from Account)
    var macroConsumptions: [MacroConsumption]

    // meal completion checklist (stores MealType raw values)
    var completedMeals: [String] = []

    // human friendly representation useful in previews / logs
    var dayString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    init(
        id: String? = UUID().uuidString,
        date: Date = Date(),
        caloriesConsumed: Int = 0,
        calorieGoal: Int = 0,
        maintenanceCalories: Int = 0,
        macroFocusRaw: String? = nil,
        macroConsumptions: [MacroConsumption] = [],
        completedMeals: [String] = []
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.caloriesConsumed = caloriesConsumed
        self.calorieGoal = calorieGoal
        self.maintenanceCalories = maintenanceCalories
        self.macroFocusRaw = macroFocusRaw
        self.macroConsumptions = macroConsumptions
        self.completedMeals = completedMeals
    }

    /// Fetch an existing `Day` for the provided date or create/insert one if missing.
    /// - Parameters:
    ///   - date: the date to find (normalizes to start-of-day)
    ///   - context: the active `ModelContext` to perform fetch/insert
    /// - Returns: an existing or newly created `Day` instance (inserted into `context` when created)
    static func fetchOrCreate(for date: Date, in context: ModelContext, trackedMacros: [TrackedMacro]? = nil) -> Day {
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

        // If creating a new Day, attempt to inherit the last-known calorie goal, maintenance, and macro focus
        var inheritedCalorieGoal: Int = 0
        var inheritedMacroFocusRaw: String? = nil
        var inheritedMaintenance: Int = 0
        do {
            let allRequest = FetchDescriptor<Day>()
            let allDays = try context.fetch(allRequest)
            if let last = allDays.sorted(by: { $0.date < $1.date }).last {
                inheritedCalorieGoal = last.calorieGoal
                inheritedMacroFocusRaw = last.macroFocusRaw
                inheritedMaintenance = last.maintenanceCalories
            }
        } catch {
            // ignore — defaults will be used
        }
        // Compute a maintenance value from the Account in the local context if available,
        // otherwise inherit from the last known Day or use 0.
        var computedMaintenance = inheritedMaintenance
        do {
            let acctReq = FetchDescriptor<Account>()
            let accounts = try context.fetch(acctReq)
            if let acct = accounts.first {
                // Attempt a Mifflin-St Jeor calculation using available account fields.
                if let weight = acct.weight, let height = acct.height {
                    // Compute age if dateOfBirth exists
                    let age: Int = {
                        if let dob = acct.dateOfBirth {
                            let comps = Calendar.current.dateComponents([.year], from: dob, to: Date())
                            return comps.year ?? 30
                        }
                        return 30
                    }()

                    let genderFactor: Double = {
                        let g = acct.gender?.lowercased() ?? ""
                        if g.starts(with: "f") || g == "female" { return -161 }
                        return 5
                    }()

                    let rmr = 10.0 * weight + 6.25 * height - 5.0 * Double(age) + genderFactor
                    let tdee = rmr * 1.55 // moderate activity factor
                    computedMaintenance = Int(round(tdee))
                }
            }
        } catch {
            // ignore and fall back to inherited value
        }

        var consumptions: [MacroConsumption] = []
        if let tracked = trackedMacros {
            consumptions = tracked.map { MacroConsumption(trackedMacroId: $0.id, name: $0.name, unit: $0.unit, consumed: 0) }
        }

        let newDay = Day(
            id: UUID().uuidString,
            date: dayStart,
            caloriesConsumed: 0,
            calorieGoal: inheritedCalorieGoal,
            maintenanceCalories: computedMaintenance,
            macroFocusRaw: inheritedMacroFocusRaw,
            macroConsumptions: consumptions,
            completedMeals: []
        )
        context.insert(newDay)
        do {
            try context.save()
        } catch {
            // best-effort save; callers may save again later
            print("Day.fetchOrCreate: failed to save new Day to context: \(error)")
        }
        return newDay
    }

    /// Align this day's macro consumptions with the provided tracked macros.
    /// Adds missing macros with zero consumption and removes any stale ones.
    func ensureMacroConsumptions(for trackedMacros: [TrackedMacro]) {
        var updated = macroConsumptions

        // Add or refresh existing macros
        for macro in trackedMacros {
            if let idx = updated.firstIndex(where: { $0.trackedMacroId == macro.id }) {
                // keep existing consumed value but update name/unit in case they changed
                updated[idx].name = macro.name
                updated[idx].unit = macro.unit
            } else {
                updated.append(
                    MacroConsumption(
                        trackedMacroId: macro.id,
                        name: macro.name,
                        unit: macro.unit,
                        consumed: 0
                    )
                )
            }
        }

        // Remove consumptions for macros no longer tracked
        updated.removeAll { consumption in
            !trackedMacros.contains(where: { $0.id == consumption.trackedMacroId })
        }

        macroConsumptions = updated
    }
}
