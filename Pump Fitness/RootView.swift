//
//  RootView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import SwiftData

import FirebaseAuth
import FirebaseCore
import Combine
import AuthenticationServices
import UserNotifications

struct RootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .nutrition
    @State private var selectedDate: Date = Date()
    @State private var consumedCalories: Int = 0
    @State private var calorieGoal: Int = 0
    @State private var maintenanceCalories: Int = 0
    @State private var selectedMacroFocus: MacroFocusOption? = nil
    @State private var trackedMacros: [TrackedMacro] = []
    @State private var macroConsumptions: [MacroConsumption] = []
    @State private var cravings: [CravingItem] = []
    @State private var itineraryEvents: [ItineraryEvent] = []
    @State private var sportsConfigs: [SportConfig] = []
    @State private var sportActivities: [SportActivityRecord] = []
    @State private var weeklyCheckInStatuses: [WorkoutCheckInStatus] = Array(repeating: .notLogged, count: 7)
    @State private var autoRestDayIndices: Set<Int> = []
    @State private var locallyUpdatedDayKeys: Set<String> = []
    @State private var checkedMeals: Set<String> = []
    @State private var caloriesBurnGoal: Int = 800
    @State private var stepsGoal: Int = 10_000
    @State private var distanceGoal: Double = 3_000
    @State private var caloriesBurnedToday: Double = 0
    @State private var stepsTakenToday: Double = 0
    @State private var distanceTravelledToday: Double = 0
    @State private var activityTimers: [ActivityTimerItem] = ActivityTimerItem.defaultTimers
    @State private var goals: [GoalItem] = GoalItem.sampleDefaults()
    @State private var habits: [HabitDefinition] = HabitDefinition.defaults
    @State private var groceryItems: [GroceryItem] = GroceryItem.sampleItems()
    @State private var expenseCategories: [ExpenseCategory] = ExpenseCategory.defaultCategories()
    @State private var expenseEntries: [ExpenseEntry] = []
    @State private var expenseCurrencySymbol: String = Account.deviceCurrencySymbol
    @State private var weightGroups: [WeightGroupDefinition] = WeightGroupDefinition.defaults
    @State private var weightEntries: [WeightExerciseValue] = []
    @State private var lastWeightEntryByExerciseId: [UUID: WeightExerciseValue] = [:]
    @State private var isHydratingDailyActivity: Bool = false
    @State private var mealReminders: [MealReminder] = MealReminder.defaults
    @State private var isHydratingTrackedMacros: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var authViewModel = AuthViewModel()
    @Query private var accounts: [Account]
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var isCheckingOnboarding: Bool = false
    private let dayFirestoreService = DayFirestoreService()
    private let accountFirestoreService = AccountFirestoreService()

    var body: some View {
        rootContent
            .environmentObject(authViewModel)
            .onAppear(perform: handleOnAppear)
            .task { handleInitialTask() }
            .onChange(of: selectedDate) { _, newValue in handleSelectedDateChange(newValue) }
            .onChange(of: consumedCalories) { _, newValue in handleConsumedCaloriesChange(newValue) }
            .onChange(of: calorieGoal) { _, newValue in handleCalorieGoalChange(newValue) }
            .onChange(of: selectedMacroFocus) { _, newValue in handleMacroFocusChange(newValue) }
            .onChange(of: trackedMacros) { _, newValue in handleTrackedMacrosChange(newValue) }
            .onChange(of: macroConsumptions) { _, newValue in handleMacroConsumptionsChange(newValue) }
            .onChange(of: cravings) { _, newValue in handleCravingsChange(newValue) }
            .onChange(of: sportsConfigs) { _, newValue in handleSportsConfigsChange(newValue) }
            .onChange(of: sportActivities) { _, newValue in handleSportActivitiesChange(newValue) }
            .onChange(of: mealReminders) { _, newValue in handleMealRemindersChange(newValue) }
            .onChange(of: itineraryEvents) { _, newValue in handleItineraryEventsChange(newValue) }
            .onChange(of: checkedMeals) { _, newValue in handleCheckedMealsChange(newValue) }
            .onChange(of: accounts.first?.maintenanceCalories) { _, newValue in handleMaintenanceCaloriesChange(newValue) }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isSignedIn, hasCompletedOnboarding {
            mainAppContent
        } else {
            WelcomeFlowView {
                handleWelcomeCompletion()
            }
            .environmentObject(authViewModel)
        }
    }

    private func handleWelcomeCompletion() {
        hasCompletedOnboarding = true
        selectedTab = .nutrition
        DispatchQueue.main.async {
            if isSignedIn {
                hasCompletedOnboarding = true
                selectedTab = .nutrition
            }
        }
    }

    private func handleOnAppear() {
        let didForceSignOutOnceKey = "didForceSignOutOnce"
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: didForceSignOutOnceKey) {
            do {
                try Auth.auth().signOut()
            } catch {
                print("Error signing out: \(error)")
            }
            hasCompletedOnboarding = false
            defaults.set(true, forKey: didForceSignOutOnceKey)
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
            if let _ = user {
                isCheckingOnboarding = true
                checkOnboardingStatus()
                // Upload any days that were created locally while the user was unauthenticated.
                dayFirestoreService.uploadPendingDays(in: modelContext) { success in
                    if !success {
                        print("DayFirestoreService: some pending days failed to upload; they remain queued.")
                    }
                }
            } else {
                hasCompletedOnboarding = false
                autoRestDayIndices = []
                weeklyCheckInStatuses = Array(repeating: .notLogged, count: 7)
            }
        }
    }
    private func handleInitialTask() {
        ensureAccountExists()
        initializeDailyGoalsFromLocal()
        initializeWeightTrackingFromLocal()
        initializeActivityTimersFromLocal()
        initializeGoalsFromLocal()
        initializeGroceryListFromLocal()
        initializeExpenseCategoriesFromLocal()
        initializeHabitsFromLocal()
        initializeTrackedMacrosFromLocal()
        initializeItineraryEventsFromLocal()
        initializeMealRemindersFromLocal()
        loadAutoRestDaysFromLocal()
        printSignedInUserDetails()
        // Ensure onboarding status is evaluated on startup
        checkOnboardingStatus()
        // Ensure today's Day exists locally and attempt to sync to Firestore
        loadDay(for: selectedDate)
        refreshWeeklyCheckInStatuses(for: selectedDate)
        loadExpensesForWeek(anchorDate: selectedDate)
    }

    private func handleSelectedDateChange(_ newDate: Date) {
        loadDay(for: newDate)
        refreshWeeklyCheckInStatuses(for: newDate)
        refreshWeightHistoryCache()
        loadExpensesForWeek(anchorDate: newDate)
    }

    private func handleConsumedCaloriesChange(_ newValue: Int) {
        // Persist the updated calories to the local SwiftData Day and attempt to sync to Firestore
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.caloriesConsumed = newValue
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save local Day: \(error)")
            }

            // Attempt to upload only the changed field to Firestore so we don't
            // overwrite other values that may be stale in-memory.
            if newValue != 0 {
                dayFirestoreService.updateDayFields(["caloriesConsumed": newValue], for: day) { success in
                    if success {
                    } else {
                        print("RootView: failed to sync caloriesConsumed to Firestore for date=\(selectedDate)")
                    }
                }
            }
        }
    }

    private func handleCalorieGoalChange(_ newValue: Int) {
        guard let account = fetchAccount() else { return }
        account.calorieGoal = newValue

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save calorieGoal to local Account: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("RootView: failed to sync calorieGoal to Firestore via Account")
            }
        }

        // Keep local Day in sync for offline UI, but do not upload via DayFirestoreService.
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.calorieGoal = newValue
            try? modelContext.save()
        }
    }

    private func handleMacroFocusChange(_ newValue: MacroFocusOption?) {
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.macroFocusRaw = newValue?.rawValue
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save local Day (macroFocus): \(error)")
            }
        }

        if let account = fetchAccount() {
            account.macroFocusRaw = newValue?.rawValue
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save macroFocus to Account locally: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if success {
                } else {
                    print("RootView: failed to sync macroFocus to Firestore via Account")
                }
            }
        }
    }

    private func handleTrackedMacrosChange(_ newValue: [TrackedMacro]) {
        persistTrackedMacros(newValue, syncWithRemote: !isHydratingTrackedMacros)
    }

    private func handleMacroConsumptionsChange(_ newValue: [MacroConsumption]) {
        persistMacroConsumptions(newValue)
    }

    private func handleCravingsChange(_ newValue: [CravingItem]) {
        persistCravings(newValue)
    }

    private func handleSportsConfigsChange(_ newValue: [SportConfig]) {
        persistSports(newValue)
    }

    private func handleSportActivitiesChange(_ newValue: [SportActivityRecord]) {
        persistSportActivities(newValue)
    }

    private func handleMealRemindersChange(_ newValue: [MealReminder]) {
        persistMealReminders(newValue)
    }

    private func handleItineraryEventsChange(_ newValue: [ItineraryEvent]) {
        persistItineraryEvents(newValue)
    }

    private func handleCheckedMealsChange(_ newValue: Set<String>) {
        persistCheckedMeals(newValue)
    }

    private func handleMaintenanceCaloriesChange(_ newValue: Int?) {
        // Keep the UI's maintenanceCalories in sync with the local Account entity
        if let updated = newValue {
            DispatchQueue.main.async {
                maintenanceCalories = updated
            }
        }
    }
    private var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }
    /// Checks if the signed-in user has a Firebase account document and sets onboarding status.
    private func checkOnboardingStatus() {
        guard let user = Auth.auth().currentUser else {
            isCheckingOnboarding = false
            return
        }
        let uid = user.uid
        accountFirestoreService.fetchAccount(withId: uid) { account in
            DispatchQueue.main.async {
                if account != nil {
                    hasCompletedOnboarding = true
                    selectedTab = .nutrition
                    if let fetched = account {
                        var resolvedTrackedMacros = fetched.trackedMacros

                        // Prefer server macros; if missing, fall back to any cached local value before defaulting.
                        if resolvedTrackedMacros.isEmpty, let local = fetchAccount(), !local.trackedMacros.isEmpty {
                            resolvedTrackedMacros = local.trackedMacros
                        }

                        if resolvedTrackedMacros.isEmpty {
                            resolvedTrackedMacros = TrackedMacro.defaults
                        }

                        fetched.trackedMacros = resolvedTrackedMacros

                        autoRestDayIndices = Set(fetched.autoRestDayIndices)

                        // Daily summary goals with defaults
                        caloriesBurnGoal = fetched.caloriesBurnGoal == 0 ? 800 : fetched.caloriesBurnGoal
                        stepsGoal = fetched.stepsGoal == 0 ? 10_000 : fetched.stepsGoal
                        distanceGoal = fetched.distanceGoal == 0 ? 3_000 : fetched.distanceGoal

                        var resolvedItineraryEvents = fetched.itineraryEvents
                        if resolvedItineraryEvents.isEmpty, let localAccount = fetchAccount(), !localAccount.itineraryEvents.isEmpty {
                            resolvedItineraryEvents = localAccount.itineraryEvents
                        }
                        fetched.itineraryEvents = resolvedItineraryEvents

                        upsertLocalAccount(with: fetched)
                        // Use the fetched maintenance calories from the account on app load
                        maintenanceCalories = fetched.maintenanceCalories
                        calorieGoal = fetched.calorieGoal
                        if let rawMF = fetched.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
                            selectedMacroFocus = mf
                        }
                        hydrateTrackedMacros(fetched.trackedMacros)
                        cravings = fetched.cravings
                        if fetched.mealReminders.isEmpty {
                            mealReminders = MealReminder.defaults
                        } else {
                            mealReminders = fetched.mealReminders
                        }
                        itineraryEvents = fetched.itineraryEvents
                        scheduleMealNotifications(mealReminders)
                        refreshWeeklyCheckInStatuses(for: selectedDate)
                    }
                } else {
                    hasCompletedOnboarding = false
                    autoRestDayIndices = []
                }
                isCheckingOnboarding = false
            }
        }
    }
}
    /// Prints the signed-in user's details from FirebaseAuth, if available.
    private func printSignedInUserDetails() {
        if let user = Auth.auth().currentUser {
            print("Signed in user:")
            print("  UID: \(user.uid)")
            print("  Email: \(user.email ?? "<none>")")
            print("  Display Name: \(user.displayName ?? "<none>")")
            print("  Provider: \(user.providerID)")
        } else {
            print("No user is currently signed in.")
        }
    }

