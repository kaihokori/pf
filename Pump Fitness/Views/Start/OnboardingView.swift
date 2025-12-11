import SwiftUI
import Combine
import FirebaseAuth

struct OnboardingView: View {
    var initialName: String? = nil
    var onComplete: (() -> Void)? = nil
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    init(initialName: String? = nil, onComplete: (() -> Void)? = nil) {
        self.initialName = initialName
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(initialName: initialName))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(theme: .other)
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        CylindricalProgressView(currentIndex: viewModel.currentStepIndex, totalSteps: viewModel.steps.count)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStepIndex)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentStep.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .padding(.top)
                            Text(viewModel.currentStep.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch viewModel.currentStep {
                            case .aboutYou:
                                AboutYouStepView(viewModel: viewModel)
                            case .bodyBasics:
                                BodyBasicsStepView(viewModel: viewModel)
                            case .routine:
                                RoutineStepView(viewModel: viewModel)
                            case .calorieTarget:
                                CalorieTargetStepView(viewModel: viewModel)
                            case .macroTargets:
                                MacroTargetsStepView(viewModel: viewModel)
                            case .supplements:
                                SupplementsStepView(viewModel: viewModel)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .padding(.bottom)

                    HStack(spacing: 12) {
                        if !viewModel.isFirstStep {
                            Button(action: { withAnimation { viewModel.goBack() } }) {
                                Text("Back")
                                    .font(.headline)
                                    .foregroundColor(Color.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .surfaceCard(16)
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        Button(action: handleContinue) {
                            Text(viewModel.buttonTitle)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .surfaceCard(16, fill: Color.accentColor, shadowOpacity: 0.12)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isFirstStep)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Invalid Input"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .interactiveDismissDisabled()
        }
    }

    @State private var showAlert = false
    @State private var alertMessage = ""

    private func handleContinue() {
        if viewModel.canContinue {
            if viewModel.isLastStep {
                // Build Account from collected onboarding fields and save to Firestore
                let uid = Auth.auth().currentUser?.uid
                let account = Account(
                    id: uid,
                    profileAvatar: nil,
                    name: viewModel.preferredName.trimmingCharacters(in: .whitespacesAndNewlines),
                    gender: viewModel.selectedGender?.rawValue,
                    dateOfBirth: viewModel.birthDate,
                    height: heightInCentimeters(),
                    weight: weightInKilograms(),
                    theme: nil,
                    unitSystem: viewModel.unitSystem.rawValue,
                    activityLevel: ActivityLevelOption.moderatelyActive.rawValue,
                    startWeekOn: nil
                )

                AccountFirestoreService().saveAccount(account) { success in
                    DispatchQueue.main.async {
                        if success {
                            hasCompletedOnboarding = true
                            onComplete?()
                            dismiss()
                        } else {
                            alertMessage = "Failed to save account. Please try again."
                            showAlert = true
                        }
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    _ = viewModel.advance()
                }
            }
        } else {
            alertMessage = validationErrorMessage()
            showAlert = true
        }
    }

    private func validationErrorMessage() -> String {
        switch viewModel.currentStep {
        case .aboutYou:
            let trimmedName = viewModel.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                return "Preferred name cannot be empty."
            }
            if !viewModel.isValidBirthDate {
                return "Please enter a valid date of birth in the supported range."
            }
            if !isBirthDateWithinSupportedRange(viewModel.birthDate) {
                return "Date of birth must produce an age between 0 and 120 years."
            }
            return "Please complete all fields."
        case .bodyBasics:
            if viewModel.selectedGender == nil {
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
            return "Please complete all fields."
        case .routine:
            return "Please complete all fields."
        case .calorieTarget:
            if viewModel.selectedMacroFocus == nil {
                return "Please select your macro focus."
            }
            if let error = validateMacroField(value: viewModel.calorieValue, label: "Calorie target", min: 0, max: 20000) {
                return error
            }
            return "Please complete all fields."
        case .macroTargets:
            if let error = validateMacroField(value: viewModel.proteinValue, label: "Protein target", min: 0, max: 10000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.carbohydrateValue, label: "Carbohydrate target", min: 0, max: 20000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.fatValue, label: "Fat target", min: 0, max: 10000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.fibreValue, label: "Fibre target", min: 0, max: 5000) {
                return error
            }
            guard parsedNumber(from: viewModel.sodiumValue) != nil else {
                return "Please enter a valid sodium target."
            }
            guard parsedNumber(from: viewModel.waterIntakeValue) != nil else {
                return "Please enter a valid water intake target."
            }
            return "Please complete all fields."
        case .supplements:
            if viewModel.selectedSupplements.contains(.other) && viewModel.otherSupplementName.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Please specify your other supplement(s)."
            }
            return "Please complete all fields."
        }
    }

    private func heightInCentimeters() -> Double? {
        switch viewModel.unitSystem {
        case .metric:
            return parsedNumber(from: viewModel.heightValue)
        case .imperial:
            guard let feet = parsedNumber(from: viewModel.heightFeet),
                  let inches = parsedNumber(from: viewModel.heightInches) else { return nil }
            let totalInches = (feet * 12) + inches
            return totalInches * 2.54
        }
    }

    private func weightInKilograms() -> Double? {
        guard let rawValue = parsedNumber(from: viewModel.weightValue) else { return nil }
        switch viewModel.unitSystem {
        case .metric:
            return rawValue
        case .imperial:
            return rawValue / 2.20462
        }
    }

    private func parsedNumber(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
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
}

private struct AboutYouStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextFieldWithLabel(
                "Preferred name",
                text: $viewModel.preferredName,
                prompt: Text("e.g. Alex")
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Date of birth")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                DateComponent(
                    date: $viewModel.birthDate,
                    range: PumpDateRange.birthdate,
                    isError: !viewModel.isValidBirthDate
                )
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BodyBasicsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Gender")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                ForEach(GenderOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: viewModel.selectedGender == option
                    ) {
                        viewModel.selectedGender = option
                    }
                }
            }

            Text("Unit of Measurement")
                .font(.footnote)
                .foregroundStyle(.secondary)
            MetricToggleView(unitSystem: viewModel.unitSystem) { newSystem in
                viewModel.updateUnitSystem(to: newSystem)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if viewModel.unitSystem == .imperial {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("0", text: $viewModel.heightFeet)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                    Text("ft")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(12)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    TextField("0", text: $viewModel.heightInches)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                    Text("in")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(12)
                            }
                        }
                    } else {
                        LabeledNumericField(
                            label: nil,
                            value: $viewModel.heightValue,
                            unitLabel: viewModel.unitSystem.heightUnit
                        )
                    }
                }
                LabeledNumericField(
                    label: "Weight",
                    value: $viewModel.weightValue,
                    unitLabel: viewModel.unitSystem.weightUnit
                )
            }
        }
        .onAppear {
            // When the calorie target step appears, if a macro focus is already
            // selected and the user hasn't entered a calorie value, populate
            // calculated macro targets automatically.
            if let focus = viewModel.selectedMacroFocus,
               focus != .custom,
               viewModel.calorieValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.selectMacroFocus(focus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoutineStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    private let pillColumns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Workout days each week")
                .font(.footnote)
                .foregroundStyle(.secondary)
            WorkoutsPerWeekView(selectedDays: viewModel.selectedWorkoutDays) { day in
                viewModel.toggleDay(day)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalorieTargetStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    private let pillColumns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Macro focus")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                ForEach(MacroFocusOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: viewModel.selectedMacroFocus == option
                    ) {
                        viewModel.selectMacroFocus(option)
                    }
                }
            }

            LabeledNumericField(
                label: "Calorie Target",
                value: Binding(
                    get: { viewModel.calorieValue },
                    set: { viewModel.updateMacroField(.calories, newValue: $0) }
                ),
                unitLabel: "cal"
            )

                if let maintenance = viewModel.estimatedMaintenanceCalories,
                    let focus = viewModel.selectedMacroFocus,
                    focus != .custom {
                let recommendation = CalorieGoalPlanner.recommendation(for: focus, maintenanceCalories: maintenance)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended for \(focus.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(maintenance) cal \(recommendation.adjustmentSymbol) \(recommendation.adjustmentPercentText) = \(recommendation.value) cal")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                    Text("We base this on your estimated maintenance of \(maintenance) cal. Adjust manually if you need a custom target.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.selectedMacroFocus == .custom {
                Text("Custom targets override the preset strategy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.selectedGender == .preferNotSay {
                Text("Maintenance cannot be calculated unless you select \"Male\" or \"Female\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Maintenance is calculated with the Mifflin-St Jeor equation plus your workout schedule, then applies the selected macro focus multiplier.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MacroTargetsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 16) {
                LabeledNumericField(
                    label: "Protein",
                    value: Binding(
                        get: { viewModel.proteinValue },
                        set: { viewModel.updateMacroField(.protein, newValue: $0) }
                    ),
                    unitLabel: "g"
                )

                LabeledNumericField(
                    label: "Fats",
                    value: Binding(
                        get: { viewModel.fatValue },
                        set: { viewModel.updateMacroField(.fats, newValue: $0) }
                    ),
                    unitLabel: "g"
                )

                LabeledNumericField(
                    label: "Carbohydrates",
                    value: Binding(
                        get: { viewModel.carbohydrateValue },
                        set: { viewModel.updateMacroField(.carbohydrates, newValue: $0) }
                    ),
                    unitLabel: "g"
                )

                LabeledNumericField(
                    label: "Fibre",
                    value: Binding(
                        get: { viewModel.fibreValue },
                        set: { viewModel.updateMacroField(.fibre, newValue: $0) }
                    ),
                    unitLabel: "g"
                )

                LabeledNumericField(
                    label: "Sodium",
                    value: Binding(
                        get: { viewModel.sodiumValue },
                        set: { viewModel.updateMacroField(.sodium, newValue: $0) }
                    ),
                    unitLabel: "mg"
                )

                LabeledNumericField(
                    label: "Water Intake",
                    value: Binding(
                        get: { viewModel.waterIntakeValue },
                        set: { viewModel.updateMacroField(.water, newValue: $0) }
                    ),
                    unitLabel: "ml"
                )
            }

            MacroCalculationExplainer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SupplementsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle("Daily Supplements")
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                ForEach(SupplementOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: viewModel.selectedSupplements.contains(option)
                    ) {
                        if viewModel.selectedSupplements.contains(option) {
                            viewModel.selectedSupplements.remove(option)
                            if option == .other {
                                viewModel.otherSupplementName = ""
                            }
                        } else if viewModel.selectedSupplements.count < 8 {
                            viewModel.selectedSupplements.insert(option)
                        }
                    }
                }
            }
            if viewModel.selectedSupplements.contains(.other) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Please specify other supplement(s)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Enter supplement name(s)", text: $viewModel.otherSupplementName)
                        .padding()
                        .surfaceCard(10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CylindricalProgressView: View {
    let currentIndex: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? Color.accentColor : Color(.systemGray4))
                    .frame(height: 8)
                    .opacity(index <= currentIndex ? 1 : 0.4)
            }
        }
    }
}

