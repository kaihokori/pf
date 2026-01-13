//
//  AccountsView.swift
//  Trackerio
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import FirebaseFirestore
import SwiftData
import Combine
import PhotosUI
import UIKit
import FirebaseAuth
import HealthKit
import TipKit

struct AccountsView: View {
    @Binding var account: Account
    @StateObject private var viewModel: AccountsViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDiscardAlert = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?
    @State private var showCameraPicker = false
    @State private var showCameraUnavailableAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showMaintenanceExplainer = false
    @State private var showActivityExplainer = false
    @State private var showHealthKitStatusAlert = false
    @State private var healthKitStatusMessage = ""
    @State private var showAlertsSheet = false
    @State private var showReportSheet = false
    @AppStorage("alerts.dailyTasksEnabled") private var dailyTasksAlertsEnabled: Bool = true
    @AppStorage("alerts.habitsEnabled") private var habitsAlertsEnabled: Bool = true
    @AppStorage("alerts.timeTrackingEnabled") private var timeTrackingAlertsEnabled: Bool = true
    @AppStorage("alerts.dailyCheckInEnabled") private var dailyCheckInAlertsEnabled: Bool = true
    @AppStorage("alerts.fastingEnabled") private var fastingAlertsEnabled: Bool = true
    @AppStorage("alerts.mealsEnabled") private var mealsAlertsEnabled: Bool = true
    @AppStorage("alerts.weeklyProgressEnabled") private var weeklyProgressAlertsEnabled: Bool = true
    @State private var showOnboarding = false
    @State private var isDeletingAccount = false
    @State private var isSigningOut = false
    @State private var isClearingTrialTimer = false

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    init(account: Binding<Account>) {
        _account = account
        _viewModel = StateObject(wrappedValue: AccountsViewModel())
    }