private extension RootView {
    func ensureAccountExists() {
        do {
            let request = FetchDescriptor<Account>()
            let existing = try modelContext.fetch(request)
            if existing.isEmpty {
                let defaultAccount = Account(
                    profileImage: nil,
                    profileAvatar: "systemBlue",
                    name: "You",
                    gender: "",
                    dateOfBirth: nil,
                    height: 170,
                    weight: 70,
                    maintenanceCalories: 0,
                    calorieGoal: 0,
                    macroFocusRaw: nil,
                    intermittentFastingMinutes: 16 * 60,
                    theme: "default",
                    unitSystem: "metric",
                    activityLevel: ActivityLevelOption.moderatelyActive.rawValue,
                    startWeekOn: "monday",
                    trackedMacros: TrackedMacro.defaults,
                    cravings: [],
                    mealReminders: MealReminder.defaults,
                    weeklyProgress: [],
                    supplements: [],
                    dailyTasks: [],
                    itineraryEvents: [],
                    caloriesBurnGoal: 800,
                    stepsGoal: 10_000,
                    distanceGoal: 3_000
                )
                modelContext.insert(defaultAccount)
                try modelContext.save()
                hydrateTrackedMacros(defaultAccount.trackedMacros)
                cravings = defaultAccount.cravings
                mealReminders = defaultAccount.mealReminders
            }
        } catch {
            print("Failed to ensure Account exists: \(error)")
        }
    }