private struct WorkoutsPerWeekView: View {
    let selectedDays: Set<Weekday>
    var toggleAction: (Weekday) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
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

private struct MetricToggleView: View {
    let unitSystem: UnitSystem
    let onChange: (UnitSystem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(UnitSystem.allCases, id: \.self) { system in
                Button(action: { onChange(system) }) {
                    Text(system.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .surfaceCard(12)
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

public struct LabeledNumericField: View {
    let label: String?
    @Binding var value: String
    let unitLabel: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                Text(unitLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .surfaceCard(12)
        }
    }
}

public struct TextFieldWithLabel: View {
    var label: String
    @Binding var text: String
    var prompt: Text

    public init(_ label: String, text: Binding<String>, prompt: Text) {
        self.label = label
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("", text: $text, prompt: prompt)
                .textInputAutocapitalization(.words)
                .padding()
                .surfaceCard(10)
        }
    }
}

public struct SectionTitle: View {
    var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.bottom, -4)
    }
}

final class OnboardingViewModel: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .aboutYou
    @Published var preferredName: String
    @Published var birthDate: Date = PumpDateRange.birthdate.upperBound

    init(initialName: String? = nil) {
        self.preferredName = initialName ?? ""
    }

    @Published var selectedGender: GenderOption?
    @Published var unitSystem: UnitSystem = .metric
    @Published var heightValue: String = ""
    @Published var heightFeet: String = ""
    @Published var heightInches: String = ""
    @Published var weightValue: String = ""