    var body: some View {
        // Sync viewModel with account when view appears
        let syncFromAccount = {
            let acc = account
            viewModel.draft.name = acc.name ?? ""
            viewModel.setAvatarImageData(acc.profileImage)
            viewModel.draft.avatarColor = AvatarColorOption(rawValue: Int(acc.profileAvatar ?? "0") ?? 0) ?? .emberPulse
            viewModel.draft.appTheme = AppTheme(rawValue: acc.theme ?? "multiColour") ?? .multiColour
            viewModel.draft.birthDate = acc.dateOfBirth ?? Date()
            viewModel.draft.selectedGender = GenderOption(rawValue: acc.gender ?? "")
            viewModel.draft.unitSystem = UnitSystem(rawValue: acc.unitSystem ?? "metric") ?? .metric
            viewModel.draft.heightValue = acc.height != nil ? String(format: "%.0f", acc.height ?? 0) : ""
            viewModel.draft.weightValue = acc.weight != nil ? String(format: "%.0f", acc.weight ?? 0) : ""
            	viewModel.draft.maintenanceCalories = acc.maintenanceCalories > 0 ? String(acc.maintenanceCalories) : ""
            	viewModel.draft.activityLevel = ActivityLevelOption(rawValue: acc.activityLevel ?? ActivityLevelOption.moderatelyActive.rawValue) ?? .moderatelyActive
            // Calculate imperial height if needed
            if viewModel.draft.unitSystem == .imperial, let cm = Double(viewModel.draft.heightValue), cm > 0 {
                let totalInches = cm / 2.54
                let feet = Int(totalInches / 12)
                let inches = totalInches - Double(feet * 12)
                viewModel.draft.heightFeet = String(feet)
                viewModel.draft.heightInches = String(format: "%.1f", inches)
            } else {
                viewModel.draft.heightFeet = ""
                viewModel.draft.heightInches = ""
            }
            viewModel.setBaselineFromDraft()
        }
        NavigationStack {
            ZStack {
                if !isDeletingAccount && !isSigningOut {
                    backgroundView
                    ScrollView {
                        VStack(spacing: 24) {
                        SectionCard(title: "Basic Details") {
                            IdentitySection(
                                viewModel: viewModel,
                                selectLibraryAction: { showPhotoPicker = true },
                                selectCameraAction: presentCameraPicker,
                                clearImageAction: { viewModel.setAvatarImageData(nil) }
                            )
                            
                            TextFieldWithLabel(
                                "Preferred name",
                                text: Binding(
                                    get: { viewModel.draft.name },
                                    set: { viewModel.draft.name = $0 }
                                ),
                                prompt: Text("e.g. Alex")
                            )
                            
                            GenderSelector(selectedGender: Binding(
                                get: { viewModel.draft.selectedGender },
                                set: { viewModel.draft.selectedGender = $0 }
                            ))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of birth")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                DateComponent(
                                    date: Binding(
                                        get: { viewModel.draft.birthDate },
                                        set: { viewModel.draft.birthDate = $0 }
                                    ),
                                    range: PumpDateRange.birthdate
                                )
                                .surfaceCard(12)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                    Text("Minimum age is 13 years.")
                                    Spacer()
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }

                            ActivityLevelPicker(selectedLevel: Binding(
                                get: { viewModel.draft.activityLevel },
                                set: { viewModel.draft.activityLevel = $0 }
                            ))

                            // Explanation tappable hint
                            Button(action: { showActivityExplainer = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                    Text("Tap for Explanation")
                                    Spacer()
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        SectionCard(title: "Measurements") {
                            HeightFields(unitSystem: viewModel.draft.unitSystem,
                                         heightValue: Binding(
                                            get: { viewModel.draft.heightValue },
                                            set: { viewModel.draft.heightValue = $0 }
                                         ),
                                         heightFeet: Binding(
                                            get: { viewModel.draft.heightFeet },
                                            set: { viewModel.draft.heightFeet = $0 }
                                         ),
                                         heightInches: Binding(
                                            get: { viewModel.draft.heightInches },
                                            set: { viewModel.draft.heightInches = $0 }
                                         ))
                            
                            LabeledNumericField(
                                label: "Weight",
                                value: Binding(
                                    get: { viewModel.draft.weightValue },
                                    set: { viewModel.draft.weightValue = $0 }
                                ),
                                unitLabel: viewModel.draft.unitSystem.weightUnit
                            )
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Maintenance Calories")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    TextField("0", text: Binding(
                                        get: { viewModel.draft.maintenanceCalories },
                                        set: { viewModel.draft.maintenanceCalories = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)

                                    Text("cal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if let gender = viewModel.draft.selectedGender, gender == .male || gender == .female {
                                        Button {
                                            Task { await MainActor.run { viewModel.calculateMaintenanceCalories() } }
                                        } label: {
                                                Text("Auto")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                                                            .fill(currentAccent)
                                                    )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                                .surfaceCard(12)

                                // Explanation tappable hint
                                Button(action: { showMaintenanceExplainer = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle")
                                        Text("Tap for Explanation")
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        SectionCard(title: "Appearance") {
                            AppearanceSection(viewModel: viewModel)
                        }
                        
                        SectionCard(title: "Extras") {
                            ExtrasSection(
                                retakeAssessmentAction: { showOnboarding = true },
                                alertsAction: { showAlertsSheet = true }
                            )
                        }
                        
                        // Permissions
                        SectionCard(title: "Permissions") {
                            PermissionsSection(
                                notificationsAction: openNotificationSettings,
                                healthSyncAction: openHealthSyncSettings
                            )
                        }
                        
                        SectionCard(title: "Account") {
                            AccountSection(
                                manageSubscriptionAction: openSubscriptionPortal,
                                reportProblemAction: { showReportSheet = true },
                                signOutAction: { showSignOutConfirmation = true },
                                deleteAccountAction: { showDeleteConfirmation = true },
                                termsAction: openTerms,
                                privacyAction: openPrivacy
                            )

//                             Group {
//                                 if subscriptionManager.isInTrialPeriod {
//                                     Text("You're trialing Pro for \(subscriptionManager.trialDaysLeft) more days")
//                                         .font(.footnote)
//                                         .foregroundStyle(.secondary)
//                                 }
//                             }
//                             .frame(maxWidth: .infinity, alignment: .center)
//                             .padding(.top, 6)
//
//                             let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
//                             let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
//                             Text("App Version: \(shortVersion) (\(buildNumber))")
//                                 .font(.footnote)
//                                 .foregroundStyle(.secondary)
//                                 .frame(maxWidth: .infinity, alignment: .center)
//                                 .padding(.top, 2)

                            // #if DEBUG
                            // Toggle(isOn: Binding(get: {
                            //     subscriptionManager.isDebugForcingNoSubscription
                            // }, set: { newVal in
                            //     subscriptionManager.isDebugForcingNoSubscription = newVal
                            // })) {
                            //     VStack(alignment: .leading, spacing: 2) {
                            //         Text("Force No Subscription (Debug)")
                            //             .font(.subheadline).fontWeight(.semibold)
                            //         Text("Subscription time left: \(subscriptionTimeLeftText())")
                            //             .font(.caption)
                            //             .foregroundStyle(.secondary)
                            //     }
                            // }
                            // .toggleStyle(.switch)
                            // .padding(.top, 6)

                            // Button {
                            //     Task { await clearTrialTimerDebug() }
                            // } label: {
                            //     VStack(alignment: .leading, spacing: 2) {
                            //         Text("Clear Trial Timer (Debug)")
                            //             .font(.subheadline).fontWeight(.semibold)
                            //         Text("Trial time left: \(trialTimeLeftText())")
                            //             .font(.caption)
                            //             .foregroundStyle(.secondary)
                            //     }
                            //     .frame(maxWidth: .infinity, alignment: .leading)
                            // }
                            // .buttonStyle(.bordered)
                            // .tint(.orange)
                            // .disabled(isClearingTrialTimer)
                            // .padding(.top, 2)

                            // Button {
                            //     if #available(iOS 17.0, *) {
                            //         Task { @MainActor in
                            //             try? Tips.resetDatastore()
                            //             try? Tips.configure([
                            //                 .displayFrequency(.immediate),
                            //                 .datastoreLocation(.applicationDefault)
                            //             ])
                                        
                            //             NutritionTips.currentStep = 0
                            //             WorkoutTips.currentStep = 0
                            //             RoutineTips.currentStep = 0
                            //         }
                            //     }
                            // } label: {
                            //     VStack(alignment: .leading, spacing: 2) {
                            //         Text("Reset TipKit Memory (Debug)")
                            //             .font(.subheadline).fontWeight(.semibold)
                            //         Text("Reset all tips to appear again.")
                            //             .font(.caption)
                            //             .foregroundStyle(.secondary)
                            //     }
                            //     .frame(maxWidth: .infinity, alignment: .leading)
                            // }
                            // .buttonStyle(.bordered)
                            // .tint(.blue)
                            // #endif
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
                } // End if !isDeletingAccount and !isSigningOut

                if isDeletingAccount || isSigningOut {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .navigationBarBackButtonHidden(true)
            .tint(currentAccent)
            .accentColor(currentAccent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isDeletingAccount && !isSigningOut {
                        Button(action: handleBack) {
                            Label("Back", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isDeletingAccount && !isSigningOut {
                        Button("Save") {
                            Task {
                                if let error = viewModel.validationErrorMessage() {
                                    await MainActor.run {
                                        validationMessage = error
                                        showValidationAlert = true
                                    }
                                    return
                                }

                                // Update the view model's profile from draft
                                viewModel.saveChanges()

                                await MainActor.run {
                                    // Check if the image has changed to avoid unnecessary re-uploads
                                    let newImageData = viewModel.profile.avatarImageData
                                    let oldImageData = account.profileImage
                                    let oldAvatar = account.profileAvatar
                                    
                                    let imageChanged = newImageData != oldImageData
                                    
                                    account.profileImage = newImageData
                                    
                                    // Only overwrite profileAvatar if we have a NEW image (to trigger upload)
                                    // or if we have NO image (to revert to color).
                                    // If we have the SAME image and it has a URL, keep the URL.
                                    if imageChanged {
                                        // Image changed: set to color index to trigger upload in AccountFirestoreService
                                        account.profileAvatar = String(describing: viewModel.profile.avatarColor.rawValue)
                                    } else if newImageData == nil {
                                        // No image: set to color index
                                        account.profileAvatar = String(describing: viewModel.profile.avatarColor.rawValue)
                                    } else {
                                        // Image exists and hasn't changed.
                                        // If oldAvatar is a URL, keep it.
                                        // If oldAvatar is NOT a URL (e.g. "0"), keep it (it might trigger upload if logic allows, or just stay as is).
                                        // But if we want to ensure consistency with color selection if it changed:
                                        if let oldAvatar = oldAvatar, oldAvatar.hasPrefix("http") {
                                            // Keep URL
                                        } else {
                                            // Update color just in case
                                            account.profileAvatar = String(describing: viewModel.profile.avatarColor.rawValue)
                                        }
                                    }

                                    account.name = viewModel.profile.name
                                    account.gender = viewModel.profile.selectedGender?.rawValue
                                    account.dateOfBirth = viewModel.profile.birthDate
                                    account.height = Double(viewModel.profile.heightValue)
                                    account.weight = Double(viewModel.profile.weightValue)
                                    account.maintenanceCalories = Int(viewModel.profile.maintenanceCalories) ?? account.maintenanceCalories
                                    account.theme = viewModel.profile.appTheme.rawValue
                                    account.unitSystem = viewModel.profile.unitSystem.rawValue
                                    account.startWeekOn = viewModel.profile.weekStart.rawValue
                                    account.activityLevel = viewModel.profile.activityLevel.rawValue

                                    themeManager.setTheme(viewModel.profile.appTheme)
                                    
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("AccountsView: failed to save locally: \(error)")
                                    }
                                }

                                // Save to Firestore using the updated account
                                let (success, newAvatarURL) = await viewModel.saveAccountToFirestore(account)
                                if !success {
                                    print("Failed to save account to Firestore")
                                }
                                
                                // Save locally again to persist any URL updates from Firestore service
                                await MainActor.run {
                                    if let url = newAvatarURL {
                                        account.profileAvatar = url
                                    }
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("AccountsView: failed to save locally after Firestore sync: \(error)")
                                    }
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.hasChanges)
                    }
                }
            }
            .alert("Discard changes?", isPresented: $showDiscardAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    viewModel.discardChanges()
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Leaving now will discard them.")
            }
            .alert("Update Incomplete", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { showValidationAlert = false }
            } message: {
                Text(validationMessage)
            }
        }
        .alert("Sign out of Trackerio?", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                let container = modelContext.container
                let vm = viewModel

                // Trigger Main App Splash to cover the transition
                NotificationCenter.default.post(name: .showSplash, object: nil)
                
                // Orchestrate the exit sequence
                Task {
                    // 1. Wait for splash fade-in (usually 0.35s in RootView, give it margin)
                    try? await Task.sleep(nanoseconds: 500_000_000)

                    // 2. Dismiss this view (AccountsView) from the navigation stack
                    await MainActor.run {
                        dismiss()
                    }

                    // 3. Perform the actual data destruction and sign out in a detached task
                    // so it survives the view's deallocation.
                    Task.detached {
                        // Wait for dismissal animation to clear and RootView to be steady
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        
                        await vm.signOut(container: container)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
            .alert("Delete your Trackerio account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                withAnimation {
                    isDeletingAccount = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure?")
        }
        .task(id: isDeletingAccount) {
            if isDeletingAccount {
                // Allow splash screen fade-in animation to complete
                try? await Task.sleep(nanoseconds: 750_000_000)
                
                let result = await viewModel.deleteFirebaseAccount()
                
                // Safe to delete local data now (view content is unmounted)
                await viewModel.deleteLocalData(in: modelContext)

                if result.requiresRecentLogin && !result.authUserDeleted {
                    await viewModel.signOut(in: modelContext)
                }

                if !result.remoteAccountDeleted {
                    print("Warning: failed to delete remote account document; local data has been cleared.")
                }
                
                await MainActor.run {
                    dismiss()
                }
            }
        }
        .onAppear {
            syncFromAccount()
            viewModel.applyExternalTheme(themeManager.selectedTheme)
            // Ensure notifications state reflects saved preference
            if dailyTasksAlertsEnabled {
                NotificationsHelper.scheduleDailyTaskNotifications(account.dailyTasks)
            } else {
                NotificationsHelper.removeDailyTaskNotifications()
            }
            
            if !habitsAlertsEnabled {
                NotificationsHelper.removeHabitNotifications()
            }
            
            if !timeTrackingAlertsEnabled {
                NotificationsHelper.removeTimeTrackingNotification(id: "stopwatch")
                NotificationsHelper.removeTimeTrackingNotification(id: "timer")
            }
            
            if !dailyCheckInAlertsEnabled {
                NotificationsHelper.removeDailyCheckInNotifications()
            }

            if fastingAlertsEnabled {
                // Fasting scheduling happens from the fasting timer when active; nothing to schedule now.
            } else {
                NotificationsHelper.removeFastingNotifications()
            }
            if mealsAlertsEnabled {
                NotificationsHelper.scheduleMealNotifications(account.mealReminders)
            } else {
                NotificationsHelper.removeMealNotifications()
            }
            if !weeklyProgressAlertsEnabled {
                NotificationsHelper.removeWeeklyProgressNotifications()
            }
        }
        .onChange(of: dailyTasksAlertsEnabled) { _, newValue in
            if newValue {
                NotificationsHelper.scheduleDailyTaskNotifications(account.dailyTasks)
            } else {
                NotificationsHelper.removeDailyTaskNotifications()
            }
        }
        .onChange(of: habitsAlertsEnabled) { _, newValue in
            if newValue {
                // Habits scheduling requires completion status which isn't readily available here.
                // It will be handled by RoutineTabView's onAppear/refreshNotifications.
                // However, we can schedule a baseline notification with all habits if needed,
                // but it's safer to let RoutineTabView handle it to be accurate.
                // For now, we'll just remove if disabled.
            } else {
                NotificationsHelper.removeHabitNotifications()
            }
        }
        .onChange(of: timeTrackingAlertsEnabled) { _, newValue in
            if !newValue {
                NotificationsHelper.removeTimeTrackingNotification(id: "stopwatch")
                NotificationsHelper.removeTimeTrackingNotification(id: "timer")
            }
        }
        .onChange(of: dailyCheckInAlertsEnabled) { _, newValue in
            if !newValue {
                NotificationsHelper.removeDailyCheckInNotifications()
            }
        }
        .onChange(of: fastingAlertsEnabled) { _, newValue in
            if newValue {
                // Fasting notifications are scheduled by the fasting timer when active; nothing to do here.
            } else {
                NotificationsHelper.removeFastingNotifications()
            }
        }
        .onChange(of: mealsAlertsEnabled) { _, newValue in
            if newValue {
                NotificationsHelper.scheduleMealNotifications(account.mealReminders)
            } else {
                NotificationsHelper.removeMealNotifications()
            }
        }
        .onChange(of: weeklyProgressAlertsEnabled) { _, newValue in
            if newValue {
                // Weekly reminder scheduling happens from WorkoutTabView when entries exist; nothing to schedule here.
            } else {
                NotificationsHelper.removeWeeklyProgressNotifications()
            }
        }
        .onChange(of: themeManager.selectedTheme) { _, newTheme in
            viewModel.applyExternalTheme(newTheme)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoPickerItem, matching: .images)
        .sheet(isPresented: $showCameraPicker) {
            ImagePickerComponent(sourceType: .camera) { data in
                if let data {
                    viewModel.setAvatarImageData(data)
                }
                showCameraPicker = false
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportProblemSheet(
                initialName: viewModel.draft.name,
                initialEmail: Auth.auth().currentUser?.email ?? "",
                accentColor: currentAccent
            )
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have a camera available.")
        }
        .alert("Apple Health", isPresented: $showHealthKitStatusAlert) {
            Button("OK", role: .cancel) { showHealthKitStatusAlert = false }
        } message: {
            Text(healthKitStatusMessage)
        }
        .onChange(of: selectedPhotoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.setAvatarImageData(data)
                    }
                }
                await MainActor.run {
                    selectedPhotoPickerItem = nil
                }
            }
        }
        .sheet(isPresented: $showMaintenanceExplainer) {
            MaintenanceCaloriesExplainer()
        }
        .sheet(isPresented: $showActivityExplainer) {
            ActivityLevelExplainer()
        }
        .sheet(isPresented: $showAlertsSheet) {
            AlertSheetView(
                workoutSchedule: account.workoutSchedule,
                itineraryEvents: account.itineraryEvents,
                nutritionSupplements: account.nutritionSupplements,
                workoutSupplements: account.workoutSupplements,
                dailyTasks: account.dailyTasks,
                habits: account.habits,
                mealReminders: account.mealReminders,
                autoRestIndices: account.autoRestDayIndices
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            // When reassessment completes, pop back to the main tab instead of returning here.
            OnboardingView(initialName: account.name, existingAccount: account, isRetake: true) {
                showOnboarding = false
                dismiss()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    struct AlertSheetView: View {
        var workoutSchedule: [WorkoutScheduleItem]
        var itineraryEvents: [ItineraryEvent]
        var nutritionSupplements: [Supplement]
        var workoutSupplements: [Supplement]
        var dailyTasks: [DailyTaskDefinition]
        var habits: [HabitDefinition]
        var mealReminders: [MealReminder]
        var autoRestIndices: [Int]
        let pillColumns = [GridItem(.adaptive(minimum: 120), spacing: 12)]
        @Environment(\.dismiss) private var dismiss
        @AppStorage("alerts.dailyTasksEnabled") private var dailyTasksAlertsEnabled: Bool = true
        @AppStorage("alerts.dailyTasksSilenceCompleted") private var silenceCompletedTasks: Bool = true
        @AppStorage("alerts.habitsEnabled") private var habitsAlertsEnabled: Bool = true
        @AppStorage("alerts.timeTrackingEnabled") private var timeTrackingAlertsEnabled: Bool = true
        @AppStorage("alerts.dailyCheckInEnabled") private var dailyCheckInAlertsEnabled: Bool = true
        @AppStorage("alerts.activityTimersEnabled") private var activityTimersAlertsEnabled: Bool = true
        @AppStorage("alerts.fastingEnabled") private var fastingAlertsEnabled: Bool = true
        @AppStorage("alerts.mealsEnabled") private var mealsAlertsEnabled: Bool = true
        @AppStorage("alerts.weeklyProgressEnabled") private var weeklyProgressAlertsEnabled: Bool = true
        @AppStorage("alerts.weeklyScheduleEnabled") private var weeklyScheduleAlertsEnabled: Bool = true
        @AppStorage("alerts.itineraryEnabled") private var itineraryAlertsEnabled: Bool = true
        @AppStorage("alerts.nutritionSupplementsEnabled") private var nutritionSupplementsAlertsEnabled: Bool = true
        @AppStorage("alerts.workoutSupplementsEnabled") private var workoutSupplementsAlertsEnabled: Bool = true
        
        @AppStorage("alerts.habitsTime") private var habitsTime: Double = 9 * 3600
        @AppStorage("alerts.dailyCheckInTime") private var dailyCheckInTime: Double = 18 * 3600
        @AppStorage("alerts.weeklyProgressTime") private var weeklyProgressTime: Double = 9 * 3600
        @AppStorage("alerts.nutritionSupplementsTime") private var nutritionSupplementsTime: Double = 9 * 3600
        @AppStorage("alerts.workoutSupplementsTime") private var workoutSupplementsTime: Double = 16 * 3600
        @AppStorage("alerts.weeklyProgressDay") private var weeklyProgressDay: Int = 2
        @EnvironmentObject private var themeManager: ThemeManager
        @Environment(\.colorScheme) private var colorScheme

        var currentAccent: Color {
            if themeManager.selectedTheme == .multiColour {
                return .accentColor
            }
            return themeManager.selectedTheme.accent(for: colorScheme)
        }

        private func dayLabel(for weekday: Int) -> String {
            switch weekday {
            case 1: return "S"
            case 2: return "M"
            case 3: return "T"
            case 4: return "W"
            case 5: return "T"
            case 6: return "F"
            case 7: return "S"
            default: return ""
            }
        }

        private func binding(for time: Binding<Double>) -> Binding<Date> {
            Binding(
                get: {
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: Date())
                    return startOfDay.addingTimeInterval(time.wrappedValue)
                },
                set: { newDate in
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: newDate)
                    let seconds = (Double(components.hour ?? 0) * 3600) + (Double(components.minute ?? 0) * 60)
                    time.wrappedValue = seconds
                }
            )
        }

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which types of alerts you would like to receive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Nutrition
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nutrition")
                                    .font(.title2.weight(.bold))
                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Supplements")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Get a reminder to take your daily supplements.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if nutritionSupplementsAlertsEnabled {
                                        DatePicker("", selection: binding(for: $nutritionSupplementsTime), displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    Toggle("", isOn: $nutritionSupplementsAlertsEnabled)
                                        .labelsHidden()
                                }

                                Toggle(isOn: $mealsAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Meal Reminders")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive reminders to log meals at scheduled times.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                Toggle(isOn: $fastingAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Intermittent Fasting")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive a notification when your fasting window ends.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)
                            }

                            // Routine
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Routine")
                                    .font(.title2.weight(.bold))
                                Divider()

                                Toggle(isOn: $dailyTasksAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Tasks")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive local reminders for tasks in your Daily Tasks list.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                Toggle(isOn: $activityTimersAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Activity Timers")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive a notification when an activity timer finishes.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Habits")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive a daily reminder with your remaining habits.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if habitsAlertsEnabled {
                                        DatePicker("", selection: binding(for: $habitsTime), displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    Toggle("", isOn: $habitsAlertsEnabled)
                                        .labelsHidden()
                                }
                            }

                            // Workout
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Workout")
                                    .font(.title2.weight(.bold))
                                Divider()

                                Toggle(isOn: $weeklyScheduleAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Weekly Schedule")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive reminders for your scheduled workouts.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Workout Supplements")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Get a reminder to take your workout supplements.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if workoutSupplementsAlertsEnabled {
                                        DatePicker("", selection: binding(for: $workoutSupplementsTime), displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    Toggle("", isOn: $workoutSupplementsAlertsEnabled)
                                        .labelsHidden()
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Check-In")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive a reminder to check in on your workout days.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if dailyCheckInAlertsEnabled {
                                        DatePicker("", selection: binding(for: $dailyCheckInTime), displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    Toggle("", isOn: $dailyCheckInAlertsEnabled)
                                        .labelsHidden()
                                }

                                VStack {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Weekly Progress")
                                                .font(.subheadline.weight(.semibold))
                                            Text("Receive a weekly reminder to capture your progress photo.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if weeklyProgressAlertsEnabled {
                                            DatePicker("", selection: binding(for: $weeklyProgressTime), displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                        }
                                        Toggle("", isOn: $weeklyProgressAlertsEnabled)
                                            .labelsHidden()
                                    }

                                    if weeklyProgressAlertsEnabled {
                                        HStack(spacing: 8) {
                                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                                let isSelected = weeklyProgressDay == day
                                                Button {
                                                    weeklyProgressDay = day
                                                } label: {
                                                    Text(dayLabel(for: day))
                                                        .font(.caption.weight(.semibold))
                                                        .frame(width: 32, height: 32)
                                                        .background(isSelected ? currentAccent : Color.secondary.opacity(0.1))
                                                        .foregroundColor(isSelected ? .white : .primary)
                                                        .clipShape(Circle())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }

                            // Itinerary
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Itinerary")
                                    .font(.title2.weight(.bold))
                                Divider()

                                Toggle(isOn: $itineraryAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Itinerary Events")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Receive reminders for your upcoming activities.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if mealsAlertsEnabled {
                                NotificationsHelper.scheduleMealNotifications(mealReminders)
                            } else {
                                NotificationsHelper.removeMealNotifications()
                            }

                            if dailyTasksAlertsEnabled {
                                NotificationsHelper.scheduleDailyTaskNotifications(dailyTasks)
                            } else {
                                NotificationsHelper.removeDailyTaskNotifications()
                            }

                            if habitsAlertsEnabled {
                                NotificationsHelper.scheduleHabitNotifications(habits)
                            } else {
                                NotificationsHelper.removeHabitNotifications()
                            }

                            if dailyCheckInAlertsEnabled {
                                NotificationsHelper.scheduleDailyCheckInNotifications(autoRestIndices: Set(autoRestIndices), completedIndices: [])
                            } else {
                                NotificationsHelper.removeDailyCheckInNotifications()
                            }

                            if weeklyProgressAlertsEnabled {
                                NotificationsHelper.scheduleWeeklyProgressNotifications(time: weeklyProgressTime, weekday: weeklyProgressDay)
                            } else {
                                NotificationsHelper.removeWeeklyProgressNotifications()
                            }

                            if weeklyScheduleAlertsEnabled {
                                NotificationsHelper.scheduleWeeklyScheduleNotifications(workoutSchedule)
                            } else {
                                NotificationsHelper.removeWeeklyScheduleNotifications()
                            }
                            
                            if itineraryAlertsEnabled {
                                NotificationsHelper.scheduleItineraryNotifications(itineraryEvents)
                            } else {
                                NotificationsHelper.removeItineraryNotifications()
                            }

                            if nutritionSupplementsAlertsEnabled {
                                NotificationsHelper.scheduleNutritionSupplementNotifications(nutritionSupplements, time: nutritionSupplementsTime)
                            } else {
                                NotificationsHelper.removeNutritionSupplementNotifications()
                            }

                            if workoutSupplementsAlertsEnabled {
                                NotificationsHelper.scheduleWorkoutSupplementNotifications(workoutSupplements, time: workoutSupplementsTime)
                            } else {
                                NotificationsHelper.removeWorkoutSupplementNotifications()
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .navigationTitle("Alert Preferences")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func handleBack() {
        if viewModel.hasChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func openSubscriptionPortal() {
        // TODO: Route user to billing portal when backend is available
    }

    private func openNotificationSettings() {
        // Request notification permissions if not already granted, else open app settings
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    // Optionally handle result
                }
            case .denied, .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            @unknown default:
                break
            }
        }
    }

    private func openHealthSyncSettings() {
        let healthStore = HKHealthStore()
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        let typesToRead: Set<HKSampleType> = [stepType, distanceType]

        func showStatus(_ message: String) {
            healthKitStatusMessage = message
            showHealthKitStatusAlert = true
        }

        let stepStatus = healthStore.authorizationStatus(for: stepType)
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)

        if stepStatus != .notDetermined && distanceStatus != .notDetermined {
            showStatus("To modify permissions, please update them in the Health app settings.")
            return
        }

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    showStatus("HealthKit access granted!")
                } else {
                    showStatus("HealthKit access failed or was denied.")
                }
            }
        }
    }

    private func openTerms() {
        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacy() {
        if let url = URL(string: "https://ambreon.com/trackerio-privacy") {
            UIApplication.shared.open(url)
        }
    }

    private func presentCameraPicker() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            showCameraUnavailableAlert = true
        }
    }
}

private struct ReportProblemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var email: String
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submissionError: String? = nil
    @State private var showSuccessAlert: Bool = false
    @FocusState private var focusedField: ReportField?
    var accentColor: Color

    init(initialName: String, initialEmail: String, accentColor: Color) {
        _name = State(initialValue: initialName)
        _email = State(initialValue: initialEmail)
        self.accentColor = accentColor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tell us what went wrong so we can help.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                TextField("", text: $name, prompt: Text("Enter your name").foregroundColor(.primary.opacity(0.7)))
                                    .textInputAutocapitalization(.words)
                                    .focused($focusedField, equals: .name)
                                    .padding()
                                    .background(Color.gray.opacity(0.12))
                                    .cornerRadius(10)
                                    .surfaceCard(10)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                TextField("", text: $email, prompt: Text("Enter your email").foregroundColor(.primary.opacity(0.7)))
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                                    .padding()
                                    .background(Color.gray.opacity(0.12))
                                    .cornerRadius(10)
                                    .surfaceCard(10)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $message)
                                        .frame(minHeight: 120)
                                        .scrollContentBackground(.hidden)
                                        .focused($focusedField, equals: .message)
                                        .padding(10)
                                        .background(Color.gray.opacity(0.12))
                                        .cornerRadius(10)
                                        .surfaceCard(10)
                                    if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Describe the issue")
                                            .foregroundStyle(.primary.opacity(0.6))
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        Button(action: submitReport) {
                            Label(isSubmitting ? "Submitting..." : "Submit", systemImage: "paperplane.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(accentColor.opacity(0.9))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isSubmitting || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let submissionError {
                            Text(submissionError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 24)
            }
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(action: dismissKeyboard) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                            .foregroundStyle(.primary)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .alert("Report submitted", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thanks for letting us know. We'll review it shortly.")
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func submitReport() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty, !trimmedMessage.isEmpty else { return }

        submissionError = nil
        isSubmitting = true

        var data: [String: Any] = [
            "name": trimmedName,
            "email": trimmedEmail.lowercased(),
            "message": trimmedMessage,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let uid = Auth.auth().currentUser?.uid {
            data["userId"] = uid
        }

        Firestore.firestore().collection("reports").addDocument(data: data) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error {
                    submissionError = "Failed to submit. Please try again."
                    print("ReportProblemSheet: failed to submit report: \(error)")
                } else {
                    showSuccessAlert = true
                    name = ""
                    email = ""
                    message = ""
                }
            }
        }
    }
}

private enum ReportField: Hashable {
    case name, email, message
}

private struct SectionCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title)
            VStack(spacing: 16, content: content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 20.0))
    }
}

private extension AccountsView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .other)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    var currentAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return .accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    func subscriptionTimeLeftText(now: Date = Date()) -> String {
        if let expiry = subscriptionManager.latestSubscriptionExpiration {
            return countdownString(now: now, until: expiry)
        }

        if subscriptionManager.purchasedProductIDs.isEmpty {
            return "No active subscription"
        }

        return "No expiration date"
    }

    func trialTimeLeftText(now: Date = Date()) -> String {
        guard let end = subscriptionManager.trialEndDate else {
            return "No active trial"
        }

        if end > now {
            return countdownString(now: now, until: end)
        }

        return "Expired"
    }

    func countdownString(now: Date = Date(), until end: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }

    @MainActor
    func clearTrialTimerDebug() async {
        guard !isClearingTrialTimer else { return }
        isClearingTrialTimer = true
        defer { isClearingTrialTimer = false }

        subscriptionManager.resetTrialState()

        // Set trialPeriodEnd to a distant past date so the backend sees the trial as expired
        // instead of missing (which would recreate a trial on next fetch).
        let expiredDate = Date(timeIntervalSince1970: 0)
        account.trialPeriodEnd = expiredDate

        do {
            try modelContext.save()
        } catch {
            print("AccountsView: failed to persist cleared trial locally: \(error)")
        }

        await clearRemoteTrialPeriodEnd()
    }

    @MainActor
    private func clearRemoteTrialPeriodEnd() async {
        let service = AccountFirestoreService()
        guard let id = (Auth.auth().currentUser?.uid ?? account.id) else { return }

        await withCheckedContinuation { continuation in
            service.updateTrialPeriodEnd(for: id, date: account.trialPeriodEnd) { success in
                if !success {
                    print("AccountsView: failed to update trialPeriodEnd in Firestore for id \(id)")
                }
                continuation.resume()
            }
        }
    }
}

// Shared action row for account actions
@ViewBuilder
private func accountActionRow(
    title: String,
    icon: String,
    role: ButtonRole?,
    foregroundColor: Color = .primary,
    action: @escaping () -> Void
) -> some View {
    Button(role: role, action: action) {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(foregroundColor)
    }
}

private struct AccountSection: View {
    var manageSubscriptionAction: () -> Void
    var reportProblemAction: () -> Void
    var signOutAction: () -> Void
    var deleteAccountAction: () -> Void
    var termsAction: () -> Void
    var privacyAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            accountActionRow(
                title: "Terms of Use (EULA)",
                icon: "doc.text",
                role: nil,
                action: termsAction
            )

            accountActionRow(
                title: "Privacy Policy",
                icon: "doc.text",
                role: nil,
                action: privacyAction
            )

            accountActionRow(
                title: "Report a Problem",
                icon: "exclamationmark.bubble",
                role: nil,
                action: reportProblemAction
            )

            accountActionRow(
                title: "Sign Out",
                icon: "arrow.right.square",
                role: nil,
                action: signOutAction
            )

            accountActionRow(
                title: "Delete Account",
                icon: "trash",
                role: .destructive,
                foregroundColor: .red,
                action: deleteAccountAction
            )
        }
    }

    @ViewBuilder
    private func accountActionRow(
        title: String,
        icon: String,
        role: ButtonRole?,
        foregroundColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.5)
            }
            .foregroundStyle(role == .destructive ? Color.red : foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .surfaceCard(16)
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionsSection: View {
    var notificationsAction: () -> Void
    var healthSyncAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            accountActionRow(
                title: "Notifications",
                icon: "bell.badge",
                role: nil,
                action: notificationsAction
            )

            accountActionRow(
                title: "Apple Health",
                icon: "heart",
                role: nil,
                action: healthSyncAction
            )
        }
    }

    // Shared action row for account actions (copied from ExtrasSection for consistency)
    @ViewBuilder
    private func accountActionRow(
        title: String,
        icon: String,
        role: ButtonRole?,
        foregroundColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.5)
            }
            .foregroundStyle(role == .destructive ? Color.red : foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .surfaceCard(16)
        }
        .buttonStyle(.plain)
    }
}

