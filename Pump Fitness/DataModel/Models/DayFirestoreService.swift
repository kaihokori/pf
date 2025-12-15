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

        print("DayFirestoreService: fetching day for key=\(key)")
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
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: remoteDate, in: ctx, trackedMacros: trackedMacros)
                    // Only overwrite fields if the remote document actually contains them.
                    if let calories = caloriesOpt {
                        day.caloriesConsumed = calories
                    }
                    if !macroConsumptionsRemote.isEmpty {
                        day.macroConsumptions = macroConsumptionsRemote
                    } else if let tracked = trackedMacros {
                        day.ensureMacroConsumptions(for: tracked)
                    }
                    if let completedMealsRemote = completedMealsRemote {
                        day.completedMeals = completedMealsRemote
                    }
                    if let takenSupplementsRemote = takenSupplementsRemote {
                        day.takenSupplements = takenSupplementsRemote
                    }
                    if let caloriesBurnedRemote = caloriesBurnedRemote {
                        day.caloriesBurned = caloriesBurnedRemote
                    }
                    if let stepsTakenRemote = stepsTakenRemote {
                        day.stepsTaken = stepsTakenRemote
                    }
                    if let distanceRemote = distanceRemote {
                        day.distanceTravelled = distanceRemote
                    }
                    if let takenWorkoutRemote = data["takenWorkoutSupplements"] as? [String] {
                        day.takenWorkoutSupplements = takenWorkoutRemote
                    }
                    day.mealIntakes = mealIntakesRemote
                    print("DayFirestoreService: found remote day for key=\(key), using date=\(remoteDate), caloriesConsumed=\(day.caloriesConsumed)")
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
                        distanceTravelled: distanceRemote ?? 0
                    )
                    print("DayFirestoreService: found remote day for key=\(key) (no context), returning ephemeral day, caloriesConsumed=\(calories)")
                    completion(day)
                    return
                }
            } else {
                // Remote doc missing — ensure local exists and upload it
                print("DayFirestoreService: no remote day for key=\(key). Creating local default.")
                // Create local default
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: date, in: ctx, trackedMacros: trackedMacros)
                    // If user is signed in, attempt immediate upload; otherwise mark for later
                    if Auth.auth().currentUser != nil {
                        print("DayFirestoreService: user signed in — attempting immediate upload for key=\(key)")
                        if self.dayHasMeaningfulData(day) {
                            self.saveDay(day) { _ in completion(day) }
                        } else {
                            print("DayFirestoreService: local day for key=\(key) has no meaningful data — skipping upload")
                            completion(day)
                        }
                    } else {
                        print("DayFirestoreService: user NOT signed in — queuing pending key=\(key)")
                        // schedule for upload when user signs in only if there is something to upload
                        if self.dayHasMeaningfulData(day) {
                            self.pendingDayKeys.insert(key)
                        } else {
                            print("DayFirestoreService: local day for key=\(key) has no meaningful data — not queued")
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
                        print("DayFirestoreService: user signed in — attempting immediate upload for key=\(key) (no context)")
                        if self.dayHasMeaningfulData(day) {
                            self.saveDay(day) { _ in completion(day) }
                        } else {
                            print("DayFirestoreService: ephemeral day for key=\(key) has no meaningful data — skipping upload")
                            completion(day)
                        }
                    } else {
                        print("DayFirestoreService: user NOT signed in — queuing pending key=\(key) (no context)")
                        if self.dayHasMeaningfulData(day) {
                            self.pendingDayKeys.insert(key)
                        } else {
                            print("DayFirestoreService: ephemeral day for key=\(key) has no meaningful data — not queued")
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
            print("DayFirestoreService: skipping save for day with no meaningful data (key will not be written)")
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
        if let uid = Auth.auth().currentUser?.uid {
            // accounts/{userID}/days/{dayDate}
            let path = "accounts/\(uid)/days/\(key)"
            print("DayFirestoreService: saving day to \(path) with data=\(data)")
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(data, merge: true) { err in
                    if let err = err {
                        print("DayFirestoreService: failed to save day to \(path): \(err)")
                    } else {
                        print("DayFirestoreService: successfully saved day to \(path)")
                    }
                    completion(err == nil)
                }
            return
        }

        // Fallback legacy path
        let path = "\(daysSubcollection)/\(key)"
        print("DayFirestoreService: saving day to legacy path \(path) with data=\(data)")
        db.collection(daysSubcollection).document(key).setData(data, merge: true) { err in
            if let err = err {
                print("DayFirestoreService: failed to save day to legacy path \(path): \(err)")
            } else {
                print("DayFirestoreService: successfully saved day to legacy path \(path)")
            }
            completion(err == nil)
        }
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
            print("DayFirestoreService: updating fields for \(path): \(fieldsToWrite)")
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(fieldsToWrite, merge: true) { err in
                    if let err = err {
                        print("DayFirestoreService: failed to update fields for \(path): \(err)")
                    } else {
                        print("DayFirestoreService: successfully updated fields for \(path)")
                    }
                    completion(err == nil)
                }
            return
        }

        // Legacy path
        let path = "\(daysSubcollection)/\(key)"
        print("DayFirestoreService: updating fields for legacy path \(path): \(fieldsToWrite)")
        db.collection(daysSubcollection).document(key).setData(fieldsToWrite, merge: true) { err in
            if let err = err {
                print("DayFirestoreService: failed to update fields for legacy path \(path): \(err)")
            } else {
                print("DayFirestoreService: successfully updated fields for legacy path \(path)")
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
        guard Auth.auth().currentUser != nil else { print("DayFirestoreService: uploadPendingDays called but user not signed in"); completion(false); return }

        print("DayFirestoreService: uploading pending days: \(pendingDayKeys)")

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
                print("DayFirestoreService: attempting upload for pending key=\(key)")
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
                            } else {
                                print("DayFirestoreService: upload succeeded for key=\(key)")
                            }
                            remaining -= 1
                            if remaining == 0 { completion(allSucceeded) }
                        }
                    } else {
                        // No local day found — nothing to upload for this key
                        print("DayFirestoreService: no local Day found for pending key=\(key), skipping")
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
