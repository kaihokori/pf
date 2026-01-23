import Foundation
import SwiftData
import SwiftUI
import FirebaseFirestore

enum WorkoutCheckInStatus: String, Codable, CaseIterable {
    case checkIn
    case rest
    case notLogged
}

enum RecoveryCategory: String, CaseIterable, Codable, Identifiable {
    case sauna = "Sauna"
    case coldPlunge = "Cold Plunge"
    case spa = "Spa"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .sauna: return "flame.fill"
        case .coldPlunge: return "snowflake"
        case .spa: return "sparkles"
        }
    }
}

enum SaunaType: String, CaseIterable, Codable, Identifiable {
    case infrared = "Infrared"
    case steam = "Steam"
    case dry = "Dry"
    case custom = "Other"
    var id: String { rawValue }
}

enum ColdPlungeType: String, CaseIterable, Codable, Identifiable {
    case coldPlunge = "Cold Plunge"
    case iceBath = "Ice Bath"
    case cryotherapy = "Cryotherapy Chamber"
    case hydrotherapy = "Hydrotherapy"
    case custom = "Other"
    var id: String { rawValue }
}

enum SpaType: String, CaseIterable, Codable, Identifiable {
    case massage = "Massage"
    case physiotherapy = "Physiotherapy"
    case chiropractic = "Chiropractic"
    case deepTissue = "Deep Tissue"
    case compression = "Compression"
    case redLight = "Red Light Therapy"
    case jacuzzi = "Jacuzzi"
    case cryotherapy = "Cryotherapy"
    case floating = "Floating Chamber"
    case cupping = "Cupping"
    case dryNeedling = "Dry Needling"
    case custom = "Other"
    var id: String { rawValue }
}

enum SpaBodyPart: String, CaseIterable, Codable, Identifiable {
    case back = "Back"
    case shoulder = "Shoulders"
    case legs = "Legs"
    case feet = "Feet"
    case head = "Head"
    case fullBody = "Full Body"
    var id: String { rawValue }
}

struct RecoverySession: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var category: RecoveryCategory
    var durationSeconds: TimeInterval
    
    var saunaType: SaunaType?
    var coldPlungeType: ColdPlungeType?
    var spaType: SpaType?
    
    var temperature: Double?
    var hydrationTimerSeconds: TimeInterval?
    var heartRateBefore: Int?
    var heartRateAfter: Int?
    var bodyPart: SpaBodyPart?
    
    var customType: String?
    
    init(date: Date, category: RecoveryCategory, durationSeconds: TimeInterval, saunaType: SaunaType? = nil, coldPlungeType: ColdPlungeType? = nil, spaType: SpaType? = nil, temperature: Double? = nil, hydrationTimerSeconds: TimeInterval? = nil, heartRateBefore: Int? = nil, heartRateAfter: Int? = nil, bodyPart: SpaBodyPart? = nil, customType: String? = nil) {
        self.date = date
        self.category = category
        self.durationSeconds = durationSeconds
        self.saunaType = saunaType
        self.coldPlungeType = coldPlungeType
        self.spaType = spaType
        self.temperature = temperature
        self.hydrationTimerSeconds = hydrationTimerSeconds
        self.heartRateBefore = heartRateBefore
        self.heartRateAfter = heartRateAfter
        self.bodyPart = bodyPart
        self.customType = customType
    }
}

