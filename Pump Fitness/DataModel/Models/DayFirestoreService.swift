import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

/// Firestore sync service for `Day` objects.
/// Documents are stored in the `days` collection and keyed by `dd-MM-yyyy` (UTC-normalized) document IDs.
class DayFirestoreService {
    private let db = Firestore.firestore()
    private let userCollection = "accounts"
    private let daysSubcollection = "days"
    /// Pending day keys (dd-MM-yyyy) that were created locally while unauthenticated and should be uploaded when a user signs in.
    private var pendingDayKeys = Set<String>()

    private func dateKey(forLocal date: Date) -> String {
        // Use local calendar to extract YMD, then construct UTC date.
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone.current
        let components = localCal.dateComponents([.year, .month, .day], from: date)
        
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStartInUTC = utcCal.date(from: components) ?? utcCal.startOfDay(for: date)

        let fmt = DateFormatter()
        fmt.calendar = utcCal
        fmt.timeZone = utcCal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: dayStartInUTC)
    }

    private func dateKey(forUTC date: Date) -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let fmt = DateFormatter()
        fmt.calendar = utcCal
        fmt.timeZone = utcCal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: date)
    }

    private func encodeMacroConsumptions(_ macros: [MacroConsumption]) -> [[String: Any]] {
        macros.map { macro in
            [
                "id": macro.id,
                "trackedMacroId": macro.trackedMacroId,
                "name": macro.name,
                "unit": macro.unit,
                "consumed": macro.consumed
            ]
        }
    }

    private func encodeMealIntakes(_ intakes: [MealIntakeEntry]) -> [[String: Any]] {
        intakes.map { intake in intake.asDictionary }
    }

    private func encodeTakenSupplements(_ ids: [String]) -> [String] {
        return ids
    }

    private func encodeTakenWorkoutSupplements(_ ids: [String]) -> [String] {
        return ids
    }

    private func encodeDailyTaskCompletions(_ completions: [DailyTaskCompletion]) -> [[String: Any]] {
        completions.map { $0.asDictionary }
    }

    private func encodeHabitCompletions(_ completions: [HabitCompletion]) -> [[String: Any]] {
        completions.map { $0.asDictionary }
    }

    private func encodeSportActivities(_ activities: [SportActivityRecord]) -> [[String: Any]] {
        return activities.map { activity in
            let dayStart = Calendar.current.startOfDay(for: activity.date)
            return [
                "id": activity.id,
                "sportName": activity.sportName,
                "colorHex": activity.colorHex,
                "date": Timestamp(date: dayStart),
                "values": activity.values.map { value in
                    [
                        "id": value.id,
                        "key": value.key,
                        "label": value.label,
                        "unit": value.unit,
                        "colorHex": value.colorHex,
                        "value": value.value
                    ]
                }
            ]
        }
    }

    private func encodeSoloMetricValues(_ values: [SoloMetricValue]) -> [[String: Any]] {
        values.map { value in
            [
                "id": value.id,
                "metricId": value.metricId,
                "metricName": value.metricName,
                "value": value.value
            ]
        }
    }

    private func encodeTeamMetricValues(_ values: [TeamMetricValue]) -> [[String: Any]] {
        values.map { value in
            [
                "id": value.id,
                "metricId": value.metricId,
                "metricName": value.metricName,
                "value": value.value
            ]
        }
    }

    private func encodeWeightEntries(_ entries: [WeightExerciseValue]) -> [[String: Any]] {
        entries.map { $0.asDictionary }
    }

    private func encodeRecoverySessions(_ sessions: [RecoverySession]) -> [[String: Any]] {
        sessions.map { session in
            var dict: [String: Any] = [
                "id": session.id.uuidString,
                "date": Timestamp(date: session.date),
                "category": session.category.rawValue,
                "durationSeconds": session.durationSeconds
            ]
            if let v = session.saunaType { dict["saunaType"] = v.rawValue }
            if let v = session.coldPlungeType { dict["coldPlungeType"] = v.rawValue }
            if let v = session.spaType { dict["spaType"] = v.rawValue }
            if let v = session.temperature { dict["temperature"] = v }
            if let v = session.hydrationTimerSeconds { dict["hydrationTimerSeconds"] = v }
            if let v = session.heartRateBefore { dict["heartRateBefore"] = v }
            if let v = session.heartRateAfter { dict["heartRateAfter"] = v }
            if let v = session.bodyPart { dict["bodyPart"] = v.rawValue }
            if let v = session.customType { dict["customType"] = v }
            return dict
        }
    }

    private func encodeExpenses(_ entries: [ExpenseEntry]) -> [[String: Any]] {
        entries.map { entry in
            [
                "id": entry.id.uuidString,
                "date": Timestamp(date: entry.date),
                "name": entry.name,
                "amount": entry.amount,
                "categoryId": entry.categoryId
            ]
        }
    }



    private func decodeMacroConsumption(_ raw: [String: Any]) -> MacroConsumption? {
        guard let trackedMacroId = raw["trackedMacroId"] as? String else { return nil }
        let id = raw["id"] as? String ?? UUID().uuidString
        let name = raw["name"] as? String ?? ""
        let unit = raw["unit"] as? String ?? "g"
        let consumed = (raw["consumed"] as? NSNumber)?.doubleValue ?? 0
        return MacroConsumption(id: id, trackedMacroId: trackedMacroId, name: name, unit: unit, consumed: consumed)
    }

    private func decodeMealIntake(_ raw: [String: Any]) -> MealIntakeEntry? {
        MealIntakeEntry(dictionary: raw)
    }

    private func decodeDailyTaskCompletion(_ raw: [String: Any]) -> DailyTaskCompletion? {
        DailyTaskCompletion(dictionary: raw)
    }

    private func decodeHabitCompletion(_ raw: [String: Any]) -> HabitCompletion? {
        HabitCompletion(dictionary: raw)
    }

    private func decodeSoloMetricValue(_ raw: [String: Any]) -> SoloMetricValue? {
        SoloMetricValue(dictionary: raw)
    }

    private func decodeTeamMetricValue(_ raw: [String: Any]) -> TeamMetricValue? {
        TeamMetricValue(dictionary: raw)
    }

    private func decodeWeightEntry(_ raw: [String: Any]) -> WeightExerciseValue? {
        WeightExerciseValue(dictionary: raw)
    }

    private func decodeRecoverySession(_ raw: [String: Any]) -> RecoverySession? {
        guard let catRaw = raw["category"] as? String,
              let category = RecoveryCategory(rawValue: catRaw) else { return nil }
        
        let id = (raw["id"] as? String).flatMap(UUID.init) ?? UUID()
        let date = (raw["date"] as? Timestamp)?.dateValue() ?? Date()
        let duration = (raw["durationSeconds"] as? NSNumber)?.doubleValue ?? 0
        
        var session = RecoverySession(
            date: date,
            category: category,
            durationSeconds: duration
        )
        session.id = id
        
        if let s = raw["saunaType"] as? String { session.saunaType = SaunaType(rawValue: s) }
        if let s = raw["coldPlungeType"] as? String { session.coldPlungeType = ColdPlungeType(rawValue: s) }
        if let s = raw["spaType"] as? String { session.spaType = SpaType(rawValue: s) }
        if let v = raw["temperature"] as? NSNumber { session.temperature = v.doubleValue }
        if let v = raw["hydrationTimerSeconds"] as? NSNumber { session.hydrationTimerSeconds = v.doubleValue }
        if let v = raw["heartRateBefore"] as? NSNumber { session.heartRateBefore = v.intValue }
        if let v = raw["heartRateAfter"] as? NSNumber { session.heartRateAfter = v.intValue }
        if let s = raw["bodyPart"] as? String { session.bodyPart = SpaBodyPart(rawValue: s) }
        session.customType = raw["customType"] as? String
        
        return session
    }

    private func decodeExpenseEntry(_ raw: [String: Any]) -> ExpenseEntry? {
        var dict = raw
        if let ts = raw["date"] as? Timestamp {
            dict["date"] = ts.dateValue()
        }
        return ExpenseEntry(dictionary: dict)
    }


    private func decodeSportActivity(_ raw: [String: Any]) -> SportActivityRecord? {
        guard let sportName = raw["sportName"] as? String else { return nil }
        let id = raw["id"] as? String ?? UUID().uuidString
        let colorHex = raw["colorHex"] as? String ?? "#007AFF"
        let date = (raw["date"] as? Timestamp)?.dateValue() ?? (raw["date"] as? Date) ?? Date()
        let values = (raw["values"] as? [[String: Any]] ?? []).compactMap { rawValue -> SportMetricValue? in
            guard let key = rawValue["key"] as? String,
                  let label = rawValue["label"] as? String,
                  let unit = rawValue["unit"] as? String,
                  let colorHex = rawValue["colorHex"] as? String else { return nil }
            let valueId = rawValue["id"] as? String ?? UUID().uuidString
            let value = (rawValue["value"] as? NSNumber)?.doubleValue ?? rawValue["value"] as? Double ?? 0
            return SportMetricValue(id: valueId, key: key, label: label, unit: unit, colorHex: colorHex, value: value)
        }
        return SportActivityRecord(id: id, sportName: sportName, colorHex: colorHex, date: date, values: values)
    }

    // Determine whether a Day instance contains any non-default data that should be uploaded.
    private func dayHasMeaningfulData(_ day: Day) -> Bool {
        if day.calorieGoal != 0 { return true }
        if day.maintenanceCalories != 0 { return true }
        if let wg = day.weightGoalRaw, !wg.isEmpty { return true }
        if let ms = day.macroStrategyRaw, !ms.isEmpty { return true }
        if day.caloriesConsumed != 0 { return true }
        if !day.completedMeals.isEmpty { return true }
        if !day.takenSupplements.isEmpty { return true }
        if !day.takenWorkoutSupplements.isEmpty { return true }
        if day.caloriesBurned != 0 { return true }
        if day.stepsTaken != 0 { return true }
        if day.distanceTravelled != 0 { return true }
        if day.nightSleepSeconds > 0 { return true }
        if day.napSleepSeconds > 0 { return true }
        if day.macroConsumptions.contains(where: { $0.consumed != 0 }) { return true }
        if !day.mealIntakes.isEmpty { return true }
        if !day.dailyTaskCompletions.isEmpty { return true }
        // Consider habit completions meaningful even when all are false so
        // clearing the last tracked habit is uploaded to Firestore.
        if !day.habitCompletions.isEmpty { return true }
        if !day.sportActivities.isEmpty { return true }
        if day.soloMetricValues.contains(where: { $0.value != 0 }) { return true }
        if day.teamMetricValues.contains(where: { $0.value != 0 }) { return true }
        if day.teamHomeScore != 0 { return true }
        if day.teamAwayScore != 0 { return true }
        if day.weightEntries.contains(where: { $0.hasContent }) { return true }
        if !day.expenses.isEmpty { return true }
        if !day.recoverySessions.isEmpty { return true }
        if !day.activityMetricAdjustments.isEmpty { return true }
        if !day.wellnessMetricAdjustments.isEmpty { return true }
        if let raw = day.workoutCheckInStatusRaw,
           let status = WorkoutCheckInStatus(rawValue: raw),
           status != .notLogged {
            return true
        }
        return false
    }


    /// Fetch a Day from Firestore for a given date. If not present remotely, a local `Day` is created (via `Day.fetchOrCreate`) and uploaded.
    /// - Parameters:
    ///   - date: date to fetch (normalized to start-of-day)
    ///   - context: optional `ModelContext` used to insert/find local model instances
    ///   - completion: returns the `Day` (local instance) or `nil` on unrecoverable errors
    func fetchDay(
        for date: Date,
        in context: ModelContext?,
        trackedMacros: [TrackedMacro]? = nil,
        soloMetrics: [SoloMetric]? = nil,
        teamMetrics: [TeamMetric]? = nil,
        completion: @escaping (Day?) -> Void
    ) {
        let key = dateKey(forLocal: date)

        // Choose docRef: user-scoped `accounts/{userID}/days/{dayDate}` when signed in, otherwise legacy `days/{dayDate}`
        let docRef: DocumentReference
        if let uid = Auth.auth().currentUser?.uid {
            docRef = db.collection(userCollection).document(uid).collection(daysSubcollection).document(key)
        } else {
            docRef = db.collection(daysSubcollection).document(key)
        }

        docRef.getDocument { snapshot, error in
            if error != nil {
                // On error, fall back to local cache if available
                print("DayFirestoreService: error fetching doc for key=\(key): \(String(describing: error))")
                if let ctx = context {
                    let local = Day.fetchOrCreate(for: date, in: ctx, trackedMacros: trackedMacros)
                    print("DayFirestoreService: falling back to local day for key=\(key)")
                    completion(local)
                    return
                }
                completion(nil)
                return
            }

            if let data = snapshot?.data() {
                // Remote doc exists — use its date if provided, otherwise use the requested date
                let ts = data["date"] as? Timestamp
                let remoteDate = ts?.dateValue() ?? date
                let caloriesOpt = data["caloriesConsumed"] as? Int
                let calorieGoalRemote = data["calorieGoal"] as? Int ?? (data["calorieGoal"] as? NSNumber)?.intValue
                let maintenanceRemote = data["maintenanceCalories"] as? Int ?? (data["maintenanceCalories"] as? NSNumber)?.intValue
                let weightGoalRemote = data["weightGoal"] as? String ?? data["weightGoalRaw"] as? String
                let macroStrategyRemote = data["macroStrategy"] as? String ?? data["macroStrategyRaw"] as? String
                let weightUnitRemote = data["weightUnit"] as? String
                let caloriesBurnedRemote = (data["caloriesBurned"] as? NSNumber)?.doubleValue
                let stepsTakenRemote = (data["stepsTaken"] as? NSNumber)?.doubleValue
                let distanceRemote = (data["distanceTravelled"] as? NSNumber)?.doubleValue
                let workoutStatusRaw = data["workoutCheckInStatus"] as? String
                let macroConsumptionsRemote = (data["macroConsumptions"] as? [[String: Any]] ?? []).compactMap { self.decodeMacroConsumption($0) }
                let takenSupplementsRemote = data["takenSupplements"] as? [String]
                let completedMealsRemote = data["completedMeals"] as? [String]
                let mealIntakesRemote = (data["mealIntakes"] as? [[String: Any]] ?? []).compactMap { self.decodeMealIntake($0) }
                let dailyTaskCompletionsRemote = (data["dailyTaskCompletions"] as? [[String: Any]] ?? []).compactMap { self.decodeDailyTaskCompletion($0) }
                let habitCompletionsRemote = (data["habitCompletions"] as? [[String: Any]] ?? []).compactMap { self.decodeHabitCompletion($0) }
                let sportActivitiesRemote = (data["sportActivities"] as? [[String: Any]] ?? []).compactMap { self.decodeSportActivity($0) }
                let soloMetricValuesRemote = (data["soloPlayEntries"] as? [[String: Any]] ?? []).compactMap { self.decodeSoloMetricValue($0) }
                let teamMetricValuesRemote = (data["teamPlayEntries"] as? [[String: Any]] ?? []).compactMap { self.decodeTeamMetricValue($0) }
                let activityAdjustmentsRemote = (data["activityMetricAdjustments"] as? [[String: Any]] ?? []).compactMap { self.decodeSoloMetricValue($0) }
                let wellnessAdjustmentsRemote = (data["wellnessMetricAdjustments"] as? [[String: Any]] ?? []).compactMap { self.decodeSoloMetricValue($0) }
                let weightEntriesRemote = (data["weightEntries"] as? [[String: Any]] ?? []).compactMap { self.decodeWeightEntry($0) }
                let expensesRemote = (data["expenses"] as? [[String: Any]] ?? []).compactMap { self.decodeExpenseEntry($0) }
                let recoverySessionsRemote = (data["recoverySessions"] as? [[String: Any]] ?? []).compactMap { self.decodeRecoverySession($0) }
                let nightSleepRemote = (data["nightSleepSeconds"] as? NSNumber)?.doubleValue ?? data["nightSleepSeconds"] as? Double
                let napSleepRemote = (data["napSleepSeconds"] as? NSNumber)?.doubleValue ?? data["napSleepSeconds"] as? Double
                let teamHomeScoreRemote = data["teamHomeScore"] as? Int ?? 0
                let teamAwayScoreRemote = data["teamAwayScore"] as? Int ?? 0
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: remoteDate, in: ctx, trackedMacros: trackedMacros, soloMetrics: soloMetrics, teamMetrics: teamMetrics)
                    // Merge remote values into local without wiping newer local data.
                    if let calories = caloriesOpt {
                        day.caloriesConsumed = max(day.caloriesConsumed, calories)
                    }

                    if let goal = calorieGoalRemote { day.calorieGoal = goal }
                    if let maintenance = maintenanceRemote { day.maintenanceCalories = maintenance }
                    if let weightGoalRemote { day.weightGoalRaw = weightGoalRemote }
                    if let macroStrategyRemote { day.macroStrategyRaw = macroStrategyRemote }
                    if let weightUnitRemote, !weightUnitRemote.isEmpty { day.weightUnitRaw = weightUnitRemote }

                    let mergedMacros = self.mergeMacroConsumptions(local: day.macroConsumptions, remote: macroConsumptionsRemote)
                    if !mergedMacros.isEmpty {
                        day.macroConsumptions = mergedMacros
                    } else if let tracked = trackedMacros {
                        day.ensureMacroConsumptions(for: tracked)
                    }

                    if let completedMealsRemote = completedMealsRemote {
                        let merged = Array(Set(day.completedMeals).union(Set(completedMealsRemote)))
                        day.completedMeals = merged
                    }

                    if let takenSupplementsRemote = takenSupplementsRemote {
                        let merged = Array(Set(day.takenSupplements).union(Set(takenSupplementsRemote)))
                        day.takenSupplements = merged
                    }

                    if let caloriesBurnedRemote = caloriesBurnedRemote {
                        day.caloriesBurned = max(day.caloriesBurned, caloriesBurnedRemote)
                    }
                    if let stepsTakenRemote = stepsTakenRemote {
                        day.stepsTaken = max(day.stepsTaken, stepsTakenRemote)
                    }
                    if let distanceRemote = distanceRemote {
                        day.distanceTravelled = max(day.distanceTravelled, distanceRemote)
                    }
                    if let nightSleepRemote = nightSleepRemote {
                        day.nightSleepSeconds = max(day.nightSleepSeconds, nightSleepRemote)
                    }
                    if let napSleepRemote = napSleepRemote {
                        day.napSleepSeconds = max(day.napSleepSeconds, napSleepRemote)
                    }
                    if let takenWorkoutRemote = data["takenWorkoutSupplements"] as? [String] {
                        let merged = Array(Set(day.takenWorkoutSupplements).union(Set(takenWorkoutRemote)))
                        day.takenWorkoutSupplements = merged
                    }
                    if !weightEntriesRemote.isEmpty {
                        let mergedWeights = self.mergeWeightEntries(local: day.weightEntries, remote: weightEntriesRemote)
                        day.weightEntries = mergedWeights
                    }

                    if !expensesRemote.isEmpty || !day.expenses.isEmpty {
                        let mergedExpenses = self.mergeExpenses(local: day.expenses, remote: expensesRemote)
                        day.expenses = mergedExpenses
                    }
                    
                    if !recoverySessionsRemote.isEmpty || !day.recoverySessions.isEmpty {
                        // Simple merge: remote wins for simplicity or union? 
                        // Let's use union by ID
                        let localDict = Dictionary(grouping: day.recoverySessions, by: { $0.id }).compactMapValues { $0.first }
                        let remoteDict = Dictionary(grouping: recoverySessionsRemote, by: { $0.id }).compactMapValues { $0.first }
                        let keys = Set(localDict.keys).union(remoteDict.keys)
                        day.recoverySessions = keys.compactMap { remoteDict[$0] ?? localDict[$0] }
                    }

                    let mergedIntakes = self.mergeMealIntakes(local: day.mealIntakes, remote: mealIntakesRemote)
                    day.mealIntakes = mergedIntakes

                    let mergedCompletions = self.mergeDailyTaskCompletions(local: day.dailyTaskCompletions, remote: dailyTaskCompletionsRemote)
                    day.dailyTaskCompletions = mergedCompletions

                    let mergedHabitCompletions = self.mergeHabitCompletions(local: day.habitCompletions, remote: habitCompletionsRemote)
                    day.habitCompletions = mergedHabitCompletions

                    let mergedSportActivities = self.mergeSportActivities(local: day.sportActivities, remote: sportActivitiesRemote)
                    day.sportActivities = mergedSportActivities

                    let mergedSoloValues = self.mergeSoloMetricValues(local: day.soloMetricValues, remote: soloMetricValuesRemote)
                    if !mergedSoloValues.isEmpty {
                        day.soloMetricValues = mergedSoloValues
                    }

                    let mergedTeamValues = self.mergeTeamMetricValues(local: day.teamMetricValues, remote: teamMetricValuesRemote)
                    if !mergedTeamValues.isEmpty {
                        day.teamMetricValues = mergedTeamValues
                    }

                    let mergedActivityAdj = self.mergeSoloMetricValues(local: day.activityMetricAdjustments, remote: activityAdjustmentsRemote)
                    if !mergedActivityAdj.isEmpty {
                        day.activityMetricAdjustments = mergedActivityAdj
                    }

                    let mergedWellnessAdj = self.mergeSoloMetricValues(local: day.wellnessMetricAdjustments, remote: wellnessAdjustmentsRemote)
                    if !mergedWellnessAdj.isEmpty {
                        day.wellnessMetricAdjustments = mergedWellnessAdj
                    }

                    day.teamHomeScore = max(day.teamHomeScore, teamHomeScoreRemote)
                    day.teamAwayScore = max(day.teamAwayScore, teamAwayScoreRemote)

                    if let statusRaw = workoutStatusRaw {
                        day.workoutCheckInStatusRaw = statusRaw
                    }

                    if day.workoutCheckInStatusRaw == nil {
                        day.workoutCheckInStatusRaw = WorkoutCheckInStatus.notLogged.rawValue
                    }

                    // Recalculate aggregates from merged meal intakes so we don't lose entries when syncing.
                    let aggregatedCalories = mergedIntakes.reduce(0) { $0 + $1.calories }

                    var aggregatedMacroById: [String: Double] = [:]
                    for intake in mergedIntakes {
                        for macro in intake.macros {
                            aggregatedMacroById[macro.trackedMacroId, default: 0] += macro.amount
                        }
                    }

                    day.caloriesConsumed = max(day.caloriesConsumed, caloriesOpt ?? 0, aggregatedCalories)

                    // Align macro consumptions with aggregated meal data while preserving manual adjustments.
                    var updatedMacros = day.macroConsumptions
                    var existingIds = Set(updatedMacros.map { $0.trackedMacroId })
                    for idx in updatedMacros.indices {
                        let id = updatedMacros[idx].trackedMacroId
                        if let aggregated = aggregatedMacroById[id] {
                            updatedMacros[idx].consumed = max(updatedMacros[idx].consumed, aggregated)
                        }
                    }

                    // Add any macros present in meal entries but missing from the day store.
                    if let tracked = trackedMacros {
                        for trackedMacro in tracked {
                            if let aggregated = aggregatedMacroById[trackedMacro.id], !existingIds.contains(trackedMacro.id) {
                                updatedMacros.append(
                                    MacroConsumption(
                                        trackedMacroId: trackedMacro.id,
                                        name: trackedMacro.name,
                                        unit: trackedMacro.unit,
                                        consumed: aggregated
                                    )
                                )
                                existingIds.insert(trackedMacro.id)
                            }
                        }
                    }

                    day.macroConsumptions = updatedMacros
                    completion(day)
                    return
                } else {
                    // If no context is provided return an ephemeral Day using whatever remote values exist
                    let calories = caloriesOpt ?? 0
                    let day = Day(
                        date: remoteDate,
                        caloriesConsumed: calories,
                        calorieGoal: calorieGoalRemote ?? 0,
                        maintenanceCalories: maintenanceRemote ?? 0,
                        weightUnitRaw: weightUnitRemote,
                        weightGoalRaw: weightGoalRemote,
                        macroStrategyRaw: macroStrategyRemote,
                        workoutCheckInStatusRaw: workoutStatusRaw ?? WorkoutCheckInStatus.notLogged.rawValue, macroConsumptions: macroConsumptionsRemote,
                        completedMeals: completedMealsRemote ?? [],
                        takenSupplements: takenSupplementsRemote ?? [],
                        takenWorkoutSupplements: data["takenWorkoutSupplements"] as? [String] ?? [],
                        mealIntakes: mealIntakesRemote,
                        dailyTaskCompletions: dailyTaskCompletionsRemote,
                        habitCompletions: habitCompletionsRemote,
                        sportActivities: sportActivitiesRemote,
                        soloMetricValues: soloMetricValuesRemote,
                        teamMetricValues: teamMetricValuesRemote,
                        teamHomeScore: teamHomeScoreRemote,
                        teamAwayScore: teamAwayScoreRemote,
                        caloriesBurned: caloriesBurnedRemote ?? 0,
                        stepsTaken: stepsTakenRemote ?? 0,
                        distanceTravelled: distanceRemote ?? 0,
                        nightSleepSeconds: nightSleepRemote ?? 0,
                        napSleepSeconds: napSleepRemote ?? 0,
                        weightEntries: weightEntriesRemote,
                        recoverySessions: recoverySessionsRemote,
                        expenses: expensesRemote,
                        activityMetricAdjustments: activityAdjustmentsRemote,
                        wellnessMetricAdjustments: wellnessAdjustmentsRemote
                    )
                    completion(day)
                    return
                }
            } else {
                // Remote doc missing — ensure local exists and upload it
                // Create local default
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: date, in: ctx, trackedMacros: trackedMacros, soloMetrics: soloMetrics, teamMetrics: teamMetrics)
                    // If user is signed in, attempt immediate upload; otherwise mark for later
                    if Auth.auth().currentUser != nil {
                        if self.dayHasMeaningfulData(day) {
                            self.saveDay(day) { _ in completion(day) }
                        } else {
                            completion(day)
                        }
                    } else {
                        // schedule for upload when user signs in only if there is something to upload
                        if self.dayHasMeaningfulData(day) {
                            self.pendingDayKeys.insert(key)
                        } else {
                        }
                        completion(day)
                    }
                    return
                } else {
                    let day = Day(
                        date: date,
                        macroConsumptions: trackedMacros?.map { MacroConsumption(trackedMacroId: $0.id, name: $0.name, unit: $0.unit, consumed: 0) } ?? []
                    )
                    if Auth.auth().currentUser != nil {
                        if self.dayHasMeaningfulData(day) {
                            self.saveDay(day) { _ in completion(day) }
                        } else {
                            completion(day)
                        }
                    } else {
                        if self.dayHasMeaningfulData(day) {
                            self.pendingDayKeys.insert(key)
                        } else {
                        }
                        completion(day)
                    }
                    return
                }
            }
        }
    }

    /// Save a Day to Firestore. Document ID will be `dd-MM-yyyy` for the `day.date`.
    /// - Parameters:
    ///   - day: Day to persist
    ///   - forceWrite: When true, write even zero/empty fields so remote data can be cleared
    func saveDay(_ day: Day, forceWrite: Bool = false, completion: @escaping (Bool) -> Void) {
        // If the day only contains default/zero values then avoid uploading it —
        // this prevents accidental overwrites of non-zero remote/core-data values with zeros.
        // `forceWrite` is used when we need to clear remote fields (e.g., deleting the last meal).
        if !forceWrite && !dayHasMeaningfulData(day) {
            completion(true)
            return
        }

        // Normalize start-of-day to UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: day.date)
        let key = dateKey(forUTC: dayStart)
        // Build a payload only containing the fields we intend to write.
        // Do not write `macroFocus` when it's nil (avoid setting it to null),
        // and use Firestore's merge option so we don't accidentally overwrite
        // unrelated fields with default values.
        var data: [String: Any] = [
            "date": Timestamp(date: dayStart)
        ]

        if forceWrite || day.calorieGoal != 0 {
            data["calorieGoal"] = day.calorieGoal
        }
        if forceWrite || day.maintenanceCalories != 0 {
            data["maintenanceCalories"] = day.maintenanceCalories
        }
        if forceWrite || (day.weightGoalRaw?.isEmpty == false) {
            data["weightGoal"] = day.weightGoalRaw ?? ""
        }
        if forceWrite || (day.macroStrategyRaw?.isEmpty == false) {
            data["macroStrategy"] = day.macroStrategyRaw ?? ""
        }
        if forceWrite || (day.weightUnitRaw?.isEmpty == false) {
            data["weightUnit"] = day.weightUnitRaw ?? "kg"
        }

        if let statusRaw = day.workoutCheckInStatusRaw {
            data["workoutCheckInStatus"] = statusRaw
        }

        if forceWrite || day.caloriesConsumed != 0 {
            data["caloriesConsumed"] = day.caloriesConsumed
        }
        if forceWrite || !day.completedMeals.isEmpty {
            data["completedMeals"] = day.completedMeals
        }
        if forceWrite || !day.takenSupplements.isEmpty {
            data["takenSupplements"] = encodeTakenSupplements(day.takenSupplements)
        }
        if forceWrite || !day.takenWorkoutSupplements.isEmpty {
            data["takenWorkoutSupplements"] = encodeTakenWorkoutSupplements(day.takenWorkoutSupplements)
        }
        if forceWrite || day.caloriesBurned > 0 {
            data["caloriesBurned"] = day.caloriesBurned
        }
        if forceWrite || day.stepsTaken > 0 {
            data["stepsTaken"] = day.stepsTaken
        }
        if forceWrite || day.distanceTravelled > 0 {
            data["distanceTravelled"] = day.distanceTravelled
        }
        if forceWrite || day.nightSleepSeconds > 0 {
            data["nightSleepSeconds"] = day.nightSleepSeconds
        }
        if forceWrite || day.napSleepSeconds > 0 {
            data["napSleepSeconds"] = day.napSleepSeconds
        }
        if forceWrite || day.macroConsumptions.contains(where: { $0.consumed != 0 }) {
            data["macroConsumptions"] = encodeMacroConsumptions(day.macroConsumptions)
        }
        if forceWrite || !day.mealIntakes.isEmpty {
            data["mealIntakes"] = encodeMealIntakes(day.mealIntakes)
        }
        if forceWrite || !day.dailyTaskCompletions.isEmpty {
            data["dailyTaskCompletions"] = encodeDailyTaskCompletions(day.dailyTaskCompletions)
        }
        // Always include habit completions when present so toggles (including
        // clearing all completions) are persisted to Firestore.
        if forceWrite || !day.habitCompletions.isEmpty {
            data["habitCompletions"] = encodeHabitCompletions(day.habitCompletions)
        }
        if forceWrite || !day.sportActivities.isEmpty {
            data["sportActivities"] = encodeSportActivities(day.sportActivities)
        }
        if forceWrite || !day.soloMetricValues.isEmpty {
            data["soloPlayEntries"] = encodeSoloMetricValues(day.soloMetricValues)
        }
        if forceWrite || !day.teamMetricValues.isEmpty {
            data["teamPlayEntries"] = encodeTeamMetricValues(day.teamMetricValues)
        }
        if forceWrite || day.teamHomeScore != 0 {
            data["teamHomeScore"] = day.teamHomeScore
        }
        if forceWrite || day.teamAwayScore != 0 {
            data["teamAwayScore"] = day.teamAwayScore
        }
        if forceWrite || day.weightEntries.contains(where: { $0.hasContent }) {
            data["weightEntries"] = encodeWeightEntries(day.weightEntries.filter { $0.hasContent })
        }
        if forceWrite || !day.expenses.isEmpty {
            data["expenses"] = encodeExpenses(day.expenses)
        }
        if forceWrite || !day.recoverySessions.isEmpty {
            data["recoverySessions"] = encodeRecoverySessions(day.recoverySessions)
        }
        if forceWrite || !day.activityMetricAdjustments.isEmpty {
            data["activityMetricAdjustments"] = encodeSoloMetricValues(day.activityMetricAdjustments)
        }
        if forceWrite || !day.wellnessMetricAdjustments.isEmpty {
            data["wellnessMetricAdjustments"] = encodeSoloMetricValues(day.wellnessMetricAdjustments)
        }

        let useMerge = !forceWrite

        if let uid = Auth.auth().currentUser?.uid {
            // accounts/{userID}/days/{dayDate}
            let path = "accounts/\(uid)/days/\(key)"
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(data, merge: useMerge) { err in
                    if let err = err {
                        print("DayFirestoreService: failed to save day to \(path): \(err)")
                    }
                    completion(err == nil)
                }
            return
        }

        // Fallback legacy path
        let path = "\(daysSubcollection)/\(key)"
        db.collection(daysSubcollection).document(key).setData(data, merge: useMerge) { err in
            if let err = err {
                print("DayFirestoreService: failed to save day to legacy path \(path): \(err)")
            }
            completion(err == nil)
        }
    }

    // Merge helpers to prevent remote reads from clobbering newer local edits.
    private func mergeMacroConsumptions(local: [MacroConsumption], remote: [MacroConsumption]) -> [MacroConsumption] {
        if remote.isEmpty { return local }

        // Deduplicate local macros first so duplicate trackedMacroIds/names cannot crash the dictionary initializer.
        var mergedById: [String: MacroConsumption] = [:]
        var localByName: [String: MacroConsumption] = [:]

        for macro in local {
            if var existing = mergedById[macro.trackedMacroId] {
                existing.consumed = max(existing.consumed, macro.consumed)
                if !macro.name.isEmpty { existing.name = macro.name }
                if !macro.unit.isEmpty { existing.unit = macro.unit }
                mergedById[macro.trackedMacroId] = existing
            } else {
                mergedById[macro.trackedMacroId] = macro
            }

            let nameKey = macro.name.lowercased()
            if var existingByName = localByName[nameKey] {
                existingByName.consumed = max(existingByName.consumed, macro.consumed)
                localByName[nameKey] = existingByName
            } else {
                localByName[nameKey] = macro
            }
        }

        for remoteMacro in remote {
            if var existing = mergedById[remoteMacro.trackedMacroId] {
                existing.consumed = max(existing.consumed, remoteMacro.consumed)
                if !remoteMacro.name.isEmpty { existing.name = remoteMacro.name }
                if !remoteMacro.unit.isEmpty { existing.unit = remoteMacro.unit }
                mergedById[remoteMacro.trackedMacroId] = existing
                continue
            }

            if var existingByName = localByName[remoteMacro.name.lowercased()] {
                existingByName.trackedMacroId = remoteMacro.trackedMacroId
                existingByName.consumed = max(existingByName.consumed, remoteMacro.consumed)
                if !remoteMacro.unit.isEmpty { existingByName.unit = remoteMacro.unit }
                mergedById[remoteMacro.trackedMacroId] = existingByName
                continue
            }

            mergedById[remoteMacro.trackedMacroId] = remoteMacro
        }

        return Array(mergedById.values)
    }

    private func mergeMealIntakes(local: [MealIntakeEntry], remote: [MealIntakeEntry]) -> [MealIntakeEntry] {
        if remote.isEmpty { return local }

        var merged = local

        func score(_ entry: MealIntakeEntry) -> Double {
            let macroSum = entry.macros.reduce(0.0) { $0 + $1.amount }
            return Double(entry.calories) + macroSum
        }

        for remoteEntry in remote {
            if let idx = merged.firstIndex(where: { $0.id == remoteEntry.id }) {
                let existing = merged[idx]
                merged[idx] = score(remoteEntry) > score(existing) ? remoteEntry : existing
            } else {
                merged.append(remoteEntry)
            }
        }

        return merged
    }

    private func mergeDailyTaskCompletions(local: [DailyTaskCompletion], remote: [DailyTaskCompletion]) -> [DailyTaskCompletion] {
        if remote.isEmpty { return local }

        var mergedById: [String: DailyTaskCompletion] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteItem in remote {
            if let existing = mergedById[remoteItem.id] {
                mergedById[remoteItem.id] = DailyTaskCompletion(id: remoteItem.id, isCompleted: existing.isCompleted || remoteItem.isCompleted)
            } else {
                mergedById[remoteItem.id] = remoteItem
            }
        }

        return Array(mergedById.values)
    }

    private func mergeHabitCompletions(local: [HabitCompletion], remote: [HabitCompletion]) -> [HabitCompletion] {
        if remote.isEmpty { return local }

        var mergedByHabit: [UUID: HabitCompletion] = Dictionary(uniqueKeysWithValues: local.map { ($0.habitId, $0) })

        for remoteItem in remote {
            if let existing = mergedByHabit[remoteItem.habitId] {
                mergedByHabit[remoteItem.habitId] = HabitCompletion(id: remoteItem.id, habitId: remoteItem.habitId, isCompleted: existing.isCompleted || remoteItem.isCompleted)
            } else {
                mergedByHabit[remoteItem.habitId] = remoteItem
            }
        }

        return Array(mergedByHabit.values)
    }

    private func mergeSportActivities(local: [SportActivityRecord], remote: [SportActivityRecord]) -> [SportActivityRecord] {
        if remote.isEmpty { return local }

        var mergedById: [String: SportActivityRecord] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteActivity in remote {
            if let existing = mergedById[remoteActivity.id] {
                mergedById[remoteActivity.id] = mergeSportActivity(existing: existing, remote: remoteActivity)
            } else {
                mergedById[remoteActivity.id] = remoteActivity
            }
        }

        return Array(mergedById.values)
    }

    private func mergeSoloMetricValues(local: [SoloMetricValue], remote: [SoloMetricValue]) -> [SoloMetricValue] {
        if remote.isEmpty { return local }

        var mergedByMetricId: [String: SoloMetricValue] = Dictionary(local.map { ($0.metricId, $0) }, uniquingKeysWith: { (first, _) in first })
        let localByName: [String: SoloMetricValue] = Dictionary(local.map { ($0.metricName.lowercased(), $0) }, uniquingKeysWith: { (first, _) in first })

        for remoteValue in remote {
            if var existing = mergedByMetricId[remoteValue.metricId] {
                existing.value = max(existing.value, remoteValue.value)
                existing.metricName = remoteValue.metricName
                mergedByMetricId[remoteValue.metricId] = existing
            } else if var existingByName = localByName[remoteValue.metricName.lowercased()] {
                existingByName.metricId = remoteValue.metricId
                existingByName.metricName = remoteValue.metricName
                existingByName.value = max(existingByName.value, remoteValue.value)
                mergedByMetricId[remoteValue.metricId] = existingByName
            } else {
                mergedByMetricId[remoteValue.metricId] = remoteValue
            }
        }

        return Array(mergedByMetricId.values)
    }

    private func mergeTeamMetricValues(local: [TeamMetricValue], remote: [TeamMetricValue]) -> [TeamMetricValue] {
        if remote.isEmpty { return local }

        var mergedByMetricId: [String: TeamMetricValue] = Dictionary(local.map { ($0.metricId, $0) }, uniquingKeysWith: { (first, _) in first })
        let localByName: [String: TeamMetricValue] = Dictionary(local.map { ($0.metricName.lowercased(), $0) }, uniquingKeysWith: { (first, _) in first })

        for remoteValue in remote {
            if var existing = mergedByMetricId[remoteValue.metricId] {
                existing.value = max(existing.value, remoteValue.value)
                existing.metricName = remoteValue.metricName
                mergedByMetricId[remoteValue.metricId] = existing
            } else if var existingByName = localByName[remoteValue.metricName.lowercased()] {
                existingByName.metricId = remoteValue.metricId
                existingByName.metricName = remoteValue.metricName
                existingByName.value = max(existingByName.value, remoteValue.value)
                mergedByMetricId[remoteValue.metricId] = existingByName
            } else {
                mergedByMetricId[remoteValue.metricId] = remoteValue
            }
        }

        return Array(mergedByMetricId.values)
    }

    private func mergeWeightEntries(local: [WeightExerciseValue], remote: [WeightExerciseValue]) -> [WeightExerciseValue] {
        if remote.isEmpty { return local }

        var merged: [WeightExerciseValue] = []
        var seenExercises: Set<UUID> = []
        let localByExercise = Dictionary(local.map { ($0.exerciseId, $0) }, uniquingKeysWith: { (first, second) in
            return first.hasContent ? first : second
        })

        for remoteEntry in remote {
            seenExercises.insert(remoteEntry.exerciseId)
            if let localEntry = localByExercise[remoteEntry.exerciseId], localEntry.hasContent {
                merged.append(localEntry)
            } else {
                merged.append(remoteEntry)
            }
        }

        for localEntry in local where !seenExercises.contains(localEntry.exerciseId) {
            merged.append(localEntry)
        }

        return merged
    }

    private func mergeExpenses(local: [ExpenseEntry], remote: [ExpenseEntry]) -> [ExpenseEntry] {
        if remote.isEmpty { return local }

        var mergedById: [UUID: ExpenseEntry] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteEntry in remote {
            mergedById[remoteEntry.id] = remoteEntry
        }

        return Array(mergedById.values)
    }


    private func mergeSportActivity(existing: SportActivityRecord, remote: SportActivityRecord) -> SportActivityRecord {
        var merged = existing
        merged.sportName = remote.sportName
        merged.colorHex = remote.colorHex
        merged.date = remote.date

        var valuesById: [String: SportMetricValue] = Dictionary(uniqueKeysWithValues: existing.values.map { ($0.id, $0) })
        for value in remote.values {
            valuesById[value.id] = value
        }
        merged.values = Array(valuesById.values)
        return merged
    }

    /// Update only specific fields of a Day document in Firestore. This avoids
    /// accidentally overwriting other fields when only a single property changed.
    func updateDayFields(_ fields: [String: Any], for day: Day, completion: @escaping (Bool) -> Void) {
        var filtered: [String: Any] = [:]
        for (key, value) in fields {
            // Only skip empty strings; allow numbers and arrays to be updated even if empty/zero
            if let str = value as? String, str.isEmpty {
                continue
            }
            filtered[key] = value
        }

        guard !filtered.isEmpty else {
            completion(true)
            return
        }
        var fieldsToWrite = filtered

        if let activities = filtered["sportActivities"] as? [SportActivityRecord] {
            fieldsToWrite["sportActivities"] = encodeSportActivities(activities)
        }
        if let wellnessAdj = filtered["wellnessMetricAdjustments"] as? [SoloMetricValue] {
            fieldsToWrite["wellnessMetricAdjustments"] = encodeSoloMetricValues(wellnessAdj)
        }
        if let activityAdj = filtered["activityMetricAdjustments"] as? [SoloMetricValue] {
            fieldsToWrite["activityMetricAdjustments"] = encodeSoloMetricValues(activityAdj)
        }
        if let soloEntries = filtered["soloPlayEntries"] as? [SoloMetricValue] {
            fieldsToWrite["soloPlayEntries"] = encodeSoloMetricValues(soloEntries)
        }
        if let teamEntries = filtered["teamPlayEntries"] as? [TeamMetricValue] {
            fieldsToWrite["teamPlayEntries"] = encodeTeamMetricValues(teamEntries)
        }
        if let weightEntries = filtered["weightEntries"] as? [WeightExerciseValue] {
            let cleaned = weightEntries.filter { $0.hasContent }
            fieldsToWrite["weightEntries"] = encodeWeightEntries(cleaned)
        }
        if let expenses = filtered["expenses"] as? [ExpenseEntry] {
            fieldsToWrite["expenses"] = encodeExpenses(expenses)
        } else if let encodedExpenses = filtered["expenses"] as? [[String: Any]] {
            fieldsToWrite["expenses"] = encodedExpenses
        }

        // Use UTC-normalized start-of-day so the key matches document IDs
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: day.date)
        let key = dateKey(forUTC: dayStart)

        if let uid = Auth.auth().currentUser?.uid {
            let path = "accounts/\(uid)/days/\(key)"
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(fieldsToWrite, merge: true) { err in
                    if let err = err {
                        print("DayFirestoreService: failed to update fields for \(path): \(err)")
                    }
                    completion(err == nil)
                }
            return
        }

        // Legacy path
        let path = "\(daysSubcollection)/\(key)"
        db.collection(daysSubcollection).document(key).setData(fieldsToWrite, merge: true) { err in
            if let err = err {
                print("DayFirestoreService: failed to update fields for legacy path \(path): \(err)")
            }
            completion(err == nil)
        }
    }

    /// Upload any locally-created days that were queued while unauthenticated.
    /// - Parameters:
    ///   - context: `ModelContext` to find local `Day` objects for the pending keys
    ///   - completion: called with `true` if all uploads succeeded (or nothing pending)
    func uploadPendingDays(in context: ModelContext, completion: @escaping (Bool) -> Void) {
        guard !pendingDayKeys.isEmpty else { completion(true); return }
        guard Auth.auth().currentUser != nil else { completion(false); return }

        // Capture keys and clear pending set (we'll re-add on failure)
        let keysToUpload = Array(pendingDayKeys)
        pendingDayKeys.removeAll()

        var remaining = keysToUpload.count
        var allSucceeded = true

        for key in keysToUpload {
            // parse key back to a date using the dateKey formatter by attempting to create a date from the key
            let fmt = DateFormatter()
            fmt.calendar = Calendar(identifier: .gregorian)
            fmt.timeZone = TimeZone(secondsFromGMT: 0)!
            fmt.dateFormat = "dd-MM-yyyy"
            if let date = fmt.date(from: key) {
                // find local Day for this date using the same UTC calendar as the formatter
                let dayStart = fmt.calendar.startOfDay(for: date)
                let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == dayStart })
                do {
                    let results = try context.fetch(request)
                    if let localDay = results.first {
                        saveDay(localDay) { success in
                            if !success {
                                allSucceeded = false
                                self.pendingDayKeys.insert(key)
                                print("DayFirestoreService: upload failed for key=\(key), re-queued")
                            }
                            remaining -= 1
                            if remaining == 0 { completion(allSucceeded) }
                        }
                    } else {
                        // No local day found — nothing to upload for this key
                        remaining -= 1
                        if remaining == 0 { completion(allSucceeded) }
                    }
                } catch {
                    allSucceeded = false
                    self.pendingDayKeys.insert(key)
                    print("DayFirestoreService: error fetching local Day for key=\(key): \(error). Re-queued")
                    remaining -= 1
                    if remaining == 0 { completion(allSucceeded) }
                }
            } else {
                // could not parse key — skip but mark as failed
                allSucceeded = false
                print("DayFirestoreService: could not parse pending key=\(key)")
                remaining -= 1
                if remaining == 0 { completion(allSucceeded) }
            }
        }
    }
}