    @Published var selectedGoal: GoalOption?
    @Published var selectedWorkoutDays: Set<Weekday> = []
    @Published var selectedMacroFocus: MacroFocusOption?
    @Published var calorieValue: String = ""
    @Published var proteinValue: String = ""
    @Published var fatValue: String = ""
    @Published var carbohydrateValue: String = ""
    @Published var fibreValue: String = ""
    @Published var sodiumValue: String = ""
    @Published var waterIntakeValue: String = ""
    @Published var selectedSupplements: Set<SupplementOption> = []
    @Published var otherSupplementName: String = ""
    private var lastCalculatedTargets: MacroTargetsSnapshot?

    let steps: [OnboardingStep] = OnboardingStep.allCases

    var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var isFirstStep: Bool { currentStepIndex == 0 }
    var isLastStep: Bool { currentStepIndex == steps.count - 1 }

    var buttonTitle: String { isLastStep ? "Finish" : "Continue" }

    var estimatedMaintenanceCalories: Int? {
        MacroCalculator.estimateMaintenanceCalories(
            genderOption: selectedGender,
            birthDate: birthDate,
            unitSystem: unitSystem,
            heightValue: heightValue,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightValue: weightValue,
            workoutDays: selectedWorkoutDays.count
        )
    }

    var canContinue: Bool {
        switch currentStep {
        case .aboutYou:
            return !preferredName.trimmingCharacters(in: .whitespaces).isEmpty && isValidBirthDate
        case .bodyBasics:
            if unitSystem == .imperial {
                return selectedGender != nil && Double(heightFeet) != nil && Double(heightInches) != nil && Double(weightValue) != nil
            } else {
                return selectedGender != nil && Double(heightValue) != nil && Double(weightValue) != nil
            }
        case .routine:
            return true
        case .calorieTarget:
            return selectedMacroFocus != nil && Double(calorieValue) != nil
        case .macroTargets:
            return Double(proteinValue) != nil
                && Double(fatValue) != nil
                && Double(carbohydrateValue) != nil
                && Double(fibreValue) != nil
                && Double(sodiumValue) != nil
                && Double(waterIntakeValue) != nil
        case .supplements:
            if selectedSupplements.contains(.other) {
                return !otherSupplementName.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return true
        }
    }

    var isValidBirthDate: Bool {
        PumpDateRange.birthdate.contains(birthDate)
    }

    func advance() -> Bool {
        guard !isLastStep else { return true }
        currentStep = steps[min(currentStepIndex + 1, steps.count - 1)]
        return false
    }

    func goBack() {
        guard !isFirstStep else { return }
        currentStep = steps[max(currentStepIndex - 1, 0)]
    }

    func updateUnitSystem(to newSystem: UnitSystem) {
        guard newSystem != unitSystem else { return }
        if newSystem == .imperial {
            // Convert metric cm to ft/in
            if let cm = Double(heightValue), cm > 0 {
                let totalInches = cm / 2.54
                let feet = Int(totalInches / 12)
                let inches = totalInches - Double(feet * 12)
                heightFeet = String(feet)
                heightInches = String(format: "%.1f", inches)
            } else {
                heightFeet = ""
                heightInches = ""
            }
            if let kg = Double(weightValue) {
                weightValue = UnitConverter.convertWeight(kg, from: .metric, to: .imperial)
            } else {
                weightValue = ""
            }
        } else {
            // Convert imperial ft/in to cm
            if let feet = Double(heightFeet), let inches = Double(heightInches) {
                let totalInches = (feet * 12) + inches
                let cm = totalInches * 2.54
                heightValue = String(format: "%.0f", cm)
            } else {
                heightValue = ""
            }
            if let lbs = Double(weightValue) {
                weightValue = UnitConverter.convertWeight(lbs, from: .imperial, to: .metric)
            } else {
                weightValue = ""
            }
        }
        unitSystem = newSystem
    }

    func toggleDay(_ day: Weekday) {
        if selectedWorkoutDays.contains(day) {
            selectedWorkoutDays.remove(day)
        } else {
            selectedWorkoutDays.insert(day)
        }
    }

    func markMacroFocusAsCustom() {
        selectedMacroFocus = .custom
        lastCalculatedTargets = nil
    }

    func selectMacroFocus(_ option: MacroFocusOption) {
        selectedMacroFocus = option

        guard option != .custom else {
            lastCalculatedTargets = nil
            return
        }

        // Calculate the simple recommended calories shown in the UI so we can
        // insert the same value into the calorie field.
        let maintenance = estimatedMaintenanceCalories ?? 0
        let recommended = CalorieGoalPlanner.recommendation(for: option, maintenanceCalories: maintenance).value

        // Try to compute full macro targets; if available, apply them but
        // override the calories with the UI recommendation so values match.
        if let input = MacroCalculator.makeInput(
            genderOption: selectedGender,
            birthDate: birthDate,
            unitSystem: unitSystem,
            heightValue: heightValue,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightValue: weightValue,
            workoutDays: selectedWorkoutDays.count,
            goal: selectedGoal,
            macroFocus: option
        ), let result = MacroCalculator.calculateTargets(for: input) {
            applyMacroTargets(result, overrideCalories: recommended)
        } else {
            // Fallback: set only the calorie value to the recommendation
            calorieValue = String(recommended)
            lastCalculatedTargets = nil
        }
    }

    private func applyMacroTargets(_ result: MacroCalculator.Result, overrideCalories: Int? = nil) {
        calorieValue = String(overrideCalories ?? result.calories)
        proteinValue = String(result.protein)
        carbohydrateValue = String(result.carbohydrates)
        fatValue = String(result.fats)
        fibreValue = String(result.fibre)
        sodiumValue = String(result.sodiumMg)
        waterIntakeValue = String(result.waterMl)
        lastCalculatedTargets = MacroTargetsSnapshot(result: result, overrideCalories: overrideCalories)
    }

    func updateMacroField(_ field: MacroField, newValue: String) {
        switch field {
        case .calories: calorieValue = newValue
        case .protein: proteinValue = newValue
        case .fats: fatValue = newValue
        case .carbohydrates: carbohydrateValue = newValue
        case .fibre: fibreValue = newValue
        case .sodium: sodiumValue = newValue
        case .water: waterIntakeValue = newValue
        }

        guard selectedMacroFocus != .custom else { return }
        guard let snapshot = lastCalculatedTargets else {
            markMacroFocusAsCustom()
            return
        }

        if snapshot.value(for: field) != newValue {
            lastCalculatedTargets = nil
            markMacroFocusAsCustom()
        }
    }
}

enum OnboardingStep: CaseIterable, Equatable {
    case aboutYou
    case bodyBasics
    case routine
    case calorieTarget
    case macroTargets
    case supplements

