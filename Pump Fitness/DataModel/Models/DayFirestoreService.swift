import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

/// Firestore sync service for `Day` objects.
/// Documents are stored in the `days` collection and keyed by `yyyy-MM-dd` (UTC-normalized) document IDs.
class DayFirestoreService {
    private let db = Firestore.firestore()
    private let userCollection = "accounts"
    private let daysSubcollection = "days"
    /// Pending day keys (yyyy-MM-dd) that were created locally while unauthenticated and should be uploaded when a user signs in.
    private var pendingDayKeys = Set<String>()

    private func dateKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = Calendar.current.startOfDay(for: date)
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: dayStart)
    }

    /// Fetch a Day from Firestore for a given date. If not present remotely, a local `Day` is created (via `Day.fetchOrCreate`) and uploaded.
    /// - Parameters:
    ///   - date: date to fetch (normalized to start-of-day)
    ///   - context: optional `ModelContext` used to insert/find local model instances
    ///   - completion: returns the `Day` (local instance) or `nil` on unrecoverable errors
    func fetchDay(for date: Date, in context: ModelContext?, completion: @escaping (Day?) -> Void) {
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
                    let local = Day.fetchOrCreate(for: date, in: ctx)
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
                let calorieGoalOpt = data["calorieGoal"] as? Int
                let macroFocusOpt = data["macroFocus"] as? String
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: remoteDate, in: ctx)
                    // Only overwrite fields if the remote document actually contains them.
                    if let calories = caloriesOpt {
                        day.caloriesConsumed = calories
                    }
                    if let calorieGoal = calorieGoalOpt {
                        day.calorieGoal = calorieGoal
                    }
                    if let macroFocus = macroFocusOpt {
                        day.macroFocusRaw = macroFocus
                    }
                    print("DayFirestoreService: found remote day for key=\(key), using date=\(remoteDate), caloriesConsumed=\(day.caloriesConsumed)")
                    completion(day)
                    return
                } else {
                    // If no context is provided return an ephemeral Day using whatever remote values exist
                    let calories = caloriesOpt ?? 0
                    let calorieGoal = calorieGoalOpt ?? 0
                    let day = Day(date: remoteDate, caloriesConsumed: calories, calorieGoal: calorieGoal, macroFocusRaw: macroFocusOpt)
                    print("DayFirestoreService: found remote day for key=\(key) (no context), returning ephemeral day, caloriesConsumed=\(calories)")
                    completion(day)
                    return
                }
            } else {
                // Remote doc missing — ensure local exists and upload it
                print("DayFirestoreService: no remote day for key=\(key). Creating local default.")
                // Create local default
                if let ctx = context {
                    let day = Day.fetchOrCreate(for: date, in: ctx)
                    // If user is signed in, attempt immediate upload; otherwise mark for later
                    if Auth.auth().currentUser != nil {
                        print("DayFirestoreService: user signed in — attempting immediate upload for key=\(key)")
                        self.saveDay(day) { _ in completion(day) }
                    } else {
                        print("DayFirestoreService: user NOT signed in — queuing pending key=\(key)")
                        // schedule for upload when user signs in
                        self.pendingDayKeys.insert(key)
                        completion(day)
                    }
                    return
                } else {
                    let day = Day(date: date)
                    if Auth.auth().currentUser != nil {
                        print("DayFirestoreService: user signed in — attempting immediate upload for key=\(key) (no context)")
                        self.saveDay(day) { _ in completion(day) }
                    } else {
                        print("DayFirestoreService: user NOT signed in — queuing pending key=\(key) (no context)")
                        self.pendingDayKeys.insert(key)
                        completion(day)
                    }
                    return
                }
            }
        }
    }

    /// Save a Day to Firestore. Document ID will be `yyyy-MM-dd` for the `day.date`.
    func saveDay(_ day: Day, completion: @escaping (Bool) -> Void) {
        let dayStart = Calendar.current.startOfDay(for: day.date)
        let key = dateKey(for: dayStart)
        // Build a payload only containing the fields we intend to write.
        // Do not write `macroFocus` when it's nil (avoid setting it to null),
        // and use Firestore's merge option so we don't accidentally overwrite
        // unrelated fields with default values.
        var data: [String: Any] = [
            "date": Timestamp(date: dayStart)
        ]
        data["caloriesConsumed"] = day.caloriesConsumed
        data["calorieGoal"] = day.calorieGoal
        if let macro = day.macroFocusRaw {
            data["macroFocus"] = macro
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
        let dayStart = Calendar.current.startOfDay(for: day.date)
        let key = dateKey(for: dayStart)

        if let uid = Auth.auth().currentUser?.uid {
            let path = "accounts/\(uid)/days/\(key)"
            print("DayFirestoreService: updating fields for \(path): \(fields)")
            db.collection(userCollection)
                .document(uid)
                .collection(daysSubcollection)
                .document(key)
                .setData(fields, merge: true) { err in
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
        print("DayFirestoreService: updating fields for legacy path \(path): \(fields)")
        db.collection(daysSubcollection).document(key).setData(fields, merge: true) { err in
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
            fmt.dateFormat = "yyyy-MM-dd"
            if let date = fmt.date(from: key) {
                print("DayFirestoreService: attempting upload for pending key=\(key)")
                // find local Day for this date
                let dayStart = Calendar.current.startOfDay(for: date)
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
