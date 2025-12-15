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
    @State private var checkedMeals: Set<String> = []
    @State private var mealReminders: [MealReminder] = MealReminder.defaults
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var authViewModel = AuthViewModel()
    @Query private var accounts: [Account]
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var isCheckingOnboarding: Bool = false
    private let dayFirestoreService = DayFirestoreService()
    private let accountFirestoreService = AccountFirestoreService()

    var body: some View {
        Group {
            if isSignedIn, hasCompletedOnboarding {
                mainAppContent
            } else {
                WelcomeFlowView {
                    hasCompletedOnboarding = true
                    selectedTab = .nutrition
                    DispatchQueue.main.async {
                        if isSignedIn {
                            hasCompletedOnboarding = true
                            selectedTab = .nutrition
                        }
                    }
                }
                .environmentObject(authViewModel)
            }
        }
        .environmentObject(authViewModel)
        .onAppear {
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
                }
            }
        }
        .task {
            ensureAccountExists()
            initializeTrackedMacrosFromLocal()
            initializeMealRemindersFromLocal()
            printSignedInUserDetails()
            // Ensure onboarding status is evaluated on startup
            checkOnboardingStatus()
            // Ensure today's Day exists locally and attempt to sync to Firestore
            loadDay(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            print("RootView: selectedDate changed to \(newDate), fetching Day from Firestore...")
            loadDay(for: newDate)
        }
        .onChange(of: consumedCalories) { _, newValue in
            // Persist the updated calories to the local SwiftData Day and attempt to sync to Firestore
            Task {
                let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
                day.caloriesConsumed = newValue
                do {
                    try modelContext.save()
                    print("RootView: saved caloriesConsumed=\(newValue) for date=\(selectedDate) to local store")
                } catch {
                    print("RootView: failed to save local Day: \(error)")
                }

                // Attempt to upload only the changed field to Firestore so we don't
                // overwrite other values that may be stale in-memory.
                if newValue != 0 {
                    dayFirestoreService.updateDayFields(["caloriesConsumed": newValue], for: day) { success in
                        if success {
                            print("RootView: successfully synced caloriesConsumed to Firestore for date=\(selectedDate)")
                        } else {
                            print("RootView: failed to sync caloriesConsumed to Firestore for date=\(selectedDate)")
                        }
                    }
                }
            }
        }

        .onChange(of: calorieGoal) { _, newValue in
            guard let account = fetchAccount() else { return }
            account.calorieGoal = newValue

            do {
                try modelContext.save()
                print("RootView: saved calorieGoal=\(newValue) to local Account")
            } catch {
                print("RootView: failed to save calorieGoal to local Account: \(error)")
            }

            accountFirestoreService.saveAccount(account) { success in
                if success {
                    print("RootView: synced calorieGoal to Firestore via Account")
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

        .onChange(of: selectedMacroFocus) { _, newValue in
            Task {
                let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
                day.macroFocusRaw = newValue?.rawValue
                do {
                    try modelContext.save()
                    print("RootView: saved macroFocus=\(String(describing: newValue)) for date=\(selectedDate) to local store")
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
                        print("RootView: synced macroFocus to Firestore via Account")
                    } else {
                        print("RootView: failed to sync macroFocus to Firestore via Account")
                    }
                }
            }
        }
        .onChange(of: trackedMacros) { _, newValue in
            persistTrackedMacros(newValue)
        }
        .onChange(of: macroConsumptions) { _, newValue in
            persistMacroConsumptions(newValue)
        }
        .onChange(of: cravings) { _, newValue in
            persistCravings(newValue)
        }
        .onChange(of: mealReminders) { _, newValue in
            persistMealReminders(newValue)
        }
        .onChange(of: checkedMeals) { _, newValue in
            persistCheckedMeals(newValue)
        }
        .onChange(of: accounts.first?.maintenanceCalories) { _, newValue in
            // Keep the UI's maintenanceCalories in sync with the local Account entity
            if let updated = newValue {
                DispatchQueue.main.async {
                    maintenanceCalories = updated
                }
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
                        if fetched.trackedMacros.isEmpty {
                            fetched.trackedMacros = TrackedMacro.defaults
                            accountFirestoreService.saveAccount(fetched) { success in
                                if !success {
                                    print("RootView: failed to seed default tracked macros to Firestore")
                                }
                            }
                        }
                        upsertLocalAccount(with: fetched)
                        // Use the fetched maintenance calories from the account on app load
                        maintenanceCalories = fetched.maintenanceCalories
                        calorieGoal = fetched.calorieGoal
                        if let rawMF = fetched.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
                            selectedMacroFocus = mf
                        }
                        trackedMacros = fetched.trackedMacros
                        cravings = fetched.cravings
                        if fetched.mealReminders.isEmpty {
                            mealReminders = MealReminder.defaults
                        } else {
                            mealReminders = fetched.mealReminders
                        }
                        scheduleMealNotifications(mealReminders)
                    }
                } else {
                    hasCompletedOnboarding = false
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
                    mealReminders: MealReminder.defaults
                )
                modelContext.insert(defaultAccount)
                try modelContext.save()
                trackedMacros = defaultAccount.trackedMacros
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
            trackedMacros = TrackedMacro.defaults
            cravings = []
            maintenanceCalories = 0
            calorieGoal = 0
            return
        }

        if account.trackedMacros.isEmpty {
            account.trackedMacros = TrackedMacro.defaults
            trackedMacros = account.trackedMacros
            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save default tracked macros locally: \(error)")
            }
        } else {
            trackedMacros = account.trackedMacros
        }

        cravings = account.cravings
        maintenanceCalories = account.maintenanceCalories
        calorieGoal = account.calorieGoal
        if let rawMF = account.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
            selectedMacroFocus = mf
        }
    }

    func loadDay(for date: Date) {
        dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
            if let d = day {
                print("RootView: fetched/created local Day for date=\(d.date)")
                DispatchQueue.main.async {
                    applyDayState(d, for: date)
                }
            } else {
                print("RootView: failed to fetch/create local Day for selectedDate=\(date)")
            }
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
        consumedCalories = day.caloriesConsumed

        let previousCount = macroConsumptions.count
        if !trackedMacros.isEmpty {
            day.ensureMacroConsumptions(for: trackedMacros)
        }
        macroConsumptions = day.macroConsumptions

        let validMeals = Set(MealType.allCases.map { $0.rawValue })
        let completed = Set(day.completedMeals.map { $0.lowercased() }).intersection(validMeals)
        checkedMeals = completed

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
                        print("RootView: synced inherited Day fields for date=\(targetDate): \(fieldsToUpdate)")
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
    }

    func persistTrackedMacros(_ macros: [TrackedMacro]) {
        guard let account = fetchAccount() else { return }

        account.trackedMacros = macros
        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save tracked macros locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
                print("RootView: synced tracked macros to Firestore")
            } else {
                print("RootView: failed to sync tracked macros to Firestore")
            }
        }

        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: macros)
        day.ensureMacroConsumptions(for: macros)
        macroConsumptions = day.macroConsumptions

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save day macro alignments: \(error)")
        }

        dayFirestoreService.saveDay(day) { success in
            if success {
                print("RootView: synced day macros after tracked macro change")
            } else {
                print("RootView: failed to sync day macros after tracked macro change")
            }
        }
    }

    func persistMacroConsumptions(_ consumptions: [MacroConsumption]) {
        Task {
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
            day.macroConsumptions = consumptions
            do {
                try modelContext.save()
                print("RootView: saved macro consumptions for date=\(selectedDate)")
            } catch {
                print("RootView: failed to save macro consumptions locally: \(error)")
            }

            let hasConsumption = consumptions.contains { $0.consumed != 0 }
            if hasConsumption {
                dayFirestoreService.saveDay(day) { success in
                    if success {
                        print("RootView: synced macro consumptions to Firestore for date=\(selectedDate)")
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
            print("RootView: saved cravings to local account")
        } catch {
            print("RootView: failed to save cravings locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
                print("RootView: synced cravings to Firestore")
            } else {
                print("RootView: failed to sync cravings to Firestore")
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
                print("RootView: saved completed meals for date=\(selectedDate): \(ordered)")
            } catch {
                print("RootView: failed to save completed meals locally: \(error)")
            }

            dayFirestoreService.updateDayFields(["completedMeals": ordered], for: day) { success in
                if success {
                    print("RootView: synced completed meals to Firestore for date=\(selectedDate)")
                } else {
                    print("RootView: failed to sync completed meals to Firestore for date=\(selectedDate)")
                }
            }
        }
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
            print("RootView: saved meal reminders locally")
        } catch {
            print("RootView: failed to save meal reminders locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
                print("RootView: synced meal reminders to Firestore")
            } else {
                print("RootView: failed to sync meal reminders to Firestore")
            }
        }

        scheduleMealNotifications(reminders)
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
                local.activityLevel = fetched.activityLevel
                local.startWeekOn = fetched.startWeekOn
                local.trackedMacros = fetched.trackedMacros
                local.cravings = fetched.cravings
                local.mealReminders = fetched.mealReminders
                local.intermittentFastingMinutes = fetched.intermittentFastingMinutes
                try modelContext.save()
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
                    trackedMacros: fetched.trackedMacros,
                    cravings: fetched.cravings,
                    mealReminders: fetched.mealReminders
                )
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
                                        local.startWeekOn = newAccount.startWeekOn
                                        local.trackedMacros = newAccount.trackedMacros
                                        local.cravings = newAccount.cravings
                                        local.mealReminders = newAccount.mealReminders
                                        try modelContext.save()
                                        mealReminders = newAccount.mealReminders
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
                                RoutineTabView(account: accountBinding, selectedDate: $selectedDate)
                            }
                            Tab(
                                "Workout",
                                systemImage: AppTab.workout.systemImage,
                                value: AppTab.workout
                            ) {
                                WorkoutTabView(account: accountBinding, selectedDate: $selectedDate)
                            }
                            Tab(
                                "Sports",
                                systemImage: AppTab.sports.systemImage,
                                value: AppTab.sports
                            ) {
                                SportsTabView(account: accountBinding, selectedDate: $selectedDate)
                            }
                            Tab(
                                "Lookup",
                                systemImage: AppTab.lookup.systemImage,
                                value: AppTab.lookup,
                                role: .search
                            ) {
                                LookupTabView(account: accountBinding, selectedDate: $selectedDate)
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
    case lookup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .routine: return "Routine"
        case .workout: return "Workout"
        case .sports: return "Sports"
        case .lookup: return "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .nutrition: return "fork.knife.circle.fill"
        case .routine: return "calendar.and.person"
        case .workout: return "figure.strengthtraining.traditional"
        case .sports: return "sportscourt.fill"
        case .lookup: return "magnifyingglass"
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ThemeManager())
}