private struct ExtrasSection: View {
    var retakeAssessmentAction: () -> Void
    var alertsAction: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            accountActionRow(
                title: "Retake Assessment",
                icon: "arrow.clockwise.circle",
                role: nil,
                action: retakeAssessmentAction
            )

            accountActionRow(
                title: "Alerts",
                icon: "bell.circle",
                role: nil,
                action: alertsAction
            )
        }
    }

    // Shared action row for account actions
    @ViewBuilder
    private func accountActionRow(
        title: String,
        icon: String,
        role: ButtonRole?,
        foregroundColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.5)
            }
            .foregroundStyle(role == .destructive ? Color.red : foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .surfaceCard(16)
        }
        .buttonStyle(.plain)
    }
}

private struct ProStatusView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    var trialEndDate: Date?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if subscriptionManager.isDebugForcingNoSubscription {
                statusRow(title: "Debug Override", detail: "Force free mode enabled")
            }

            if subscriptionManager.isTrialActive, let end = trialEndDate ?? subscriptionManager.trialEndDate {
                statusRow(title: "Trial Active", detail: countdownString(until: end))
                statusRow(title: "Ends", detail: formatted(date: end))
            } else if let end = trialEndDate, end > now {
                statusRow(title: "Trial Restored", detail: countdownString(until: end))
                statusRow(title: "Ends", detail: formatted(date: end))
            }

            if !subscriptionManager.purchasedProductIDs.isEmpty {
                if let expiry = subscriptionManager.latestSubscriptionExpiration {
                    statusRow(title: "Subscription", detail: "Active • renews " + formatted(date: expiry))
                } else {
                    statusRow(title: "Subscription", detail: "Active")
                }
            } else if !(subscriptionManager.isTrialActive || (trialEndDate ?? Date.distantPast) > now) {
                statusRow(title: "Free Tier", detail: "No active trial or subscription")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusRow(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private func countdownString(until end: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


private struct IdentitySection: View {
    @ObservedObject var viewModel: AccountsViewModel
    var selectLibraryAction: () -> Void
    var selectCameraAction: () -> Void
    var clearImageAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Circle()
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                    .frame(width: 96, height: 96)
                    .overlay {
                        if let avatarImage = viewModel.avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            Text(viewModel.avatarInitials)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }

                HStack(spacing: 12) {
                    if viewModel.hasUploadedAvatar {
                        uploadMenuButton(title: "Update")

                        Button(action: clearImageAction) {
                            actionLabel(text: "Clear", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .tint(.red)
                    } else {
                        uploadMenuButton(title: "Upload")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func uploadMenuButton(title: String) -> some View {
        Menu {
            Button(action: selectLibraryAction) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            .tint(.primary)
            Button(action: selectCameraAction) {
                Label("Take Photo", systemImage: "camera")
            }
            .tint(.primary)
        } label: {
            actionLabel(text: title, systemImage: "square.and.arrow.up")
        }
        .menuStyle(.automatic)
        .tint(.primary)
    }

    private func actionLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        )
        .foregroundStyle(.primary)
    }
}

private struct GenderSelector: View {
    @Binding var selectedGender: GenderOption?
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gender")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(GenderOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: selectedGender == option
                    ) {
                        selectedGender = option
                    }
                }
            }
            if selectedGender == .preferNotSay {
                Text("Automatic maintenance calorie calculations are disabled unless you select Male or Female.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ActivityLevelPicker: View {
    @Binding var selectedLevel: ActivityLevelOption
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Level")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(ActivityLevelOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: selectedLevel == option
                    ) {
                        selectedLevel = option
                    }
                }
            }
        }
    }
}