    func fetchAccount() -> Account? {
        do {
            let request = FetchDescriptor<Account>()
            let accounts = try modelContext.fetch(request)
            return accounts.first
        } catch {
            print("Failed to fetch Account: \(error)")
            return nil
        }
    }

    func initializeTrackedMacrosFromLocal() {
        guard let account = fetchAccount() else {
            hydrateTrackedMacros(TrackedMacro.defaults)
            cravings = []
            maintenanceCalories = 0
            calorieGoal = 0
                sportsConfigs = SportConfig.defaults
            return
        }

        if account.trackedMacros.isEmpty {
            account.trackedMacros = TrackedMacro.defaults
            hydrateTrackedMacros(account.trackedMacros)
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default tracked macros locally: \(error)")
            }
        } else {
            hydrateTrackedMacros(account.trackedMacros)
        }

            sportsConfigs = account.sports.isEmpty ? SportConfig.defaults : account.sports
            if account.sports.isEmpty {
                account.sports = sportsConfigs
                do {
                    try modelContext.save()
                } catch {
                    print("RootView: failed to save default sports configs: \(error)")
                }
            }

        cravings = account.cravings
        maintenanceCalories = account.maintenanceCalories
        calorieGoal = account.calorieGoal
        if let rawMF = account.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
            selectedMacroFocus = mf
        }
    }

    func initializeItineraryEventsFromLocal() {
        guard let account = fetchAccount() else {
            itineraryEvents = []
            return
        }

        itineraryEvents = account.itineraryEvents
    }

    func initializeDailyGoalsFromLocal() {
        guard let account = fetchAccount() else { return }

        caloriesBurnGoal = account.caloriesBurnGoal == 0 ? 800 : account.caloriesBurnGoal
        stepsGoal = account.stepsGoal == 0 ? 10_000 : account.stepsGoal
        distanceGoal = account.distanceGoal == 0 ? 3_000 : account.distanceGoal
    }

    func initializeActivityTimersFromLocal() {
        guard let account = fetchAccount() else {
            activityTimers = ActivityTimerItem.defaultTimers
            return
        }
        activityTimers = account.activityTimers.isEmpty ? ActivityTimerItem.defaultTimers : account.activityTimers
    }

    func initializeHabitsFromLocal() {
        guard let account = fetchAccount() else {
            habits = HabitDefinition.defaults
            return
        }

        let resolved = account.habits.isEmpty ? HabitDefinition.defaults : account.habits
        habits = resolved

        if account.habits.isEmpty {
            account.habits = resolved
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default habits to local account: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if !success {
                    print("RootView: failed to sync default habits to Firestore")
                }
            }
        }
    }

    func initializeGoalsFromLocal() {
        guard let account = fetchAccount() else {
            goals = GoalItem.sampleDefaults()
            return
        }

        let resolved = account.goals.isEmpty ? GoalItem.sampleDefaults() : account.goals
        goals = resolved

        if account.goals.isEmpty {
            account.goals = resolved
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default goals to local account: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if !success {
                    print("RootView: failed to sync default goals to Firestore")
                }
            }
        }
    }

    func initializeGroceryListFromLocal() {
        guard let account = fetchAccount() else {
            groceryItems = GroceryItem.sampleItems()
            return
        }

        let resolved = account.groceryItems.isEmpty ? GroceryItem.sampleItems() : account.groceryItems
        groceryItems = resolved

        if account.groceryItems.isEmpty {
            account.groceryItems = resolved
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default grocery items locally: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if !success {
                    print("RootView: failed to sync default grocery items to Firestore")
                }
            }
        }
    }

    func initializeExpenseCategoriesFromLocal() {
        let deviceCurrency = Account.deviceCurrencySymbol

        guard let account = fetchAccount() else {
            expenseCategories = ExpenseCategory.defaultCategories()
            expenseCurrencySymbol = deviceCurrency
            return
        }

        let resolvedCategories = account.expenseCategories.isEmpty ? ExpenseCategory.defaultCategories() : account.expenseCategories
        expenseCategories = resolvedCategories

        let storedCurrency = account.expenseCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCurrency = storedCurrency.isEmpty ? deviceCurrency : storedCurrency
        expenseCurrencySymbol = resolvedCurrency

        var shouldPersist = false
        if account.expenseCategories.isEmpty {
            account.expenseCategories = resolvedCategories
            shouldPersist = true
        }
        if storedCurrency.isEmpty {
            account.expenseCurrencySymbol = resolvedCurrency
            shouldPersist = true
        }

        if shouldPersist {
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default expense settings locally: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if !success {
                    print("RootView: failed to sync default expense settings to Firestore")
                }
            }
        }
    }

    func initializeWeightTrackingFromLocal() {
        if let account = fetchAccount() {
            weightGroups = account.weightGroups.isEmpty ? WeightGroupDefinition.defaults : account.weightGroups
        }
        refreshWeightHistoryCache()
    }

    func loadDay(for date: Date) {
        dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
            if let d = day {
                DispatchQueue.main.async {
                    applyDayState(d, for: date)
                }
            } else {
                print("RootView: failed to fetch/create local Day for selectedDate=\(date)")
            }
        }
    }

    func loadExpensesForWeek(anchorDate: Date) {
        let dates = datesForWeek(containing: anchorDate)
        let group = DispatchGroup()
        var collected: [ExpenseEntry] = []

        for date in dates {
            group.enter()
            dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
                DispatchQueue.main.async {
                    let resolvedDay = day ?? Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
                    collected.append(contentsOf: resolvedDay.expenses)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.expenseEntries = collected.sorted { $0.date < $1.date }
        }
    }

    func applyDayState(_ day: Day, for targetDate: Date) {
        if let account = fetchAccount() {
            maintenanceCalories = account.maintenanceCalories
            calorieGoal = account.calorieGoal
            if let rawMF = account.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
                selectedMacroFocus = mf
            }
        }
        isHydratingDailyActivity = true
        caloriesBurnedToday = day.caloriesBurned
        stepsTakenToday = day.stepsTaken
        distanceTravelledToday = day.distanceTravelled
        consumedCalories = day.caloriesConsumed
        weightEntries = day.weightEntries
        refreshWeightHistoryCache()

        let previousCount = macroConsumptions.count
        if !trackedMacros.isEmpty {
            day.ensureMacroConsumptions(for: trackedMacros)
        }
        macroConsumptions = day.macroConsumptions

        let validMeals = Set(MealType.allCases.map { $0.rawValue })
        let completed = Set(day.completedMeals.map { $0.lowercased() }).intersection(validMeals)
        checkedMeals = completed

        sportActivities = day.sportActivities
        updateExpenseEntriesState(forDay: day.date, with: day.expenses)

        let resolvedStatus = WorkoutCheckInStatus(rawValue: day.workoutCheckInStatusRaw ?? WorkoutCheckInStatus.notLogged.rawValue) ?? .notLogged
        let idx = weekdayIndex(for: targetDate)
        let statusToApply = (resolvedStatus == .notLogged && autoRestDayIndices.contains(idx)) ? .rest : resolvedStatus
        setWeeklyStatusInState(statusToApply, for: targetDate)

        var fieldsToUpdate: [String: Any] = [:]
        if day.calorieGoal == 0 && calorieGoal > 0 {
            day.calorieGoal = calorieGoal
            fieldsToUpdate["calorieGoal"] = calorieGoal
        }
        if day.macroFocusRaw == nil, let localMF = selectedMacroFocus {
            day.macroFocusRaw = localMF.rawValue
            fieldsToUpdate["macroFocus"] = localMF.rawValue
        }

        if !fieldsToUpdate.isEmpty || previousCount != macroConsumptions.count {
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save Day after applying state: \(error)")
            }

            if !fieldsToUpdate.isEmpty {
                dayFirestoreService.updateDayFields(fieldsToUpdate, for: day) { success in
                    if success {
                    } else {
                        print("RootView: failed to sync inherited Day fields for date=\(targetDate)")
                    }
                }
            } else {
                dayFirestoreService.saveDay(day) { success in
                    if !success {
                        print("RootView: failed to sync macro consumptions for date=\(targetDate)")
                    }
                }
            }
        }
        isHydratingDailyActivity = false
    }

    private func updateExpenseEntriesState(forDay dayDate: Date, with entries: [ExpenseEntry]) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let weekStarts = datesForWeek(containing: selectedDate).map { calendar.startOfDay(for: $0) }
        guard weekStarts.contains(dayStart) else { return }

        var filtered = expenseEntries.filter { calendar.startOfDay(for: $0.date) != dayStart }
        filtered.append(contentsOf: entries)
        filtered.sort { $0.date < $1.date }
        expenseEntries = filtered
    }

    func persistTrackedMacros(_ macros: [TrackedMacro], syncWithRemote: Bool = true) {
        guard let account = fetchAccount() else { return }

        account.trackedMacros = macros
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save tracked macros locally: \(error)")
        }

        if syncWithRemote {
            accountFirestoreService.saveAccount(account) { success in
                if success {
                } else {
                    print("RootView: failed to sync tracked macros to Firestore")
                }
            }
        }

        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: macros)

        // Preserve any existing macro intake amounts when the tracked list changes.
        let baselineConsumptions = macroConsumptions.isEmpty ? day.macroConsumptions : macroConsumptions
        let alignedConsumptions = alignMacroConsumptions(baselineConsumptions, with: macros)

        day.macroConsumptions = alignedConsumptions
        macroConsumptions = alignedConsumptions

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save day macro alignments: \(error)")
        }

        if syncWithRemote {
            dayFirestoreService.saveDay(day) { success in
                if success {
                } else {
                    print("RootView: failed to sync day macros after tracked macro change")
                }
            }
        }
    }

    /// Update tracked macros state without triggering a Firestore sync during hydration.
    func hydrateTrackedMacros(_ macros: [TrackedMacro]) {
        isHydratingTrackedMacros = true
        trackedMacros = macros
        DispatchQueue.main.async {
            self.isHydratingTrackedMacros = false
        }
    }

    private func alignMacroConsumptions(_ current: [MacroConsumption], with trackedMacros: [TrackedMacro]) -> [MacroConsumption] {
        let existingById = Dictionary(uniqueKeysWithValues: current.map { ($0.trackedMacroId, $0) })
        let existingByName = Dictionary(uniqueKeysWithValues: current.map { ($0.name.lowercased(), $0) })

        return trackedMacros.map { macro in
            if var match = existingById[macro.id] {
                match.name = macro.name
                match.unit = macro.unit
                return match
            }

            if var match = existingByName[macro.name.lowercased()] {
                match.trackedMacroId = macro.id
                match.name = macro.name
                match.unit = macro.unit
                return match
            }

            return MacroConsumption(
                trackedMacroId: macro.id,
                name: macro.name,
                unit: macro.unit,
                consumed: 0
            )
        }
    }

    func persistMacroConsumptions(_ consumptions: [MacroConsumption]) {
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.macroConsumptions = consumptions
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save macro consumptions locally: \(error)")
            }

            let hasConsumption = consumptions.contains { $0.consumed != 0 }
            if hasConsumption {
                dayFirestoreService.saveDay(day) { success in
                    if success {
                    } else {
                        print("RootView: failed to sync macro consumptions to Firestore for date=\(selectedDate)")
                    }
                }
            }
        }
    }

    func persistCravings(_ updatedCravings: [CravingItem]) {
        guard let account = fetchAccount() else { return }

        account.cravings = updatedCravings
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save cravings locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("RootView: failed to sync cravings to Firestore")
            }
        }
    }

    func persistSports(_ configs: [SportConfig]) {
        guard let account = fetchAccount() else { return }

        account.sports = configs
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save sports locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync sports to Firestore")
            }
        }
    }

    func persistSportActivities(_ activities: [SportActivityRecord]) {
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.sportActivities = activities

            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save sport activities locally: \(error)")
            }

            guard !activities.isEmpty else { return }

            dayFirestoreService.saveDay(day) { success in
                if !success {
                    print("RootView: failed to sync sport activities to Firestore for date=\(selectedDate)")
                }
            }
        }
    }

    func persistCheckedMeals(_ meals: Set<String>) {
        Task {
            let normalizedSet = Set(meals.map { $0.lowercased() })
            let ordered = MealType.allCases.map { $0.rawValue }.filter { normalizedSet.contains($0) }

            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.completedMeals = ordered

            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save completed meals locally: \(error)")
            }

            dayFirestoreService.updateDayFields(["completedMeals": ordered], for: day) { success in
                if success {
                } else {
                    print("RootView: failed to sync completed meals to Firestore for date=\(selectedDate)")
                }
            }
        }
    }

    func persistDailyActivity(calories: Double? = nil, steps: Double? = nil, distance: Double? = nil) {
        if isHydratingDailyActivity { return }

        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        if let calories {
            day.caloriesBurned = calories
            caloriesBurnedToday = calories
        }
        if let steps {
            day.stepsTaken = steps
            stepsTakenToday = steps
        }
        if let distance {
            day.distanceTravelled = distance
            distanceTravelledToday = distance
        }

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save daily activity locally: \(error)")
        }

        var fields: [String: Any] = [:]
        if let calories { fields["caloriesBurned"] = calories }
        if let steps { fields["stepsTaken"] = steps }
        if let distance { fields["distanceTravelled"] = distance }

        guard !fields.isEmpty else { return }

        dayFirestoreService.updateDayFields(fields, for: day) { success in
            if !success {
                print("RootView: failed to sync daily activity metrics to Firestore for date=\(selectedDate)")
            }
        }
    }

    func persistDailyGoals(calorieGoalBurn: Int, stepsGoal: Int, distanceGoal: Double) {
        guard let account = fetchAccount() else { return }

        caloriesBurnGoal = calorieGoalBurn
        self.stepsGoal = stepsGoal
        self.distanceGoal = distanceGoal

        account.caloriesBurnGoal = calorieGoalBurn
        account.stepsGoal = stepsGoal
        account.distanceGoal = distanceGoal

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save daily goals locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync daily goals to Firestore")
            }
        }
    }

    func persistGroceryItems(_ items: [GroceryItem]) {
        guard let account = fetchAccount() else { return }

        groceryItems = items
        account.groceryItems = items

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save grocery items locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync grocery items to Firestore")
            }
        }
    }

    func persistExpenseSettings(_ categories: [ExpenseCategory], currencySymbol: String) {
        guard let account = fetchAccount() else { return }

        let trimmedCurrency = currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCurrency = trimmedCurrency.isEmpty ? Account.deviceCurrencySymbol : trimmedCurrency

        expenseCategories = categories
        expenseCurrencySymbol = resolvedCurrency
        account.expenseCategories = categories
        account.expenseCurrencySymbol = resolvedCurrency

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save expense settings locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync expense settings to Firestore")
            }
        }
    }

    func persistExpenseEntry(_ entry: ExpenseEntry) {
        Task {
            let day = Day.fetchOrCreate(for: entry.date, in: modelContext, trackedMacros: trackedMacros)
            var updated = day.expenses.filter { $0.id != entry.id }
            updated.append(entry)
            updated.sort { $0.date < $1.date }
            day.expenses = updated

            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save expense entry locally: \(error)")
            }

            updateExpenseEntriesState(forDay: day.date, with: updated)

            dayFirestoreService.updateDayFields(["expenses": updated], for: day) { success in
                if !success {
                    print("RootView: failed to sync expense entry to Firestore for date=\(day.date)")
                }
            }
        }
    }

    func deleteExpenseEntry(_ id: UUID) {
        guard let existing = expenseEntries.first(where: { $0.id == id }) else { return }
        let targetDate = existing.date

        Task {
            let day = Day.fetchOrCreate(for: targetDate, in: modelContext, trackedMacros: trackedMacros)
            day.expenses.removeAll { $0.id == id }

            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to remove expense entry locally: \(error)")
            }

            updateExpenseEntriesState(forDay: day.date, with: day.expenses)

            dayFirestoreService.updateDayFields(["expenses": day.expenses], for: day) { success in
                if !success {
                    print("RootView: failed to sync expense removal to Firestore for date=\(day.date)")
                }
            }
        }
    }

    func persistHabits(_ updated: [HabitDefinition]) {
        guard let account = fetchAccount() else { return }

        habits = updated
        account.habits = updated

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save habits locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync habits to Firestore")
            }
        }
    }

    func persistGoals(_ updatedGoals: [GoalItem]) {
        guard let account = fetchAccount() else { return }

        goals = updatedGoals
        account.goals = updatedGoals

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save goals locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync goals to Firestore")
            }
        }
    }

    func refreshWeightHistoryCache(upTo cutoff: Date? = nil) {
        do {
            let descriptor = FetchDescriptor<Day>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let days = try modelContext.fetch(descriptor)
            var cache: [UUID: WeightExerciseValue] = [:]
            for day in days {
                if let cutoff = cutoff, day.date > cutoff { continue }
                for entry in day.weightEntries where entry.hasContent {
                    if cache[entry.exerciseId] == nil {
                        cache[entry.exerciseId] = entry
                    }
                }
            }
            lastWeightEntryByExerciseId = cache
        } catch {
            print("RootView: failed to refresh weight history cache: \(error)")
        }
    }

    func persistWeightGroups(_ groups: [WeightGroupDefinition]) {
        guard let account = fetchAccount() else { return }
        weightGroups = groups.isEmpty ? WeightGroupDefinition.defaults : groups
        account.weightGroups = weightGroups
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save Account weight groups: \(error)")
        }
        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync weight groups to Firestore")
            }
        }
    }

    func persistActivityTimers(_ timers: [ActivityTimerItem]) {
        guard let account = fetchAccount() else { return }
        activityTimers = timers.isEmpty ? ActivityTimerItem.defaultTimers : timers
        account.activityTimers = activityTimers
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save activity timers to Account: \(error)")
        }
        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync activity timers to Firestore")
            }
        }
    }

    func persistWeightEntries(_ entries: [WeightExerciseValue], for date: Date) {
        let day = Day.fetchOrCreate(for: date, in: modelContext)
        weightEntries = entries
        day.weightEntries = entries
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save weight entries to Day: \(error)")
        }
        dayFirestoreService.updateDayFields(["weightEntries": entries], for: day) { success in
            if !success {
                print("RootView: failed to sync weight entries for date=\(date)")
            }
        }
        refreshWeightHistoryCache(upTo: date)
    }

    func initializeMealRemindersFromLocal() {
        guard let account = fetchAccount() else {
            mealReminders = MealReminder.defaults
            return
        }

        if account.mealReminders.isEmpty {
            account.mealReminders = MealReminder.defaults
            mealReminders = account.mealReminders
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default meal reminders locally: \(error)")
            }
            accountFirestoreService.saveAccount(account) { success in
                if !success {
                    print("RootView: failed to seed default meal reminders to Firestore")
                }
            }
        } else {
            mealReminders = account.mealReminders
        }

        scheduleMealNotifications(mealReminders)
    }

    func persistMealReminders(_ reminders: [MealReminder]) {
        guard let account = fetchAccount() else { return }

        account.mealReminders = reminders
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save meal reminders locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("RootView: failed to sync meal reminders to Firestore")
            }
        }

        scheduleMealNotifications(reminders)
    }

    func persistItineraryEvents(_ events: [ItineraryEvent]) {
        guard let account = fetchAccount() else { return }

        account.itineraryEvents = events.sorted { $0.date < $1.date }
        itineraryEvents = account.itineraryEvents

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save itinerary events locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("RootView: failed to sync itinerary events to Firestore")
            }
        }
    }

    func loadAutoRestDaysFromLocal() {
        guard let account = fetchAccount() else {
            autoRestDayIndices = []
            return
        }
        autoRestDayIndices = Set(account.autoRestDayIndices)
    }

    func persistAutoRestDays(_ indices: Set<Int>) {
        guard let account = fetchAccount() else { return }
        account.autoRestDayIndices = indices.sorted()
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save auto rest days locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync auto rest days to Firestore")
            }
        }

        autoRestDayIndices = indices
        refreshWeeklyCheckInStatuses(for: selectedDate)
    }

    func refreshWeeklyCheckInStatuses(for anchorDate: Date) {
        let weekDates = datesForWeek(containing: anchorDate)
        var resolved: [WorkoutCheckInStatus] = Array(repeating: .notLogged, count: 7)
        let group = DispatchGroup()

        for (index, date) in weekDates.enumerated() {
            group.enter()
            dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
                if let day {
                    let raw = day.workoutCheckInStatusRaw ?? WorkoutCheckInStatus.notLogged.rawValue
                    resolved[index] = WorkoutCheckInStatus(rawValue: raw) ?? .notLogged
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            var applied = resolved
            var autoRestNeedsPersist: [(Date, WorkoutCheckInStatus)] = []

            for (idx, status) in resolved.enumerated() {
                // If this date was recently updated locally, preserve the local value
                let key = self.dateKey(for: weekDates[idx])
                if self.locallyUpdatedDayKeys.contains(key) {
                    // keep existing weeklyCheckInStatuses value if available
                    if self.weeklyCheckInStatuses.indices.contains(idx) {
                        applied[idx] = self.weeklyCheckInStatuses[idx]
                    } else {
                        applied[idx] = status
                    }
                    continue
                }

                if autoRestDayIndices.contains(idx) && status == .notLogged {
                    applied[idx] = .rest
                    autoRestNeedsPersist.append((weekDates[idx], .rest))
                } else {
                    applied[idx] = status
                }
            }

            weeklyCheckInStatuses = applied

            for (date, status) in autoRestNeedsPersist {
                updateCheckInStatus(status, for: date, shouldRefresh: false)
            }
        }
    }

    func updateCheckInStatus(_ status: WorkoutCheckInStatus, for date: Date, shouldRefresh: Bool = true) {
        Task {
            let key = dateKey(for: date)
            // Mark as locally updated to avoid quick remote refresh overwrite
            DispatchQueue.main.async {
                self.locallyUpdatedDayKeys.insert(key)
            }
            // Remove the local lock after a short debounce window
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.locallyUpdatedDayKeys.remove(key)
            }
            let day = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
            day.workoutCheckInStatusRaw = status.rawValue
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save workout check-in status locally: \(error)")
            }

            dayFirestoreService.updateDayFields(["workoutCheckInStatus": status.rawValue], for: day) { success in
                if !success {
                    print("RootView: failed to sync workout check-in status to Firestore for date=\(date)")
                }
            }

            DispatchQueue.main.async {
                setWeeklyStatusInState(status, for: date)
            }

            if shouldRefresh {
                refreshWeeklyCheckInStatuses(for: date)
            }
        }
    }

    func setWeeklyStatusInState(_ status: WorkoutCheckInStatus, for date: Date) {
        let selectedWeekStart = startOfWeek(containing: selectedDate)
        let targetWeekStart = startOfWeek(containing: date)
        guard selectedWeekStart == targetWeekStart else { return }

        let idx = weekdayIndex(for: date)
        guard weeklyCheckInStatuses.indices.contains(idx) else { return }

        var updated = weeklyCheckInStatuses
        updated[idx] = status
        weeklyCheckInStatuses = updated
    }

    func datesForWeek(containing date: Date) -> [Date] {
        let start = startOfWeek(containing: date)
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    func startOfWeek(containing date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    func weekdayIndex(for date: Date) -> Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let start = startOfWeek(containing: date)
        let startOfDay = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: start, to: startOfDay).day ?? 0
        return max(0, min(6, diff))
    }

    private func dateKey(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = cal.startOfDay(for: date)
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: dayStart)
    }

    func scheduleMealNotifications(_ reminders: [MealReminder]) {
        let center = UNUserNotificationCenter.current()

        let allIdentifiers = MealType.allCases.map { "mealReminder.\($0.rawValue)" }
        if reminders.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            return
        }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("RootView: notification permission error: \(error)")
            }
            guard granted else {
                print("RootView: notification permission not granted for meal reminders")
                return
            }

            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    print("RootView: notification settings not authorized")
                    return
                }

                for reminder in reminders {
                    let identifier = "mealReminder.\(reminder.mealType.rawValue)"
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])

                    var components = DateComponents()
                    components.hour = reminder.hour
                    components.minute = reminder.minute

                    let content = UNMutableNotificationContent()
                    content.title = "\(reminder.mealType.displayName) Reminder"
                    content.body = "Don't forget to log your \(reminder.mealType.displayName.lowercased())!"
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(request) { error in
                        if let error = error {
                            print("RootView: failed to schedule \(identifier) notification: \(error)")
                        }
                    }
                }
            }
        }
    }

    /// Upsert a Firestore-backed `Account` into the local SwiftData store so
    /// the app UI reads the most recent server values.
    func upsertLocalAccount(with fetched: Account) {
        do {
            let request = FetchDescriptor<Account>()
            let existing = try modelContext.fetch(request)
            if let local = existing.first {
                // Debug: show counts before applying fetched values
                local.profileImage = fetched.profileImage
                local.profileAvatar = fetched.profileAvatar
                local.name = fetched.name
                local.gender = fetched.gender
                local.dateOfBirth = fetched.dateOfBirth
                local.maintenanceCalories = fetched.maintenanceCalories
                local.calorieGoal = fetched.calorieGoal
                local.macroFocusRaw = fetched.macroFocusRaw
                local.height = fetched.height
                local.weight = fetched.weight
                local.theme = fetched.theme
                local.unitSystem = fetched.unitSystem
                // Only overwrite activityLevel if the fetched value is present
                if let fetchedActivity = fetched.activityLevel, !fetchedActivity.isEmpty {
                    let previousActivity = local.activityLevel
                    local.activityLevel = fetchedActivity
                    // If the activity level changed on the server, attempt to recompute maintenance
                    if previousActivity != fetchedActivity {
                    if let genderRaw = fetched.gender,
                       let genderOption = GenderOption(rawValue: genderRaw),
                       genderOption != .preferNotSay,
                       let dob = fetched.dateOfBirth,
                       let height = fetched.height,
                       let weight = fetched.weight {
                        if let recomputed = MacroCalculator.estimateMaintenanceCalories(
                            genderOption: genderOption,
                            birthDate: dob,
                            unitSystem: UnitSystem(rawValue: fetched.unitSystem ?? "metric") ?? .metric,
                            heightValue: String(format: "%.0f", height),
                            heightFeet: "",
                            heightInches: "",
                            weightValue: String(format: "%.0f", weight),
                            workoutDays: 0,
                                activityLevelRaw: fetched.activityLevel
                        ) {
                            local.maintenanceCalories = recomputed
                        }
                    }
                    }
                }
                local.startWeekOn = fetched.startWeekOn
                local.autoRestDayIndices = fetched.autoRestDayIndices
                local.trackedMacros = fetched.trackedMacros
                local.cravings = fetched.cravings
                local.groceryItems = fetched.groceryItems
                local.expenseCategories = fetched.expenseCategories
                local.expenseCurrencySymbol = fetched.expenseCurrencySymbol
                    // Persist weekly progress and supplements from server into local Account
                    local.weeklyProgress = fetched.weeklyProgress
                    local.supplements = fetched.supplements
                local.goals = fetched.goals
                local.habits = fetched.habits
                local.mealReminders = fetched.mealReminders
                local.intermittentFastingMinutes = fetched.intermittentFastingMinutes
                local.itineraryEvents = fetched.itineraryEvents
                    local.caloriesBurnGoal = fetched.caloriesBurnGoal
                    local.stepsGoal = fetched.stepsGoal
                    local.distanceGoal = fetched.distanceGoal
                local.activityTimers = fetched.activityTimers
                local.weightGroups = fetched.weightGroups
                try modelContext.save()
                weightGroups = local.weightGroups
                goals = local.goals
                habits = local.habits
                groceryItems = local.groceryItems
                expenseCategories = local.expenseCategories
                expenseCurrencySymbol = local.expenseCurrencySymbol
            } else {
                let newAccount = Account(
                    id: fetched.id,
                    profileImage: fetched.profileImage,
                    profileAvatar: fetched.profileAvatar,
                    name: fetched.name,
                    gender: fetched.gender,
                    dateOfBirth: fetched.dateOfBirth,
                    height: fetched.height,
                    weight: fetched.weight,
                    maintenanceCalories: fetched.maintenanceCalories,
                    calorieGoal: fetched.calorieGoal,
                    macroFocusRaw: fetched.macroFocusRaw,
                    intermittentFastingMinutes: fetched.intermittentFastingMinutes,
                    theme: fetched.theme,
                    unitSystem: fetched.unitSystem,
                    activityLevel: fetched.activityLevel,
                    startWeekOn: fetched.startWeekOn,
                        autoRestDayIndices: fetched.autoRestDayIndices,
                        trackedMacros: fetched.trackedMacros,
                        cravings: fetched.cravings,
                    groceryItems: fetched.groceryItems,
                    expenseCategories: fetched.expenseCategories, expenseCurrencySymbol: fetched.expenseCurrencySymbol, goals: fetched.goals, habits: fetched.habits, mealReminders: fetched.mealReminders,
                    weeklyProgress: fetched.weeklyProgress,
                    supplements: fetched.supplements,
                    dailyTasks: fetched.dailyTasks,
                    itineraryEvents: fetched.itineraryEvents,
                    sports: fetched.sports,
                    soloMetrics: fetched.soloMetrics,
                    teamMetrics: fetched.teamMetrics,
                    caloriesBurnGoal: fetched.caloriesBurnGoal,
                    stepsGoal: fetched.stepsGoal,
                    distanceGoal: fetched.distanceGoal,
                    weightGroups: fetched.weightGroups,
                    activityTimers: fetched.activityTimers
                )
                    weightGroups = newAccount.weightGroups
                goals = newAccount.goals
                habits = newAccount.habits
                groceryItems = newAccount.groceryItems
                expenseCategories = newAccount.expenseCategories
                expenseCurrencySymbol = newAccount.expenseCurrencySymbol
                modelContext.insert(newAccount)
                try modelContext.save()
            }
        } catch {
            print("Failed to upsert local Account: \(error)")
        }
    }
}

