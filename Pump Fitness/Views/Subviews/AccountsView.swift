//
//  AccountsView.swift
//  Pump Fitness
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

enum AlertType: String, CaseIterable, Identifiable {
    case mealTracking = "Meal Tracking"
    case fastingTimer = "Fasting Timer"
    case dailyTasks = "Daily Tasks"
    case activityTimers = "Activity Timers"
    case dailyCheckIn = "Daily Check-In"
    var id: String { rawValue }
}

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
    @State private var showHealthKitStatusAlert = false
    @State private var healthKitStatusMessage = ""
    @State private var showAlertsSheet = false
    @State private var selectedAlerts: Set<AlertType> = []

    init(account: Binding<Account>) {
        _account = account
        _viewModel = StateObject(wrappedValue: AccountsViewModel())
    }

    var body: some View {
        // Sync viewModel with account when view appears
        let syncFromAccount = {
            let acc = account
            viewModel.draft.name = acc.name ?? ""
            viewModel.draft.avatarImageData = acc.profileImage
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
        }
        NavigationStack {
            ZStack {
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
                            }
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
                                        Button(action: {
                                            Task { await MainActor.run { viewModel.calculateMaintenanceCalories() } }
                                        }) {
                                            Text("Auto")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                                .surfaceCard(12)
                            }
                        }
                        
                        SectionCard(title: "Appearance") {
                            AppearanceSection(viewModel: viewModel)
                        }
                        
                        SectionCard(title: "Extras") {
                            ExtrasSection(
                                retakeAssessmentAction: { /* TODO: Implement assessment flow */ },
                                alertsAction: { showAlertsSheet = true },
                                privacyAction: openPrivacyAndTerms,
                            )
                        }
                        
                        // Permissions
                        SectionCard(title: "Permissions") {
                            PermissionsSection(
                                notificationsAction: openNotificationSettings,
                                healthSyncAction: openHealthSyncSettings,
                            )
                        }
                        
                        SectionCard(title: "Account") {
                            AccountSection(
                                manageSubscriptionAction: openSubscriptionPortal,
                                signOutAction: { showSignOutConfirmation = true },
                                deleteAccountAction: { showDeleteConfirmation = true }
                            )
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
            }
            .navigationBarBackButtonHidden(true)
            .tint(currentAccent)
            .accentColor(currentAccent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBack) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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

                                // Build a new Account and assign it to the binding so the
                                // parent's binding `set` handler applies the changes and
                                // persists them. This ensures RootView's observers
                                // (including maintenanceCalories) are updated.
                                await MainActor.run {
                                    let updated = Account(
                                        id: account.id,
                                        profileImage: viewModel.profile.avatarImageData,
                                        profileAvatar: String(describing: viewModel.profile.avatarColor.rawValue),
                                        name: viewModel.profile.name,
                                        gender: viewModel.profile.selectedGender?.rawValue,
                                        dateOfBirth: viewModel.profile.birthDate,
                                        height: Double(viewModel.profile.heightValue),
                                        weight: Double(viewModel.profile.weightValue),
                                        maintenanceCalories: Int(viewModel.profile.maintenanceCalories) ?? account.maintenanceCalories,
                                        theme: viewModel.profile.appTheme.rawValue,
                                        unitSystem: viewModel.profile.unitSystem.rawValue,
                                        startWeekOn: viewModel.profile.weekStart.rawValue
                                    )

                                    account = updated
                                    themeManager.setTheme(viewModel.profile.appTheme)
                                }

                                // Save to Firestore using the authenticated user's UID
                                if let firestoreAccount = viewModel.buildFirestoreAccount() {
                                    let success = await viewModel.saveAccountToFirestore(firestoreAccount)
                                    if !success {
                                        print("Failed to save account to Firestore")
                                    }
                                } else {
                                    print("No authenticated user; cannot save account to Firestore.")
                                }

                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }
                    .disabled(!viewModel.hasChanges)
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
        .alert("Sign out of Pump Fitness?", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete your Pump Fitness account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                    await viewModel.signOut()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure?")
        }
        .onAppear {
            syncFromAccount()
            viewModel.applyExternalTheme(themeManager.selectedTheme)
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
        .sheet(isPresented: $showAlertsSheet) {
            AlertSheetView(selectedAlerts: $selectedAlerts)
        }
    }
    
    struct AlertSheetView: View {
        @Binding var selectedAlerts: Set<AlertType>
        let pillColumns = [GridItem(.adaptive(minimum: 120), spacing: 12)]
        @Environment(\.dismiss) private var dismiss
        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which types of alerts you would like to receive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(AlertType.allCases) { alert in
                                HStack {
                                    Text(alert.rawValue)
                                        .font(.headline.weight(.semibold))
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Toggle(isOn: Binding(
                                        get: { selectedAlerts.contains(alert) },
                                        set: { isOn in
                                            if isOn {
                                                selectedAlerts.insert(alert)
                                            } else {
                                                selectedAlerts.remove(alert)
                                            }
                                        }
                                    )) {
                                        EmptyView()
                                    }
                                    .labelsHidden()
                                }
                            }
                        }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .navigationTitle("Alert Preferences")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(300), .medium])
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

    private func openPrivacyAndTerms() {
        // TODO: Present privacy policy and terms when legal docs are connected
    }

    private func presentCameraPicker() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            showCameraUnavailableAlert = true
        }
    }
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
    var signOutAction: () -> Void
    var deleteAccountAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            accountActionRow(
                title: "Manage Subscription",
                icon: "creditcard",
                role: nil,
                action: manageSubscriptionAction
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
    var privacyAction: () -> Void

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

            accountActionRow(
                title: "Privacy & Terms",
                icon: "doc.text.magnifyingglass",
                role: nil,
                action: privacyAction
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


private struct IdentitySection: View {
    @ObservedObject var viewModel: AccountsViewModel
    var selectLibraryAction: () -> Void
    var selectCameraAction: () -> Void
    var clearImageAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Circle()
                    .fill(viewModel.avatarGradient)
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

                        Button(action: viewModel.shuffleAvatarColor) {
                            actionLabel(text: "Shuffle", systemImage: "die.face.5")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .tint(.primary)
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

final class AccountsViewModel: ObservableObject {
    private static let weekStartDefaultsKey = "weekStartPreference"
    private static let defaultWeekStart: WeekStartOption = .monday

    @Published private(set) var profile: AccountProfile
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
    func saveAccountToFirestore(_ account: Account) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            firestoreService.saveAccount(account) { success in
                continuation.resume(returning: success)
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
        // Only auto-update if gender is known and not 'preferNotSay'
        guard let gender = draft.selectedGender, gender != .preferNotSay else { return }

        guard let weightKg = weightInKilograms(), let heightCm = heightInCentimeters() else { return }

        let calendar = Calendar.current
        let today = Date()
        let years = calendar.dateComponents([.year], from: draft.birthDate, to: today).year ?? 0
        let age = max(0, years)

        let rmr: Double
        if gender == .male {
            rmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) + 5.0
        } else {
            rmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) - 161.0
        }

        let multiplier = draft.activityLevel.tdeeMultiplier
        let tdee = rmr * multiplier
        let newValue = String(Int(tdee.rounded()))

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
    func signOut() async {
        await performDestructiveAction {
            // Sign out from Firebase Auth
            do {
                try Auth.auth().signOut()
            } catch {
                print("Error signing out: \(error)")
            }
            // Clear account from UserDefaults
            let keysToRemove = [
                ThemeManager.defaultsKey,
                Self.weekStartDefaultsKey
            ]
            for key in keysToRemove {
                self.defaults.removeObject(forKey: key)
            }
            // Clear all Core Data objects
            // TODO: Implement Core Data clearing using your persistence controller/model context
            // Example: PersistenceController.shared.clearAll()
        }
    }

    @MainActor
    func deleteAccount() async {
        await performDestructiveAction {
            // Delete account document from Firestore using async/await
            guard let user = Auth.auth().currentUser else {
                print("No authenticated user; cannot delete account from Firestore.")
                return
            }
            let uid = user.uid
            let db = Firestore.firestore()
            do {
                try await db.collection("accounts").document(uid).delete()
            } catch {
                print("Failed to delete account: \(error)")
            }
            // Optionally clear local state, UserDefaults, and Core Data as in signOut()
        }
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
