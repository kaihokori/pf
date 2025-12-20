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

    private func dateKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        // Use the UTC calendar to compute the start-of-day so keys are UTC-normalized
        let dayStart = cal.startOfDay(for: date)
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: dayStart)
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

    // Determine whether a Day instance contains any non-default data that should be uploaded.
    private func dayHasMeaningfulData(_ day: Day) -> Bool {
        if day.caloriesConsumed != 0 { return true }
        if !day.completedMeals.isEmpty { return true }
        if !day.takenSupplements.isEmpty { return true }
        if !day.takenWorkoutSupplements.isEmpty { return true }
        if day.caloriesBurned != 0 { return true }
        if day.stepsTaken != 0 { return true }
        if day.distanceTravelled != 0 { return true }
        if day.macroConsumptions.contains(where: { $0.consumed != 0 }) { return true }
        if !day.mealIntakes.isEmpty { return true }
        if !day.dailyTaskCompletions.isEmpty { return true }
        return false
    }


    /// Fetch a Day from Firestore for a given date. If not present remotely, a local `Day` is created (via `Day.fetchOrCreate`) and uploaded.
    /// - Parameters:
    ///   - date: date to fetch (normalized to start-of-day)
    ///   - context: optional `ModelContext` used to insert/find local model instances
    ///   - completion: returns the `Day` (local instance) or `nil` on unrecoverable errors
    func fetchDay(for date: Date, in context: ModelContext?, trackedMacros: [TrackedMacro]? = nil, completion: @escaping (Day?) -> Void) {
        let key = dateKey(for: date)

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
                let caloriesBurnedRemote = (data["caloriesBurned"] as? NSNumber)?.doubleValue
                let stepsTakenRemote = (data["stepsTaken"] as? NSNumber)?.doubleValue
                let distanceRemote = (data["distanceTravelled"] as? NSNumber)?.doubleValue
                let macroConsumptionsRemote = (data["macroConsumptions"] as? [[String: Any]] ?? []).compactMap { self.decodeMacroConsumption($0) }
                let takenSupplementsRemote = data["takenSupplements"] as? [String]
                let completedMealsRemote = data["completedMeals"] as? [String]
                let mealIntakesRemote = (data["mealIntakes"] as? [[String: Any]] ?? []).compactMap { self.decodeMealIntake($0) }
                let dailyTaskCompletionsRemote = (data["dailyTaskCompletions"] as? [[String: Any]] ?? []).compactMap { self.decodeDailyTaskCompletion($0) }
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: remoteDate, in: ctx, trackedMacros: trackedMacros)
                    // Merge remote values into local without wiping newer local data.
                    if let calories = caloriesOpt {
                        day.caloriesConsumed = max(day.caloriesConsumed, calories)
                    }

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
                    if let takenWorkoutRemote = data["takenWorkoutSupplements"] as? [String] {
                        let merged = Array(Set(day.takenWorkoutSupplements).union(Set(takenWorkoutRemote)))
                        day.takenWorkoutSupplements = merged
                    }

                    let mergedIntakes = self.mergeMealIntakes(local: day.mealIntakes, remote: mealIntakesRemote)
                    day.mealIntakes = mergedIntakes

                    let mergedCompletions = self.mergeDailyTaskCompletions(local: day.dailyTaskCompletions, remote: dailyTaskCompletionsRemote)
                    day.dailyTaskCompletions = mergedCompletions

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
                        macroConsumptions: macroConsumptionsRemote,
                        completedMeals: completedMealsRemote ?? [],
                        takenSupplements: takenSupplementsRemote ?? [],
                        takenWorkoutSupplements: data["takenWorkoutSupplements"] as? [String] ?? [],
                        mealIntakes: mealIntakesRemote,
                        caloriesBurned: caloriesBurnedRemote ?? 0,
                        stepsTaken: stepsTakenRemote ?? 0,
                        distanceTravelled: distanceRemote ?? 0,
                        dailyTaskCompletions: dailyTaskCompletionsRemote
                    )
                    completion(day)
                    return
                }
            } else {
                // Remote doc missing — ensure local exists and upload it
                // Create local default
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: date, in: ctx, trackedMacros: trackedMacros)
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
    func saveDay(_ day: Day, completion: @escaping (Bool) -> Void) {
        // If the day only contains default/zero values then avoid uploading it —
        // this prevents accidental overwrites of non-zero remote/core-data values with zeros.
        if !dayHasMeaningfulData(day) {
            completion(true)
            return
        }

        // Normalize start-of-day to UTC to match `dateKey(for:)` behavior
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: day.date)
        let key = dateKey(for: dayStart)
        // Build a payload only containing the fields we intend to write.
        // Do not write `macroFocus` when it's nil (avoid setting it to null),
        // and use Firestore's merge option so we don't accidentally overwrite
        // unrelated fields with default values.
        var data: [String: Any] = [
            "date": Timestamp(date: dayStart)
        ]

        if day.caloriesConsumed != 0 {
            data["caloriesConsumed"] = day.caloriesConsumed
        }
        if !day.completedMeals.isEmpty {
            data["completedMeals"] = day.completedMeals
        }
        if !day.takenSupplements.isEmpty {
            data["takenSupplements"] = encodeTakenSupplements(day.takenSupplements)
        }
        if !day.takenWorkoutSupplements.isEmpty {
            data["takenWorkoutSupplements"] = encodeTakenWorkoutSupplements(day.takenWorkoutSupplements)
        }
        if day.caloriesBurned > 0 {
            data["caloriesBurned"] = day.caloriesBurned
        }
        if day.stepsTaken > 0 {
            data["stepsTaken"] = day.stepsTaken
        }
        if day.distanceTravelled > 0 {
            data["distanceTravelled"] = day.distanceTravelled
        }
        if day.macroConsumptions.contains(where: { $0.consumed != 0 }) {
            data["macroConsumptions"] = encodeMacroConsumptions(day.macroConsumptions)
        }
        if !day.mealIntakes.isEmpty {
            data["mealIntakes"] = encodeMealIntakes(day.mealIntakes)
        }
        if !day.dailyTaskCompletions.isEmpty {
            data["dailyTaskCompletions"] = encodeDailyTaskCompletions(day.dailyTaskCompletions)
        }
        if let uid = Auth.auth().currentUser?.uid {
            // accounts/{userID}/days/{dayDate}
            let path = "accounts/\(uid)/days/\(key)"
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(data, merge: true) { err in
                    if let err = err {
                        print("DayFirestoreService: failed to save day to \(path): \(err)")
                    }
                    completion(err == nil)
                }
            return
        }

        // Fallback legacy path
        let path = "\(daysSubcollection)/\(key)"
        db.collection(daysSubcollection).document(key).setData(data, merge: true) { err in
            if let err = err {
                print("DayFirestoreService: failed to save day to legacy path \(path): \(err)")
            } else {
            }
            completion(err == nil)
        }
    }

    // Merge helpers to prevent remote reads from clobbering newer local edits.
    private func mergeMacroConsumptions(local: [MacroConsumption], remote: [MacroConsumption]) -> [MacroConsumption] {
        if remote.isEmpty { return local }

        var mergedById: [String: MacroConsumption] = Dictionary(uniqueKeysWithValues: local.map { ($0.trackedMacroId, $0) })
        let localByName: [String: MacroConsumption] = Dictionary(uniqueKeysWithValues: local.map { ($0.name.lowercased(), $0) })

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

    /// Update only specific fields of a Day document in Firestore. This avoids
    /// accidentally overwriting other fields when only a single property changed.
    func updateDayFields(_ fields: [String: Any], for day: Day, completion: @escaping (Bool) -> Void) {
        // Avoid writing defaults back to Firestore; filter out empty/zero values.
        var filtered: [String: Any] = [:]
        for (key, value) in fields {
            switch value {
            case let int as Int where int == 0:
                continue
            case let double as Double where double == 0:
                continue
            case let array as [Any] where array.isEmpty:
                continue
            case let string as String where string.isEmpty:
                continue
            default:
                filtered[key] = value
            }
        }

        guard !filtered.isEmpty else {
            completion(true)
            return
        }
        let fieldsToWrite = filtered

        // Use UTC-normalized start-of-day so the key matches document IDs
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: day.date)
        let key = dateKey(for: dayStart)

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
