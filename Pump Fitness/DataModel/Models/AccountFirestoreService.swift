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
                supplements: (data["supplements"] as? [[String: Any]] ?? []).compactMap { Supplement(dictionary: $0) }
            )
            completion(account)
        }
    }

    func saveAccount(_ account: Account, completion: @escaping (Bool) -> Void) {
        guard let id = account.id else {
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
        if let activity = account.activityLevel, !activity.isEmpty {
            data["activityLevel"] = activity
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
            data["weeklyProgress"] = account.weeklyProgress.map { $0.asDictionary }
        }
        if !account.supplements.isEmpty {
            data["supplements"] = account.supplements.map { $0.asDictionary }
        }

        guard !data.isEmpty else {
            completion(true)
            return
        }

        db.collection(collection).document(id).setData(data, merge: true) { error in
            completion(error == nil)
        }
    }
}