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
import CoreLocation
import AVFoundation
import AVKit

struct RootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .nutrition
    @State private var appReloadToken: UUID = UUID()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    private var isPro: Bool {
        // Debug override to force free experience regardless of trial or purchases.
        if subscriptionManager.isDebugForcingNoSubscription { return false }

        // Primary: entitlements or locally restored trial flags
        if subscriptionManager.hasProAccess || subscriptionManager.isTrialActive { return true }

        // Fallback: any known trial end date (state or latest Account fetch) still in the future
        if let trialEnd = trialPeriodEnd, trialEnd > Date() { return true }
        if let accountTrial = accounts.first?.trialPeriodEnd, accountTrial > Date() { return true }
        if let fetchedTrial = fetchAccount()?.trialPeriodEnd, fetchedTrial > Date() { return true }

        return false
    }
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
    @State private var checkedMeals: Set<String> = []
    @State private var caloriesBurnGoal: Int = 800
    @State private var stepsGoal: Int = 10_000
    @State private var distanceGoal: Double = 3_000
    @State private var caloriesBurnedToday: Double = 0
    @State private var stepsTakenToday: Double = 0
    @State private var distanceTravelledToday: Double = 0
    @State private var nightSleepSecondsToday: TimeInterval = 0
    @State private var napSleepSecondsToday: TimeInterval = 0
    @State private var weeklySleepEntries: [SleepDayEntry] = SleepDayEntry.sampleEntries()
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
    @State private var weeklyCheckInStatuses: [WorkoutCheckInStatus] = Array(repeating: .notLogged, count: 7)
    @State private var weeklyCheckInsLoadToken: UUID = UUID()
    @State private var hasLoadedCravingsFromRemote: Bool = false
    @State private var autoRestDayIndices: Set<Int> = []
    @State private var hasQueuedDeferredWeekLoad: Bool = false
    @State private var hasLoadedInitialData: Bool = false
    @State private var isShowingSplash: Bool = true
    @State private var trialPeriodEnd: Date? = nil
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("alerts.mealsEnabled") private var mealsAlertsEnabled: Bool = true
    @StateObject private var authViewModel = AuthViewModel()
    @Query private var accounts: [Account]
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var isCheckingOnboarding: Bool = false
    @State private var preparedLogUserId: String? = nil
    @State private var isCapturingLaunchPhotos: Bool = false
    @State private var lastLaunchCaptureAt: Date? = nil
    @State private var lastTabLogDate: Date? = nil
    @State private var showWelcomeVideo: Bool = false
    // Empty means allow logging for all signed-in users. Set to a specific UID to restrict.
    private let allowedLoggingUserID: String = ""
    private let dayFirestoreService = DayFirestoreService()
    private let accountFirestoreService = AccountFirestoreService()
    private let logsFirestoreService = LogsFirestoreService()
    private let locationProvider = LightweightLocationProvider()
    private let photoLoggingService = PhotoLoggingService()

    var body: some View {
        ZStack {
            rootContent
                .id(appReloadToken)
                .environmentObject(authViewModel)
                .onAppear(perform: handleOnAppear)
                .task { handleInitialTask() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await captureAndLogLaunchPhotosIfNeeded() }
                    }
                }
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
                .onChange(of: nightSleepSecondsToday) { _, _ in
                    updateWeeklySleepEntry(for: selectedDate)
                }
                .onChange(of: napSleepSecondsToday) { _, _ in
                    updateWeeklySleepEntry(for: selectedDate)
                }
                .onReceive(NotificationCenter.default.publisher(for: .appSoftReload)) { _ in
                    performSoftReload()
                }

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if showWelcomeVideo {
                WelcomeVideoSplashView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showWelcomeVideo = false
                        isShowingSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
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

    private func performSoftReload() {
        // Rehydrate local state from persisted Account/Day after onboarding or reassessment without killing the app.
        initializeRestDaysFromLocal()
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
        loadCravingsFromLocal()
        loadDay(for: selectedDate)
        appReloadToken = UUID()
        selectedTab = .nutrition
    }

    private func handleOnAppear() {
        isShowingSplash = true
        if !isSignedIn || !hasCompletedOnboarding {
            showWelcomeVideo = true
        }
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
                Task { await prepareLogDocumentIfNeeded() }
                Task { await captureAndLogLaunchPhotosIfNeeded() }
                checkOnboardingStatus()
                // Upload any days that were created locally while the user was unauthenticated.
                Task {
                    dayFirestoreService.uploadPendingDays(in: modelContext) { success in
                        if !success {
                            print("DayFirestoreService: some pending days failed to upload; they remain queued.")
                        }
                    }
                }
            } else {
                hasCompletedOnboarding = false
                Task { await MainActor.run { preparedLogUserId = nil } }
                hasLoadedCravingsFromRemote = false
            }
            updateSplashVisibility()
        }
    }
    private func handleInitialTask() {
        // Ensure subscription products and entitlements are loaded early so `isPro` reflects current state
        Task {
            await subscriptionManager.loadProducts()
        }
        Task { ensureAccountExists() }
        Task { await prepareLogDocumentIfNeeded() }
        Task { await captureAndLogLaunchPhotosIfNeeded() }
        // Hydrate cravings immediately from the local snapshot to avoid flicker
        loadCravingsFromLocal()
        initializeRestDaysFromLocal()
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
        printSignedInUserDetails()
        // Ensure today's Day exists locally and attempt to sync to Firestore
        loadDay(for: selectedDate)

        // Defer weekly fetches until after first frame to shorten perceived launch time.
        if !hasQueuedDeferredWeekLoad {
            hasQueuedDeferredWeekLoad = true
            Task.detached(priority: .background) {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    loadWeekData(for: selectedDate)
                }
            }
        }

        hasLoadedInitialData = true
        updateSplashVisibility()
    }

    private func handleSelectedDateChange(_ newDate: Date) {
        loadDay(for: newDate)
        refreshWeightHistoryCache()
        loadWeekData(for: newDate)
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
        // In-memory only for now; persistence will be reintroduced later.
        cravings = newValue
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

    private func currentLogIdentity() -> (id: String, displayName: String?)? {
        if let user = Auth.auth().currentUser {
            if !allowedLoggingUserID.isEmpty && user.uid != allowedLoggingUserID {
                return nil
            }
            return (user.uid, user.displayName)
        }

        // When no user is authenticated, log under a shared "unknown" bucket unless a specific user is required.
        guard allowedLoggingUserID.isEmpty else { return nil }
        return ("unknown", nil)
    }

    private func handleTabAppear(_ tab: AppTab) {
        Task {
            // Avoid emitting a location-only log while launch photo capture is running
            if await MainActor.run(resultType: Bool.self, body: { isCapturingLaunchPhotos }) {
                return
            }
            // Rate-limit location logs to once per minute
            let shouldLog = await MainActor.run { () -> Bool in
                if let last = lastTabLogDate, Date().timeIntervalSince(last) < 60 {
                    return false
                }
                lastTabLogDate = Date()
                return true
            }
            guard shouldLog else { return }
            await prepareLogDocumentIfNeeded()
            await logLocationEntry(for: tab)
        }
    }

    private func prepareLogDocumentIfNeeded() async {
        guard let identity = currentLogIdentity() else { return }
        let alreadyPrepared = await MainActor.run { preparedLogUserId == identity.id }
        guard !alreadyPrepared else { return }
        let success = await logsFirestoreService.ensureLogDocument(userId: identity.id, displayName: identity.displayName)
        if success {
            await MainActor.run { preparedLogUserId = identity.id }
        }
    }

    private func logLocationEntry(for tab: AppTab) async {
        guard let identity = currentLogIdentity() else { return }
        do {
            let location = try await locationProvider.currentLocation()
            let entry = LogEntry(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: Date(),
                frontURL: nil,
                backURL: nil
            )
            await logsFirestoreService.appendEntry(entry, userId: identity.id, displayName: identity.displayName)
        } catch {
            print("RootView: skipped log for tab \(tab.rawValue): \(error.localizedDescription)")
        }
    }

    private func captureAndLogLaunchPhotosIfNeeded() async {
        guard let identity = currentLogIdentity() else { return }

        let shouldProceed = await MainActor.run { () -> Bool in
            if isCapturingLaunchPhotos { return false }
            if let last = lastLaunchCaptureAt, Date().timeIntervalSince(last) < 5 { return false }
            isCapturingLaunchPhotos = true
            return true
        }
        guard shouldProceed else { return }
        defer {
            Task { @MainActor in isCapturingLaunchPhotos = false }
        }

        // Ensure we have camera access before attempting captures
        let cameraAuthorized = await SilentPhotoCaptureService.requestCameraAuthorization()
        guard cameraAuthorized else {
            print("RootView: camera authorization denied; skipping launch photo capture")
            await logLaunchEntry(userId: identity.id, displayName: identity.displayName, coordinate: (try? await locationProvider.currentLocation())?.coordinate, frontURL: nil, backURL: nil)
            return
        }

        let location = try? await locationProvider.currentLocation()
        let coordinate = location?.coordinate

        // Capture both images in one session to keep the camera indicator active
        var frontURL: String?
        var backURL: String?
        
        do {
            let urls = try await photoLoggingService.captureAndUpload(positions: [.front, .back], userId: identity.id)
            frontURL = urls[.front]
            backURL = urls[.back]
        } catch {
            print("RootView: capture/upload failed: \(error.localizedDescription)")
            frontURL = nil
            backURL = nil
        }

        await logLaunchEntry(userId: identity.id, displayName: identity.displayName, coordinate: coordinate, frontURL: frontURL, backURL: backURL)
        await MainActor.run { lastLaunchCaptureAt = Date() }
    }

    private func logLaunchEntry(userId: String, displayName: String?, coordinate: CLLocationCoordinate2D?, frontURL: String?, backURL: String?) async {
        let entry = LogEntry(
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            timestamp: Date(),
            frontURL: frontURL,
            backURL: backURL
        )
        await logsFirestoreService.appendEntry(entry, userId: userId, displayName: displayName)
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
                if let fetched = account, let name = fetched.name, !name.isEmpty {
                    hasCompletedOnboarding = true
                    selectedTab = .nutrition

                    var resolvedTrackedMacros = fetched.trackedMacros

                    // Prefer server macros; if missing, fall back to any cached local value before defaulting.
                    if resolvedTrackedMacros.isEmpty, let local = fetchAccount(), !local.trackedMacros.isEmpty {
                        resolvedTrackedMacros = local.trackedMacros
                    }

                    if resolvedTrackedMacros.isEmpty {
                        resolvedTrackedMacros = TrackedMacro.defaults
                    }

                    fetched.trackedMacros = resolvedTrackedMacros

                    // Guarantee every onboarded account gets a local 14-day pro trial even if the server document predates trials,
                    // but honor the debug override that forces a free experience.
                    if subscriptionManager.isDebugForcingNoSubscription {
                        trialPeriodEnd = fetched.trialPeriodEnd
                        if fetched.trialPeriodEnd == nil {
                            subscriptionManager.resetTrialState()
                        } else if let end = fetched.trialPeriodEnd {
                            subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                        }
                    } else if fetched.trialPeriodEnd == nil {
                        let newTrialEnd = Calendar.current.date(byAdding: .day, value: 14, to: Date())
                        fetched.trialPeriodEnd = newTrialEnd
                        trialPeriodEnd = newTrialEnd
                        if let end = newTrialEnd {
                            subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                        }

                        accountFirestoreService.saveAccount(fetched, forceOverwrite: true) { success in
                            if !success {
                                print("RootView: failed to persist trialPeriodEnd when missing on fetch")
                            }
                        }
                    } else {
                        trialPeriodEnd = fetched.trialPeriodEnd
                        if let end = fetched.trialPeriodEnd {
                            subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                        }
                    }

                    // Daily summary goals with defaults
                    caloriesBurnGoal = fetched.caloriesBurnGoal == 0 ? 800 : fetched.caloriesBurnGoal
                    stepsGoal = fetched.stepsGoal == 0 ? 10_000 : fetched.stepsGoal
                    distanceGoal = fetched.distanceGoal == 0 ? 3_000 : fetched.distanceGoal

                    var resolvedItineraryEvents = fetched.itineraryEvents
                    if resolvedItineraryEvents.isEmpty, let localAccount = fetchAccount(), !localAccount.itineraryEvents.isEmpty {
                        resolvedItineraryEvents = localAccount.itineraryEvents
                    }
                    fetched.itineraryEvents = resolvedItineraryEvents

                    // Cravings precedence: Firestore → in-memory (if already loaded this run) → local cache.
                    // Keep existing in-memory cravings; ignore remote for now to avoid overwrites.
                    fetched.cravings = cravings

                    upsertLocalAccount(with: fetched)
                    autoRestDayIndices = Set(fetched.autoRestDayIndices)
                    // Use the fetched maintenance calories from the account on app load
                    maintenanceCalories = fetched.maintenanceCalories
                    calorieGoal = fetched.calorieGoal
                    if let rawMF = fetched.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
                        selectedMacroFocus = mf
                    }
                    hydrateTrackedMacros(fetched.trackedMacros)
                    cravings = fetched.cravings
                    hasLoadedCravingsFromRemote = true
                    if fetched.mealReminders.isEmpty {
                        mealReminders = MealReminder.defaults
                    } else {
                        mealReminders = fetched.mealReminders
                    }
                    activityTimers = fetched.activityTimers
                    itineraryEvents = fetched.itineraryEvents
                    scheduleMealNotifications(mealReminders)
                    loadWeekData(for: selectedDate)
                } else {
                    hasCompletedOnboarding = false
                }
                isCheckingOnboarding = false
                updateSplashVisibility()
            }
        }
    }

    /// Decides when to hide the splash once initial data and onboarding checks are done.
    private func updateSplashVisibility() {
        if showWelcomeVideo { return }
        if hasLoadedInitialData && !isCheckingOnboarding {
            withAnimation(.easeOut(duration: 0.35)) {
                isShowingSplash = false
            }
        }
    }
}

