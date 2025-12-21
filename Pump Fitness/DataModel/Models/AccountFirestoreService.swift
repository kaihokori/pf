import FirebaseFirestore
import Foundation

class AccountFirestoreService {
    private let db = Firestore.firestore()
    private let collection = "accounts"

    func fetchAccount(withId id: String, completion: @escaping (Account?) -> Void) {
        db.collection(collection).document(id).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                completion(nil)
                return
            }

            let soloMetricDefs = (data["soloMetrics"] as? [[String: Any]] ?? []).compactMap { SoloMetric(dictionary: $0) }

            let account = Account(
                id: id,
                profileImage: nil, // Handle image separately
                profileAvatar: data["profileAvatar"] as? String,
                name: data["name"] as? String,
                gender: data["gender"] as? String,
                dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
                height: data["height"] as? Double,
                weight: data["weight"] as? Double,
                maintenanceCalories: data["maintenanceCalories"] as? Int ?? 0,
                calorieGoal: data["calorieGoal"] as? Int ?? 0,
                macroFocusRaw: data["macroFocus"] as? String,
                intermittentFastingMinutes: data["intermittentFastingMinutes"] as? Int ?? 16 * 60,
                theme: data["theme"] as? String,
                unitSystem: data["unitSystem"] as? String,
                activityLevel: data["activityLevel"] as? String,
                startWeekOn: data["startWeekOn"] as? String,
                trackedMacros: (data["trackedMacros"] as? [[String: Any]] ?? []).compactMap { TrackedMacro(dictionary: $0) },
                cravings: (data["cravings"] as? [[String: Any]] ?? []).compactMap { CravingItem(dictionary: $0) },
                mealReminders: (data["mealReminders"] as? [[String: Any]] ?? []).compactMap { MealReminder(dictionary: $0) },
                weeklyProgress: (data["weeklyProgress"] as? [[String: Any]] ?? []).compactMap { WeeklyProgressRecord(dictionary: $0) },
                supplements: (data["supplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) },
                dailyTasks: (data["dailyTasks"] as? [[String: Any]] ?? []).compactMap { DailyTaskDefinition(dictionary: $0) },
                itineraryEvents: (data["itineraryEvents"] as? [[String: Any]] ?? []).compactMap { ItineraryEvent(dictionary: $0) },
                sports: (data["sports"] as? [[String: Any]] ?? []).compactMap { SportConfig(dictionary: $0) },
                soloMetrics: soloMetricDefs.isEmpty ? SoloMetric.defaultMetrics : soloMetricDefs
            )

            // Debug: print parsed weeklyProgress records
            let dateFmt = DateFormatter()
            dateFmt.dateStyle = .short
            dateFmt.timeStyle = .none
            for rec in account.weeklyProgress {
                print("  id=\(rec.id) date=\(dateFmt.string(from: rec.date)) weight=\(rec.weight) hasPhoto=\(rec.photoData != nil)")
            }
            completion(account)
        }
    }

    func saveAccount(_ account: Account, completion: @escaping (Bool) -> Void) {
        guard let id = account.id, !id.isEmpty else {
            print("AccountFirestoreService.saveAccount: missing account id")
            completion(false)
            return
        }
        var data: [String: Any] = [:]

        if let avatar = account.profileAvatar, !avatar.isEmpty {
            data["profileAvatar"] = avatar
        }
        if let name = account.name, !name.isEmpty {
            data["name"] = name
        }
        if let gender = account.gender, !gender.isEmpty {
            data["gender"] = gender
        }
        if let dob = account.dateOfBirth {
            data["dateOfBirth"] = dob
        }
        if let height = account.height, height != 0 {
            data["height"] = height
        }
        if let weight = account.weight, weight != 0 {
            data["weight"] = weight
        }
        if account.maintenanceCalories != 0 {
            data["maintenanceCalories"] = account.maintenanceCalories
        }
        if account.calorieGoal != 0 {
            data["calorieGoal"] = account.calorieGoal
        }
        if let macroFocus = account.macroFocusRaw, !macroFocus.isEmpty {
            data["macroFocus"] = macroFocus
        }
        if account.intermittentFastingMinutes != 0 {
            data["intermittentFastingMinutes"] = account.intermittentFastingMinutes
        }
        if let theme = account.theme, !theme.isEmpty {
            data["theme"] = theme
        }
        if let unitSystem = account.unitSystem, !unitSystem.isEmpty {
            data["unitSystem"] = unitSystem
        }
        // Handle activityLevel carefully: avoid writing a default 'sedentary'
        // value into Firestore on initial saves (e.g. app launch). If the
        // activity is 'sedentary' and the remote document doesn't already
        // have an activityLevel, skip persisting it to avoid introducing
        // an implicit default. Otherwise include it as usual.
        var shouldIncludeActivity = false
        if let activity = account.activityLevel, !activity.isEmpty {
            if activity == ActivityLevelOption.sedentary.rawValue {
                // Check remote doc to see if activityLevel already exists.
                self.db.collection(self.collection).document(id).getDocument { snapshot, error in
                    if let dataRemote = snapshot?.data(), let _ = dataRemote["activityLevel"] as? String {
                        // remote already has a value; include ours to update
                        shouldIncludeActivity = true
                    } else {
                        // remote has no activityLevel; do not write a default 'sedentary'
                        shouldIncludeActivity = false
                    }

                    if shouldIncludeActivity {
                        data["activityLevel"] = activity
                    }

                    // If there are no other fields to write and activity was skipped,
                    // return success (nothing to do).
                    if data.isEmpty {
                        completion(true)
                        return
                    }

                    self.db.collection(self.collection).document(id).setData(data, merge: true) { error in
                        completion(error == nil)
                    }
                }
                return
            } else {
                data["activityLevel"] = activity
            }
        }
        if let startWeekOn = account.startWeekOn, !startWeekOn.isEmpty {
            data["startWeekOn"] = startWeekOn
        }
        if !account.trackedMacros.isEmpty {
            data["trackedMacros"] = account.trackedMacros.map { $0.asDictionary }
        }
        if !account.cravings.isEmpty {
            data["cravings"] = account.cravings.map { $0.asDictionary }
        }
        if !account.mealReminders.isEmpty {
            data["mealReminders"] = account.mealReminders.map { $0.asDictionary }
        }
        if !account.weeklyProgress.isEmpty {
            data["weeklyProgress"] = account.weeklyProgress.map { $0.asFirestoreDictionary() }
        }
        if !account.supplements.isEmpty {
            data["supplements"] = account.supplements.map { $0.asDictionary }
        }
        if !account.dailyTasks.isEmpty {
            data["dailyTasks"] = account.dailyTasks.map { $0.asDictionary }
        }
        if !account.sports.isEmpty {
            data["sports"] = account.sports.map { $0.asDictionary }
        }
        data["soloMetrics"] = account.soloMetrics.map { $0.asDictionary }
        // Persist itinerary events even when empty so deletions propagate.
        data["itineraryEvents"] = account.itineraryEvents.map { $0.asFirestoreDictionary() }

        guard !data.isEmpty else {
            completion(true)
            return
        }

        self.db.collection(self.collection).document(id).setData(data, merge: true) { error in
            if let error {
                print("AccountFirestoreService.saveAccount error: \(error.localizedDescription)")
            }
            completion(error == nil)
        }
    }
}