struct SobrietyEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var metricID: UUID
    var isSober: Bool? // true = Sober/Success, false = Failed, nil = Not Logged
    var date: Date
    
    // Additional Context
    var note: String?
    
    init(id: UUID = UUID(), metricID: UUID, isSober: Bool?, date: Date, note: String? = nil) {
        self.id = id
        self.metricID = metricID
        self.isSober = isSober
        self.date = date
        self.note = note
    }
    
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "metricID": metricID.uuidString,
            "date": Timestamp(date: date)
        ]
        if let isSober = isSober {
            dict["isSober"] = isSober
        }
        if let note = note {
            dict["note"] = note
        }
        return dict
    }
    
    init?(dictionary: [String: Any]) {
        guard let metricIDStr = dictionary["metricID"] as? String,
              let metricID = UUID(uuidString: metricIDStr) else { return nil }
              
        self.id = (dictionary["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        self.metricID = metricID
        self.isSober = dictionary["isSober"] as? Bool
        self.date = (dictionary["date"] as? Timestamp)?.dateValue() ?? Date()
        self.note = dictionary["note"] as? String
    }
}

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
    var manualValue: Double
    var healthKitValue: Double
    
    var value: Double {
        manualValue + healthKitValue
    }

    init(id: String = UUID().uuidString, metricId: String, metricName: String, manualValue: Double = 0, healthKitValue: Double = 0) {
        self.id = id
        self.metricId = metricId
        self.metricName = metricName
        self.manualValue = manualValue
        self.healthKitValue = healthKitValue
    }
    
    // Legacy support init - assumes manual entry
    init(id: String = UUID().uuidString, metricId: String, metricName: String, value: Double) {
        self.id = id
        self.metricId = metricId
        self.metricName = metricName
        self.manualValue = value
        self.healthKitValue = 0
    }

    init?(dictionary: [String: Any]) {
        guard let metricId = dictionary["metricId"] as? String,
              let metricName = dictionary["metricName"] as? String else { return nil }
        let id = dictionary["id"] as? String ?? UUID().uuidString
        
        let manual = (dictionary["manualValue"] as? NSNumber)?.doubleValue ??  dictionary["manualValue"] as? Double ?? 0
        let hk = (dictionary["healthKitValue"] as? NSNumber)?.doubleValue ?? dictionary["healthKitValue"] as? Double ?? 0
        
        // Legacy: if "value" exists but no new fields, map it to manualValue.
        let legacyValue = (dictionary["value"] as? NSNumber)?.doubleValue ?? dictionary["value"] as? Double ?? 0
        
        if dictionary["manualValue"] == nil && dictionary["healthKitValue"] == nil {
            self.manualValue = legacyValue
            self.healthKitValue = 0
        } else {
            self.manualValue = manual
            self.healthKitValue = hk
        }
        
        self.id = id
        self.metricId = metricId
        self.metricName = metricName
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "metricId": metricId,
            "metricName": metricName,
            "value": value,
            "manualValue": manualValue,
            "healthKitValue": healthKitValue
        ]
    }
}

struct TeamMetricValue: Codable, Hashable, Identifiable {
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
        self.id = id
        self.sportName = sportName
        self.colorHex = colorHex
        // Keep the date anchored in the user's current calendar/time zone to avoid off-by-one-day shifts when viewing charts.
        self.date = Calendar.current.startOfDay(for: date)
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

struct SleepDayEntry: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var nightSeconds: TimeInterval
    var napSeconds: TimeInterval

    var totalSeconds: TimeInterval { nightSeconds + napSeconds }

    static func sampleEntries() -> [SleepDayEntry] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let startIndex = 2 // Monday
        let offsetToStart = (weekday - startIndex + 7) % 7
        let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: cal.startOfDay(for: today)) ?? today

        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: startOfWeek) else { return nil }
            let night = TimeInterval(6 * 3600 + (i % 3) * 1800)
            let nap = TimeInterval((i % 4 == 0) ? 30 * 60 : 0)
            return SleepDayEntry(date: d, nightSeconds: night, napSeconds: nap)
        }
    }
}

struct WeightExerciseValue: Codable, Hashable, Identifiable {
    var id: String
    var groupId: UUID
    var exerciseId: UUID
    var exerciseName: String
    var weight: String
    var unit: String
    var sets: String
    var reps: String

    init(
        id: String? = nil,
        groupId: UUID,
        exerciseId: UUID,
        exerciseName: String,
        weight: String,
        unit: String = "kg",
        sets: String,
        reps: String
    ) {
        self.id = id ?? exerciseId.uuidString
        self.groupId = groupId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.weight = weight
        self.unit = unit
        self.sets = sets
        self.reps = reps
    }