private struct UnitToggleView: View {
    var unitSystem: UnitSystem
    var onChange: (UnitSystem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(UnitSystem.allCases, id: \.self) { system in
                Button(action: { onChange(system) }) {
                    Text(system.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .surfaceCard(
                            12,
                            fill: system == unitSystem ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(system == unitSystem ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                        .foregroundColor(system == unitSystem ? Color.accentColor : Color.primary)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct HeightFields: View {
    var unitSystem: UnitSystem
    @Binding var heightValue: String
    @Binding var heightFeet: String
    @Binding var heightInches: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Height")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if unitSystem == .imperial {
                HStack(spacing: 12) {
                    LabeledField(value: $heightFeet, unit: "ft")
                    LabeledField(value: $heightInches, unit: "in")
                }
            } else {
                LabeledNumericField(
                    label: nil,
                    value: $heightValue,
                    unitLabel: unitSystem.heightUnit
                )
            }
        }
    }

    private struct LabeledField: View {
        @Binding var value: String
        var unit: String

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TextField("0", text: $value)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .surfaceCard(12)
            }
        }
    }
}

private struct WorkoutsPerWeekSelector: View {
    var selectedDays: Set<Weekday>
    var toggleAction: (Weekday) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Workout days each week")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 10)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Weekday.allCases) { day in
                    let isSelected = selectedDays.contains(day)
                    Button(action: { toggleAction(day) }) {
                        Text(day.shortLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                            .frame(width: 40, height: 40)
                            .surfaceCard(
                                20,
                                fill: isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.accentColor : PumpPalette.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AppearanceSection: View {
    @ObservedObject var viewModel: AccountsViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Theme")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, -15)
            HStack(alignment: .center, spacing: 16) {
                themePreview(for: viewModel.draft.appTheme)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    ForEach(AppTheme.allCases) { theme in
                        Button(theme.displayName) {
                            viewModel.setTheme(theme)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(viewModel.draft.appTheme.displayName)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(PumpPalette.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .surfaceCard(18)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Unit System")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
      
                UnitToggleView(unitSystem: viewModel.draft.unitSystem) { newSystem in
                    viewModel.updateUnitSystem(to: newSystem)
                }
            }

            // Week starts on setting removed
        }
    }

    private func themePreview(for theme: AppTheme) -> some View {
        HStack {
            ThickThemePreviewRow(theme: theme, colorScheme: colorScheme)
            Spacer()
        }
    }

    // Local thick rectangle theme preview for AccountsView
    private struct ThickThemePreviewRow: View {
        var theme: AppTheme
        var colorScheme: ColorScheme

        private var isMultiColour: Bool { theme == .multiColour }

        private var nutritionColors: [Color] {
            [
                Color.purple.opacity(0.18),
                Color.blue.opacity(0.14),
                Color.indigo.opacity(0.18)
            ]
        }

        private var subtleRainbowGradient: LinearGradient {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.99, green: 0.45, blue: 0.45).opacity(0.8),
                    Color(red: 1.00, green: 0.72, blue: 0.32).opacity(0.8),
                    Color(red: 0.42, green: 0.85, blue: 0.55).opacity(0.8),
                    Color(red: 0.36, green: 0.70, blue: 0.99).opacity(0.8),
                    Color(red: 0.63, green: 0.48, blue: 0.96).opacity(0.8)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        private var swatchBackground: LinearGradient {
            if isMultiColour {
                LinearGradient(
                    gradient: Gradient(colors: nutritionColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                theme.previewBackground(for: colorScheme)
            }
        }

        var body: some View {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(swatchBackground)
                    .overlay {
                        if isMultiColour {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(subtleRainbowGradient, lineWidth: 2.5)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.accent(for: colorScheme), lineWidth: 2.5)
                        }
                    }
                    .frame(width: 64, height: 40)
                    .overlay {
                        if isMultiColour {
                            Circle()
                                .fill(subtleRainbowGradient)
                                .frame(width: 8, height: 8)
                        } else {
                            Circle()
                                .fill(theme.accent(for: colorScheme))
                                .frame(width: 8, height: 8)
                        }
                    }
            }
        }
    }
}

struct AccountDeletionResult {
    let remoteAccountDeleted: Bool
    let authUserDeleted: Bool
    let requiresRecentLogin: Bool
}

final class AccountsViewModel: ObservableObject {
    private static let weekStartDefaultsKey = "weekStartPreference"
    private static let defaultWeekStart: WeekStartOption = .monday

    @Published private(set) var profile: AccountProfile
    @Published var requiresRecentLoginEncountered = false
    @Published var draft: AccountProfile {
        didSet {
            // Detect manual edits to maintenance field
            if oldValue.maintenanceCalories != draft.maintenanceCalories {
                if draft.maintenanceCalories == lastAutoComputedMaintenance {
                    maintenanceManuallyEdited = false
                } else {
                    maintenanceManuallyEdited = true
                }
            }
        }
    }

    private var lastAutoComputedMaintenance: String? = nil
    private var maintenanceManuallyEdited: Bool = false
    @Published var isPerformingDestructiveAction = false

    private let defaults: UserDefaults
    private var defaultsObserver: AnyCancellable?
    private let firestoreService = AccountFirestoreService()

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        defaults.register(defaults: [
            Self.weekStartDefaultsKey: Self.defaultWeekStart.rawValue
        ])

        let storedTheme = defaults.string(forKey: ThemeManager.defaultsKey)
        let initialTheme = AppTheme(rawValue: storedTheme ?? "") ?? .multiColour
        let storedWeekStartRaw = defaults.string(forKey: Self.weekStartDefaultsKey)
        let initialWeekStart = WeekStartOption(rawValue: storedWeekStartRaw ?? "") ?? Self.defaultWeekStart
        let initialProfile = AccountProfile(
            name: "Dafa Budiman",
            avatarColor: .emberPulse,
            avatarImageData: nil,
            avatarImageSignature: AccountProfile.signature(for: nil),
            appTheme: initialTheme,
            weekStart: initialWeekStart,
            birthDate: Calendar.current.date(from: DateComponents(year: 1994, month: 8, day: 14)) ?? Date(),
            selectedGender: .male,
            unitSystem: .metric,
            heightValue: "172",
            heightFeet: "5",
            heightInches: "7.7",
            weightValue: "67",
            maintenanceCalories: "",
            activityLevel: ActivityLevelOption.moderatelyActive
        )
        self.profile = initialProfile
        self.draft = initialProfile

        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncWeekStartFromDefaults()
            }
    }

    deinit {
        defaultsObserver?.cancel()
    }

    private func clearUserDefaultsState() {
        if let bundle = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundle)
        }

        let keysToRemove = [
            ThemeManager.defaultsKey,
            Self.weekStartDefaultsKey,
            "currentUserName",
            "fasting.durationMinutes",
            "fasting.startTimestamp",
            "alerts.dailyTasksEnabled",
            "alerts.dailyTasksSilenceCompleted",
            "alerts.habitsEnabled",
            "alerts.timeTrackingEnabled",
            "alerts.dailyCheckInEnabled",
            "alerts.activityTimersEnabled",
            "alerts.fastingEnabled",
            "alerts.mealsEnabled",
            "alerts.weeklyProgressEnabled"
        ]

        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }

    var hasUploadedAvatar: Bool {
        draft.avatarImageData != nil
    }

    var avatarInitials: String {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").filter { !$0.isEmpty }
        let initials = parts.prefix(2).map { $0.prefix(1).uppercased() }.joined()
        return initials.isEmpty ? "PF" : initials
    }

    var avatarImage: Image? {
        guard let data = draft.avatarImageData,
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var avatarGradient: LinearGradient {
        draft.avatarColor.gradient
    }

    var hasChanges: Bool {
        draft != profile
    }

    func saveChanges() {
        profile = draft
        persistWeekStartPreference(draft.weekStart)
        // Use Firebase Auth UID as the Firestore document ID
        guard let user = Auth.auth().currentUser else {
            print("No authenticated user; cannot save account to Firestore.")
            return
        }
        let uid = user.uid
        // Build an Account object for callers that may want to persist to Firestore.
            _ = Account(
            id: uid,
            profileImage: draft.avatarImageData,
            profileAvatar: String(describing: draft.avatarColor.rawValue),
            name: draft.name,
            gender: draft.selectedGender?.rawValue,
            dateOfBirth: draft.birthDate,
            height: Double(draft.heightValue),
            weight: Double(draft.weightValue),
            maintenanceCalories: Int(draft.maintenanceCalories) ?? 0,
            theme: draft.appTheme.rawValue,
            unitSystem: draft.unitSystem.rawValue,
            activityLevel: draft.activityLevel.rawValue,
            startWeekOn: draft.weekStart.rawValue
        )
    }

    // Async wrapper so callers can await Firestore save
    func saveAccountToFirestore(_ account: Account) async -> (Bool, String?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, String?), Never>) in
            firestoreService.saveAccount(account) { success, url in
                continuation.resume(returning: (success, url))
            }
        }
    }

    /// Build an `Account` object for Firestore using the authenticated user's UID
    func buildFirestoreAccount() -> Account? {
        guard let user = Auth.auth().currentUser else { return nil }
        let uid = user.uid
        let account = Account(
            id: uid,
            profileImage: draft.avatarImageData,
            profileAvatar: String(describing: draft.avatarColor.rawValue),
            name: draft.name,
            gender: draft.selectedGender?.rawValue,
            dateOfBirth: draft.birthDate,
            height: Double(draft.heightValue),
            weight: Double(draft.weightValue),
            maintenanceCalories: Int(draft.maintenanceCalories) ?? 0,
            theme: draft.appTheme.rawValue,
            unitSystem: draft.unitSystem.rawValue,
            activityLevel: draft.activityLevel.rawValue,
            startWeekOn: draft.weekStart.rawValue
        )
        return account
    }

    func fetchAccountFromFirestore(id: String, completion: @escaping (Account?) -> Void) {
        firestoreService.fetchAccount(withId: id) { account in
            completion(account)
        }
    }

    func validationErrorMessage() -> String? {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Preferred name cannot be empty."
        }

        if !isBirthDateWithinSupportedRange(draft.birthDate) {
            return "Date of birth must produce an age between 0 and 120 years."
        }

        if draft.selectedGender == nil {
            return "Please select your gender."
        }

        guard let heightCm = heightInCentimeters() else {
            return "Please enter your height using numbers only."
        }
        if !(30...300).contains(heightCm) {
            return "Height must be between 30 cm and 300 cm."
        }

        guard let weightKg = weightInKilograms() else {
            return "Please enter your weight using numbers only."
        }
        if !(20...1000).contains(weightKg) {
            return "Weight must be between 20 kg and 1000 kg."
        }

        return nil
    }