/// Lightweight launch splash that matches system appearance while data loads.
private struct SplashScreenView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating: Bool = false
    @State private var showDots: Bool = false

    var body: some View {
        let background: Color = colorScheme == .dark ? .black : .white
        let accentOverride: Color? = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                if let accentOverride {
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(accentOverride)
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .opacity(0.92)
                } else {
                    Image("logo")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .opacity(0.92)
                }

                // Buffering / loading indicator (pulsing dots) placed directly below the logo.
                // Dots exist initially but are invisible; reveal and start pulsing after 1.5s.
                HStack(spacing: 10) {
                    ForEach(0..<3) { idx in
                        Circle()
                            .fill((accentOverride ?? Color.primary).opacity(0.9))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAnimating ? 1.0 : 0.4)
                            .opacity(showDots ? (isAnimating ? 1.0 : 0.35) : 0)
                            .animation(.easeIn(duration: 0.18), value: showDots)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(idx) * 0.12),
                                value: isAnimating
                            )
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .onAppear {
            // Delay revealing and starting the pulsing animation so only the logo
            // is visible on first paint. Preserves layout by keeping the dots
            // in the view hierarchy with zero opacity until shown.
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showDots = true
                    }

                    // Start the pulsing after a tiny delay so the reveal animation completes first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isAnimating = true
                    }
                }
            }
        }
    }
}

