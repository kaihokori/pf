import FirebaseFirestore
import FirebaseAuth
import Foundation

class AccountFirestoreService {
    private let db = Firestore.firestore()
    private let collection = "accounts"

    func fetchAccount(withId id: String, completion: @escaping (Account?) -> Void) {
        db.collection(collection).document(id).getDocument { snapshot, error in
            if let error {
                print("AccountFirestoreService.fetchAccount error for id=\(id): \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let snapshot = snapshot else {
                print("AccountFirestoreService.fetchAccount: no snapshot returned for id=\(id)")
                completion(nil)
                return
            }

            if !snapshot.exists {
                print("AccountFirestoreService.fetchAccount: document does not exist for id=\(id)")
                completion(nil)
                return
            }

            guard let data = snapshot.data() else {
                print("AccountFirestoreService.fetchAccount: snapshot exists but no data for id=\(id)")
                completion(nil)
                return
            }

            let soloMetricDefs = (data["soloMetrics"] as? [[String: Any]] ?? []).compactMap { SoloMetric(dictionary: $0) }
            let teamMetricDefs = (data["teamMetrics"] as? [[String: Any]] ?? []).compactMap { TeamMetric(dictionary: $0) }

            let remoteWeightGroups = (data["weightGroups"] as? [[String: Any]] ?? []).compactMap { WeightGroupDefinition(dictionary: $0) }
            let remoteActivityTimers = (data["activityTimers"] as? [[String: Any]] ?? []).compactMap { ActivityTimerItem(dictionary: $0) }
                let remoteGoals = (data["goals"] as? [[String: Any]] ?? []).compactMap { GoalItem(dictionary: $0) }
            let remoteHabits = (data["habits"] as? [[String: Any]] ?? []).compactMap { HabitDefinition(dictionary: $0) }
                let remoteGroceries = (data["groceryItems"] as? [[String: Any]] ?? []).compactMap { GroceryItem(dictionary: $0) }
            let remoteExpenseCategories = (data["expenseCategories"] as? [[String: Any]] ?? []).compactMap { ExpenseCategory(dictionary: $0) }
            let remoteCurrencySymbol = (data["expenseCurrencySymbol"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteWorkoutSchedule = (data["workoutSchedule"] as? [[String: Any]] ?? []).compactMap { WorkoutScheduleItem(dictionary: $0) }

            let workoutSupplements = (data["workoutSupplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
            let nutritionSupplements = (data["nutritionSupplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
            // Preserve empty remote supplement arrays rather than substituting legacy defaults.
            let resolvedWorkoutSupplements = workoutSupplements
            let resolvedNutritionSupplements = nutritionSupplements

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
                autoRestDayIndices: (data["autoRestDayIndices"] as? [Int]) ?? (data["autoRestDayIndices"] as? [NSNumber])?.map { $0.intValue } ?? [],
                workoutSchedule: remoteWorkoutSchedule.isEmpty ? WorkoutScheduleItem.defaults : remoteWorkoutSchedule,
                trackedMacros: (data["trackedMacros"] as? [[String: Any]] ?? []).compactMap { TrackedMacro(dictionary: $0) },
                cravings: (data["cravings"] as? [[String: Any]] ?? []).compactMap { CravingItem(dictionary: $0) },
                // Preserve empty remote grocery arrays rather than substituting defaults.
                groceryItems: remoteGroceries,
                expenseCategories: remoteExpenseCategories.isEmpty ? ExpenseCategory.defaultCategories() : remoteExpenseCategories,
                expenseCurrencySymbol: (remoteCurrencySymbol?.isEmpty == false ? remoteCurrencySymbol! : Account.deviceCurrencySymbol),
                // Preserve empty remote goals arrays rather than substituting defaults.
                goals: remoteGoals,
                // Preserve empty remote habits arrays rather than substituting defaults.
                habits: remoteHabits,
                mealReminders: (data["mealReminders"] as? [[String: Any]] ?? []).compactMap { MealReminder(dictionary: $0) },
                weeklyProgress: (data["weeklyProgress"] as? [[String: Any]] ?? []).compactMap { WeeklyProgressRecord(dictionary: $0) },
                workoutSupplements: resolvedWorkoutSupplements,
                nutritionSupplements: resolvedNutritionSupplements,
                dailyTasks: (data["dailyTasks"] as? [[String: Any]] ?? []).compactMap { DailyTaskDefinition(dictionary: $0) },
                itineraryEvents: (data["itineraryEvents"] as? [[String: Any]] ?? []).compactMap { ItineraryEvent(dictionary: $0) },
                sports: (data["sports"] as? [[String: Any]] ?? []).compactMap { SportConfig(dictionary: $0) },
                // Preserve empty remote soloMetrics arrays rather than substituting defaults.
                soloMetrics: soloMetricDefs,
                // Preserve empty remote teamMetrics arrays rather than substituting defaults.
                teamMetrics: teamMetricDefs,
                caloriesBurnGoal: data["caloriesBurnGoal"] as? Int ?? 800,
                stepsGoal: data["stepsGoal"] as? Int ?? 10_000,
                distanceGoal: (data["distanceGoal"] as? NSNumber)?.doubleValue ?? data["distanceGoal"] as? Double ?? 3_000,
                // Preserve empty remote weightGroups arrays rather than substituting defaults.
                weightGroups: remoteWeightGroups,
                // Preserve empty remote activity timers arrays rather than substituting defaults.
                activityTimers: remoteActivityTimers,
                trialPeriodEnd: (data["trialPeriodEnd"] as? Timestamp)?.dateValue(),
                didCompleteOnboarding: data["didCompleteOnboarding"] as? Bool ?? false
            )

            completion(account)
        }
    }

    /// Fetch only the `cravings` array for an account document.
    func fetchCravings(withId id: String, completion: @escaping ([CravingItem]?) -> Void) {
        db.collection(collection).document(id).getDocument { snapshot, error in
            if let error {
                print("AccountFirestoreService.fetchCravings error for id=\(id): \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = snapshot?.data() else {
                // Document missing or empty — treat as empty cravings list.
                completion([])
                return
            }

            let remoteCravings = (data["cravings"] as? [[String: Any]] ?? []).compactMap { CravingItem(dictionary: $0) }
            completion(remoteCravings)
        }
    }

    /// Replace the `cravings` field for the given account id. This is
    /// intended to be called explicitly when the user modifies cravings.
    func updateCravings(withId id: String, cravings: [CravingItem], completion: @escaping (Bool) -> Void) {
        let payload = cravings.map { $0.asDictionary }
        self.db.collection(self.collection).document(id).setData(["cravings": payload], merge: true) { error in
            if let error {
                print("AccountFirestoreService.updateCravings error: \(error.localizedDescription)")
            }
            completion(error == nil)
        }
    }

    /// Persist account fields to Firestore. Set `includeCravings` to true only
    /// when the caller intentionally updates cravings to avoid wiping server
    /// data during unrelated saves.
    func saveAccount(_ account: Account, includeCravings: Bool = false, forceOverwrite: Bool = false, completion: @escaping (Bool) -> Void) {
        // Prefer the authenticated user's UID for the document id when signed in.
        let currentUID = Auth.auth().currentUser?.uid
        guard let id = (currentUID ?? account.id), !id.isEmpty else {
            print("AccountFirestoreService.saveAccount: missing account id and no authenticated user")
            completion(false)
            return
        }
        var data: [String: Any] = [:]

        if forceOverwrite || (account.profileAvatar?.isEmpty == false) {
            data["profileAvatar"] = account.profileAvatar ?? ""
        }
        if forceOverwrite || (account.name?.isEmpty == false) {
            data["name"] = account.name ?? ""
        }
        if forceOverwrite || (account.gender?.isEmpty == false) {
            data["gender"] = account.gender ?? ""
        }
        if forceOverwrite || account.dateOfBirth != nil {
            if let dob = account.dateOfBirth {
                data["dateOfBirth"] = dob
            }
        }
        if forceOverwrite || (account.height ?? 0) != 0 {
            data["height"] = account.height ?? 0
        }
        if forceOverwrite || (account.weight ?? 0) != 0 {
            data["weight"] = account.weight ?? 0
        }
        if forceOverwrite || account.maintenanceCalories != 0 {
            data["maintenanceCalories"] = account.maintenanceCalories
        }
        if forceOverwrite || account.calorieGoal != 0 {
            data["calorieGoal"] = account.calorieGoal
        }
        if forceOverwrite || (account.macroFocusRaw?.isEmpty == false) {
            data["macroFocus"] = account.macroFocusRaw ?? ""
        }
        if forceOverwrite || account.intermittentFastingMinutes != 0 {
            data["intermittentFastingMinutes"] = account.intermittentFastingMinutes
        }
        if forceOverwrite || (account.theme?.isEmpty == false) {
            data["theme"] = account.theme ?? ""
        }
        if forceOverwrite || (account.unitSystem?.isEmpty == false) {
            data["unitSystem"] = account.unitSystem ?? ""
        }
        data["caloriesBurnGoal"] = account.caloriesBurnGoal
        data["stepsGoal"] = account.stepsGoal
        data["distanceGoal"] = account.distanceGoal
        let resolvedCurrency = account.expenseCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        data["expenseCurrencySymbol"] = resolvedCurrency.isEmpty ? Account.deviceCurrencySymbol : resolvedCurrency

        if forceOverwrite || account.didCompleteOnboarding {
            data["didCompleteOnboarding"] = account.didCompleteOnboarding
        }
        
        if forceOverwrite || (account.startWeekOn?.isEmpty == false) {
            data["startWeekOn"] = account.startWeekOn ?? ""
        }
        data["autoRestDayIndices"] = account.autoRestDayIndices
        data["trackedMacros"] = account.trackedMacros.map { $0.asDictionary }
        let shouldFallbackCategories = !forceOverwrite && account.expenseCategories.isEmpty
        let categoriesToPersist = shouldFallbackCategories ? ExpenseCategory.defaultCategories() : account.expenseCategories
        data["expenseCategories"] = categoriesToPersist.map { $0.asDictionary }
        if includeCravings {
            data["cravings"] = account.cravings.map { $0.asDictionary }
        }
        // Persist grocery list even when empty so deletions propagate.
        data["groceryItems"] = account.groceryItems.map { $0.asDictionary }
        data["habits"] = account.habits.map { $0.asDictionary }
        data["goals"] = account.goals.map { $0.asDictionary }
        data["mealReminders"] = account.mealReminders.map { $0.asDictionary }
        data["weeklyProgress"] = account.weeklyProgress.map { $0.asFirestoreDictionary() }
        // Persist split supplement lists; also emit legacy combined list for backward compatibility
        data["workoutSupplements"] = account.workoutSupplements.map { $0.asDictionary }
        data["nutritionSupplements"] = account.nutritionSupplements.map { $0.asDictionary }
        var legacySeen = Set<String>()
        let legacySupplements = (account.workoutSupplements + account.nutritionSupplements)
            .filter { legacySeen.insert($0.id).inserted }
        data["supplements"] = legacySupplements.map { $0.asDictionary }

        data["dailyTasks"] = account.dailyTasks.map { $0.asDictionary }
        data["sports"] = account.sports.map { $0.asDictionary }
        data["weightGroups"] = account.weightGroups.map { $0.asDictionary }
        data["soloMetrics"] = account.soloMetrics.map { $0.asDictionary }
        data["teamMetrics"] = account.teamMetrics.map { $0.asDictionary }
        data["activityTimers"] = account.activityTimers.map { $0.asDictionary }
        data["workoutSchedule"] = account.workoutSchedule.map { $0.asDictionary }
        // Persist itinerary events even when empty so deletions propagate.
        data["itineraryEvents"] = account.itineraryEvents.map { $0.asFirestoreDictionary() }
        if let trialEnd = account.trialPeriodEnd {
            data["trialPeriodEnd"] = Timestamp(date: trialEnd)
        } else if forceOverwrite {
            data["trialPeriodEnd"] = FieldValue.delete()
        }

        // Handle activityLevel carefully: avoid writing a default 'sedentary'
        // value into Firestore on initial saves (e.g. app launch). If the
        // activity is 'sedentary' and the remote document doesn't already
        // have an activityLevel, skip persisting it to avoid introducing
        // an implicit default. Otherwise include it as usual.
        if let activity = account.activityLevel, !activity.isEmpty {
            if forceOverwrite {
                data["activityLevel"] = activity
            } else if activity == ActivityLevelOption.sedentary.rawValue {
                // Check remote doc to see if activityLevel already exists.
                self.db.collection(self.collection).document(id).getDocument { snapshot, error in
                    var shouldIncludeActivity = false
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

                    if includeCravings {
                        data["cravings"] = account.cravings.map { $0.asDictionary }
                    }

                    // If there are no other fields to write and activity was skipped,
                    // return success (nothing to do).
                    if data.isEmpty {
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
                return
            } else {
                data["activityLevel"] = activity
            }
        }

        guard !data.isEmpty else {
            completion(true)
            return
        }

        if includeCravings {
            data["cravings"] = account.cravings.map { $0.asDictionary }
        }

        self.db.collection(self.collection).document(id).setData(data, merge: true) { error in
            if let error {
                print("AccountFirestoreService.saveAccount error: \(error.localizedDescription)")
            }
            completion(error == nil)
        }
    }
}