    var title: String {
        switch self {
        case .aboutYou: return "Basic Details"
        case .bodyBasics: return "Body Basics"
        case .routine: return "Your Routine"
        case .calorieTarget: return "Calorie Target"
        case .macroTargets: return "Macro Targets"
        case .supplements: return "Supplements"
        }
    }

    var subtitle: String {
        switch self {
        case .aboutYou: return "Tell us a little about yourself"
        case .bodyBasics: return "Dial in the essentials"
        case .routine: return "Tune your weekly rhythm"
        case .calorieTarget: return "Lock in your daily calories"
        case .macroTargets: return "Fine-tune your macro mix"
        case .supplements: return "Optimise your nutrition"
        }
    }
}

enum GenderOption: String, CaseIterable, Identifiable {
    case male, female, preferNotSay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotSay: return "Prefer Not Say"
        }
    }
}

enum GoalOption: String, CaseIterable, Identifiable {
    case loseFat
    case maintain
    case gainMuscle
    case recomposition
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loseFat: return "Lose Fat"
        case .maintain: return "Maintain"
        case .gainMuscle: return "Gain Muscle"
        case .recomposition: return "Recomposition"
        }
    }
}

enum MacroFocusOption: String, CaseIterable, Identifiable {
    case highProtein
    case balanced
    case lowCarb
    case custom
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highProtein: return "High-Protein"
        case .balanced: return "Balanced"
        case .lowCarb: return "Low-Carb"
        case .custom: return "Custom"
        }
    }

    init?(rawValue: String) {
        if rawValue == "other" {
            self = .custom
            return
        }
        guard let match = MacroFocusOption.allCases.first(where: { $0.rawValue == rawValue }) else {
            return nil
        }
        self = match
    }
}