    func discardChanges() {
        draft = profile
    }

    func updateUnitSystem(to newSystem: UnitSystem) {
        guard newSystem != draft.unitSystem else { return }
        if newSystem == .imperial {
            if let cm = Double(draft.heightValue), cm > 0 {
                let totalInches = cm / 2.54
                let feet = Int(totalInches / 12)
                let inches = totalInches - Double(feet * 12)
                draft.heightFeet = String(feet)
                draft.heightInches = String(format: "%.1f", inches)
            } else {
                draft.heightFeet = ""
                draft.heightInches = ""
            }
            if let kg = Double(draft.weightValue) {
                draft.weightValue = UnitConverter.convertWeight(kg, from: .metric, to: .imperial)
            } else {
                draft.weightValue = ""
            }
        } else {
            if let feet = Double(draft.heightFeet), let inches = Double(draft.heightInches) {
                let totalInches = (feet * 12) + inches
                let cm = totalInches * 2.54
                draft.heightValue = String(format: "%.0f", cm)
            } else {
                draft.heightValue = ""
            }
            if let lbs = Double(draft.weightValue) {
                draft.weightValue = UnitConverter.convertWeight(lbs, from: .imperial, to: .metric)
            } else {
                draft.weightValue = ""
            }
        }
        draft.unitSystem = newSystem
    }