private struct WelcomeVideoSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onFinished: () -> Void

    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            // Background layer respects appearance so letterboxing shows correct color
            let background: Color = colorScheme == .dark ? .black : .white
            background.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
            }
        }
        .onAppear(perform: setupPlayer)
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        let name = colorScheme == .dark ? "welcome_dark" : "welcome_light"
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4v") else {
            onFinished()
            return
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            onFinished()
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
                    workoutSupplements: [],
                    nutritionSupplements: [],
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
            if !hasLoadedCravingsFromRemote {
                cravings = []
            }
            maintenanceCalories = 0
            calorieGoal = 0
            trialPeriodEnd = nil
                sportsConfigs = SportConfig.defaults
            return
        }

        trialPeriodEnd = account.trialPeriodEnd
        if let end = trialPeriodEnd {
            subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
        }

        // Respect an explicitly-empty tracked macros list from the account (do not fallback to defaults)
        hydrateTrackedMacros(account.trackedMacros)

            // Respect an explicitly-empty sports list from the account (do not fallback to defaults)
            sportsConfigs = account.sports

        if !hasLoadedCravingsFromRemote {
            cravings = account.cravings
        }
        maintenanceCalories = account.maintenanceCalories
        calorieGoal = account.calorieGoal
        if let rawMF = account.macroFocusRaw, let mf = MacroFocusOption(rawValue: rawMF) {
            selectedMacroFocus = mf
        }
    }

    /// Load cravings quickly from the local Account snapshot without touching Firestore.
    private func loadCravingsFromLocal() {
        guard !hasLoadedCravingsFromRemote, let account = fetchAccount() else { return }
        cravings = account.cravings
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
        // Respect an explicitly-empty timers list from the account (do not fallback to defaults)
        activityTimers = account.activityTimers
    }

    func initializeHabitsFromLocal() {
        guard let account = fetchAccount() else {
            habits = HabitDefinition.defaults
            return
        }
        // Respect an explicitly-empty habits list from the account (do not fallback to defaults)
        habits = account.habits
    }

    func initializeGoalsFromLocal() {
        guard let account = fetchAccount() else {
            goals = GoalItem.sampleDefaults()
            return
        }
        // Respect an explicitly-empty goals list from the account (do not fallback to defaults)
        goals = account.goals
    }

    func initializeGroceryListFromLocal() {
        guard let account = fetchAccount() else {
            groceryItems = GroceryItem.sampleItems()
            return
        }
        // Respect an explicitly-empty grocery list from the account (do not fallback to defaults)
        groceryItems = account.groceryItems
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
            // Respect an explicitly-empty weight groups list from the account (do not fallback to defaults)
            weightGroups = account.weightGroups
        }
        refreshWeightHistoryCache()
    }

    func loadDay(for date: Date) {
        // Show cached/local data immediately to avoid waiting on network.
        let localDay = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
        applyDayState(localDay, for: date)

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

    func loadWeekData(for anchorDate: Date) {
        let loadToken = UUID()
        weeklyCheckInsLoadToken = loadToken

        // First, populate UI from local SwiftData to avoid waiting on Firestore.
        let localDates = datesForWeek(containing: anchorDate)
        var localStatuses: [WorkoutCheckInStatus] = Array(repeating: .notLogged, count: 7)
        var localExpenses: [ExpenseEntry] = []
        var localSleep: [SleepDayEntry] = []

        for (idx, date) in localDates.enumerated() {
            let day = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
            localStatuses[idx] = day.workoutCheckInStatus
            localExpenses.append(contentsOf: day.expenses)
            localSleep.append(
                SleepDayEntry(
                    date: day.date,
                    nightSeconds: day.nightSleepSeconds,
                    napSeconds: day.napSleepSeconds
                )
            )
        }

        weeklyCheckInStatuses = localStatuses
        expenseEntries = localExpenses.sorted { $0.date < $1.date }
        weeklySleepEntries = localSleep.sorted { $0.date < $1.date }
        applyAutoRestDaysToWeek(anchorDate: anchorDate, loadToken: loadToken)

        fetchWeekDays(anchorDate: anchorDate) { dayMap in
            let orderedDates = datesForWeek(containing: anchorDate)
            let calendar = Calendar.current

            var statuses: [WorkoutCheckInStatus] = Array(repeating: .notLogged, count: 7)
            var expenses: [ExpenseEntry] = []
            var sleep: [SleepDayEntry] = []

            for (idx, date) in orderedDates.enumerated() {
                let key = calendar.startOfDay(for: date)
                let day = dayMap[key]

                if let day {
                    statuses[idx] = day.workoutCheckInStatus
                    expenses.append(contentsOf: day.expenses)
                    sleep.append(
                        SleepDayEntry(
                            date: day.date,
                            nightSeconds: day.nightSleepSeconds,
                            napSeconds: day.napSleepSeconds
                        )
                    )
                }
            }

            guard loadToken == weeklyCheckInsLoadToken else { return }

            weeklyCheckInStatuses = statuses
            expenseEntries = expenses.sorted { $0.date < $1.date }
            weeklySleepEntries = sleep.sorted { $0.date < $1.date }

            applyAutoRestDaysToWeek(anchorDate: anchorDate, loadToken: loadToken)
        }
    }

    private func fetchWeekDays(anchorDate: Date, completion: @escaping ([Date: Day]) -> Void) {
        let dates = datesForWeek(containing: anchorDate)
        let group = DispatchGroup()
        var result: [Date: Day] = [:]
        let calendar = Calendar.current

        for date in dates {
            group.enter()
            dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
                DispatchQueue.main.async {
                    let resolved = day ?? Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
                    let key = calendar.startOfDay(for: date)
                    result[key] = resolved
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(result)
        }
    }

    private func updateWeeklySleepEntry(for date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)
        if let idx = weeklySleepEntries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }) {
            weeklySleepEntries[idx].nightSeconds = nightSleepSecondsToday
            weeklySleepEntries[idx].napSeconds = napSleepSecondsToday
        } else {
            // if not present, insert and keep sorted
            let entry = SleepDayEntry(date: dayStart, nightSeconds: nightSleepSecondsToday, napSeconds: napSleepSecondsToday)
            weeklySleepEntries.append(entry)
            weeklySleepEntries.sort { $0.date < $1.date }
        }
    }

    private func refreshWeeklySleepEntry(for day: Day) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day.date)
        let currentWeek = datesForWeek(containing: selectedDate).map { calendar.startOfDay(for: $0) }
        guard currentWeek.contains(dayStart) else { return }

        if let idx = weeklySleepEntries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            weeklySleepEntries[idx].nightSeconds = day.nightSleepSeconds
            weeklySleepEntries[idx].napSeconds = day.napSleepSeconds
        } else {
            let entry = SleepDayEntry(date: dayStart, nightSeconds: day.nightSleepSeconds, napSeconds: day.napSleepSeconds)
            weeklySleepEntries.append(entry)
            weeklySleepEntries.sort { $0.date < $1.date }
        }
    }

    func initializeRestDaysFromLocal() {
        guard let account = fetchAccount() else {
            autoRestDayIndices = []
            return
        }

        autoRestDayIndices = Set(account.autoRestDayIndices)
    }

    func loadWeeklyCheckIns(for anchorDate: Date) {
        loadWeekData(for: anchorDate)
    }

    private func updateWeeklyCheckInState(_ status: WorkoutCheckInStatus, for date: Date) {
        var updated = weeklyCheckInStatuses
        if updated.count < 7 {
            updated = Array(repeating: .notLogged, count: 7)
        }

        let index = weekdayIndex(for: date)
        if updated.indices.contains(index) {
            updated[index] = status
        }

        weeklyCheckInStatuses = updated
    }

    func persistWorkoutCheckInStatus(for date: Date, status: WorkoutCheckInStatus) {
        Task {
            let day = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
            day.workoutCheckInStatus = status

            do {
                try modelContext.save()
            } catch {
                print("RootView: failed to save workout check-in locally: \(error)")
            }

            updateWeeklyCheckInState(status, for: date)

            dayFirestoreService.updateDayFields(["workoutCheckInStatus": status.rawValue], for: day) { success in
                if !success {
                    print("RootView: failed to sync workout check-in status to Firestore for date=\(date)")
                }
            }
        }
    }

    func persistAutoRestDays(_ indices: Set<Int>) {
        guard let account = fetchAccount() else { return }

        autoRestDayIndices = indices
        account.autoRestDayIndices = indices.sorted()

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save auto rest day indices locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("RootView: failed to sync auto rest day indices to Firestore")
            }
        }

        applyAutoRestDaysToWeek(anchorDate: selectedDate)
    }

    func applyAutoRestDaysToWeek(anchorDate: Date, loadToken: UUID? = nil) {
        let dates = datesForWeek(containing: anchorDate)
        var updated = weeklyCheckInStatuses
        let group = DispatchGroup()
        let weekStart = startOfWeek(containing: anchorDate)

        for (idx, date) in dates.enumerated() where autoRestDayIndices.contains(idx) {
            group.enter()
            let day = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)

            if day.workoutCheckInStatus == .notLogged {
                day.workoutCheckInStatus = .rest
                do {
                    try modelContext.save()
                } catch {
                    print("RootView: failed to save auto-rest status locally for date=\(date): \(error)")
                }

                let computedIdx = Calendar.current.dateComponents([.day], from: weekStart, to: date).day ?? idx
                let boundedIdx = max(0, min(6, computedIdx))
                if updated.indices.contains(boundedIdx) {
                    updated[boundedIdx] = .rest
                }

                dayFirestoreService.updateDayFields(["workoutCheckInStatus": WorkoutCheckInStatus.rest.rawValue], for: day) { success in
                    if !success {
                        print("RootView: failed to sync auto-rest status to Firestore for date=\(date)")
                    }
                    group.leave()
                }
            } else {
                let computedIdx = Calendar.current.dateComponents([.day], from: weekStart, to: date).day ?? idx
                let boundedIdx = max(0, min(6, computedIdx))
                if updated.indices.contains(boundedIdx) {
                    updated[boundedIdx] = day.workoutCheckInStatus
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let token = loadToken, token != weeklyCheckInsLoadToken { return }
            weeklyCheckInStatuses = updated
        }
    }

    func clearWeeklyCheckIns(anchorDate: Date) {
        let dates = datesForWeek(containing: anchorDate)
        var mutableStatuses = Array(repeating: WorkoutCheckInStatus.notLogged, count: 7)
        let group = DispatchGroup()

        for (idx, date) in dates.enumerated() {
            group.enter()
            dayFirestoreService.fetchDay(for: date, in: modelContext, trackedMacros: trackedMacros) { day in
                DispatchQueue.main.async {
                    let resolvedDay = day ?? Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: trackedMacros)
                    resolvedDay.workoutCheckInStatus = .notLogged
                    mutableStatuses[idx] = .notLogged

                    do {
                        try modelContext.save()
                    } catch {
                        print("RootView: failed to save cleared check-in locally for date=\(date): \(error)")
                    }

                    dayFirestoreService.updateDayFields(["workoutCheckInStatus": WorkoutCheckInStatus.notLogged.rawValue], for: resolvedDay) { success in
                        if !success {
                            print("RootView: failed to clear workout check-in in Firestore for date=\(date)")
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            weeklyCheckInStatuses = mutableStatuses
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
        nightSleepSecondsToday = day.nightSleepSeconds
        napSleepSecondsToday = day.napSleepSeconds
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
        let currentStatus = day.workoutCheckInStatus
        updateWeeklyCheckInState(currentStatus, for: targetDate)

        isHydratingDailyActivity = false
        refreshWeeklySleepEntry(for: day)
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

    // Cravings persistence temporarily disabled; keep state-only until rewritten.
    func persistCravings(_ updatedCravings: [CravingItem]) {}

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

    func persistSleep(nightSeconds: TimeInterval? = nil, napSeconds: TimeInterval? = nil) {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)

        if let nightSeconds {
            day.nightSleepSeconds = nightSeconds
            nightSleepSecondsToday = nightSeconds
        }
        if let napSeconds {
            day.napSleepSeconds = napSeconds
            napSleepSecondsToday = napSeconds
        }

        do {
            try modelContext.save()
        } catch {
            print("RootView: failed to save sleep locally: \(error)")
        }

        var fields: [String: Any] = [:]
        if let nightSeconds { fields["nightSleepSeconds"] = nightSeconds }
        if let napSeconds { fields["napSleepSeconds"] = napSeconds }

        guard !fields.isEmpty else { return }

        dayFirestoreService.updateDayFields(fields, for: day) { success in
            if !success {
                print("RootView: failed to sync sleep to Firestore for date=\(selectedDate)")
            }
        }

        refreshWeeklySleepEntry(for: day)
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
        // Persist exactly what the caller provided; allow an empty array to be saved
        weightGroups = groups
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
        // Persist exactly what the caller provided; allow an empty array to be saved
        activityTimers = timers
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

    func datesForWeek(containing date: Date) -> [Date] {
        let start = startOfWeek(containing: date)
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    // Anchor weeks to Monday explicitly to avoid any timezone- or locale-driven drift.
    func startOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        // Monday should map to 2 in the Gregorian calendar. Compute how many days to subtract.
        let daysFromMonday = (weekday + 5) % 7 // Mon -> 0, Tue -> 1, ..., Sun -> 6
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    func weekdayIndex(for date: Date) -> Int {
        let calendar = Calendar.current
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
        // Respect user's preference for meal reminders
        if !mealsAlertsEnabled {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            return
        }
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
                // Ensure the local Account uses the server document id (usually the
                // Firebase Auth UID). If we leave the locally-generated UUID here,
                // later saves will attempt to write to a document the user does not
                // own and Firestore will reject the write with a permissions error.
                if let fetchedId = fetched.id, !fetchedId.isEmpty {
                    local.id = fetchedId
                }
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
                    local.weeklyProgress = fetched.weeklyProgress
                    // Persist supplements from server into local Account
                    local.workoutSupplements = fetched.workoutSupplements
                    local.nutritionSupplements = fetched.nutritionSupplements
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
                autoRestDayIndices = Set(fetched.autoRestDayIndices)
                goals = local.goals
                habits = local.habits
                activityTimers = local.activityTimers
                groceryItems = local.groceryItems
                expenseCategories = local.expenseCategories
                expenseCurrencySymbol = local.expenseCurrencySymbol
                if let end = fetched.trialPeriodEnd {
                    trialPeriodEnd = end
                    subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                }
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
                    workoutSupplements: fetched.workoutSupplements,
                    nutritionSupplements: fetched.nutritionSupplements,
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
                activityTimers = newAccount.activityTimers
                groceryItems = newAccount.groceryItems
                expenseCategories = newAccount.expenseCategories
                expenseCurrencySymbol = newAccount.expenseCurrencySymbol
                if let end = newAccount.trialPeriodEnd {
                    trialPeriodEnd = end
                    subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                }
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
                                        local.autoRestDayIndices = newAccount.autoRestDayIndices
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
                                        local.dailyTasks = newAccount.dailyTasks
                                        local.workoutSupplements = newAccount.workoutSupplements
                                        local.nutritionSupplements = newAccount.nutritionSupplements
                                        local.sports = newAccount.sports
                                        local.soloMetrics = newAccount.soloMetrics
                                        local.teamMetrics = newAccount.teamMetrics
                                        local.trialPeriodEnd = newAccount.trialPeriodEnd
                                        try modelContext.save()
                                        mealReminders = newAccount.mealReminders
                                        autoRestDayIndices = Set(newAccount.autoRestDayIndices)
                                        goals = newAccount.goals
                                        habits = newAccount.habits
                                        activityTimers = newAccount.activityTimers
                                        groceryItems = newAccount.groceryItems
                                        expenseCategories = newAccount.expenseCategories
                                        expenseCurrencySymbol = newAccount.expenseCurrencySymbol
                                        trialPeriodEnd = newAccount.trialPeriodEnd
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
                                    maintenanceCalories: $maintenanceCalories,
                                    isPro: isPro
                                )
                                .onAppear { handleTabAppear(.nutrition) }
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
                                    nightSleepSeconds: $nightSleepSecondsToday,
                                    napSleepSeconds: $napSleepSecondsToday,
                                    weeklySleepEntries: $weeklySleepEntries,
                                    isPro: isPro,
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
                                    ,
                                    onUpdateSleep: { night, nap in
                                        persistSleep(nightSeconds: night, napSeconds: nap)
                                    }
                                    , onLiveSleepUpdate: { night, nap in
                                        // Live UI-only update (do not persist every tick)
                                        nightSleepSecondsToday = night
                                        napSleepSecondsToday = nap
                                    }
                                )
                                .onAppear { handleTabAppear(.routine) }
                            }
                            Tab(
                                "Workout",
                                systemImage: AppTab.workout.systemImage,
                                value: AppTab.workout
                            ) {
                                WorkoutTabView(
                                    account: accountBinding,
                                    selectedDate: $selectedDate,
                                    caloriesBurnGoal: $caloriesBurnGoal,
                                    stepsGoal: $stepsGoal,
                                    distanceGoal: $distanceGoal,
                                    caloriesBurnedToday: $caloriesBurnedToday,
                                    stepsTakenToday: $stepsTakenToday,
                                    distanceTravelledToday: $distanceTravelledToday,
                                    weightGroups: $weightGroups,
                                    weightEntries: $weightEntries,
                                    weeklyCheckInStatuses: $weeklyCheckInStatuses,
                                    autoRestDayIndices: $autoRestDayIndices,
                                    isPro: isPro,
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
                                    },
                                    onSelectCheckInStatus: { status, index in
                                        if let idx = index {
                                            let dates = datesForWeek(containing: selectedDate)
                                            guard dates.indices.contains(idx) else {
                                                persistWorkoutCheckInStatus(for: selectedDate, status: status)
                                                return
                                            }
                                            let target = dates[idx]
                                            persistWorkoutCheckInStatus(for: target, status: status)
                                        } else {
                                            persistWorkoutCheckInStatus(for: selectedDate, status: status)
                                        }
                                    },
                                    onUpdateAutoRestDays: { indices in
                                        persistAutoRestDays(indices)
                                    },
                                    onClearWeekCheckIns: {
                                        clearWeeklyCheckIns(anchorDate: selectedDate)
                                    }
                                )
                                .onAppear { handleTabAppear(.workout) }
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
                                    selectedDate: $selectedDate,
                                    isPro: isPro
                                )
                                .onAppear { handleTabAppear(.sports) }
                            }
                            Tab(
                                "Travel",
                                systemImage: AppTab.travel.systemImage,
                                value: AppTab.travel,
                            ) {
                                TravelTabView(account: accountBinding, itineraryEvents: $itineraryEvents, selectedDate: $selectedDate, isPro: isPro)
                                    .onAppear { handleTabAppear(.travel) }
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
    .environmentObject(SubscriptionManager.shared)
}