private extension RootView {
    struct WelcomeFlowView: View {
        @State private var showingOnboarding = false
        @State private var onboardingName: String? = nil
        var onCompletion: () -> Void

        var body: some View {
            Group {
                if showingOnboarding {
                    OnboardingView(initialName: onboardingName) {
                        showingOnboarding = false
                        onCompletion()
                    }
                } else {
                    WelcomeView(startOnboarding: {
                        // Fetch the name from UserDefaults (set after sign-in)
                        let name = UserDefaults.standard.string(forKey: "currentUserName")
                        onboardingName = name
                        withAnimation {
                            showingOnboarding = true
                        }
                    })
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingOnboarding)
        }
    }

    var mainAppContent: some View {
        ZStack {
            backgroundView

            NavigationStack {
                if let account = fetchAccount() {
                        // Create a writable Binding<Account> so child views can update
                        // the local SwiftData `Account` and have changes persisted.
                        let accountBinding = Binding<Account>(
                            get: { fetchAccount() ?? account },
                            set: { newAccount in
                                do {
                                    let request = FetchDescriptor<Account>()
                                    let existing = try modelContext.fetch(request)
                                    if let local = existing.first {
                                        local.profileImage = newAccount.profileImage
                                        local.profileAvatar = newAccount.profileAvatar
                                        local.name = newAccount.name
                                        local.gender = newAccount.gender
                                        local.dateOfBirth = newAccount.dateOfBirth
                                        local.maintenanceCalories = newAccount.maintenanceCalories
                                        local.calorieGoal = newAccount.calorieGoal
                                        local.macroFocusRaw = newAccount.macroFocusRaw
                                        local.height = newAccount.height
                                        local.weight = newAccount.weight
                                        local.theme = newAccount.theme
                                        local.unitSystem = newAccount.unitSystem
                                        local.autoRestDayIndices = newAccount.autoRestDayIndices
                                        local.startWeekOn = newAccount.startWeekOn
                                        local.trackedMacros = newAccount.trackedMacros
                                        local.cravings = newAccount.cravings
                                        local.groceryItems = newAccount.groceryItems
                                        local.expenseCategories = newAccount.expenseCategories
                                        local.expenseCurrencySymbol = newAccount.expenseCurrencySymbol
                                        local.mealReminders = newAccount.mealReminders
                                        local.caloriesBurnGoal = newAccount.caloriesBurnGoal
                                        local.stepsGoal = newAccount.stepsGoal
                                        local.distanceGoal = newAccount.distanceGoal
                                        local.itineraryEvents = newAccount.itineraryEvents
                                        local.weightGroups = newAccount.weightGroups
                                        local.goals = newAccount.goals
                                        local.habits = newAccount.habits
                                        local.activityTimers = newAccount.activityTimers
                                        try modelContext.save()
                                        mealReminders = newAccount.mealReminders
                                        goals = newAccount.goals
                                        habits = newAccount.habits
                                        groceryItems = newAccount.groceryItems
                                        expenseCategories = newAccount.expenseCategories
                                        expenseCurrencySymbol = newAccount.expenseCurrencySymbol
                                    }
                                } catch {
                                    print("RootView: failed to apply account binding set: \(error)")
                                }
                            }
                        )

                        TabView(selection: $selectedTab) {
                            Tab(
                                "Nutrition",
                                systemImage: AppTab.nutrition.systemImage,
                                value: AppTab.nutrition
                            ) {
                                NutritionTabView(
                                    account: accountBinding,
                                    consumedCalories: $consumedCalories,
                                    selectedDate: $selectedDate,
                                    calorieGoal: $calorieGoal,
                                    selectedMacroFocus: $selectedMacroFocus,
                                    trackedMacros: $trackedMacros,
                                    macroConsumptions: $macroConsumptions,
                                    cravings: $cravings,
                                    mealReminders: $mealReminders,
                                    checkedMeals: $checkedMeals,
                                    maintenanceCalories: $maintenanceCalories
                                )
                            }
                            Tab(
                                "Routine",
                                systemImage: AppTab.routine.systemImage,
                                value: AppTab.routine
                            ) {
                                RoutineTabView(
                                    account: accountBinding,
                                    selectedDate: $selectedDate,
                                    goals: $goals,
                                    habits: $habits,
                                    groceryItems: $groceryItems,
                                    activityTimers: $activityTimers,
                                    expenseCurrencySymbol: $expenseCurrencySymbol,
                                    expenseCategories: $expenseCategories,
                                    expenseEntries: $expenseEntries,
                                    onUpdateActivityTimers: { timers in
                                        persistActivityTimers(timers)
                                    },
                                    onUpdateHabits: { defs in
                                        persistHabits(defs)
                                    },
                                    onUpdateGoals: { items in
                                        persistGoals(items)
                                    },
                                    onUpdateGroceryItems: { items in
                                        persistGroceryItems(items)
                                    },
                                    onUpdateExpenseCategories: { categories, currencySymbol in
                                        persistExpenseSettings(categories, currencySymbol: currencySymbol)
                                    },
                                    onSaveExpenseEntry: { entry in
                                        persistExpenseEntry(entry)
                                    },
                                    onDeleteExpenseEntry: { id in
                                        deleteExpenseEntry(id)
                                    }
                                )
                            }
                            Tab(
                                "Workout",
                                systemImage: AppTab.workout.systemImage,
                                value: AppTab.workout
                            ) {
                                WorkoutTabView(
                                    account: accountBinding,
                                    selectedDate: $selectedDate,
                                    weeklyProgress: $weeklyCheckInStatuses,
                                    autoRestDayIndices: $autoRestDayIndices,
                                    currentDayIndex: weekdayIndex(for: selectedDate),
                                    onUpdateCheckInStatus: { status in
                                        updateCheckInStatus(status, for: selectedDate)
                                    },
                                    onUpdateAutoRestDays: { indices in
                                        persistAutoRestDays(indices)
                                    },
                                    caloriesBurnGoal: $caloriesBurnGoal,
                                    stepsGoal: $stepsGoal,
                                    distanceGoal: $distanceGoal,
                                    caloriesBurnedToday: $caloriesBurnedToday,
                                    stepsTakenToday: $stepsTakenToday,
                                    distanceTravelledToday: $distanceTravelledToday,
                                    weightGroups: $weightGroups,
                                    weightEntries: $weightEntries,
                                    lastWeightEntryByExerciseId: lastWeightEntryByExerciseId,
                                    onUpdateDailyActivity: { calories, steps, distance in
                                        persistDailyActivity(calories: calories, steps: steps, distance: distance)
                                    },
                                    onUpdateDailyGoals: { burnGoal, stepsGoal, distanceGoal in
                                        persistDailyGoals(calorieGoalBurn: burnGoal, stepsGoal: stepsGoal, distanceGoal: distanceGoal)
                                    },
                                    onUpdateWeightGroups: { groups in
                                        persistWeightGroups(groups)
                                    },
                                    onUpdateWeightEntries: { entries in
                                        persistWeightEntries(entries, for: selectedDate)
                                    }
                                )
                            }
                            Tab(
                                "Sports",
                                systemImage: AppTab.sports.systemImage,
                                value: AppTab.sports
                            ) {
                                SportsTabView(
                                    account: accountBinding,
                                    sportConfigs: $sportsConfigs,
                                    sportActivities: $sportActivities,
                                    selectedDate: $selectedDate
                                )
                            }
                            Tab(
                                "Travel",
                                systemImage: AppTab.travel.systemImage,
                                value: AppTab.travel,
                            ) {
                                TravelTabView(account: accountBinding, itineraryEvents: $itineraryEvents, selectedDate: $selectedDate)
                            }
                        }
                    }
            }
        }
        .tint(currentAccent)
        .accentColor(currentAccent)
    }
}

extension RootView {
    @ViewBuilder
    private var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .other)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    private var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case nutrition
    case routine
    case workout
    case sports
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .routine: return "Routine"
        case .workout: return "Workout"
        case .sports: return "Sports"
        case .travel: return "Travel"
        }
    }

    var systemImage: String {
        switch self {
        case .nutrition: return "fork.knife.circle.fill"
        case .routine: return "calendar.and.person"
        case .workout: return "figure.strengthtraining.traditional"
        case .sports: return "sportscourt.fill"
        case .travel: return "globe.asia.australia.fill"
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ThemeManager())
}