    func shuffleAvatarColor() {
        guard let option = AvatarColorOption.allCases.randomElement() else { return }
        draft.avatarColor = option
    }

    func setAvatarColor(_ option: AvatarColorOption) {
        draft.avatarColor = option
    }

    func setTheme(_ theme: AppTheme) {
        draft.appTheme = theme
    }

    func setWeekStart(_ option: WeekStartOption) {
        draft.weekStart = option
    }

    func setAvatarImageData(_ data: Data?) {
        draft.avatarImageData = data
        draft.avatarImageSignature = AccountProfile.signature(for: data)
    }

    func setBaselineFromDraft() {
        profile = draft
    }

    func applyExternalTheme(_ theme: AppTheme) {
        profile.appTheme = theme
        draft.appTheme = theme
    }

    private func persistWeekStartPreference(_ option: WeekStartOption) {
        defaults.set(option.rawValue, forKey: Self.weekStartDefaultsKey)
    }

    private func syncWeekStartFromDefaults() {
        let storedRaw = defaults.string(forKey: Self.weekStartDefaultsKey) ?? Self.defaultWeekStart.rawValue
        let option = WeekStartOption(rawValue: storedRaw) ?? Self.defaultWeekStart
        guard option != profile.weekStart || option != draft.weekStart else { return }
        profile.weekStart = option
        draft.weekStart = option
    }