    init?(dictionary: [String: Any]) {
        guard let groupIdRaw = dictionary["groupId"] as? String,
              let exerciseIdRaw = dictionary["exerciseId"] as? String,
              let groupId = UUID(uuidString: groupIdRaw),
              let exerciseId = UUID(uuidString: exerciseIdRaw) else { return nil }

        let id = dictionary["id"] as? String ?? exerciseId.uuidString
        let exerciseName = dictionary["exerciseName"] as? String ?? ""
        let weight = dictionary["weight"] as? String ?? ""
        let unit = dictionary["unit"] as? String ?? "kg"
        let sets = dictionary["sets"] as? String ?? ""
        let reps = dictionary["reps"] as? String ?? ""

        self.init(
            id: id,
            groupId: groupId,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            weight: weight,
            unit: unit,
            sets: sets,
            reps: reps
        )
    }

    var asDictionary: [String: Any] {
        [
            "id": id,
            "groupId": groupId.uuidString,
            "exerciseId": exerciseId.uuidString,
            "exerciseName": exerciseName,
            "weight": weight,
            "unit": unit,
            "sets": sets,
            "reps": reps
        ]
    }

    var hasContent: Bool {
        !weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !sets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ExpenseEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var date: Date
    var name: String
    var amount: Double
    var categoryId: Int

    init(id: UUID = UUID(), date: Date, name: String, amount: Double, categoryId: Int) {
        self.id = id
        self.date = date
        self.name = name
        self.amount = amount
        self.categoryId = categoryId
    }

    init?(dictionary: [String: Any]) {
        let idString = dictionary["id"] as? String
        let resolvedId = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
        let dateValue: Date = {
            if let ts = dictionary["date"] as? Date {
                return ts
            }
            if let raw = dictionary["date"] as? NSNumber {
                return Date(timeIntervalSince1970: raw.doubleValue)
            }
            return Date()
        }()
        guard let name = dictionary["name"] as? String else { return nil }
        let amount = (dictionary["amount"] as? NSNumber)?.doubleValue ?? dictionary["amount"] as? Double ?? 0
        let categoryId = dictionary["categoryId"] as? Int ?? 0
        self.init(id: resolvedId, date: dateValue, name: name, amount: amount, categoryId: categoryId)
    }

    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "date": date,
            "name": name,
            "amount": amount,
            "categoryId": categoryId
        ]
    }
}


@Model
class Day {
    var id: String? = UUID().uuidString
    var date: Date = Date()
    var caloriesConsumed: Int = 0
    var calorieGoal: Int = 0
    var maintenanceCalories: Int = 0
    var weightGoalRaw: String?
    var macroStrategyRaw: String?
    var workoutCheckInStatusRaw: String? = WorkoutCheckInStatus.notLogged.rawValue
    var workoutCheckInStatus: WorkoutCheckInStatus {
        get { WorkoutCheckInStatus(rawValue: workoutCheckInStatusRaw ?? WorkoutCheckInStatus.notLogged.rawValue) ?? .notLogged }
        set { workoutCheckInStatusRaw = newValue.rawValue }
    }
    var macroConsumptions: [MacroConsumption] = []
    var completedMeals: [String] = []
    var takenSupplements: [String] = []
    var takenWorkoutSupplements: [String] = []
    var mealIntakes: [MealIntakeEntry] = []
    var dailyTaskCompletions: [DailyTaskCompletion] = []
    var habitCompletions: [HabitCompletion] = []
    var sportActivities: [SportActivityRecord] = []
    var soloMetricValues: [SoloMetricValue] = []
    var teamMetricValues: [TeamMetricValue] = []
    var teamHomeScore: Int = 0
    var teamAwayScore: Int = 0
    var caloriesBurned: Double = 0
    var stepsTaken: Double = 0
    var distanceTravelled: Double = 0
    var nightSleepSeconds: Double = 0
    var napSleepSeconds: Double = 0
    var weightEntries: [WeightExerciseValue] = []
    var recoverySessions: [RecoverySession] = []
    var expenses: [ExpenseEntry] = []
    var sobrietyEntries: [SobrietyEntry] = []
    
