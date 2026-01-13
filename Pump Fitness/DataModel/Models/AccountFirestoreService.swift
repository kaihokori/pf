import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
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

            let profileAvatar = (data["profileAvatar"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            func finish(with imageData: Data?) {
                if let data = imageData {
                    print("AccountFirestoreService: Finishing fetchAccount with image data attached. Size: \(data.count)")
                } else {
                    print("AccountFirestoreService: Finishing fetchAccount with NIL image data.")
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
                let remoteMealSchedule = (data["mealSchedule"] as? [[String: Any]] ?? []).compactMap { MealScheduleItem(dictionary: $0) }
                let remoteMealCatalog = (data["mealCatalog"] as? [[String: Any]] ?? []).compactMap { CatalogMeal(dictionary: $0) }

                let workoutSupplements = (data["workoutSupplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
                let nutritionSupplements = (data["nutritionSupplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
                // Preserve empty remote supplement arrays rather than substituting legacy defaults.
                let resolvedWorkoutSupplements = workoutSupplements
                let resolvedNutritionSupplements = nutritionSupplements

                let account = Account(
                    id: id,
                    profileImage: imageData,
                    profileAvatar: profileAvatar,
                    name: data["name"] as? String,
                    gender: data["gender"] as? String,
                    dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
                    height: data["height"] as? Double,
                    weight: data["weight"] as? Double,
                    maintenanceCalories: data["maintenanceCalories"] as? Int ?? 0,
                    calorieGoal: data["calorieGoal"] as? Int ?? 0,
                    weightGoalRaw: data["weightGoal"] as? String,
                    macroStrategyRaw: data["macroStrategy"] as? String,
                    intermittentFastingMinutes: data["intermittentFastingMinutes"] as? Int ?? 16 * 60,
                    theme: data["theme"] as? String,
                    unitSystem: data["unitSystem"] as? String,
                    activityLevel: data["activityLevel"] as? String,
                    startWeekOn: data["startWeekOn"] as? String,
                    autoRestDayIndices: (data["autoRestDayIndices"] as? [Int]) ?? (data["autoRestDayIndices"] as? [NSNumber])?.map { $0.intValue } ?? [],
                    workoutSchedule: remoteWorkoutSchedule.isEmpty ? WorkoutScheduleItem.defaults : remoteWorkoutSchedule,
                    mealSchedule: remoteMealSchedule.isEmpty ? MealScheduleItem.defaults : remoteMealSchedule,
                    mealCatalog: remoteMealCatalog,
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
                    itineraryTrips: (data["itineraryTrips"] as? [[String: Any]] ?? []).compactMap { ItineraryTrip(dictionary: $0) },
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
                    proPeriodEnd: (data["proPeriodEnd"] as? Timestamp)?.dateValue(),
                    subscriptionStatus: data["subscriptionStatus"] as? String,
                    subscriptionStatusUpdatedAt: (data["subscriptionStatusUpdatedAt"] as? Timestamp)?.dateValue(),
                    didCompleteOnboarding: data["didCompleteOnboarding"] as? Bool ?? false,
                    googleRefreshToken: data["googleRefreshToken"] as? String
                )

                completion(account)
            }

            if let avatarString = profileAvatar, !avatarString.isEmpty {
                print("AccountFirestoreService: Found avatar string: \(avatarString)")
                // If it's a Firebase Storage URL (gs:// or firebasestorage domain), use the Storage SDK
                // so it handles auth if the rules invoke it, though usually public URLs work with URLSession too.
                if avatarString.hasPrefix("gs://") || (avatarString.hasPrefix("http") && avatarString.contains("firebasestorage.googleapis.com")) {
                    print("AccountFirestoreService: Attempting Firebase Storage download")
                    let storageRef = Storage.storage().reference(forURL: avatarString)
                    // Max size 5MB
                    storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("AccountFirestoreService: Error downloading profile image: \(error)")
                            // Fallback to simpler URL download if it was http, or just fail
                            if avatarString.hasPrefix("http"), let url = URL(string: avatarString) {
                                print("AccountFirestoreService: Falling back to standard URL download")
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    finish(with: data)
                                }.resume()
                            } else {
                                finish(with: nil)
                            }
                        } else {
                            print("AccountFirestoreService: Successfully downloaded image via Storage SDK. Size: \(data?.count ?? 0) bytes")
                            finish(with: data)
                        }
                    }
                } else if avatarString.hasPrefix("http"), let url = URL(string: avatarString) {
                    // External URL (e.g. Google auth image, unrelated host)
                    print("AccountFirestoreService: Attempting external URL download: \(url)")
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data, error == nil {
                            print("AccountFirestoreService: Successfully downloaded external image. Size: \(data.count) bytes")
                            finish(with: data)
                        } else {
                            print("AccountFirestoreService: Error downloading external profile image: \(error?.localizedDescription ?? "unknown")")
                            finish(with: nil)
                        }
                    }.resume()
                } else {
                    // Not a URL string (e.g. "0", "1" for local colors), so no image data to fetch.
                    print("AccountFirestoreService: Avatar string is not a URL (likely a color index). No image to fetch.")
                    finish(with: nil)
                }
            } else {
                print("AccountFirestoreService: profileAvatar is nil or empty")
                finish(with: nil)
            }
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

    /// Explicitly updates the trialPeriodEnd field.
    /// Use this instead of saveAccount to avoid race conditions overwriting remote values with stale local data.
    func updateTrialPeriodEnd(for id: String, date: Date?, completion: ((Bool) -> Void)? = nil) {
        var data: [String: Any] = [:]
        if let d = date {
            data["trialPeriodEnd"] = Timestamp(date: d)
        } else {
            data["trialPeriodEnd"] = FieldValue.delete()
        }
        
        db.collection(collection).document(id).setData(data, merge: true) { error in
            if let error {
                print("AccountFirestoreService.updateTrialPeriodEnd error: \(error.localizedDescription)")
            }
            completion?(error == nil)
        }
    }

    /// Explicitly updates the proPeriodEnd field.
    /// Use this instead of saveAccount to avoid race conditions overwriting remote values with stale local data.
    func updateProPeriodEnd(for id: String, date: Date?, completion: ((Bool) -> Void)? = nil) {
        var data: [String: Any] = [:]
        if let d = date {
            data["proPeriodEnd"] = Timestamp(date: d)
        } else {
            // Set to null to clear the override but keep the field key present
            data["proPeriodEnd"] = NSNull()
        }
        
        db.collection(collection).document(id).setData(data, merge: true) { error in
            if let error {
                print("AccountFirestoreService.updateProPeriodEnd error: \(error.localizedDescription)")
            }
            completion?(error == nil)
        }
    }

    /// Persist a lightweight subscription status string for analytics/metadata.
    func updateSubscriptionStatus(for id: String, status: String, completion: ((Bool) -> Void)? = nil) async {
        let payload: [String: Any] = [
            "subscriptionStatus": status,
            "subscriptionStatusUpdatedAt": Timestamp(date: Date())
        ]

        await withCheckedContinuation { continuation in
            db.collection(collection).document(id).setData(payload, merge: true) { error in
                if let error {
                    print("AccountFirestoreService.updateSubscriptionStatus error: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    completion?(true)
                }
                continuation.resume()
            }
        }
    }

    /// Checks if 'proPeriodEnd' exists in the document. If not, initializes it to null.
    /// This ensures the field is visible in the console for manual editing.
    func ensureProPeriodFieldExists(for id: String) {
        let docRef = db.collection(collection).document(id)
        docRef.getDocument { snapshot, error in
            if let data = snapshot?.data() {
                // If key is missing entirely, set it to NSNull() to make it "present" but empty.
                if data["proPeriodEnd"] == nil {
                     print("AccountFirestoreService: proPeriodEnd missing, initializing to null.")
                     docRef.setData(["proPeriodEnd": NSNull()], merge: true)
                }
            }
        }
    }

    /// Overload for backward compatibility
    func saveAccount(_ account: Account, includeCravings: Bool = false, forceOverwrite: Bool = false, completion: @escaping (Bool) -> Void) {
        saveAccount(account, includeCravings: includeCravings, forceOverwrite: forceOverwrite) { success, _ in
            completion(success)
        }
    }

    /// Persist account fields to Firestore. Set `includeCravings` to true only
    /// when the caller intentionally updates cravings to avoid wiping server
    /// data during unrelated saves.
    func saveAccount(_ account: Account, includeCravings: Bool = false, forceOverwrite: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        // Prefer the authenticated user's UID for the document id when signed in.
        let currentUID = Auth.auth().currentUser?.uid
        guard let id = (currentUID ?? account.id), !id.isEmpty else {
            print("AccountFirestoreService.saveAccount: missing account id and no authenticated user")
            completion(false, nil)
            return
        }

        // Extract data synchronously to avoid threading issues with SwiftData
        let profileImage = account.profileImage
        let profileAvatar = account.profileAvatar
        let name = account.name
        let gender = account.gender
        let dateOfBirth = account.dateOfBirth
        let height = account.height
        let weight = account.weight
        let maintenanceCalories = account.maintenanceCalories
        let calorieGoal = account.calorieGoal
        let weightGoalRaw = account.weightGoalRaw
        let macroStrategyRaw = account.macroStrategyRaw
        let intermittentFastingMinutes = account.intermittentFastingMinutes
        let theme = account.theme
        let unitSystem = account.unitSystem
        let caloriesBurnGoal = account.caloriesBurnGoal
        let stepsGoal = account.stepsGoal
        let distanceGoal = account.distanceGoal
        let expenseCurrencySymbol = account.expenseCurrencySymbol
        let didCompleteOnboarding = account.didCompleteOnboarding
        let startWeekOn = account.startWeekOn
        let autoRestDayIndices = account.autoRestDayIndices
        let trackedMacros = account.trackedMacros
        let expenseCategories = account.expenseCategories
        let cravings = account.cravings
        let groceryItems = account.groceryItems
        let habits = account.habits
        let goals = account.goals
        let mealReminders = account.mealReminders
        let weeklyProgress = account.weeklyProgress
        let workoutSupplements = account.workoutSupplements
        let nutritionSupplements = account.nutritionSupplements
        let dailyTasks = account.dailyTasks
        let sports = account.sports
        let weightGroups = account.weightGroups
        let soloMetrics = account.soloMetrics
        let teamMetrics = account.teamMetrics
        let activityTimers = account.activityTimers
        let workoutSchedule = account.workoutSchedule
        let mealSchedule = account.mealSchedule
        let mealCatalog = account.mealCatalog
        let itineraryEvents = account.itineraryEvents
        let itineraryTrips = account.itineraryTrips
        let activityLevel = account.activityLevel
        let googleRefreshToken = account.googleRefreshToken

        func proceedWithSave(avatarURL: String?) {
            var data: [String: Any] = [:]

            if let url = avatarURL {
                data["profileAvatar"] = url
            } else if forceOverwrite || (profileAvatar?.isEmpty == false) {
                data["profileAvatar"] = profileAvatar ?? ""
            }
            if forceOverwrite || (name?.isEmpty == false) {
                data["name"] = name ?? ""
            }
            if forceOverwrite || (gender?.isEmpty == false) {
                data["gender"] = gender ?? ""
            }
            if forceOverwrite || dateOfBirth != nil {
                if let dob = dateOfBirth {
                    data["dateOfBirth"] = dob
                }
            }
            if forceOverwrite || (height ?? 0) != 0 {
                data["height"] = height ?? 0
            }
            if forceOverwrite || (weight ?? 0) != 0 {
                data["weight"] = weight ?? 0
            }
            if forceOverwrite || maintenanceCalories != 0 {
                data["maintenanceCalories"] = maintenanceCalories
            }
            if forceOverwrite || calorieGoal != 0 {
                data["calorieGoal"] = calorieGoal
            }
            if forceOverwrite || (weightGoalRaw?.isEmpty == false) {
                data["weightGoal"] = weightGoalRaw ?? ""
            }
            if forceOverwrite || (macroStrategyRaw?.isEmpty == false) {
                data["macroStrategy"] = macroStrategyRaw ?? ""
            }
            if forceOverwrite || intermittentFastingMinutes != 0 {
                data["intermittentFastingMinutes"] = intermittentFastingMinutes
            }
            if forceOverwrite || (theme?.isEmpty == false) {
                data["theme"] = theme ?? ""
            }
            if forceOverwrite || (unitSystem?.isEmpty == false) {
                data["unitSystem"] = unitSystem ?? ""
            }
            data["caloriesBurnGoal"] = caloriesBurnGoal
            data["stepsGoal"] = stepsGoal
            data["distanceGoal"] = distanceGoal
            let resolvedCurrency = expenseCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            data["expenseCurrencySymbol"] = resolvedCurrency.isEmpty ? Account.deviceCurrencySymbol : resolvedCurrency

            if forceOverwrite || didCompleteOnboarding {
                data["didCompleteOnboarding"] = didCompleteOnboarding
            }
            if forceOverwrite || (googleRefreshToken?.isEmpty == false) {
                // Only write if we have a token, or if we are overwriting everything (though usually token is only added/updated, not removed)
                if let token = googleRefreshToken {
                    data["googleRefreshToken"] = token
                }
            }
            
            if forceOverwrite || (startWeekOn?.isEmpty == false) {
                data["startWeekOn"] = startWeekOn ?? ""
            }
            data["autoRestDayIndices"] = autoRestDayIndices
            data["trackedMacros"] = trackedMacros.map { $0.asDictionary }
            let shouldFallbackCategories = !forceOverwrite && expenseCategories.isEmpty
            let categoriesToPersist = shouldFallbackCategories ? ExpenseCategory.defaultCategories() : expenseCategories
            data["expenseCategories"] = categoriesToPersist.map { $0.asDictionary }
            if includeCravings {
                data["cravings"] = cravings.map { $0.asDictionary }
            }
            // Persist grocery list even when empty so deletions propagate.
            data["groceryItems"] = groceryItems.map { $0.asDictionary }
            data["habits"] = habits.map { $0.asDictionary }
            data["goals"] = goals.map { $0.asDictionary }
            data["mealReminders"] = mealReminders.map { $0.asDictionary }
            data["weeklyProgress"] = weeklyProgress.map { $0.asFirestoreDictionary() }
            // Persist split supplement lists; also emit legacy combined list for backward compatibility
            data["workoutSupplements"] = workoutSupplements.map { $0.asDictionary }
            data["nutritionSupplements"] = nutritionSupplements.map { $0.asDictionary }
            var legacySeen = Set<String>()
            let legacySupplements = (workoutSupplements + nutritionSupplements)
                .filter { legacySeen.insert($0.id).inserted }
            data["supplements"] = legacySupplements.map { $0.asDictionary }

            data["dailyTasks"] = dailyTasks.map { $0.asDictionary }
            data["sports"] = sports.map { $0.asDictionary }
            data["weightGroups"] = weightGroups.map { $0.asDictionary }
            data["soloMetrics"] = soloMetrics.map { $0.asDictionary }
            data["teamMetrics"] = teamMetrics.map { $0.asDictionary }
            data["activityTimers"] = activityTimers.map { $0.asDictionary }
            data["workoutSchedule"] = workoutSchedule.map { $0.asDictionary }
            data["mealSchedule"] = mealSchedule.map { $0.asDictionary }
            data["mealCatalog"] = mealCatalog.map { $0.asDictionary }
            // Persist itinerary events even when empty so deletions propagate.
            data["itineraryEvents"] = itineraryEvents.map { $0.asFirestoreDictionary() }
            data["itineraryTrips"] = itineraryTrips.map { $0.asFirestoreDictionary }
            
            // Handle activityLevel carefully: avoid writing a default 'sedentary'
            // value into Firestore on initial saves (e.g. app launch). If the
            // activity is 'sedentary' and the remote document doesn't already
            // have an activityLevel, skip persisting it to avoid introducing
            // an implicit default. Otherwise include it as usual.
            if let activity = activityLevel, !activity.isEmpty {
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
                            data["cravings"] = cravings.map { $0.asDictionary }
                        }

                        // If there are no other fields to write and activity was skipped,
                        // return success (nothing to do).
                        if data.isEmpty {
                            completion(true, avatarURL)
                            return
                        }

                        self.db.collection(self.collection).document(id).setData(data, merge: true) { error in
                            if let error {
                                print("AccountFirestoreService.saveAccount error: \(error.localizedDescription)")
                            }
                            completion(error == nil, avatarURL)
                        }
                    }
                    return
                } else {
                    data["activityLevel"] = activity
                }
            }

            guard !data.isEmpty else {
                completion(true, avatarURL)
                return
            }

            if includeCravings {
                data["cravings"] = cravings.map { $0.asDictionary }
            }

            self.db.collection(self.collection).document(id).setData(data, merge: true) { error in
                if let error {
                    print("AccountFirestoreService.saveAccount error: \(error.localizedDescription)")
                }
                completion(error == nil, avatarURL)
            }
        }

        // Check if we need to upload image
        // Only upload if we have image data AND the current avatar string is NOT a URL (meaning it's a color index or empty, implying a change or initial set)
        // OR if we want to force re-upload (but we don't have a flag for that here).
        // Actually, if the user just picked a new image, AccountsView sets profileAvatar to a color string.
        // If the user loaded an existing image, profileAvatar is a URL.
        // So if profileAvatar is NOT a URL, and we have image data, we should upload.
        if let imageData = profileImage, !(profileAvatar?.hasPrefix("http") ?? false) {
            // Store each user's avatar inside a folder named by their uid so
            // Storage rules can easily allow per-user writes to that folder.
            let storageRef = Storage.storage().reference().child("profile_images/\(id)/avatar.jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("AccountFirestoreService: Error uploading profile image: \(error)")
                    // Proceed without URL update (will save color string or whatever was there)
                    proceedWithSave(avatarURL: nil)
                    return
                }
                storageRef.downloadURL { url, error in
                    if let urlString = url?.absoluteString {
                        // Update the local account object so subsequent saves don't re-upload
                        // account.profileAvatar = urlString // REMOVED: Thread unsafe
                        proceedWithSave(avatarURL: urlString)
                    } else {
                        proceedWithSave(avatarURL: nil)
                    }
                }
            }
        } else {
            proceedWithSave(avatarURL: nil)
        }
    }
}