    private func parsedNumber(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func autoUpdateMaintenanceCalories(force: Bool = false) {
        // Use MacroCalculator to ensure consistency with Onboarding
        guard let calories = MacroCalculator.estimateMaintenanceCalories(
            genderOption: draft.selectedGender,
            birthDate: draft.birthDate,
            unitSystem: draft.unitSystem,
            heightValue: draft.heightValue,
            heightFeet: draft.heightFeet,
            heightInches: draft.heightInches,
            weightValue: draft.weightValue,
            workoutDays: 0, // Ignored when activityLevelRaw is provided
            activityLevelRaw: draft.activityLevel.rawValue
        ) else { return }
        
        let newValue = String(calories)

        if force {
            // Force overwrite when relevant fields changed (user expects recalculation)
            lastAutoComputedMaintenance = newValue
            maintenanceManuallyEdited = false
            if draft.maintenanceCalories != newValue {
                draft.maintenanceCalories = newValue
            }
            return
        }

        // Non-forced update — preserve manual edits
        if draft.maintenanceCalories.isEmpty || draft.maintenanceCalories == lastAutoComputedMaintenance {
            lastAutoComputedMaintenance = newValue
            if draft.maintenanceCalories != newValue {
                draft.maintenanceCalories = newValue
            }
        }
    }

    /// Public API to request a maintenance calories calculation.
    /// This replaces automatic recalculation and is triggered by the UI's "Auto" button.
    @MainActor
    func calculateMaintenanceCalories() {
        autoUpdateMaintenanceCalories(force: true)
    }

    private func heightInCentimeters() -> Double? {
        switch draft.unitSystem {
        case .metric:
            return parsedNumber(from: draft.heightValue)
        case .imperial:
            guard let feet = parsedNumber(from: draft.heightFeet),
                  let inches = parsedNumber(from: draft.heightInches) else { return nil }
            let totalInches = (feet * 12) + inches
            return totalInches * 2.54
        }
    }

    private func weightInKilograms() -> Double? {
        guard let rawValue = parsedNumber(from: draft.weightValue) else { return nil }
        switch draft.unitSystem {
        case .metric:
            return rawValue
        case .imperial:
            return rawValue / 2.20462
        }
    }

    private func validateMacroField(value: String, label: String, min: Double, max: Double) -> String? {
        guard let number = parsedNumber(from: value) else {
            return "Please enter a valid \(label.lowercased())."
        }
        if number < min || number > max {
            let minInt = Int(min)
            let maxInt = Int(max)
            return "\(label) must be between \(minInt) and \(maxInt)."
        }
        return nil
    }

    private func isBirthDateWithinSupportedRange(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let years = calendar.dateComponents([.year], from: date, to: today).year else { return false }
        return (0...120).contains(years)
    }

    @MainActor
    func signOut(in context: ModelContext? = nil) async {
        await performDestructiveAction {
            do {
                try Auth.auth().signOut()
            } catch {
                print("Error signing out: \(error)")
            }

            // Give the app time to detect the auth change and switch the RootView to the Welcome screen.
            // This ensures AccountsView (and its bindings to Account) are deallocated before we destroy the data.
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            self.clearUserDefaultsState()
            self.clearSwiftData(in: context)
        }
    }
    
    @MainActor
    func signOut(container: ModelContainer) async {
        await performDestructiveAction {
            do {
                try Auth.auth().signOut()
            } catch {
                print("Error signing out: \(error)")
            }

            // Give the app time to detect the auth change and switch the RootView to the Welcome screen.
            // This ensures AccountsView (and its bindings to Account) are deallocated before we destroy the data.
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            self.clearUserDefaultsState()
            self.clearSwiftData(container: container)
        }
    }
    
    private func clearSwiftData(in context: ModelContext?) {
        guard let ctx = context else {
            print("No ModelContext provided; skipping local SwiftData cleanup.")
            return
        }
        clearSwiftData(container: ctx.container)
    }

    private func clearSwiftData(container: ModelContainer) {
        do {
            let deleteContext = ModelContext(container)
            deleteContext.autosaveEnabled = false

            let dayReq = FetchDescriptor<Day>()
            let days = try deleteContext.fetch(dayReq)
            for d in days { deleteContext.delete(d) }

            let acctReq = FetchDescriptor<Account>()
            let accts = try deleteContext.fetch(acctReq)
            for a in accts { deleteContext.delete(a) }

            try deleteContext.save()
        } catch {
            print("Failed to clear local SwiftData models: \(error)")
        }
    }

    private func deleteDocuments(in collection: CollectionReference, batchSize: Int = 100) async throws {
        let snapshot = try await collection.limit(to: batchSize).getDocuments()
        guard !snapshot.isEmpty else { return }

        let batch = collection.firestore.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        try await batch.commit()

        if snapshot.count >= batchSize {
            try await deleteDocuments(in: collection, batchSize: batchSize)
        }
    }

    @MainActor
    func deleteFirebaseAccount() async -> AccountDeletionResult {
        guard !isPerformingDestructiveAction else {
            return AccountDeletionResult(remoteAccountDeleted: false, authUserDeleted: false, requiresRecentLogin: false)
        }
        isPerformingDestructiveAction = true
        defer { isPerformingDestructiveAction = false }

        guard let user = Auth.auth().currentUser else {
            print("No authenticated user; cannot delete account from Firestore.")
            return AccountDeletionResult(remoteAccountDeleted: false, authUserDeleted: false, requiresRecentLogin: false)
        }

        let uid = user.uid
        let db = Firestore.firestore()
        var remoteAccountDeleted = true

        do {
            let daysCollection = db.collection("accounts").document(uid).collection("days")
            try await deleteDocuments(in: daysCollection)
        } catch {
            remoteAccountDeleted = false
            print("Failed to delete days subcollection: \(error)")
        }

        do {
            try await db.collection("accounts").document(uid).delete()
        } catch {
            remoteAccountDeleted = false
            print("Failed to delete account doc: \(error)")
        }

        do {
            try await db.collection("logs").document(uid).delete()
        } catch {
            print("Failed to delete logs doc: \(error)")
        }

        do {
            try await user.delete()
            return AccountDeletionResult(remoteAccountDeleted: remoteAccountDeleted, authUserDeleted: true, requiresRecentLogin: false)
        } catch {
            let nsError = error as NSError
            let requiresRecent = nsError.domain == AuthErrorDomain && nsError.code == AuthErrorCode.requiresRecentLogin.rawValue
            if requiresRecent {
                self.requiresRecentLoginEncountered = true
            }
            print("Failed to delete Firebase Auth user: \(error)")
            return AccountDeletionResult(remoteAccountDeleted: remoteAccountDeleted, authUserDeleted: false, requiresRecentLogin: requiresRecent)
        }
    }

    @MainActor
    func deleteLocalData(in context: ModelContext?) async {
        clearUserDefaultsState()
        clearSwiftData(in: context)
    }

    @MainActor
    private func performDestructiveAction(_ work: @escaping () async -> Void) async {
        guard !isPerformingDestructiveAction else { return }
        isPerformingDestructiveAction = true
        defer { isPerformingDestructiveAction = false }
        await work()
    }
}

struct AccountProfile: Equatable {
    var name: String
    var avatarColor: AvatarColorOption
    var avatarImageData: Data?
    var avatarImageSignature: Int
    var appTheme: AppTheme
    var weekStart: WeekStartOption
    var birthDate: Date
    var selectedGender: GenderOption?
    var unitSystem: UnitSystem
    var heightValue: String
    var heightFeet: String
    var heightInches: String
    var weightValue: String
    var maintenanceCalories: String
    var activityLevel: ActivityLevelOption

