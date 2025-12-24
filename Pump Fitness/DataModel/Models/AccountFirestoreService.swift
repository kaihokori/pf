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
            let legacySupplements = (data["supplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
            let resolvedWorkoutSupplements = workoutSupplements.isEmpty ? legacySupplements : workoutSupplements
            let resolvedNutritionSupplements = nutritionSupplements.isEmpty ? legacySupplements : nutritionSupplements

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
                groceryItems: remoteGroceries.isEmpty ? GroceryItem.sampleItems() : remoteGroceries,
                expenseCategories: remoteExpenseCategories.isEmpty ? ExpenseCategory.defaultCategories() : remoteExpenseCategories,
                expenseCurrencySymbol: (remoteCurrencySymbol?.isEmpty == false ? remoteCurrencySymbol! : Account.deviceCurrencySymbol),
                goals: remoteGoals.isEmpty ? GoalItem.sampleDefaults() : remoteGoals,
                habits: remoteHabits.isEmpty ? HabitDefinition.defaults : remoteHabits,
                mealReminders: (data["mealReminders"] as? [[String: Any]] ?? []).compactMap { MealReminder(dictionary: $0) },
                weeklyProgress: (data["weeklyProgress"] as? [[String: Any]] ?? []).compactMap { WeeklyProgressRecord(dictionary: $0) },
                workoutSupplements: resolvedWorkoutSupplements,
                nutritionSupplements: resolvedNutritionSupplements,
                dailyTasks: (data["dailyTasks"] as? [[String: Any]] ?? []).compactMap { DailyTaskDefinition(dictionary: $0) },
                itineraryEvents: (data["itineraryEvents"] as? [[String: Any]] ?? []).compactMap { ItineraryEvent(dictionary: $0) },
                sports: (data["sports"] as? [[String: Any]] ?? []).compactMap { SportConfig(dictionary: $0) },
                soloMetrics: soloMetricDefs.isEmpty ? SoloMetric.defaultMetrics : soloMetricDefs,
                teamMetrics: teamMetricDefs.isEmpty ? TeamMetric.defaultMetrics : teamMetricDefs,
                caloriesBurnGoal: data["caloriesBurnGoal"] as? Int ?? 800,
                stepsGoal: data["stepsGoal"] as? Int ?? 10_000,
                distanceGoal: (data["distanceGoal"] as? NSNumber)?.doubleValue ?? data["distanceGoal"] as? Double ?? 3_000,
                weightGroups: remoteWeightGroups.isEmpty ? WeightGroupDefinition.defaults : remoteWeightGroups,
                activityTimers: remoteActivityTimers.isEmpty ? ActivityTimerItem.defaultTimers : remoteActivityTimers
            )

            completion(account)
        }
    }

    func saveAccount(_ account: Account, completion: @escaping (Bool) -> Void) {
        // Prefer the authenticated user's UID for the document id when signed in.
        let currentUID = Auth.auth().currentUser?.uid
        guard let id = (currentUID ?? account.id), !id.isEmpty else {
            print("AccountFirestoreService.saveAccount: missing account id and no authenticated user")
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
        data["caloriesBurnGoal"] = account.caloriesBurnGoal
        data["stepsGoal"] = account.stepsGoal
        data["distanceGoal"] = account.distanceGoal
        let resolvedCurrency = account.expenseCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        data["expenseCurrencySymbol"] = resolvedCurrency.isEmpty ? Account.deviceCurrencySymbol : resolvedCurrency
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
        data["autoRestDayIndices"] = account.autoRestDayIndices
        if !account.trackedMacros.isEmpty {
            data["trackedMacros"] = account.trackedMacros.map { $0.asDictionary }
        }
        let categoriesToPersist = account.expenseCategories.isEmpty ? ExpenseCategory.defaultCategories() : account.expenseCategories
        data["expenseCategories"] = categoriesToPersist.map { $0.asDictionary }
        if !account.cravings.isEmpty {
            data["cravings"] = account.cravings.map { $0.asDictionary }
        }
        // Persist grocery list even when empty so deletions propagate.
        data["groceryItems"] = account.groceryItems.map { $0.asDictionary }
        if !account.habits.isEmpty {
            data["habits"] = account.habits.map { $0.asDictionary }
        }
        data["goals"] = account.goals.map { $0.asDictionary }
        if !account.mealReminders.isEmpty {
            data["mealReminders"] = account.mealReminders.map { $0.asDictionary }
        }
        if !account.weeklyProgress.isEmpty {
            data["weeklyProgress"] = account.weeklyProgress.map { $0.asFirestoreDictionary() }
        }

        // Persist split supplement lists; also emit legacy combined list for backward compatibility
        data["workoutSupplements"] = account.workoutSupplements.map { $0.asDictionary }
        data["nutritionSupplements"] = account.nutritionSupplements.map { $0.asDictionary }
        var legacySeen = Set<String>()
        let legacySupplements = (account.workoutSupplements + account.nutritionSupplements)
            .filter { legacySeen.insert($0.id).inserted }
        data["supplements"] = legacySupplements.map { $0.asDictionary }

        if !account.dailyTasks.isEmpty {
            data["dailyTasks"] = account.dailyTasks.map { $0.asDictionary }
        }
        if !account.sports.isEmpty {
            data["sports"] = account.sports.map { $0.asDictionary }
        }
        data["weightGroups"] = account.weightGroups.map { $0.asDictionary }
        data["soloMetrics"] = account.soloMetrics.map { $0.asDictionary }
        data["teamMetrics"] = account.teamMetrics.map { $0.asDictionary }
        data["activityTimers"] = account.activityTimers.map { $0.asDictionary }
        data["workoutSchedule"] = account.workoutSchedule.map { $0.asDictionary }
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
