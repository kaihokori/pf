//
//  RootView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .nutrition
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainAppContent
            } else {
                WelcomeFlowView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .task {
            ensureAccountExists()
        }
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
}

private extension RootView {
    struct WelcomeFlowView: View {
        @State private var showingOnboarding = false
        var onCompletion: () -> Void

        var body: some View {
            Group {
                if showingOnboarding {
                    OnboardingView {
                        showingOnboarding = false
                        onCompletion()
                    }
                } else {
                    WelcomeView(startOnboarding: {
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
                } else {
                    ProgressView("Loading account...")
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