    // Generic manual adjustments for extended activity metrics
    var activityMetricAdjustments: [SoloMetricValue] = []
    var wellnessMetricAdjustments: [SoloMetricValue] = []

    var dayString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    // Preferred unit for weight display for this day. "kg" or "lbs".
    var weightUnitRaw: String? = "kg"

    var weightUnit: String {
        weightUnitRaw ?? "kg"
    }

    init(
        id: String? = UUID().uuidString,
        date: Date = Date(),
        caloriesConsumed: Int = 0,
        calorieGoal: Int = 0,
        maintenanceCalories: Int = 0,
        weightUnitRaw: String? = "kg",
        weightGoalRaw: String? = nil,
        macroStrategyRaw: String? = nil,
        workoutCheckInStatusRaw: String? = WorkoutCheckInStatus.notLogged.rawValue,
        macroConsumptions: [MacroConsumption] = [],
        completedMeals: [String] = [],
        takenSupplements: [String] = [],
        takenWorkoutSupplements: [String] = [],
        mealIntakes: [MealIntakeEntry] = [],
        dailyTaskCompletions: [DailyTaskCompletion] = [],
        habitCompletions: [HabitCompletion] = [],
        sportActivities: [SportActivityRecord] = [],
        soloMetricValues: [SoloMetricValue] = [],
        teamMetricValues: [TeamMetricValue] = [],
        teamHomeScore: Int = 0,
        teamAwayScore: Int = 0,
        caloriesBurned: Double = 0,
        stepsTaken: Double = 0,
        distanceTravelled: Double = 0,
        nightSleepSeconds: Double = 0,
        napSleepSeconds: Double = 0,
        weightEntries: [WeightExerciseValue] = [],
        recoverySessions: [RecoverySession] = [],
        expenses: [ExpenseEntry] = [],
        sobrietyEntries: [SobrietyEntry] = [],
        activityMetricAdjustments: [SoloMetricValue] = [],
        wellnessMetricAdjustments: [SoloMetricValue] = []
    ) {
        self.id = id
        // Use local calendar to extract YMD, then construct UTC date.
        let localCal = Calendar.current
        let components = localCal.dateComponents([.year, .month, .day], from: date)
        
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        self.date = utcCal.date(from: components) ?? utcCal.startOfDay(for: date)
        self.caloriesConsumed = caloriesConsumed
        self.calorieGoal = calorieGoal
        self.maintenanceCalories = maintenanceCalories
        self.weightUnitRaw = weightUnitRaw
        self.weightGoalRaw = weightGoalRaw
        self.macroStrategyRaw = macroStrategyRaw
        self.workoutCheckInStatusRaw = workoutCheckInStatusRaw
        self.macroConsumptions = macroConsumptions
        self.completedMeals = completedMeals
        self.takenSupplements = takenSupplements
        self.takenWorkoutSupplements = takenWorkoutSupplements
        self.mealIntakes = mealIntakes
        self.dailyTaskCompletions = dailyTaskCompletions
        self.habitCompletions = habitCompletions
        self.sportActivities = sportActivities
        self.soloMetricValues = soloMetricValues
        self.teamMetricValues = teamMetricValues
        self.teamHomeScore = teamHomeScore
        self.teamAwayScore = teamAwayScore
        self.caloriesBurned = caloriesBurned
        self.stepsTaken = stepsTaken
        self.distanceTravelled = distanceTravelled
        self.nightSleepSeconds = nightSleepSeconds
        self.napSleepSeconds = napSleepSeconds
        self.weightEntries = weightEntries
        self.recoverySessions = recoverySessions
        self.expenses = expenses
        self.sobrietyEntries = sobrietyEntries
        self.activityMetricAdjustments = activityMetricAdjustments
        self.wellnessMetricAdjustments = wellnessMetricAdjustments
    }

