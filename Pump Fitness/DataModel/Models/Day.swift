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

struct MealMacroEntry: Codable, Hashable, Identifiable {
    var id: String
    var trackedMacroId: String
    var name: String
    var unit: String
    var amount: Double

    init(
        id: String = UUID().uuidString,
        trackedMacroId: String,
        name: String,
        unit: String,
        amount: Double = 0
    ) {
        self.id = id
        self.trackedMacroId = trackedMacroId
        self.name = name
        self.unit = unit
        self.amount = amount
    }

    init?(dictionary: [String: Any]) {
        guard let trackedMacroId = dictionary["trackedMacroId"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let name = dictionary["name"] as? String ?? ""
        let unit = dictionary["unit"] as? String ?? "g"
        let amount = (dictionary["amount"] as? NSNumber)?.doubleValue ?? dictionary["amount"] as? Double ?? 0
        self.init(id: id, trackedMacroId: trackedMacroId, name: name, unit: unit, amount: amount)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "trackedMacroId": trackedMacroId,
            "name": name,
            "unit": unit,
            "amount": amount
        ]
    }
}

struct MealIntakeEntry: Codable, Hashable, Identifiable {
    var id: String
    var mealType: MealType
    var itemName: String
    var quantityPerServing: String
    var calories: Int
    var macros: [MealMacroEntry]

    init(
        id: String = UUID().uuidString,
        mealType: MealType,
        itemName: String,
        quantityPerServing: String,
        calories: Int,
        macros: [MealMacroEntry]
    ) {
        self.id = id
        self.mealType = mealType
        self.itemName = itemName
        self.quantityPerServing = quantityPerServing
        self.calories = calories
        self.macros = macros
    }

    init?(dictionary: [String: Any]) {
        guard
            let rawType = dictionary["mealType"] as? String,
            let mealType = MealType(rawValue: rawType)
        else { return nil }

        let id = dictionary["id"] as? String ?? UUID().uuidString
        let itemName = dictionary["itemName"] as? String ?? ""
        let quantity = dictionary["quantityPerServing"] as? String ?? ""
        let calories = dictionary["calories"] as? Int ?? (dictionary["calories"] as? NSNumber)?.intValue ?? 0
        let macrosRaw = dictionary["macros"] as? [[String: Any]] ?? []
        let macros = macrosRaw.compactMap { MealMacroEntry(dictionary: $0) }

        self.init(
            id: id,
            mealType: mealType,
            itemName: itemName,
            quantityPerServing: quantity,
            calories: calories,
            macros: macros
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "mealType": mealType.rawValue,
            "itemName": itemName,
            "quantityPerServing": quantityPerServing,
            "calories": calories,
            "macros": macros.map { $0.asDictionary }
        ]
    }
}

struct DailyTaskCompletion: Codable, Hashable, Identifiable {
    var id: String
    var isCompleted: Bool

    init(id: String, isCompleted: Bool = false) {
        self.id = id
        self.isCompleted = isCompleted
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String else { return nil }
        let completed = dictionary["isCompleted"] as? Bool ?? false
        self.init(id: id, isCompleted: completed)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "isCompleted": isCompleted
        ]
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

    // macro focus stored as rawValue (e.g. "leanCutting", "lowCarb", "balanced", "leanBulking", "custom")
    var macroFocusRaw: String?

    // per-macro consumption for this day (mirrors tracked macros from Account)
    var macroConsumptions: [MacroConsumption]

    // meal completion checklist (stores MealType raw values)
    var completedMeals: [String] = []

    // list of supplement ids taken for this day (corresponds to Account.Supplement.id)
    var takenSupplements: [String] = []

    // list of workout-specific supplement ids taken for this day
    var takenWorkoutSupplements: [String] = []

    // logged meals/intakes for this day
    var mealIntakes: [MealIntakeEntry] = []

    // per-task completion state for this day (by task id)
    var dailyTaskCompletions: [DailyTaskCompletion] = []

