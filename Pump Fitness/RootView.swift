//
//  RootView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var themeManager: ThemeManager
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
                TabView(selection: $selectedTab) {
                    Tab(
                        "Nutrition",
                        systemImage: AppTab.nutrition.systemImage,
                        value: AppTab.nutrition
                    ) {
                        NutritionTabView()
                    }
                    Tab(
                        "Workout",
                        systemImage: AppTab.workout.systemImage,
                        value: AppTab.workout
                    ) {
                        WorkoutTabView()
                    }
                    Tab(
                        "Coaching",
                        systemImage: AppTab.coaching.systemImage,
                        value: AppTab.coaching
                    ) {
                        /*WorkoutTabView()*/
                        Text("Coaching")
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
    case workout
    case coaching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: return "Nutrition"
        case .workout: return "Workout"
        case .coaching: return "Coaching"
        }
    }

    var systemImage: String {
        switch self {
        case .nutrition: return "fork.knife.circle.fill"
        case .workout: return "figure.strengthtraining.traditional"
        case .coaching: return "person.2.wave.2"
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ThemeManager())
}