    static func fetchOrCreate(for date: Date, in context: ModelContext, trackedMacros: [TrackedMacro]? = nil, soloMetrics: [SoloMetric]? = nil, teamMetrics: [TeamMetric]? = nil) -> Day {
        // Use local calendar to extract YMD, then construct UTC date.
        // This ensures that "Thursday" local always maps to "Thursday" UTC-normalized Day.
        let localCal = Calendar.current
        let components = localCal.dateComponents([.year, .month, .day], from: date)
        
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = utcCal.date(from: components) ?? utcCal.startOfDay(for: date)

        let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == dayStart })
        do {
            let results = try context.fetch(request)
            if let existing = results.first {
                if let tracked = trackedMacros { existing.ensureMacroConsumptions(for: tracked) }
                if let solo = soloMetrics { existing.ensureSoloMetricValues(for: solo) }
                if let team = teamMetrics { existing.ensureTeamMetricValues(for: team) }
                if existing.workoutCheckInStatusRaw == nil {
                    existing.workoutCheckInStatusRaw = WorkoutCheckInStatus.notLogged.rawValue
                }
                return existing
            }
        } catch {
            print("Failed to fetch Day from context: \(error)")
        }

        do {
            let nextDay = utcCal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let rangeRequest = FetchDescriptor<Day>(predicate: #Predicate { $0.date >= dayStart && $0.date < nextDay })
            let rangeResults = try context.fetch(rangeRequest)
            if let existing = rangeResults.first {
                existing.date = dayStart
                if let tracked = trackedMacros { existing.ensureMacroConsumptions(for: tracked) }
                if let solo = soloMetrics { existing.ensureSoloMetricValues(for: solo) }
                if let team = teamMetrics { existing.ensureTeamMetricValues(for: team) }
                if existing.workoutCheckInStatusRaw == nil {
                    existing.workoutCheckInStatusRaw = WorkoutCheckInStatus.notLogged.rawValue
                }
                try? context.save()
                return existing
            }
        } catch {
            print("Failed range fetch for Day: \(error)")
        }

        var inheritedCalorieGoal: Int = 0
        var inheritedWeightGoalRaw: String? = nil
        var inheritedMacroStrategyRaw: String? = nil
        var inheritedMaintenance: Int = 0
        do {
            let acctReq = FetchDescriptor<Account>()
            let accounts = try context.fetch(acctReq)
            if let acct = accounts.first {
                inheritedCalorieGoal = acct.calorieGoal
                inheritedWeightGoalRaw = acct.weightGoalRaw
                inheritedMacroStrategyRaw = acct.macroStrategyRaw
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
                    if inheritedWeightGoalRaw == nil { inheritedWeightGoalRaw = last.weightGoalRaw }
                    if inheritedMacroStrategyRaw == nil { inheritedMacroStrategyRaw = last.macroStrategyRaw }
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

        let teamValues: [TeamMetricValue] = (teamMetrics ?? []).map { metric in
            TeamMetricValue(metricId: metric.id, metricName: metric.name, value: 0)
        }

        let newDay = Day(
            id: UUID().uuidString,
            date: dayStart,
            caloriesConsumed: 0,
            calorieGoal: inheritedCalorieGoal,
            maintenanceCalories: inheritedMaintenance,
            weightGoalRaw: inheritedWeightGoalRaw,
            macroStrategyRaw: inheritedMacroStrategyRaw,
            macroConsumptions: consumptions,
            completedMeals: [],
            takenSupplements: [],
            takenWorkoutSupplements: [],
            mealIntakes: [],
            dailyTaskCompletions: [],
            habitCompletions: [],
            sportActivities: [],
            soloMetricValues: soloValues,
            teamMetricValues: teamValues,
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

    func ensureTeamMetricValues(for metrics: [TeamMetric]) {
        let existingById: [String: TeamMetricValue] = teamMetricValues.reduce(into: [:]) { acc, item in
            acc[item.metricId] = item
        }

        let existingByName: [String: TeamMetricValue] = teamMetricValues.reduce(into: [:]) { acc, item in
            acc[item.metricName.lowercased()] = item
        }

        var updated: [TeamMetricValue] = []

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

            updated.append(TeamMetricValue(metricId: metric.id, metricName: metric.name, value: 0))
        }

        teamMetricValues = updated
    }
}
