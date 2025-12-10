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

struct RootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .nutrition
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var isCheckingOnboarding: Bool = false
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
                } else {
                    hasCompletedOnboarding = false
                }
            }
        }
        .task {
            ensureAccountExists()
            printSignedInUserDetails()
            // Ensure onboarding status is evaluated on startup
            checkOnboardingStatus()
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
                        upsertLocalAccount(with: fetched)
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
                    theme: "default",
                    unitSystem: "metric",
                    startWeekOn: "monday"
                )
                modelContext.insert(defaultAccount)
                try modelContext.save()
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
                local.height = fetched.height
                local.weight = fetched.weight
                local.theme = fetched.theme
                local.unitSystem = fetched.unitSystem
                local.startWeekOn = fetched.startWeekOn
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
                    theme: fetched.theme,
                    unitSystem: fetched.unitSystem,
                    startWeekOn: fetched.startWeekOn
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
                    TabView(selection: $selectedTab) {
                        Tab(
                            "Nutrition",
                            systemImage: AppTab.nutrition.systemImage,
                            value: AppTab.nutrition
                        ) {
                            NutritionTabView(account: .constant(account))
                        }
                        Tab(
                            "Routine",
                            systemImage: AppTab.routine.systemImage,
                            value: AppTab.routine
                        ) {
                            RoutineTabView(account: .constant(account))
                        }
                        Tab(
                            "Workout",
                            systemImage: AppTab.workout.systemImage,
                            value: AppTab.workout
                        ) {
                            WorkoutTabView(account: .constant(account))
                        }
                        Tab(
                            "Sports",
                            systemImage: AppTab.sports.systemImage,
                            value: AppTab.sports
                        ) {
                            SportsTabView(account: .constant(account))
                        }
                        Tab(
                            "Lookup",
                            systemImage: AppTab.lookup.systemImage,
                            value: AppTab.lookup,
                            role: .search
                        ) {
                            LookupTabView(account: .constant(account))
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