    // activity metrics for this day
    var caloriesBurned: Double = 0
    var stepsTaken: Double = 0
    var distanceTravelled: Double = 0

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
        completedMeals: [String] = [],
        takenSupplements: [String] = [],
        takenWorkoutSupplements: [String] = [],
        mealIntakes: [MealIntakeEntry] = [],
        caloriesBurned: Double = 0,
        stepsTaken: Double = 0,
        distanceTravelled: Double = 0,
        dailyTaskCompletions: [DailyTaskCompletion] = []
    ) {
        self.id = id
        // Normalize stored date to UTC start-of-day to match Firestore keys and syncing
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        self.date = cal.startOfDay(for: date)
        self.caloriesConsumed = caloriesConsumed
        self.calorieGoal = calorieGoal
        self.maintenanceCalories = maintenanceCalories
        self.macroFocusRaw = macroFocusRaw
        self.macroConsumptions = macroConsumptions
        self.completedMeals = completedMeals
        self.takenSupplements = takenSupplements
        self.takenWorkoutSupplements = takenWorkoutSupplements
        self.mealIntakes = mealIntakes
        self.caloriesBurned = caloriesBurned
        self.stepsTaken = stepsTaken
        self.distanceTravelled = distanceTravelled
        self.dailyTaskCompletions = dailyTaskCompletions
    }

    /// Fetch an existing `Day` for the provided date or create/insert one if missing.
    /// - Parameters:
    ///   - date: the date to find (normalizes to start-of-day)
    ///   - context: the active `ModelContext` to perform fetch/insert
    /// - Returns: an existing or newly created `Day` instance (inserted into `context` when created)
    static func fetchOrCreate(for date: Date, in context: ModelContext, trackedMacros: [TrackedMacro]? = nil) -> Day {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: date)

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

        // If no exact match was found, attempt a range match for the same calendar day to
        // avoid creating duplicates when the stored date isn't perfectly normalized.
        do {
            let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let rangeRequest = FetchDescriptor<Day>(predicate: #Predicate { $0.date >= dayStart && $0.date < nextDay })
            let rangeResults = try context.fetch(rangeRequest)
            if let existing = rangeResults.first {
                // Normalize the stored date so subsequent lookups hit the exact match path
                existing.date = dayStart
                try? context.save()
                return existing
            }
        } catch {
            print("Failed range fetch for Day: \(error)")
        }

        // If creating a new Day, prefer pulling goal/focus/maintenance from Account so
        // those values are Account-scoped rather than day-scoped.
        var inheritedCalorieGoal: Int = 0
        var inheritedMacroFocusRaw: String? = nil
        var inheritedMaintenance: Int = 0
        do {
            let acctReq = FetchDescriptor<Account>()
            let accounts = try context.fetch(acctReq)
            if let acct = accounts.first {
                inheritedCalorieGoal = acct.calorieGoal
                inheritedMacroFocusRaw = acct.macroFocusRaw
                inheritedMaintenance = acct.maintenanceCalories
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
                    inheritedMaintenance = Int(round(tdee))
                }
            }
        } catch {
            // ignore and fall back to any previously stored values
        }

        // If no Account values existed, fall back to last known Day values for maintenance.
        if inheritedCalorieGoal == 0 || inheritedMaintenance == 0 {
            do {
                let allRequest = FetchDescriptor<Day>()
                let allDays = try context.fetch(allRequest)
                if let last = allDays.sorted(by: { $0.date < $1.date }).last {
                    if inheritedCalorieGoal == 0 { inheritedCalorieGoal = last.calorieGoal }
                    if inheritedMacroFocusRaw == nil { inheritedMacroFocusRaw = last.macroFocusRaw }
                    if inheritedMaintenance == 0 { inheritedMaintenance = last.maintenanceCalories }
                }
            } catch {
                // ignore — defaults will be used
            }
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
            maintenanceCalories: inheritedMaintenance,
            macroFocusRaw: inheritedMacroFocusRaw,
            macroConsumptions: consumptions,
            completedMeals: [],
            takenSupplements: [],
            takenWorkoutSupplements: [],
            mealIntakes: [],
            caloriesBurned: 0,
            stepsTaken: 0,
            distanceTravelled: 0
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
        // Preserve consumed values when IDs change by matching on normalized names as a fallback.
        // Use reduce(into:) so duplicate keys won't crash; last-wins for duplicates.
        let existingById: [String: MacroConsumption] = macroConsumptions.reduce(into: [:]) { acc, item in
            acc[item.trackedMacroId] = item
        }

        let existingByName: [String: MacroConsumption] = macroConsumptions.reduce(into: [:]) { acc, item in
            acc[item.name.lowercased()] = item
        }

        var updated: [MacroConsumption] = []

        for macro in trackedMacros {
            if var existing = existingById[macro.id] {
                existing.name = macro.name
                existing.unit = macro.unit
                updated.append(existing)
                continue
            }

            if var existingByLabel = existingByName[macro.name.lowercased()] {
                existingByLabel.trackedMacroId = macro.id
                existingByLabel.name = macro.name
                existingByLabel.unit = macro.unit
                updated.append(existingByLabel)
                continue
            }

            updated.append(
                MacroConsumption(
                    trackedMacroId: macro.id,
                    name: macro.name,
                    unit: macro.unit,
                    consumed: 0
                )
            )
        }

        macroConsumptions = updated
    }
}