    static func signature(for data: Data?) -> Int {
        guard let data else { return 0 }
        let sample = data.prefix(256)
        var hasher = Hasher()
        hasher.combine(data.count)
        for byte in sample {
            hasher.combine(byte)
        }
        return hasher.finalize()
    }

    static func == (lhs: AccountProfile, rhs: AccountProfile) -> Bool {
        lhs.name == rhs.name &&
        lhs.avatarColor == rhs.avatarColor &&
        lhs.avatarImageSignature == rhs.avatarImageSignature &&
        lhs.appTheme == rhs.appTheme &&
        lhs.weekStart == rhs.weekStart &&
        lhs.birthDate == rhs.birthDate &&
        lhs.selectedGender == rhs.selectedGender &&
        lhs.unitSystem == rhs.unitSystem &&
        lhs.heightValue == rhs.heightValue &&
        lhs.heightFeet == rhs.heightFeet &&
        lhs.heightInches == rhs.heightInches &&
        lhs.weightValue == rhs.weightValue &&
        lhs.maintenanceCalories == rhs.maintenanceCalories &&
        lhs.activityLevel == rhs.activityLevel
    }
}

enum WeekStartOption: String, CaseIterable, Identifiable {
    case sunday
    case monday

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        }
    }
}

enum AvatarColorOption: Int, CaseIterable, Identifiable {
    case emberPulse
    case auroraWave
    case neonLagoon
    case arcticGlow
    case cosmicBerry
    case mossAura

    var id: Int { rawValue }

    private var colors: [Color] {
        switch self {
        case .emberPulse:
            return [
                Color(red: 0.99, green: 0.36, blue: 0.33),
                Color(red: 1.00, green: 0.63, blue: 0.34)
            ]
        case .auroraWave:
            return [
                Color(red: 0.24, green: 0.64, blue: 1.00),
                Color(red: 0.30, green: 0.89, blue: 0.88)
            ]
        case .neonLagoon:
            return [
                Color(red: 0.39, green: 0.12, blue: 0.94),
                Color(red: 0.68, green: 0.33, blue: 1.00)
            ]
        case .arcticGlow:
            return [
                Color(red: 0.23, green: 0.86, blue: 0.97),
                Color(red: 0.56, green: 0.97, blue: 1.00)
            ]
        case .cosmicBerry:
            return [
                Color(red: 0.76, green: 0.27, blue: 0.69),
                Color(red: 0.99, green: 0.42, blue: 0.66)
            ]
        case .mossAura:
            return [
                Color(red: 0.26, green: 0.67, blue: 0.52),
                Color(red: 0.64, green: 0.87, blue: 0.45)
            ]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