extension OnboardingViewModel {
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

        init(result: MacroCalculator.Result, overrideCalories: Int? = nil) {
            calories = String(overrideCalories ?? result.calories)
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

enum SupplementOption: String, CaseIterable, Identifiable {
    case vitaminC
    case vitaminD
    case zinc
    case iron
    case magnesium
    case magnesiumGlycinate
    case melatonin
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vitaminC: return "Vitamin C"
        case .vitaminD: return "Vitamin D"
        case .zinc: return "Zinc"
        case .iron: return "Iron"
        case .magnesium: return "Magnesium"
        case .magnesiumGlycinate: return "Magnesium Glycinate"
        case .melatonin: return "Melatonin"
        case .other: return "Other"
        }
    }
}

enum UnitSystem: String, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }

    var heightUnit: String { self == .metric ? "cm" : "in" }
    var weightUnit: String { self == .metric ? "kg" : "lb" }
}

struct Weekday: Identifiable, Hashable, CaseIterable {
    let id: Int
    let shortLabel: String

    static let allCases: [Weekday] = [
        Weekday(id: 0, shortLabel: "M"),
        Weekday(id: 1, shortLabel: "Tu"),
        Weekday(id: 2, shortLabel: "W"),
        Weekday(id: 3, shortLabel: "Th"),
        Weekday(id: 4, shortLabel: "F"),
        Weekday(id: 5, shortLabel: "Sa"),
        Weekday(id: 6, shortLabel: "Su")
    ]
}

enum UnitConverter {
    static func convertHeight(_ value: Double, from: UnitSystem, to: UnitSystem) -> String {
        guard from != to else { return String(format: "%.0f", value) }
        switch (from, to) {
        case (.metric, .imperial):
            return String(format: "%.1f", value / 2.54)
        case (.imperial, .metric):
            return String(format: "%.0f", value * 2.54)
        default:
            return String(format: "%.0f", value)
        }
    }

    static func convertWeight(_ value: Double, from: UnitSystem, to: UnitSystem) -> String {
        guard from != to else { return String(format: "%.1f", value) }
        switch (from, to) {
        case (.metric, .imperial):
            return String(format: "%.1f", value * 2.20462)
        case (.imperial, .metric):
            return String(format: "%.1f", value / 2.20462)
        default:
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    OnboardingView()
}
