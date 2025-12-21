import Foundation
import SwiftData
import SwiftUI

struct MacroConsumption: Codable, Hashable, Identifiable {
    var id: String
    var trackedMacroId: String
    var name: String
    var unit: String
    var consumed: Double

    init(id: String = UUID().uuidString, trackedMacroId: String, name: String, unit: String, consumed: Double) {
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

    init(id: String = UUID().uuidString, trackedMacroId: String, name: String, unit: String, amount: Double) {
        self.id = id
        self.trackedMacroId = trackedMacroId
        self.name = name
        self.unit = unit
        self.amount = amount
    }

    init?(dictionary: [String: Any]) {
        guard let trackedMacroId = dictionary["trackedMacroId"] as? String,
              let name = dictionary["name"] as? String,
              let unit = dictionary["unit"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
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

    init(id: String = UUID().uuidString, mealType: MealType, itemName: String, quantityPerServing: String, calories: Int, macros: [MealMacroEntry]) {
        self.id = id
        self.mealType = mealType
        self.itemName = itemName
        self.quantityPerServing = quantityPerServing
        self.calories = calories
        self.macros = macros
    }

    init?(dictionary: [String: Any]) {
        guard let mealTypeRaw = dictionary["mealType"] as? String,
              let mealType = MealType(rawValue: mealTypeRaw),
              let itemName = dictionary["itemName"] as? String,
              let quantityPerServing = dictionary["quantityPerServing"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let calories = dictionary["calories"] as? Int ?? (dictionary["calories"] as? NSNumber)?.intValue ?? 0
        let macrosRaw = dictionary["macros"] as? [[String: Any]] ?? []
        let macros = macrosRaw.compactMap { MealMacroEntry(dictionary: $0) }
        self.init(id: id, mealType: mealType, itemName: itemName, quantityPerServing: quantityPerServing, calories: calories, macros: macros)
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

    init(id: String = UUID().uuidString, isCompleted: Bool) {
        self.id = id
        self.isCompleted = isCompleted
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String else { return nil }
        let isCompleted = dictionary["isCompleted"] as? Bool ?? false
        self.init(id: id, isCompleted: isCompleted)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "isCompleted": isCompleted
        ]
    }
}

struct SoloMetricValue: Codable, Hashable, Identifiable {
    var id: String
    var metricId: String
    var metricName: String
    var value: Double

    init(id: String = UUID().uuidString, metricId: String, metricName: String, value: Double) {
        self.id = id
        self.metricId = metricId
        self.metricName = metricName
        self.value = value
    }

    init?(dictionary: [String: Any]) {
        guard let metricId = dictionary["metricId"] as? String,
              let metricName = dictionary["metricName"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let value = (dictionary["value"] as? NSNumber)?.doubleValue ?? dictionary["value"] as? Double ?? 0
        self.init(id: id, metricId: metricId, metricName: metricName, value: value)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "metricId": metricId,
            "metricName": metricName,
            "value": value
        ]
    }
}

struct SportMetricValue: Codable, Hashable, Identifiable {
    var id: String
    var key: String
    var label: String
    var unit: String
    var colorHex: String
    var value: Double

    init(id: String = UUID().uuidString, key: String, label: String, unit: String, colorHex: String, value: Double) {
        self.id = id
        self.key = key
        self.label = label
        self.unit = unit
        self.colorHex = colorHex
        self.value = value
    }

    init?(dictionary: [String: Any]) {
        guard let key = dictionary["key"] as? String,
              let label = dictionary["label"] as? String,
              let unit = dictionary["unit"] as? String,
              let colorHex = dictionary["colorHex"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        let value = (dictionary["value"] as? NSNumber)?.doubleValue ?? dictionary["value"] as? Double ?? 0
        self.init(id: id, key: key, label: label, unit: unit, colorHex: colorHex, value: value)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "key": key,
            "label": label,
            "unit": unit,
            "colorHex": colorHex,
            "value": value
        ]
    }
}

struct SportActivityRecord: Codable, Hashable, Identifiable {
    var id: String
    var sportName: String
    var colorHex: String
    var date: Date
    var values: [SportMetricValue]

    init(
        id: String = UUID().uuidString,
        sportName: String,
        colorHex: String,
        date: Date,
        values: [SportMetricValue]
    ) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        self.id = id
        self.sportName = sportName
        self.colorHex = colorHex
        self.date = cal.startOfDay(for: date)
        self.values = values
    }

    init?(dictionary: [String: Any]) {
        guard let sportName = dictionary["sportName"] as? String,
              let colorHex = dictionary["colorHex"] as? String else { return nil }

        let id = dictionary["id"] as? String ?? UUID().uuidString
        let rawDate = dictionary["date"] as? Date
        let epochDate = (dictionary["date"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        let date = rawDate ?? epochDate ?? Date()
        let valuesRaw = dictionary["values"] as? [[String: Any]] ?? []
        let values = valuesRaw.compactMap { SportMetricValue(dictionary: $0) }
        self.init(id: id, sportName: sportName, colorHex: colorHex, date: date, values: values)
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "sportName": sportName,
            "colorHex": colorHex,
            "date": date,
            "values": values.map { $0.asDictionary }
        ]
    }
}

@Model
class Day {
    var id: String? = UUID().uuidString
    var date: Date
    var caloriesConsumed: Int
    var calorieGoal: Int
    var maintenanceCalories: Int
    var macroFocusRaw: String?
    var macroConsumptions: [MacroConsumption]
    var completedMeals: [String] = []
    var takenSupplements: [String] = []
    var takenWorkoutSupplements: [String] = []
    var mealIntakes: [MealIntakeEntry] = []
    var dailyTaskCompletions: [DailyTaskCompletion] = []
    var sportActivities: [SportActivityRecord] = []
    var soloMetricValues: [SoloMetricValue] = []
    var caloriesBurned: Double = 0
    var stepsTaken: Double = 0
    var distanceTravelled: Double = 0

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
        dailyTaskCompletions: [DailyTaskCompletion] = [],
        sportActivities: [SportActivityRecord] = [],
        soloMetricValues: [SoloMetricValue] = [],
        caloriesBurned: Double = 0,
        stepsTaken: Double = 0,
        distanceTravelled: Double = 0
    ) {
        self.id = id
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
        self.dailyTaskCompletions = dailyTaskCompletions
        self.sportActivities = sportActivities
        self.soloMetricValues = soloMetricValues
        self.caloriesBurned = caloriesBurned
        self.stepsTaken = stepsTaken
        self.distanceTravelled = distanceTravelled
    }

    static func fetchOrCreate(for date: Date, in context: ModelContext, trackedMacros: [TrackedMacro]? = nil, soloMetrics: [SoloMetric]? = nil) -> Day {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: date)

        let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == dayStart })
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                if let tracked = trackedMacros { existing.ensureMacroConsumptions(for: tracked) }
                if let solo = soloMetrics { existing.ensureSoloMetricValues(for: solo) }
                return existing
            }
        } catch {
            print("Failed to fetch Day from context: \(error)")
        }

        do {
            let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let rangeRequest = FetchDescriptor<Day>(predicate: #Predicate { $0.date >= dayStart && $0.date < nextDay })
            let rangeResults = try context.fetch(rangeRequest)
            if let existing = rangeResults.first {
                existing.date = dayStart
                if let tracked = trackedMacros { existing.ensureMacroConsumptions(for: tracked) }
                if let solo = soloMetrics { existing.ensureSoloMetricValues(for: solo) }
                try? context.save()
                return existing
            }
        } catch {
            print("Failed range fetch for Day: \(error)")
        }

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
                if let weight = acct.weight, let height = acct.height {
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
                    let tdee = rmr * 1.55
                    inheritedMaintenance = Int(round(tdee))
                }
            }
        } catch {
        }

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
            }
        }

        var consumptions: [MacroConsumption] = []
        if let tracked = trackedMacros {
            consumptions = tracked.map { MacroConsumption(trackedMacroId: $0.id, name: $0.name, unit: $0.unit, consumed: 0) }
        }

        let soloValues: [SoloMetricValue] = (soloMetrics ?? []).map { metric in
            SoloMetricValue(metricId: metric.id, metricName: metric.name, value: 0)
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
            dailyTaskCompletions: [],
            sportActivities: [],
            soloMetricValues: soloValues,
            caloriesBurned: 0,
            stepsTaken: 0,
            distanceTravelled: 0
        )
        context.insert(newDay)
        do {
            try context.save()
        } catch {
            print("Day.fetchOrCreate: failed to save new Day to context: \(error)")
        }
        return newDay
    }

    func ensureMacroConsumptions(for trackedMacros: [TrackedMacro]) {
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

    func ensureSoloMetricValues(for metrics: [SoloMetric]) {
        let existingById: [String: SoloMetricValue] = soloMetricValues.reduce(into: [:]) { acc, item in
            acc[item.metricId] = item
        }

        let existingByName: [String: SoloMetricValue] = soloMetricValues.reduce(into: [:]) { acc, item in
            acc[item.metricName.lowercased()] = item
        }

        var updated: [SoloMetricValue] = []

        for metric in metrics {
            if var match = existingById[metric.id] {
                match.metricName = metric.name
                updated.append(match)
                continue
            }

            if var match = existingByName[metric.name.lowercased()] {
                match.metricId = metric.id
                match.metricName = metric.name
                updated.append(match)
                continue
            }

            updated.append(SoloMetricValue(metricId: metric.id, metricName: metric.name, value: 0))
        }

        soloMetricValues = updated
    }
}
