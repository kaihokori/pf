//
//  AccountsView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 30/11/2025.
//

import SwiftUI
import Combine
import PhotosUI
import UIKit

struct AccountsView: View {
    @StateObject private var viewModel = AccountsViewModel()
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

    var body: some View {
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
                                .glassEffect(in: .rect(cornerRadius: 12.0))
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
                        }

                        SectionCard(title: "Routine") {
                            VStack(alignment: .leading) {
                                Text("Primary goal")
                                    .padding(.bottom, 10)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                                    ForEach(GoalOption.allCases) { option in
                                        SelectablePillComponent(
                                            label: option.displayName,
                                            isSelected: viewModel.draft.selectedGoal == option
                                        ) {
                                            viewModel.draft.selectedGoal = option
                                        }
                                    }
                                }

                                WorkoutsPerWeekSelector(selectedDays: viewModel.draft.selectedWorkoutDays) { day in
                                    viewModel.toggleDay(day)
                                }
                            }
                        }

                        SectionCard(title: "Appearance") {
                            AppearanceSection(viewModel: viewModel)
                        }

                        SectionCard(title: "Other") {
                            OtherSection(
                                notificationsAction: openNotificationSettings,
                                healthSyncAction: openHealthSyncSettings,
                                privacyAction: openPrivacyAndTerms
                            )
                        }

                        SectionCard(title: "Account") {
                            AccountSection(
                                manageSubscriptionAction: openSubscriptionPortal,
                                signOutAction: { showSignOutConfirmation = true },
                                deleteAction: { showDeleteConfirmation = true },
                                isDisabled: viewModel.isPerformingDestructiveAction
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
                        if let error = viewModel.validationErrorMessage() {
                            validationMessage = error
                            showValidationAlert = true
                        } else {
                            viewModel.saveChanges()
                            themeManager.setTheme(viewModel.profile.appTheme)
                            dismiss()
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
        .confirmationDialog(
            "Sign out of Pump Fitness?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete your Pump Fitness account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
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
        // TODO: Present notification preferences once notification center is wired
    }

    private func openHealthSyncSettings() {
        // TODO: Present HealthKit sync configuration when HealthKit flow is ready
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

private struct AccountSection: View {
    var manageSubscriptionAction: () -> Void
    var signOutAction: () -> Void
    var deleteAction: () -> Void
    var isDisabled: Bool

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
                icon: "rectangle.portrait.and.arrow.right",
                role: .destructive,
                foregroundColor: .white,
                action: signOutAction
            )

            accountActionRow(
                title: "Delete Account",
                icon: "trash",
                role: .destructive,
                action: deleteAction
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.6 : 1)
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
            .glassEffect(in: .rect(cornerRadius: 16.0))
        }
        .buttonStyle(.plain)
    }
}

private struct OtherSection: View {
    var notificationsAction: () -> Void
    var healthSyncAction: () -> Void
    var privacyAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            accountActionRow(
                title: "Notifications",
                icon: "bell.badge",
                role: nil,
                action: notificationsAction
            )

            accountActionRow(
                title: "Apps and Devices",
                icon: "dot.radiowaves.left.and.right",
                role: nil,
                action: healthSyncAction
            )

            accountActionRow(
                title: "Privacy & Terms",
                icon: "doc.text.magnifyingglass",
                role: nil,
                action: privacyAction
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
            .glassEffect(in: .rect(cornerRadius: 16.0))
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
        .glassEffect(.regular.tint(Color.white.opacity(0.12)), in: .capsule)
        .overlay(
            Capsule(style: .continuous)
                .stroke(PumpPalette.cardBorder, lineWidth: 1)
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
                        .glassEffect(in: .rect(cornerRadius: 12.0))
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
                .glassEffect(in: .rect(cornerRadius: 12.0))
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
            SectionTitle("Workouts per week")
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
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular, in: .circle)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
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
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(PumpPalette.cardBorder, lineWidth: 1)
                            )
                    )
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

            VStack(alignment: .leading, spacing: 12) {
                Text("Week starts on")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(WeekStartOption.allCases) { option in
                        SelectablePillComponent(
                            label: option.displayName,
                            isSelected: viewModel.draft.weekStart == option
                        ) {
                            viewModel.setWeekStart(option)
                        }
                    }
                }
            }
        }
    }

    private func themePreview(for theme: AppTheme) -> some View {
        HStack {
            ThemePreviewRow(theme: theme, colorScheme: colorScheme)
            Text("Preview:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

final class AccountsViewModel: ObservableObject {
    private static let weekStartDefaultsKey = "weekStartPreference"
    private static let defaultWeekStart: WeekStartOption = .monday

    @Published private(set) var profile: AccountProfile
    @Published var draft: AccountProfile
    @Published var isPerformingDestructiveAction = false
    private var lastCalculatedTargets: MacroTargetsSnapshot?

    private let defaults: UserDefaults
    private var defaultsObserver: AnyCancellable?

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
            selectedGoal: .gainMuscle,
            selectedWorkoutDays: Set([Weekday.allCases[0], Weekday.allCases[1], Weekday.allCases[2], Weekday.allCases[3], Weekday.allCases[4], Weekday.allCases[5], Weekday.allCases[6]]),
            selectedMacroFocus: .highProtein,
            selectedSupplements: [.vitaminC, .vitaminD, .zinc, .iron, .magnesium, .melatonin],
            otherSupplementName: "Omega-3",
            calorieValue: "2400",
            proteinValue: "150",
            fatValue: "70",
            carbohydrateValue: "260",
            fibreValue: "30",
            waterIntakeValue: "2500",
            sodiumValue: "2300"
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
        // TODO: Persist to Firebase/Core Data when available
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

        if draft.selectedGoal == nil {
            return "Please select your primary goal."
        }
        if draft.selectedMacroFocus == nil {
            return "Please select your macro focus."
        }

        if let error = validateMacroField(value: draft.calorieValue, label: "Calorie target", min: 0, max: 20000) {
            return error
        }
        if let error = validateMacroField(value: draft.proteinValue, label: "Protein target", min: 0, max: 10000) {
            return error
        }
        if let error = validateMacroField(value: draft.carbohydrateValue, label: "Carbohydrate target", min: 0, max: 20000) {
            return error
        }
        if let error = validateMacroField(value: draft.fatValue, label: "Fat target", min: 0, max: 10000) {
            return error
        }
        if let error = validateMacroField(value: draft.fibreValue, label: "Fibre target", min: 0, max: 5000) {
            return error
        }
        guard parsedNumber(from: draft.sodiumValue) != nil else {
            return "Please enter a valid sodium target."
        }
        guard parsedNumber(from: draft.waterIntakeValue) != nil else {
            return "Please enter a valid water intake target."
        }
        if draft.selectedSupplements.contains(.other) && draft.otherSupplementName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please specify your other supplement(s)."
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

    func toggleDay(_ day: Weekday) {
        if draft.selectedWorkoutDays.contains(day) {
            draft.selectedWorkoutDays.remove(day)
        } else {
            draft.selectedWorkoutDays.insert(day)
        }
    }

    func toggleSupplement(_ option: SupplementOption) {
        if draft.selectedSupplements.contains(option) {
            draft.selectedSupplements.remove(option)
            if option == .other {
                draft.otherSupplementName = ""
            }
        } else if draft.selectedSupplements.count < 8 {
            draft.selectedSupplements.insert(option)
        }
    }

    func selectMacroFocus(_ option: MacroFocusOption) {
        draft.selectedMacroFocus = option

        guard option != .other else {
            lastCalculatedTargets = nil
            return
        }

        guard let input = MacroCalculator.makeInput(
                  genderOption: draft.selectedGender,
                  birthDate: draft.birthDate,
                  unitSystem: draft.unitSystem,
                  heightValue: draft.heightValue,
                  heightFeet: draft.heightFeet,
                  heightInches: draft.heightInches,
                  weightValue: draft.weightValue,
                  workoutDays: draft.selectedWorkoutDays.count,
                  goal: draft.selectedGoal,
                  macroFocus: option
              ),
              let result = MacroCalculator.calculateTargets(for: input) else {
            return
        }

        applyMacroTargets(result)
    }

    private func applyMacroTargets(_ result: MacroCalculator.Result) {
        draft.calorieValue = String(result.calories)
        draft.proteinValue = String(result.protein)
        draft.carbohydrateValue = String(result.carbohydrates)
        draft.fatValue = String(result.fats)
        draft.fibreValue = String(result.fibre)
        draft.sodiumValue = String(result.sodiumMg)
        draft.waterIntakeValue = String(result.waterMl)
        lastCalculatedTargets = MacroTargetsSnapshot(result: result)
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

    func markMacroFocusAsOther() {
        draft.selectedMacroFocus = .other
        lastCalculatedTargets = nil
    }

    func updateMacroField(_ field: MacroField, newValue: String) {
        switch field {
        case .calories: draft.calorieValue = newValue
        case .protein: draft.proteinValue = newValue
        case .fats: draft.fatValue = newValue
        case .carbohydrates: draft.carbohydrateValue = newValue
        case .fibre: draft.fibreValue = newValue
        case .sodium: draft.sodiumValue = newValue
        case .water: draft.waterIntakeValue = newValue
        }

        guard draft.selectedMacroFocus != .other else { return }
        guard let snapshot = lastCalculatedTargets else {
            markMacroFocusAsOther()
            return
        }

        if snapshot.value(for: field) != newValue {
            lastCalculatedTargets = nil
            markMacroFocusAsOther()
        }
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
            // TODO: Invoke Firebase Auth sign-out when available
        }
    }

    @MainActor
    func deleteAccount() async {
        await performDestructiveAction {
            // TODO: Invoke account deletion flow when backend is ready
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
    var selectedGoal: GoalOption?
    var selectedWorkoutDays: Set<Weekday>
    var selectedMacroFocus: MacroFocusOption?
    var selectedSupplements: Set<SupplementOption>
    var otherSupplementName: String
    var calorieValue: String
    var proteinValue: String
    var fatValue: String
    var carbohydrateValue: String
    var fibreValue: String
    var waterIntakeValue: String
    var sodiumValue: String
}

extension AccountsViewModel {
    enum MacroField {
        case calories
        case protein
        case fats
        case carbohydrates
        case fibre
        case sodium
        case water
    }

    private struct MacroTargetsSnapshot {
        let calories: String
        let protein: String
        let carbohydrates: String
        let fats: String
        let fibre: String
        let sodium: String
        let water: String

        init(result: MacroCalculator.Result) {
            calories = String(result.calories)
            protein = String(result.protein)
            carbohydrates = String(result.carbohydrates)
            fats = String(result.fats)
            fibre = String(result.fibre)
            sodium = String(result.sodiumMg)
            water = String(result.waterMl)
        }

        func value(for field: MacroField) -> String {
            switch field {
            case .calories: return calories
            case .protein: return protein
            case .fats: return fats
            case .carbohydrates: return carbohydrates
            case .fibre: return fibre
            case .sodium: return sodium
            case .water: return water
            }
        }
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

#Preview {
    AccountsView()
        .environmentObject(ThemeManager())
}

