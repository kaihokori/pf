import SwiftUI
import Combine
import FirebaseAuth
import SwiftData

struct OnboardingView: View {
    var initialName: String? = nil
    var isRetake: Bool = false
    var onComplete: (() -> Void)? = nil
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var isKeyboardVisible = false
    @State private var isSaving = false

    init(initialName: String? = nil, existingAccount: Account? = nil, isRetake: Bool = false, onComplete: (() -> Void)? = nil) {
        self.initialName = initialName
        self.isRetake = isRetake
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(initialName: initialName, isRetake: isRetake, existingAccount: existingAccount))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackground(theme: .other)
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        ProgressBarView(currentIndex: viewModel.currentStepIndex, totalSteps: viewModel.steps.count)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStepIndex)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                if let symbol = viewModel.currentStep.symbol {
                                    Image(systemName: symbol)
                                        .font(.title2.weight(.semibold))
                                }
                                Text(viewModel.currentStep.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.primary)
                            .padding(.top)
                            .frame(maxWidth: .infinity, alignment: .center)

                            if let subtitle = viewModel.currentStep.subtitle {
                                Text(subtitle)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Text(viewModel.currentStep.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let description2 = viewModel.currentStep.description2 {
                                Text(description2)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                Color.clear.frame(height: 0).id("onboarding-top")
                                switch viewModel.currentStep {
                                case .accountSetup:
                                    AccountSetupStepView(viewModel: viewModel)
                                case .nutritionTracking:
                                    NutritionTrackingStepView(viewModel: viewModel)
                                case .dailySupplements:
                                    DailySupplementsStepView(viewModel: viewModel)
                                case .workoutSupplements:
                                    WorkoutSupplementsStepView(viewModel: viewModel)
                                case .dailyTasks:
                                    DailyTasksStepView(viewModel: viewModel)
                                case .goals:
                                    GoalsStepView(viewModel: viewModel)
                                case .habits:
                                    HabitsStepView(viewModel: viewModel)
                                case .workoutTracking:
                                    WorkoutTrackingStepView(viewModel: viewModel)
                                case .weightsTracking:
                                    WeightsTrackingStepView(viewModel: viewModel)
                                case .expenses:
                                    ExpensesStepView(viewModel: viewModel)
                                case .sports:
                                    SportsStepView(viewModel: viewModel)
                                case .itinerary:
                                    TravelStepView(viewModel: viewModel)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .id(viewModel.currentStep)
                        .scrollDismissesKeyboard(.immediately)
                        .onChange(of: viewModel.currentStep) { _, _ in
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo("onboarding-top", anchor: .top)
                                }
                            }
                        }
                        .onAppear {
                            proxy.scrollTo("onboarding-top", anchor: .top)
                            enforceLimitsAndSave()
                        }
                    }

                    let trialEligible = viewModel.isLastStep && !viewModel.isRetake && !subscriptionManager.hasProAccess && subscriptionManager.trialStartDate == nil

                    if trialEligible {
                        Text("By continuing you'll begin a 14 day trial of Pro")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !viewModel.isLastStep {
                        Text("You can modify this later")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        if viewModel.isFirstStep && viewModel.isRetake {
                            Button(action: { dismiss() }) {
                                Text("Close")
                                    .font(.headline)
                                    .foregroundColor(Color.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .surfaceCard(16)
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        } else if !viewModel.isFirstStep {
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
                            if isSaving && isRetake {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .surfaceCard(16, fill: Color.accentColor, shadowOpacity: 0.12)
                            } else {
                                Text(viewModel.buttonTitle)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .surfaceCard(16, fill: Color.accentColor, shadowOpacity: 0.12)
                            }
                        }
                        .disabled(isSaving && isRetake)
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isFirstStep)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Invalid Input"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                VStack {
                    Spacer()
                    KeyboardDismissBar(isVisible: isKeyboardVisible) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .interactiveDismissDisabled()
        }
    }

    @State private var showAlert = false
    @State private var alertMessage = ""

    private func enforceLimitsAndSave() {
        guard !subscriptionManager.hasProAccess else { return }
        
        let changed = viewModel.enforceLimits()
        
        if changed && isRetake {
            saveAccountToStorage { success in
                if !success {
                    print("Failed to save enforced limits")
                }
            }
        }
    }

    private func saveAccountToStorage(completion: @escaping (Bool) -> Void) {
        // Build Account from collected onboarding fields and save to Firestore
        let uid = Auth.auth().currentUser?.uid

        let randomPaletteColor: () -> String = {
            ColorPalette.randomHex()
        }

        func resolvedColor(_ hex: String?) -> String {
            let trimmed = (hex ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? randomPaletteColor() : trimmed
        }

        // Map tracked macros
        let trackedMacros: [TrackedMacro] = {
            let base: [TrackedMacro] = [
                TrackedMacro(name: "Protein", target: Double(viewModel.proteinValue) ?? 0, unit: viewModel.proteinUnit, colorHex: "#FF3B30"),
                TrackedMacro(name: "Carbs", target: Double(viewModel.carbohydrateValue) ?? 0, unit: viewModel.carbohydrateUnit, colorHex: "#34C759"),
                TrackedMacro(name: "Fats", target: Double(viewModel.fatValue) ?? 0, unit: viewModel.fatUnit, colorHex: "#FF9500"),
                TrackedMacro(name: "Water", target: Double(viewModel.waterIntakeValue) ?? 0, unit: viewModel.waterUnit, colorHex: "#32ADE6")
            ]

            let custom = viewModel.customMacros.map { macro in
                TrackedMacro(
                    id: macro.id,
                    name: macro.name,
                    target: macro.target,
                    unit: macro.unit,
                    colorHex: resolvedColor(macro.colorHex)
                )
            }

            return base + custom
        }()
        
        // Map supplements
        let nutritionSupplements = viewModel.dailySupplements
        let workoutSupplements = viewModel.workoutSupplementsList
        
        // Map daily tasks
        let dailyTasks = viewModel.dailyTasks.map { task in
            DailyTaskDefinition(
                id: task.id,
                name: task.name,
                time: task.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "09:00" : task.time,
                colorHex: resolvedColor(task.colorHex),
                repeats: task.repeats
            )
        }
        
        // Map goals
        var goals = viewModel.goals
        if let selectedGoal = viewModel.selectedGoal {
            let title = selectedGoal.displayName
            if !goals.contains(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) {
                let defaultDue = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
                goals.append(GoalItem(title: title, note: "", dueDate: defaultDue))
            }
        }
        
        // Map habits
        let habits = viewModel.habits.map { habit in
            HabitDefinition(id: habit.id, name: habit.name, colorHex: resolvedColor(habit.colorHex))
        }
        
        // Map workout schedule (selected days now represent typical rest days)
        let autoRestDayIndices = viewModel.selectedWorkoutDays.map { $0.id }.sorted()
        let sortedBodyParts = viewModel.trackedBodyParts.sorted()
        let resolvedBodyParts = sortedBodyParts.isEmpty ? [] : sortedBodyParts
        let workoutSchedule = viewModel.alignedWorkoutSchedule(using: resolvedBodyParts)
        
        // Map weight groups (body parts)
        let weightGroups = sortedBodyParts.map { part in
            // Create the body group with a single empty exercise so the user can name sets later.
            WeightGroupDefinition(name: part, exercises: [WeightExerciseDefinition(name: "")])
        }
        
        // Calculate calorie goal if not set
        var calorieGoal = Int(viewModel.calorieValue) ?? 0
        if calorieGoal == 0 {
            let p = Double(viewModel.proteinValue) ?? 0
            let c = Double(viewModel.carbohydrateValue) ?? 0
            let f = Double(viewModel.fatValue) ?? 0
            calorieGoal = Int((p * 4) + (c * 4) + (f * 9))
        }
        
        // Fetch existing account or create new
        var account: Account
        if let uid = uid {
            let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == uid })
            if let existing = try? modelContext.fetch(descriptor).first {
                account = existing
            } else {
                account = Account(id: uid)
                modelContext.insert(account)
            }
        } else {
            // Fallback for unauthenticated (shouldn't happen in this flow usually)
            account = Account()
            modelContext.insert(account)
        }
        
        // Update properties
        account.name = viewModel.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        account.gender = viewModel.selectedGender?.rawValue
        account.dateOfBirth = viewModel.birthDate
        account.height = heightInCentimeters()
        account.weight = weightInKilograms()
        account.unitSystem = viewModel.unitSystem.rawValue
        account.activityLevel = viewModel.selectedActivityLevel.rawValue
        account.maintenanceCalories = Int(viewModel.maintenanceCaloriesValue) ?? 0
        account.calorieGoal = calorieGoal
        account.weightGoalRaw = viewModel.selectedWeightGoal?.rawValue
        account.macroStrategyRaw = viewModel.selectedMacroStrategy.rawValue
        
        account.startWeekOn = account.startWeekOn?.isEmpty == false ? account.startWeekOn : "monday"
        account.autoRestDayIndices = autoRestDayIndices
        account.workoutSchedule = workoutSchedule
        account.trackedMacros = trackedMacros
        account.goals = goals
        account.habits = habits
        account.workoutSupplements = workoutSupplements
        account.nutritionSupplements = nutritionSupplements
        account.dailyTasks = dailyTasks
        
        // New sections
        account.expenseCategories = viewModel.expenseCategories.map { category in
            ExpenseCategory(id: category.id, name: category.name, colorHex: resolvedColor(category.colorHex))
        }
        account.sports = viewModel.sports.map { sport in
            SportConfig(id: sport.id, name: sport.name, colorHex: resolvedColor(sport.colorHex), metrics: sport.metrics)
        }
        account.itineraryEvents = viewModel.itineraryEvents
        account.expenseCurrencySymbol = account.expenseCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Account.deviceCurrencySymbol : account.expenseCurrencySymbol
        
        // Only update weight groups if user selected some, otherwise keep defaults or existing
        if !weightGroups.isEmpty {
            account.weightGroups = weightGroups
        } else if account.weightGroups.isEmpty {
            account.weightGroups = WeightGroupDefinition.defaults
        }

        // Set trial end if not already recorded
        if account.trialPeriodEnd == nil {
            account.trialPeriodEnd = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        }

        // Seed today's Day with calorie goals and macro focus so charts reflect onboarding choices immediately.
        let weightUnitRaw = viewModel.unitSystem == .imperial ? "lbs" : "kg"
        let today = Calendar.current.startOfDay(for: Date())
        let day = Day.fetchOrCreate(for: today, in: modelContext, trackedMacros: trackedMacros)
        day.calorieGoal = calorieGoal
        day.maintenanceCalories = account.maintenanceCalories
        day.weightGoalRaw = account.weightGoalRaw
        day.macroStrategyRaw = account.macroStrategyRaw
        day.weightUnitRaw = weightUnitRaw
        day.ensureMacroConsumptions(for: trackedMacros)
        if !dailyTasks.isEmpty {
            day.dailyTaskCompletions = dailyTasks.map { DailyTaskCompletion(id: $0.id, isCompleted: false) }
        }
        if !habits.isEmpty {
            day.habitCompletions = habits.map { HabitCompletion(id: UUID().uuidString, habitId: $0.id, isCompleted: false) }
        }

        // Save to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("Failed to save account to SwiftData: \(error)")
        }
        
        // Schedule notifications
        // Daily Tasks
        if UserDefaults.standard.object(forKey: "alerts.dailyTasksEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleDailyTaskNotifications(dailyTasks)
        } else {
            NotificationsHelper.removeDailyTaskNotifications()
        }

        // Habits
        if UserDefaults.standard.object(forKey: "alerts.habitsEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleHabitNotifications(habits)
        } else {
            NotificationsHelper.removeHabitNotifications()
        }

        // Daily Check-In
        if UserDefaults.standard.object(forKey: "alerts.dailyCheckInEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleDailyCheckInNotifications(autoRestIndices: Set(account.autoRestDayIndices), completedIndices: [])
        } else {
            NotificationsHelper.removeDailyCheckInNotifications()
        }

        // Weekly Progress
        if UserDefaults.standard.object(forKey: "alerts.weeklyProgressEnabled") as? Bool ?? true {
            let time = UserDefaults.standard.double(forKey: "alerts.weeklyProgressTime")
            let resolvedTime = time == 0 ? 9 * 3600 : time
            NotificationsHelper.scheduleWeeklyProgressNotifications(time: resolvedTime)
        } else {
            NotificationsHelper.removeWeeklyProgressNotifications()
        }

        if UserDefaults.standard.object(forKey: "alerts.weeklyScheduleEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleWeeklyScheduleNotifications(workoutSchedule)
        } else {
            NotificationsHelper.removeWeeklyScheduleNotifications()
        }
        
        if UserDefaults.standard.object(forKey: "alerts.itineraryEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleItineraryNotifications(account.itineraryEvents)
        } else {
            NotificationsHelper.removeItineraryNotifications()
        }

        let defaults = UserDefaults.standard
        let nutritionEnabled = defaults.object(forKey: "alerts.nutritionSupplementsEnabled") as? Bool ?? true
        let nutritionTime = defaults.object(forKey: "alerts.nutritionSupplementsTime") as? Double ?? (9 * 3600)
        if nutritionEnabled {
            NotificationsHelper.scheduleNutritionSupplementNotifications(account.nutritionSupplements, time: nutritionTime)
        } else {
            NotificationsHelper.removeNutritionSupplementNotifications()
        }

        let workoutSuppEnabled = defaults.object(forKey: "alerts.workoutSupplementsEnabled") as? Bool ?? true
        let workoutSuppTime = defaults.object(forKey: "alerts.workoutSupplementsTime") as? Double ?? (16 * 3600)
        if workoutSuppEnabled {
            NotificationsHelper.scheduleWorkoutSupplementNotifications(account.workoutSupplements, time: workoutSuppTime)
        } else {
            NotificationsHelper.removeWorkoutSupplementNotifications()
        }

        let accountService = AccountFirestoreService()
        let dayService = DayFirestoreService()

        accountService.saveAccount(account, forceOverwrite: true) { accountSuccess in
            if let uid = account.id {
                accountService.updateTrialPeriodEnd(for: uid, date: account.trialPeriodEnd)
            }
            dayService.saveDay(day, forceWrite: true) { daySuccess in
                // Ensure SubscriptionManager immediately reflects the saved trial end
                    if let end = account.trialPeriodEnd {
                        Task { @MainActor in
                            subscriptionManager.restoreTrialIfNeeded(trialEnd: end)
                        }

                        // Persist a lightweight subscription status metadata for analytics immediately
                        if let uid = Auth.auth().currentUser?.uid {
                            Task {
                                let status = subscriptionManager.subscriptionStatusDescription(trialEndDate: account.trialPeriodEnd, ignoreDebugOverride: true)
                                await accountService.updateSubscriptionStatus(for: uid, status: status)
                            }
                        }
                    }

                DispatchQueue.main.async {
                    completion(accountSuccess && daySuccess)
                }
            }
        }
    }

    private func handleContinue() {
        // If the user filled a "new" row but didn't tap +, add it automatically for the current step
        func flushPendingForCurrentStep() {
            switch viewModel.currentStep {
            case .nutritionTracking:
                if !viewModel.newMacroName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddCustomMacros {
                    viewModel.addCustomMacro()
                }
            case .dailySupplements:
                if !viewModel.newDailySupplementName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddDailySupplements {
                    viewModel.addDailySupplement()
                }
            case .workoutSupplements:
                if !viewModel.newWorkoutSupplementName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddWorkoutSupplements {
                    viewModel.addWorkoutSupplement()
                }
            case .dailyTasks:
                if !viewModel.newTaskName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddDailyTasks {
                    viewModel.addDailyTask()
                }
            case .goals:
                if !viewModel.newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddGoals {
                    viewModel.addGoal()
                }
            case .habits:
                if !viewModel.newHabitName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddHabits {
                    viewModel.addHabit()
                }
            case .workoutTracking:
                // `newBodyPart` is local to the view; nothing to flush here
                break
            case .sports:
                if !viewModel.newSportName.trimmingCharacters(in: .whitespaces).isEmpty,
                   viewModel.canAddSports {
                    viewModel.addSport()
                }
            case .itinerary:
                if !viewModel.newEventName.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.addItineraryEvent()
                }
            default:
                break
            }
        }

        flushPendingForCurrentStep()

        if viewModel.canContinue {
            if viewModel.isLastStep {
                if isRetake {
                    isSaving = true
                }
                saveAccountToStorage { success in
                    if isRetake {
                        isSaving = false
                    }
                    if success {
                        _ = subscriptionManager.activateOnboardingTrialIfEligible()
                        hasCompletedOnboarding = true
                        onComplete?()
                        dismiss()
                    } else {
                        alertMessage = "Failed to save account setup. Please try again."
                        showAlert = true
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
        case .accountSetup:
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
        case .nutritionTracking:
            if let error = validateMacroField(value: viewModel.calorieValue, label: "Calorie target", min: 500, max: 20000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.proteinValue, label: "Protein target", min: 0, max: 10000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.carbohydrateValue, label: "Carbohydrate target", min: 0, max: 20000) {
                return error
            }
            if let error = validateMacroField(value: viewModel.fatValue, label: "Fat target", min: 0, max: 10000) {
                return error
            }
            guard parsedNumber(from: viewModel.waterIntakeValue) != nil else {
                return "Please enter a valid water intake target."
            }
            if viewModel.selectedWeightGoal == nil {
                return "Please select your weight goal."
            }
            return "Please complete all fields."
        case .dailySupplements:
            return "Please complete all fields."
        case .workoutSupplements:
            return "Please complete all fields."
        case .dailyTasks:
            return "Please complete all fields."
        case .goals:
            return "Please complete all fields."
        case .habits:
            return "Please complete all fields."
        case .workoutTracking:
            return "Please complete all fields."
        case .weightsTracking:
            return "Please complete all fields."
        case .expenses:
            return "Please complete all fields."
        case .sports:
            return "Please complete all fields."
        case .itinerary:
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

private struct AccountSetupStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showActivityExplainer = false
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("You must be at least 13 years old to continue.")
                    Spacer()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

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
            if viewModel.selectedGender == .preferNotSay {
                Text("Automatic maintenance calorie calculations are disabled unless you select Male or Female.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
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
            
            ActivityLevelSelector(selection: $viewModel.selectedActivityLevel)
            
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showActivityExplainer) {
            ActivityLevelExplainer()
        }
    }
}

private struct NutritionTrackingStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showWeightGoalExplainer = false
    @State private var showMacroStrategyExplainer = false
    @State private var showMaintenanceExplainer = false
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle("Maintenance Calories")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maintenance Calories")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField(
                            "0",
                            text: Binding(
                                get: { viewModel.maintenanceCaloriesValue },
                                set: { viewModel.updateMaintenanceCalories($0) }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        Text("cal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        let disableAuto = viewModel.shouldDisableMaintenanceAuto
                        Button(action: { viewModel.calculateMaintenanceCalories() }) {
                            Text("Auto")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                                        .fill(Color.accentColor)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(disableAuto)
                        .opacity(disableAuto ? 0.5 : 1)
                    }
                    .padding()
                    .surfaceCard(12)

                    // Tap for Explanation (opens Maintenance Calories Explainer)
                    Button(action: {
                        showMaintenanceExplainer = true
                    }) {
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
            }

            SectionTitle("Weight Goal")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                ForEach(MacroCalculator.WeightGoalOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: viewModel.selectedWeightGoal == option
                    ) {
                        viewModel.selectWeightGoal(option)
                    }
                }
            }

            Button(action: { showWeightGoalExplainer = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("Tap for Explanation")
                    Spacer()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            SectionTitle("Macro Strategy")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                ForEach(MacroCalculator.MacroDistributionStrategy.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: viewModel.selectedMacroStrategy == option
                    ) {
                        viewModel.selectedMacroStrategy = option
                    }
                }
            }

            Button(action: { showMacroStrategyExplainer = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("Tap for Explanation")
                    Spacer()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            HStack {
                SectionTitle("Target Calories")
                    // .font(.footnote)
                    // .foregroundStyle(.secondary)
                Spacer()
                let disableAuto = viewModel.shouldDisableCalorieAuto
                Button(action: { viewModel.autoCalculateMacro(.calories) }) {
                    Text("Auto Calculate Target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(disableAuto)
                .opacity(disableAuto ? 0.5 : 1)
            }
            .padding(.bottom, -8)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.calorieValue },
                            set: { viewModel.updateMacroField(.calories, newValue: $0) }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    Text("cal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .surfaceCard(12)
            }

            HStack {
                SectionTitle("Tracked Macros")
                Spacer()
                Button(action: { viewModel.autoCalculateAllMacros() }) {
                    Text("Auto Calculate Macros")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, -8)
            
            VStack(spacing: 16) {
                // Protein
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Protein")
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            let amountBinding = Binding<String>(
                                get: {
                                    let value = viewModel.proteinValue
                                    if value.isEmpty { return "" }
                                    let unit = viewModel.proteinUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return unit.isEmpty ? value : "\(value) \(unit)"
                                },
                                set: { newText in
                                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let digitSet = CharacterSet(charactersIn: "0123456789.")
                                    let digits = trimmed.unicodeScalars.filter { digitSet.contains($0) }
                                    let suffixScalars = trimmed.unicodeScalars.filter { !digitSet.contains($0) }
                                    let numberString = String(String.UnicodeScalarView(digits))
                                    
                                    viewModel.updateMacroField(.protein, newValue: numberString)
                                    
                                    let newUnit = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newUnit.isEmpty {
                                        viewModel.proteinUnit = newUnit
                                    }
                                }
                            )

                            TextField("Amount", text: amountBinding)
                                .keyboardType(.default)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    // No remove for default macros - keep layout consistent
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.clear)
                }
                .padding()
                .surfaceCard(12)

                // Fats
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fats")
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            let amountBinding = Binding<String>(
                                get: {
                                    let value = viewModel.fatValue
                                    if value.isEmpty { return "" }
                                    let unit = viewModel.fatUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return unit.isEmpty ? value : "\(value) \(unit)"
                                },
                                set: { newText in
                                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let digitSet = CharacterSet(charactersIn: "0123456789.")
                                    let digits = trimmed.unicodeScalars.filter { digitSet.contains($0) }
                                    let suffixScalars = trimmed.unicodeScalars.filter { !digitSet.contains($0) }
                                    let numberString = String(String.UnicodeScalarView(digits))
                                    
                                    viewModel.updateMacroField(.fats, newValue: numberString)
                                    
                                    let newUnit = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newUnit.isEmpty {
                                        viewModel.fatUnit = newUnit
                                    }
                                }
                            )

                            TextField("Amount", text: amountBinding)
                                .keyboardType(.default)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.clear)
                }
                .padding()
                .surfaceCard(12)

                // Carbohydrates
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Carbohydrates")
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            let amountBinding = Binding<String>(
                                get: {
                                    let value = viewModel.carbohydrateValue
                                    if value.isEmpty { return "" }
                                    let unit = viewModel.carbohydrateUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return unit.isEmpty ? value : "\(value) \(unit)"
                                },
                                set: { newText in
                                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let digitSet = CharacterSet(charactersIn: "0123456789.")
                                    let digits = trimmed.unicodeScalars.filter { digitSet.contains($0) }
                                    let suffixScalars = trimmed.unicodeScalars.filter { !digitSet.contains($0) }
                                    let numberString = String(String.UnicodeScalarView(digits))
                                    
                                    viewModel.updateMacroField(.carbohydrates, newValue: numberString)
                                    
                                    let newUnit = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newUnit.isEmpty {
                                        viewModel.carbohydrateUnit = newUnit
                                    }
                                }
                            )

                            TextField("Amount", text: amountBinding)
                                .keyboardType(.default)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.clear)
                }
                .padding()
                .surfaceCard(12)

                // Water Intake
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Water Intake")
                            .fontWeight(.medium)
                        HStack(spacing: 6) {
                            let amountBinding = Binding<String>(
                                get: {
                                    let value = viewModel.waterIntakeValue
                                    if value.isEmpty { return "" }
                                    let unit = viewModel.waterUnit.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return unit.isEmpty ? value : "\(value) \(unit)"
                                },
                                set: { newText in
                                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let digitSet = CharacterSet(charactersIn: "0123456789.")
                                    let digits = trimmed.unicodeScalars.filter { digitSet.contains($0) }
                                    let suffixScalars = trimmed.unicodeScalars.filter { !digitSet.contains($0) }
                                    let numberString = String(String.UnicodeScalarView(digits))
                                    
                                    viewModel.updateMacroField(.water, newValue: numberString)
                                    
                                    let newUnit = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !newUnit.isEmpty {
                                        viewModel.waterUnit = newUnit
                                    }
                                }
                            )

                            TextField("Amount", text: amountBinding)
                                .keyboardType(.default)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.clear)
                }
                .padding()
                .surfaceCard(12)
            }

            if !viewModel.customMacros.isEmpty {
                VStack(spacing: 8) {
                    ForEach($viewModel.customMacros) { $macro in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(macro.name)
                                    .fontWeight(.medium)
                                HStack(spacing: 6) {
                                    let amountBinding = Binding<String>(
                                        get: {
                                            let value = macro.target
                                            let formatted = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
                                            let unit = macro.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                                            return unit.isEmpty ? formatted : "\(formatted) \(unit)"
                                        },
                                        set: { newText in
                                            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            guard !trimmed.isEmpty else { return }
                                            let digitSet = CharacterSet(charactersIn: "0123456789.")
                                            let digits = trimmed.unicodeScalars.filter { digitSet.contains($0) }
                                            let suffixScalars = trimmed.unicodeScalars.filter { !digitSet.contains($0) }
                                            let numberString = String(String.UnicodeScalarView(digits))
                                            guard let amount = Double(numberString) else { return }
                                            let newUnit = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
                                            macro.target = amount
                                            if !newUnit.isEmpty {
                                                macro.unit = newUnit
                                            }
                                        }
                                    )

                                    TextField("Amount", text: amountBinding)
                                        .keyboardType(.default)
                                        .frame(width: 120, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { viewModel.removeCustomMacro(macro) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }
            
            // Quick Add - hide presets that are already tracked (defaults + custom)
            let trackedNames = Set(viewModel.customMacros.map { $0.name.lowercased() } + ["Protein", "Carbs", "Fats", "Water"].map { $0.lowercased() })
            let availableMacroPresets = MacroPreset.allCases.filter { preset in
                !trackedNames.contains(preset.displayName.lowercased())
            }

            if !availableMacroPresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availableMacroPresets, id: \.self) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(preset.displayName)
                                    .fontWeight(.medium)
                                Text(preset.allowedLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { addPresetMacro(preset) }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canAddCustomMacros)
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Input row for adding a new custom macro (keeps same style)
            HStack(spacing: 8) {
                TextField("Name", text: $viewModel.newMacroName)
                    .frame(maxWidth: .infinity)
                // Combined amount + unit field (e.g. "100 g" or "2500ml")
                TextField("Amount (e.g. 100 g)", text: $viewModel.newMacroAmount)
                    .keyboardType(.default)
                    .frame(width: 170)

                Button(action: { viewModel.addCustomMacro() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
                .disabled(!viewModel.canAddCustomMacros)
            }
            .padding()
            .surfaceCard(12)

            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxCustomMacros) Macros")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showMaintenanceExplainer) {
                MaintenanceCaloriesExplainer()
            }
            .sheet(isPresented: $showWeightGoalExplainer) {
                NavigationStack {
                    WeightGoalExplainer()
                        .padding(.horizontal, 18)
                        .navigationTitle("Weight Goals")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showWeightGoalExplainer = false
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                }
            }
            .sheet(isPresented: $showMacroStrategyExplainer) {
                NavigationStack {
                    MacroStrategyExplainer()
                        .padding(.horizontal, 18)
                        .navigationTitle("Macro Strategies")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showMacroStrategyExplainer = false
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                }
            }

    
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addPresetMacro(_ preset: MacroPreset) {
        // Parse allowedLabel like "100g" or "2500mL" into numeric target and unit
        let allowed = preset.allowedLabel
        let digits = allowed.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789.").contains($0) }
        let suffixScalars = allowed.unicodeScalars.filter { !CharacterSet(charactersIn: "0123456789.").contains($0) }
        let numberString = String(String.UnicodeScalarView(digits))
        let suffix = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        let targetValue = Double(numberString) ?? 0

        let colorHex: String = {
            switch preset {
            case .protein: return "#D84A4A"
            case .carbs: return "#E6C84F"
            case .fats: return "#E39A3B"
            case .fibre: return "#4CAF6A"
            case .water: return "#4A7BD0"
            case .sodium: return "#4FB6C6"
            case .potassium: return "#7A5FD1"
            case .sugar: return "#C85FA8"
            case .cholesterol: return "#2a65edff"
            }
        }()

        let macro = TrackedMacro(name: preset.displayName, target: targetValue, unit: suffix.isEmpty ? "g" : suffix, colorHex: colorHex)
        viewModel.customMacros.append(macro)
    }

}

private struct DailySupplementsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var dailyAmounts: [String: String] = [:]

    private let dailyPresets: [Supplement] = [
        Supplement(name: "Vitamin D", amountLabel: "50 μg"),
        Supplement(name: "Vitamin B Complex", amountLabel: "50 mg"),
        Supplement(name: "Magnesium", amountLabel: "200 mg"),
        Supplement(name: "Probiotics", amountLabel: "10 Billion CFU"),
        Supplement(name: "Fish Oil", amountLabel: "1000 mg"),
        Supplement(name: "Ashwagandha", amountLabel: "500 mg"),
        Supplement(name: "Melatonin", amountLabel: "3 mg"),
        Supplement(name: "Calcium", amountLabel: "500 mg"),
        Supplement(name: "Iron", amountLabel: "18 mg"),
        Supplement(name: "Zinc", amountLabel: "15 mg"),
        Supplement(name: "Vitamin C", amountLabel: "1000 mg"),
        Supplement(name: "Caffeine", amountLabel: "200 mg")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Tracked Supplements
            if !viewModel.dailySupplements.isEmpty {
                SectionTitle("Tracked Supplements")
                VStack(spacing: 8) {
                    ForEach($viewModel.dailySupplements) { $supplement in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Name", text: $supplement.name)
                                    .fontWeight(.medium)
                                TextField(
                                    "Amount",
                                    text: Binding(
                                        get: { supplement.amountLabel ?? "" },
                                        set: { supplement.amountLabel = $0.isEmpty ? nil : $0 }
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { viewModel.removeDailySupplement(supplement) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            SectionTitle("Quick Add")
            VStack(spacing: 8) {
                let trackedNames = Set(viewModel.dailySupplements.map { $0.name.lowercased() })
                let availablePresets = dailyPresets.filter { !trackedNames.contains($0.name.lowercased()) }

                ForEach(availablePresets) { option in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.name)
                                .fontWeight(.medium)
                            Text(option.amountLabel ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            let amount = option.amountLabel ?? ""
                            let sup = Supplement(name: option.name, amountLabel: amount.isEmpty ? nil : amount)
                            viewModel.dailySupplements.append(sup)
                            dailyAmounts[option.name] = option.amountLabel ?? ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canAddDailySupplements)
                        .opacity(viewModel.canAddDailySupplements ? 1 : 0.5)
                    }
                    .padding()
                    .surfaceCard(12)
                }
            }

            // Custom Supplements
            SectionTitle("Custom Supplements")
            HStack(spacing: 8) {
                TextField("Name", text: $viewModel.newDailySupplementName)
                    .frame(maxWidth: .infinity)
                TextField("Amount", text: $viewModel.newDailySupplementAmount)
                    .frame(width: 120)

                Button(action: { viewModel.addDailySupplement() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
                .disabled(!viewModel.canAddDailySupplements)
            }
            .padding()
            .surfaceCard(12)
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxDailySupplements) Daily Supplements")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if dailyAmounts.isEmpty {
                for preset in dailyPresets {
                    dailyAmounts[preset.name] = preset.amountLabel ?? ""
                }
            }
        }
    }

}

private struct WorkoutSupplementsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var workoutAmounts: [String: String] = [:]
    
    private let workoutPresets: [Supplement] = [
        Supplement(name: "Pre-workout", amountLabel: "1 scoop"),
        Supplement(name: "Creatine", amountLabel: "5 g"),
        Supplement(name: "Whey Protein", amountLabel: "30 g"),
        Supplement(name: "BCAA", amountLabel: "10 g"),
        Supplement(name: "Electrolytes", amountLabel: "1 scoop")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Tracked Supplements
            if !viewModel.workoutSupplementsList.isEmpty {
                SectionTitle("Tracked Supplements")
                VStack(spacing: 8) {
                    ForEach($viewModel.workoutSupplementsList) { $supplement in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Name", text: $supplement.name)
                                    .fontWeight(.medium)
                                TextField(
                                    "Amount",
                                    text: Binding(
                                        get: { supplement.amountLabel ?? "" },
                                        set: { supplement.amountLabel = $0.isEmpty ? nil : $0 }
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { viewModel.removeWorkoutSupplement(supplement) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            SectionTitle("Quick Add")
            VStack(spacing: 8) {
                let trackedNames = Set(viewModel.workoutSupplementsList.map { $0.name.lowercased() })
                let availablePresets = workoutPresets.filter { !trackedNames.contains($0.name.lowercased()) }

                ForEach(availablePresets) { option in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.name)
                                .fontWeight(.medium)
                            Text(option.amountLabel ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            let amount = option.amountLabel ?? ""
                            let sup = Supplement(name: option.name, amountLabel: amount.isEmpty ? nil : amount)
                            viewModel.workoutSupplementsList.append(sup)
                            workoutAmounts[option.name] = option.amountLabel ?? ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canAddWorkoutSupplements)
                        .opacity(viewModel.canAddWorkoutSupplements ? 1 : 0.5)
                    }
                    .padding()
                    .surfaceCard(12)
                }
            }

            // Custom Supplements
            SectionTitle("Custom Supplements")
            HStack(spacing: 8) {
                TextField("Name", text: $viewModel.newWorkoutSupplementName)
                    .frame(maxWidth: .infinity)
                TextField("Amount", text: $viewModel.newWorkoutSupplementAmount)
                    .frame(width: 120)

                Button(action: { viewModel.addWorkoutSupplement() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
                .disabled(!viewModel.canAddWorkoutSupplements)
            }
            .padding()
            .surfaceCard(12)
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxWorkoutSupplements) Workout Supplements")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if workoutAmounts.isEmpty {
                for preset in workoutPresets {
                    workoutAmounts[preset.name] = preset.amountLabel ?? ""
                }
            }
        }
    }
}

private struct DailyTasksStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    private let taskPresets = ["Wake Up", "Coffee", "Stretch", "Lunch", "Workout"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !viewModel.dailyTasks.isEmpty {
                SectionTitle("Tracked Tasks")
                VStack(spacing: 8) {
                    ForEach($viewModel.dailyTasks) { $task in
                        HStack {
                            VStack(alignment: .leading) {
                                TextField("Task Name", text: $task.name)
                                    .fontWeight(.medium)
                                DatePicker("", selection: Binding(
                                    get: {
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "HH:mm"
                                        return formatter.date(from: task.time) ?? Date()
                                    },
                                    set: { newDate in
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "HH:mm"
                                        task.time = formatter.string(from: newDate)
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                            Spacer()
                            Button(action: { viewModel.removeDailyTask(task) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            let availablePresets = taskPresets.filter { preset in
                !viewModel.dailyTasks.contains(where: { $0.name == preset })
            }
            
            if !availablePresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availablePresets, id: \.self) { preset in
                        HStack {
                            Text(preset)
                            Spacer()
                            Button(action: {
                                let time: String = {
                                    switch preset {
                                    case "Wake Up": return "07:00"
                                    case "Coffee": return "08:00"
                                    case "Stretch": return "09:00"
                                    case "Lunch": return "12:30"
                                    case "Workout": return "18:00"
                                    default: return "09:00"
                                    }
                                }()
                                let task = DailyTaskDefinition(name: preset, time: time)
                                viewModel.dailyTasks.append(task)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(!viewModel.canAddDailyTasks)
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Custom Task
            SectionTitle("Custom Task", onIconTap: { isFocused = true })
            HStack(spacing: 12) {
                TextField("Name", text: $viewModel.newTaskName)
                    .focused($isFocused)
                DatePicker("", selection: $viewModel.newTaskTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: 90)
                Spacer(minLength: 0)
                Button(action: { viewModel.addDailyTask() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(!viewModel.canAddDailyTasks)
            }
            .padding()
            .surfaceCard(12)
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxDailyTasks) Daily Tasks")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GoalsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    private let goalPresets = ["10 min Walk", "Read 10 pages", "Prep healthy lunch"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Tracked Goals
            if !viewModel.goals.isEmpty {
                SectionTitle("Tracked Goals")
                VStack(spacing: 8) {
                    ForEach($viewModel.goals) { $goal in
                        HStack {
                            VStack(alignment: .leading) {
                                TextField("Goal Title", text: $goal.title)
                                    .fontWeight(.medium)
                                TextField("Note", text: $goal.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DatePicker("", selection: $goal.dueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            Spacer()
                            Button(action: { viewModel.removeGoal(goal) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            let availablePresets = goalPresets.filter { preset in
                !viewModel.goals.contains(where: { $0.title == preset })
            }
            
            if !availablePresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availablePresets, id: \.self) { preset in
                        HStack {
                            Text(preset)
                            Spacer()
                            Button(action: {
                                let today = Date()
                                let due: Date = {
                                    switch preset {
                                    case "10 min Walk": return today
                                    case "Read 10 pages": return Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today
                                    case "Prep healthy lunch": return Calendar.current.date(byAdding: .day, value: 14, to: today) ?? today
                                    default: return Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today
                                    }
                                }()
                                let goal = GoalItem(title: preset, dueDate: due)
                                viewModel.goals.append(goal)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(!viewModel.canAddGoals)
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Custom Goal
            SectionTitle("Custom Goal", onIconTap: { isFocused = true })
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Title", text: $viewModel.newGoalTitle)
                        .focused($isFocused)
                    DatePicker("", selection: $viewModel.newGoalDueDate, displayedComponents: .date)
                        .labelsHidden()
                    Spacer(minLength: 0)
                }
                .padding([.leading, .vertical])
                .surfaceCard(12)

                HStack(spacing: 12) {
                    TextField("Note (Optional)", text: $viewModel.newGoalNote)
                    Spacer(minLength: 0)
                    Button(action: { viewModel.addGoal() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .disabled(!viewModel.canAddGoals)
                }
                .padding()
                .surfaceCard(12)
            }
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxGoals) Goals")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    private let habitPresets = ["Morning Stretch", "Meditation", "Read"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
          // Tracked Habits
            if !viewModel.habits.isEmpty {
                SectionTitle("Tracked Habits")
                VStack(spacing: 8) {
                    ForEach($viewModel.habits) { $habit in
                        HStack {
                            TextField("Habit Name", text: $habit.name)
                                .fontWeight(.medium)
                            Spacer()
                            Button(action: { viewModel.removeHabit(habit) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            let availablePresets = habitPresets.filter { preset in
                !viewModel.habits.contains(where: { $0.name == preset })
            }
            
            if !availablePresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availablePresets, id: \.self) { preset in
                        HStack {
                            Text(preset)
                            Spacer()
                            Button(action: {
                                let habit = HabitDefinition(name: preset, colorHex: "#007AFF")
                                viewModel.habits.append(habit)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(!viewModel.canAddHabits)
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Custom Habit
            SectionTitle("Custom Habit", onIconTap: { isFocused = true })
            HStack(spacing: 12) {
                TextField("Name", text: $viewModel.newHabitName)
                    .focused($isFocused)
                Spacer(minLength: 0)
                Button(action: { viewModel.addHabit() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(!viewModel.canAddHabits)
            }
            .padding()
            .surfaceCard(12)
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxHabits) Habits")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutTrackingStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private let bodyPartPresets = ["Chest", "Back", "Legs", "Biceps", "Triceps", "Shoulders", "Abs", "Glutes"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle("Typical Rest Days")
            Text("Select the days you typically rest")
                .font(.footnote)
                .foregroundStyle(.secondary)
            WorkoutsPerWeekView(selectedDays: viewModel.selectedWorkoutDays) { day in
                viewModel.toggleDay(day)
                viewModel.regenerateWorkoutSchedule()
            }

            SectionTitle("Weekly Schedule")
            Text("Mark rest days and add sessions with time.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach($viewModel.workoutSchedule) { $day in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.day)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        if let weekday = Weekday.from(label: day.day), viewModel.selectedWorkoutDays.contains(weekday) {
                            // Rest day: no sessions shown.
                        } else {
                            ForEach($day.sessions) { $session in
                                let timeBinding = Binding<Date>(
                                    get: {
                                        var comps = DateComponents()
                                        comps.hour = session.hour
                                        comps.minute = session.minute
                                        return Calendar.current.date(from: comps) ?? Date()
                                    },
                                    set: { newDate in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                        session.hour = comps.hour ?? session.hour
                                        session.minute = comps.minute ?? session.minute
                                    }
                                )

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        TextField("Session name", text: $session.name)
                                            .textInputAutocapitalization(.words)
                                        Spacer(minLength: 0)
                                        Button(action: {
                                            if let idx = day.sessions.firstIndex(of: session) {
                                                day.sessions.remove(at: idx)
                                            }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                }
                                .padding(10)
                                .surfaceCard(10)
                            }

                            Button(action: {
                                day.sessions.append(WorkoutSession(name: ""))
                            }) {
                                Label("Add session", systemImage: "plus.circle.fill")
                                    .font(.footnote.weight(.semibold))
                            }
                            .disabled(day.sessions.count >= 3)
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .surfaceCard(14)
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WeightsTrackingStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var newBodyPart: String = ""
    private let bodyPartPresets = ["Chest", "Back", "Legs", "Biceps", "Triceps", "Shoulders", "Abs", "Glutes"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !viewModel.trackedBodyParts.isEmpty {
                SectionTitle("Tracked Body Parts")
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.trackedBodyParts).sorted(), id: \.self) { part in
                        HStack {
                            Text(part)
                                .fontWeight(.medium)
                            Spacer()
                            Button(action: {
                                viewModel.trackedBodyParts.remove(part)
                                viewModel.regenerateWorkoutSchedule()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            Button(action: { viewModel.autoFillBodyPartsFromSchedule() }) {
                Label("Auto-fill from schedule", systemImage: "wand.and.stars")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .surfaceCard(16, fill: Color.accentColor.opacity(0.12))
            }

            // Quick Add
            let availablePresets = bodyPartPresets.filter { !viewModel.trackedBodyParts.contains($0) }
            
            if !availablePresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availablePresets, id: \.self) { preset in
                        HStack {
                            Text(preset)
                            Spacer()
                            Button(action: {
                                viewModel.trackedBodyParts.insert(preset)
                                viewModel.regenerateWorkoutSchedule()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }
            
            // Custom Body Part
            SectionTitle("Custom Body Part")
            HStack(spacing: 12) {
                TextField("Add a body part...", text: $newBodyPart)
                    .onSubmit { addBodyPart() }
                Spacer(minLength: 0)
                Button(action: addBodyPart) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .surfaceCard(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addBodyPart() {
        let trimmed = newBodyPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.trackedBodyParts.insert(trimmed)
        viewModel.regenerateWorkoutSchedule()
        newBodyPart = ""
    }
}

private struct ExpensesStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                ForEach($viewModel.expenseCategories) { $category in
                    HStack {
                        Circle()
                            .fill(Color(hex: category.colorHex) ?? .gray)
                            .frame(width: 12, height: 12)
                        TextField("Category Name", text: $category.name)
                            .fontWeight(.medium)
                            .focused($focusedField, equals: category.id)
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                focusedField = category.id
                            }
                    }
                    .padding()
                    .surfaceCard(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SportsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private let sportPresets = SportConfig.defaults

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Tracked Sports
            if !viewModel.sports.isEmpty {
                SectionTitle("Tracked Sports")
                VStack(spacing: 8) {
                    ForEach($viewModel.sports) { $sport in
                        HStack {
                            TextField("Sport Name", text: $sport.name)
                                .fontWeight(.medium)
                            Spacer()
                            Button(action: { viewModel.removeSport(sport) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Quick Add
            let availablePresets = sportPresets.filter { preset in
                !viewModel.sports.contains(where: { $0.name == preset.name })
            }
            
            if !availablePresets.isEmpty {
                SectionTitle("Quick Add")
                VStack(spacing: 8) {
                    ForEach(availablePresets, id: \.self) { preset in
                        HStack {
                            Text(preset.name)
                            Spacer()
                            Button(action: {
                                viewModel.sports.append(preset)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .disabled(!viewModel.canAddSports)
                            .opacity(viewModel.canAddSports ? 1 : 0.5)
                        }
                        .padding()
                        .surfaceCard(12)
                    }
                }
            }

            // Custom Sport
            SectionTitle("Custom Sport")
            HStack(spacing: 12) {
                TextField("Sport Name", text: $viewModel.newSportName)
                Spacer(minLength: 0)
                Button(action: { viewModel.addSport() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(!viewModel.canAddSports)
            }
            .padding()
            .surfaceCard(12)
            VStack(alignment: .center) {
                Text("You can add up to \(viewModel.maxSports) Sports")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TravelStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            let imageName = colorScheme == .dark ? "travel_dark" : "travel_light"
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 460)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                .padding(.horizontal, 8)
                .padding(.top, -14)

            VStack(alignment: .center, spacing: 8) {
                Text("Plan Your adventures with ease")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                Text("You can add itineraries later from the Travel tab.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ProgressBarView: View {
    let currentIndex: Int
    let totalSteps: Int
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentIndex + 1) / Double(totalSteps)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)

                let accent: Color = themeManager.selectedTheme.accent(for: colorScheme)
                let gradientColors: [Color] = {
                    if themeManager.selectedTheme == .multiColour {
                        return [
                            Color(red: 0.8274509804, green: 0.9882352941, blue: 0.9411764706),
                            Color(red: 0.7450980392, green: 0.8196078431, blue: 0.9843137255),
                            Color(red: 0.737254902, green: 0.5215686275, blue: 0.9725490196),
                            Color(red: 0.7450980392, green: 0.4352941176, blue: 0.968627451)
                        ]
                    }
                    return [accent, accent.opacity(0.36)]
                }()
                let gradient = LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )

                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 8)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 8)
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
                        .surfaceCard(
                            12,
                            fill: system == unitSystem ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground)
                        )
                        .foregroundColor(system == unitSystem ? Color.accentColor : Color.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(system == unitSystem ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
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

public struct LabeledNumericFieldWithAuto: View {
    let label: String
    @Binding var value: String
    let unitLabel: String
    let onAuto: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                Text(unitLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(action: onAuto) {
                    Text("Auto")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
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
    var onIconTap: (() -> Void)?

    public init(_ text: String, onIconTap: (() -> Void)? = nil) {
        self.text = text
        self.onIconTap = onIconTap
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolFor(text))
                .font(.caption)
                .foregroundStyle(.secondary)
                .onTapGesture {
                    onIconTap?()
                }
            Text(text.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, -4)
    }

    private func symbolFor(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("tracked") { return "checkmark.seal.fill" }
        if lower.contains("quick add") || lower.contains("quick") { return "sparkles" }
        if lower.contains("custom") { return "pencil" }
        if lower.contains("macro") || lower.contains("calorie") { return "chart.pie.fill" }
        return "circle.grid.3x3.fill"
    }
}

final class OnboardingViewModel: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .accountSetup
    @Published var preferredName: String
    @Published var birthDate: Date = PumpDateRange.birthdate.upperBound

    @Published var selectedGender: GenderOption?
    @Published var unitSystem: UnitSystem = .metric
    @Published var heightValue: String = ""
    @Published var heightFeet: String = ""
    @Published var heightInches: String = ""
    @Published var weightValue: String = ""
    @Published var selectedActivityLevel: ActivityLevelOption = .moderatelyActive

    @Published var selectedGoal: GoalOption?
    @Published var selectedWorkoutDays: Set<Weekday> = [] // UI collects typical rest days; invert for workout calculations

    private var workoutDaysCount: Int {
        max(0, Weekday.allCases.count - selectedWorkoutDays.count)
    }
    @Published var selectedWeightGoal: MacroCalculator.WeightGoalOption?
    @Published var selectedMacroStrategy: MacroCalculator.MacroDistributionStrategy = .balanced
    @Published var maintenanceCaloriesValue: String = ""
    @Published var calorieValue: String = ""
    @Published var proteinValue: String = ""
    @Published var proteinUnit: String = "g"
    @Published var fatValue: String = ""
    @Published var fatUnit: String = "g"
    @Published var carbohydrateValue: String = ""
    @Published var carbohydrateUnit: String = "g"
    
    @Published var sodiumValue: String = ""
    @Published var waterIntakeValue: String = ""
    @Published var waterUnit: String = "ml"
    
    // Custom Macros & Supplements
    @Published var customMacros: [TrackedMacro] = []
    @Published var newMacroName: String = ""
    @Published var newMacroAmount: String = ""
    @Published var newMacroUnit: String = "g"
    
    @Published var dailySupplements: [Supplement] = []
    @Published var newDailySupplementName: String = ""
    @Published var newDailySupplementAmount: String = ""
    
    @Published var workoutSupplementsList: [Supplement] = []
    @Published var newWorkoutSupplementName: String = ""
    @Published var newWorkoutSupplementAmount: String = ""
    
    // New properties
    @Published var dailyTasks: [DailyTaskDefinition] = []
    @Published var newTaskName: String = ""
    @Published var newTaskTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    
    @Published var goals: [GoalItem] = []
    @Published var newGoalTitle: String = ""
    @Published var newGoalNote: String = ""
    @Published var newGoalDueDate: Date = Date().addingTimeInterval(86400 * 30)
    
    @Published var habits: [HabitDefinition] = []
    @Published var newHabitName: String = ""
    @Published var newHabitColor: Color = .blue
    
    @Published var trackedBodyParts: Set<String> = []
    @Published var workoutSchedule: [WorkoutScheduleItem] = Weekday.allCases.enumerated().map { idx, day in
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return WorkoutScheduleItem(day: dayNames[idx], sessions: [])
    }
    
    // Expenses, Sports, Travel
    @Published var expenseCategories: [ExpenseCategory] = ExpenseCategory.defaultCategories()
    
    @Published var sports: [SportConfig] = []
    @Published var newSportName: String = ""
    
    @Published var itineraryEvents: [ItineraryEvent] = []
    @Published var newEventName: String = ""
    @Published var newEventDate: Date = Date()
    @Published var newEventType: ItineraryCategory = .other
    
    private var lastCalculatedTargets: MacroTargetsSnapshot?
    let isRetake: Bool

    // Limits for onboarding additions
    let maxCustomMacros: Int = 4 // 4 base + 4 custom = 8 total
    let maxDailySupplements: Int = 8
    let maxDailyTasks: Int = 12
    let maxGoals: Int = 12
    let maxHabits: Int = 3
    let maxWorkoutSupplements: Int = 8
    let maxSports: Int = 8

    var canAddCustomMacros: Bool { customMacros.count < maxCustomMacros }
    var canAddDailySupplements: Bool { dailySupplements.count < maxDailySupplements }
    var canAddWorkoutSupplements: Bool { workoutSupplementsList.count < maxWorkoutSupplements }
    var canAddDailyTasks: Bool { dailyTasks.count < maxDailyTasks }
    var canAddGoals: Bool { goals.count < maxGoals }
    var canAddHabits: Bool { habits.count < maxHabits }
    var canAddSports: Bool { sports.count < maxSports }

    var steps: [OnboardingStep] {
        if isRetake {
            return [
                .accountSetup,
                .nutritionTracking,
                .dailySupplements,
                .habits,
                .dailyTasks,
                .expenses,
                .workoutTracking,
                .weightsTracking,
                .workoutSupplements,
                .sports,
                .itinerary
            ]
        } else {
            return [
                .accountSetup,
                .nutritionTracking,
                .dailySupplements,
                .habits,
                .dailyTasks,
                .expenses,
                .workoutTracking,
                .weightsTracking,
                .workoutSupplements,
                .sports,
                .itinerary
            ]
        }
    }

    init(initialName: String? = nil, isRetake: Bool = false, existingAccount: Account? = nil) {
        self.preferredName = initialName ?? ""
        self.isRetake = isRetake

        if let account = existingAccount {
            preferredName = account.name ?? preferredName
            birthDate = account.dateOfBirth ?? birthDate
            selectedGender = GenderOption(rawValue: account.gender ?? "")
            unitSystem = UnitSystem(rawValue: account.unitSystem ?? unitSystem.rawValue) ?? .metric
            if unitSystem == .imperial {
                let cm = account.height ?? 0
                if cm > 0 {
                    let inchesTotal = cm / 2.54
                    let feet = Int(inchesTotal / 12)
                    let inches = inchesTotal - Double(feet * 12)
                    heightFeet = String(feet)
                    heightInches = String(format: "%.1f", inches)
                }
            } else {
                if let cm = account.height, cm > 0 {
                    heightValue = String(format: "%.0f", cm)
                }
            }
            if let kg = account.weight, kg > 0 {
                weightValue = unitSystem == .imperial ? UnitConverter.convertWeight(kg, from: .metric, to: .imperial) : String(format: "%.1f", kg)
            }
            selectedActivityLevel = ActivityLevelOption(rawValue: account.activityLevel ?? ActivityLevelOption.moderatelyActive.rawValue) ?? .moderatelyActive
            maintenanceCaloriesValue = account.maintenanceCalories > 0 ? String(account.maintenanceCalories) : ""
            calorieValue = account.calorieGoal > 0 ? String(account.calorieGoal) : ""
            if let wRaw = account.weightGoalRaw {
                selectedWeightGoal = MacroCalculator.WeightGoalOption(rawValue: wRaw)
            }
            if let sRaw = account.macroStrategyRaw {
                selectedMacroStrategy = MacroCalculator.MacroDistributionStrategy(rawValue: sRaw) ?? .balanced
            }
            customMacros = account.trackedMacros.filter { defaultMacroNames.contains($0.name) == false }
            goals = account.goals
            expenseCategories = account.expenseCategories
            habits = account.habits
            dailyTasks = account.dailyTasks
            dailySupplements = account.nutritionSupplements
            workoutSupplementsList = account.workoutSupplements
            sports = account.sports
            trackedBodyParts = Set(account.weightGroups.map { $0.name })
            workoutSchedule = account.workoutSchedule.isEmpty ? blankWorkoutSchedule() : account.workoutSchedule
        }
    }

    private var defaultMacroNames: Set<String> {
        ["Protein", "Carbs", "Fats", "Water"]
    }


    var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var isFirstStep: Bool { currentStepIndex == 0 }
    var isLastStep: Bool { currentStepIndex == steps.count - 1 }

    var buttonTitle: String { 
        if isRetake && isLastStep {
            return "Save"
        }
        return isLastStep ? "Finish" : "Continue" 
    }

    var estimatedMaintenanceCalories: Int? {
        MacroCalculator.estimateMaintenanceCalories(
            genderOption: selectedGender,
            birthDate: birthDate,
            unitSystem: unitSystem,
            heightValue: heightValue,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightValue: weightValue,
            workoutDays: workoutDaysCount,
            activityLevelRaw: selectedActivityLevel.rawValue
        )
    }

    var shouldDisableMaintenanceAuto: Bool {
        selectedGender == .preferNotSay
    }

    var shouldDisableCalorieAuto: Bool {
        // Disable calorie Auto when gender is unspecified or the user
        // has selected a custom macro focus (cannot compute from presets).
        selectedGender == .preferNotSay || selectedWeightGoal == .custom
    }

    var canContinue: Bool {
        switch currentStep {
        case .accountSetup:
            let basicValid = !preferredName.trimmingCharacters(in: .whitespaces).isEmpty && isValidBirthDate && selectedGender != nil
            let heightValid = unitSystem == .imperial ? (Double(heightFeet) != nil && Double(heightInches) != nil) : (Double(heightValue) != nil)
            let weightValid = Double(weightValue) != nil
            return basicValid && heightValid && weightValid
        case .nutritionTracking:
             let macrosValid = Double(proteinValue) != nil
                && Double(fatValue) != nil
                && Double(carbohydrateValue) != nil
                && Double(waterIntakeValue) != nil
            let macroFocusValid = selectedWeightGoal != nil
            return macrosValid && macroFocusValid
        case .dailySupplements:
            return true
        case .workoutSupplements:
            return true
        case .dailyTasks:
            return true
        case .goals:
            return true
        case .habits:
            return true
        case .workoutTracking:
            return true // Optional?
        case .weightsTracking:
            return true
        case .expenses:
            return true
        case .sports:
            return true
        case .itinerary:
            return true
        }
    }

    var isValidBirthDate: Bool {
        PumpDateRange.birthdate.contains(birthDate)
    }

    func enforceLimits() -> Bool {
        var changed = false
        
        if habits.count > maxHabits {
            habits = Array(habits.prefix(maxHabits))
            changed = true
        }
        if goals.count > maxGoals {
            goals = Array(goals.prefix(maxGoals))
            changed = true
        }
        if dailyTasks.count > maxDailyTasks {
            dailyTasks = Array(dailyTasks.prefix(maxDailyTasks))
            changed = true
        }
        if customMacros.count > maxCustomMacros {
            customMacros = Array(customMacros.prefix(maxCustomMacros))
            changed = true
        }
        if dailySupplements.count > maxDailySupplements {
            dailySupplements = Array(dailySupplements.prefix(maxDailySupplements))
            changed = true
        }
        if workoutSupplementsList.count > maxWorkoutSupplements {
            workoutSupplementsList = Array(workoutSupplementsList.prefix(maxWorkoutSupplements))
            changed = true
        }
        if sports.count > maxSports {
            sports = Array(sports.prefix(maxSports))
            changed = true
        }
        
        return changed
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

    /// Rebuild the weekly workout schedule based on selected rest days and tracked body parts.
    func regenerateWorkoutSchedule() {
        workoutSchedule = alignedWorkoutSchedule(using: Array(trackedBodyParts).sorted())
    }

    func blankWorkoutSchedule() -> [WorkoutScheduleItem] {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return Weekday.allCases.enumerated().map { idx, _ in
            WorkoutScheduleItem(day: dayNames[idx], sessions: [])
        }
    }

    /// Aligns the current schedule with the provided body parts and rest-day selections.
    /// - Ensures rest days are empty and leaves non-rest days untouched unless missing.
    func alignedWorkoutSchedule(using bodyParts: [String]) -> [WorkoutScheduleItem] {
        let restDayIds = Set(selectedWorkoutDays.map { $0.id })
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let existingByDay: [String: WorkoutScheduleItem] = Dictionary(uniqueKeysWithValues: workoutSchedule.map { ($0.day, $0) })

        let updated = Weekday.allCases.enumerated().map { tuple -> WorkoutScheduleItem in
            let (idx, day) = tuple
            let label = dayNames[idx]

            if restDayIds.contains(day.id) {
                return WorkoutScheduleItem(day: label, sessions: [])
            }

            if let existing = existingByDay[label] {
                return existing
            }

            // Create an empty training day; user can add sessions manually.
            return WorkoutScheduleItem(day: label, sessions: [])
        }

        workoutSchedule = updated
        return updated
    }

    /// Pulls unique session names from the schedule into tracked body parts.
    func autoFillBodyPartsFromSchedule() {
        let names = workoutSchedule
            .flatMap { $0.sessions }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        trackedBodyParts.formUnion(names)
        regenerateWorkoutSchedule()
    }

    func markWeightGoalAsCustom() {
        selectedWeightGoal = .custom
        lastCalculatedTargets = nil
    }

    func selectWeightGoal(_ option: MacroCalculator.WeightGoalOption) {
        selectedWeightGoal = option

        guard option != .custom else {
            lastCalculatedTargets = nil
            return
        }
        
        // Auto-populate maintenance calories if empty
        if maintenanceCaloriesValue.isEmpty, let maintenance = estimatedMaintenanceCalories {
            maintenanceCaloriesValue = String(maintenance)
        }

        // Do not auto-apply macros here; let the user trigger Auto explicitly.
        lastCalculatedTargets = nil
    }

    func updateMaintenanceCalories(_ newValue: String) {
        maintenanceCaloriesValue = newValue

        guard let focus = selectedWeightGoal, focus != .custom else { return }
        guard let autoMaintenance = estimatedMaintenanceCalories else { return }

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let enteredValue = Double(trimmed) else { return }

        if Int(enteredValue.rounded()) != autoMaintenance {
            markWeightGoalAsCustom()
        }
    }
    
    func calculateMaintenanceCalories() {
        guard !shouldDisableMaintenanceAuto else { return }
        if let maintenance = estimatedMaintenanceCalories {
            updateMaintenanceCalories(String(maintenance))
        }
    }
    
    func autoCalculateMacro(_ field: MacroField) {
        // First try to respect the selected weight goal using current maintenance, then
        // fall back to the full macro calculator if needed.
        if field == .calories, let goal = selectedWeightGoal, goal != .custom {
            let maintenance = Int(maintenanceCaloriesValue)
                ?? estimatedMaintenanceCalories

            let targetCalories: Int? = {
                guard let maintenance else { return nil }
                switch goal {
                case .maintainWeight: return maintenance
                case .mildWeightLoss: return maintenance - 250
                case .weightLoss: return maintenance - 500
                case .extremeWeightLoss: return maintenance - 1000
                case .mildWeightGain: return maintenance + 250
                case .weightGain: return maintenance + 500
                case .extremeWeightGain: return maintenance + 1000
                case .custom: return maintenance
                }
            }()

            if let target = targetCalories {
                calorieValue = String(max(1200, target))
                return
            }
        }

        guard let input = MacroCalculator.makeInput(
            genderOption: selectedGender,
            birthDate: birthDate,
            unitSystem: unitSystem,
            heightValue: heightValue,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightValue: weightValue,
            workoutDays: workoutDaysCount,
            weightGoal: selectedWeightGoal ?? .maintainWeight,
            macroStrategy: selectedMacroStrategy
        ), let result = MacroCalculator.calculateTargets(for: input) else { return }
        
        switch field {
        case .calories: calorieValue = String(result.calories)
        case .protein: proteinValue = String(result.protein)
        case .fats: fatValue = String(result.fats)
        case .carbohydrates: carbohydrateValue = String(result.carbohydrates)
        case .sodium: sodiumValue = String(result.sodiumMg)
        case .water: waterIntakeValue = String(result.waterMl)
        }
    }

    /// Auto-calculate all macro targets and apply them to the view model fields.
    func autoCalculateAllMacros() {
        // Prefer provided gender, otherwise default to male for calculation
        let genderForCalc = selectedGender ?? .male
        
        // Use current calorie value if valid
        let currentCalories = Int(calorieValue)
        
        guard let input = MacroCalculator.makeInput(
            genderOption: genderForCalc,
            birthDate: birthDate,
            unitSystem: unitSystem,
            heightValue: heightValue,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightValue: weightValue,
            workoutDays: workoutDaysCount,
            weightGoal: selectedWeightGoal ?? .maintainWeight,
            macroStrategy: selectedMacroStrategy
        ), let result = MacroCalculator.calculateTargets(for: input, overrideCalories: currentCalories) else { return }

        applyMacroTargets(result, overrideCalories: currentCalories, updateCalories: false)
    }

    private func applyMacroTargets(_ result: MacroCalculator.Result, overrideCalories: Int? = nil, updateCalories: Bool = true) {
        if updateCalories {
            calorieValue = String(overrideCalories ?? result.calories)
        }
        proteinValue = String(result.protein)
        proteinUnit = "g"
        carbohydrateValue = String(result.carbohydrates)
        carbohydrateUnit = "g"
        fatValue = String(result.fats)
        fatUnit = "g"
        sodiumValue = String(result.sodiumMg)
        waterIntakeValue = String(result.waterMl)
        waterUnit = "ml"
        lastCalculatedTargets = MacroTargetsSnapshot(result: result, overrideCalories: overrideCalories)
    }

    func updateMacroField(_ field: MacroField, newValue: String) {
        switch field {
        case .calories:
            calorieValue = newValue
        case .protein: proteinValue = newValue
        case .fats: fatValue = newValue
        case .carbohydrates: carbohydrateValue = newValue
        case .sodium: sodiumValue = newValue
        case .water: waterIntakeValue = newValue
        }

        guard selectedWeightGoal != .custom else { return }
        guard let snapshot = lastCalculatedTargets else {
            markWeightGoalAsCustom()
            return
        }

        if snapshot.value(for: field) != newValue {
            lastCalculatedTargets = nil
            markWeightGoalAsCustom()
        }
    }
    
    func addCustomMacro() {
        guard !newMacroName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Parse combined amount+unit from newMacroAmount (e.g. "100 g", "2500ml")
        let allowed = newMacroAmount
        let digits = allowed.unicodeScalars.filter { CharacterSet(charactersIn: "0123456789.").contains($0) }
        let suffixScalars = allowed.unicodeScalars.filter { !CharacterSet(charactersIn: "0123456789.").contains($0) }
        let numberString = String(String.UnicodeScalarView(digits))
        let suffix = String(String.UnicodeScalarView(suffixScalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        // If user doesn't enter an amount, default to 0 so a macro can still be created.
        let amount = Double(numberString) ?? 0

        let unitString = suffix.isEmpty ? "g" : suffix

        let macro = TrackedMacro(
            name: newMacroName,
            target: amount,
            unit: unitString,
            colorHex: "#8E8E93"
        )
        customMacros.append(macro)
        
        // Reset fields
        newMacroName = ""
        newMacroAmount = ""
        newMacroUnit = "g"
    }
    
    func removeCustomMacro(_ macro: TrackedMacro) {
        if let index = customMacros.firstIndex(of: macro) {
            customMacros.remove(at: index)
        }
    }
    
    func addDailySupplement() {
        guard !newDailySupplementName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let supplement = Supplement(
            name: newDailySupplementName,
            amountLabel: newDailySupplementAmount.isEmpty ? nil : newDailySupplementAmount
        )
        dailySupplements.append(supplement)
        
        // Reset fields
        newDailySupplementName = ""
        newDailySupplementAmount = ""
    }
    
    func removeDailySupplement(_ supplement: Supplement) {
        if let index = dailySupplements.firstIndex(of: supplement) {
            dailySupplements.remove(at: index)
        }
    }

    func addWorkoutSupplement() {
        guard !newWorkoutSupplementName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let supplement = Supplement(
            name: newWorkoutSupplementName,
            amountLabel: newWorkoutSupplementAmount.isEmpty ? nil : newWorkoutSupplementAmount
        )
        workoutSupplementsList.append(supplement)
        
        // Reset fields
        newWorkoutSupplementName = ""
        newWorkoutSupplementAmount = ""
    }
    
    func removeWorkoutSupplement(_ supplement: Supplement) {
        if let index = workoutSupplementsList.firstIndex(of: supplement) {
            workoutSupplementsList.remove(at: index)
        }
    }
    
    func addDailyTask() {
        guard !newTaskName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: newTaskTime)
        
        let task = DailyTaskDefinition(name: newTaskName, time: timeString)
        dailyTasks.append(task)
        
        newTaskName = ""
    }
    
    func removeDailyTask(_ task: DailyTaskDefinition) {
        if let index = dailyTasks.firstIndex(of: task) {
            dailyTasks.remove(at: index)
        }
    }
    
    func addGoal() {
        guard !newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let goal = GoalItem(title: newGoalTitle, note: newGoalNote, dueDate: newGoalDueDate)
        goals.append(goal)
        
        newGoalTitle = ""
        newGoalNote = ""
        newGoalDueDate = Date().addingTimeInterval(86400 * 30)
    }
    
    func removeGoal(_ goal: GoalItem) {
        if let index = goals.firstIndex(of: goal) {
            goals.remove(at: index)
        }
    }
    
    func addHabit() {
        guard !newHabitName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let habit = HabitDefinition(name: newHabitName, colorHex: newHabitColor.toHex() ?? "#007AFF")
        habits.append(habit)
        
        newHabitName = ""
        newHabitColor = .blue
    }
    
    func removeHabit(_ habit: HabitDefinition) {
        if let index = habits.firstIndex(of: habit) {
            habits.remove(at: index)
        }
    }
    
    func addSport() {
        guard !newSportName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let sport = SportConfig(name: newSportName, colorHex: "#007AFF", metrics: [])
        sports.append(sport)
        
        newSportName = ""
    }
    
    func removeSport(_ sport: SportConfig) {
        if let index = sports.firstIndex(of: sport) {
            sports.remove(at: index)
        }
    }
    
    func addItineraryEvent() {
        guard !newEventName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let event = ItineraryEvent(
            name: newEventName,
            notes: "",
            date: newEventDate,
            type: newEventType.rawValue
        )
        itineraryEvents.append(event)
        
        newEventName = ""
        newEventDate = Date()
        newEventType = .other
    }
    
    func removeItineraryEvent(_ event: ItineraryEvent) {
        if let index = itineraryEvents.firstIndex(of: event) {
            itineraryEvents.remove(at: index)
        }
    }
}

enum OnboardingStep: CaseIterable, Equatable {
    case accountSetup
    case nutritionTracking
    case dailySupplements
    case workoutSupplements
    case dailyTasks
    case goals
    case habits
    case workoutTracking
    case weightsTracking
    case expenses
    case sports
    case itinerary

    var title: String {
        switch self {
        case .accountSetup: return "Profile"
        case .nutritionTracking: return "Nutrition"
        case .dailySupplements: return "Daily Supplements"
        case .workoutSupplements: return "Workout Supplements"
        case .dailyTasks: return "Routine"
        case .goals: return "Routine"
        case .habits: return "Routine"
        case .workoutTracking: return "Workout"
        case .weightsTracking: return "Weights"
        case .expenses: return "Routine"
        case .sports: return "Sports"
        case .itinerary: return "Itinerary"
        }
    }

    var subtitle: String? {
        switch self {
        case .dailyTasks: return "Daily Tasks"
        case .goals: return "Goals"
        case .habits: return "Habits"
        case .expenses: return "Expenses"
        default: return nil
        }
    }

    var symbol: String? {
        switch self {
        case .accountSetup: return "person.crop.circle"
        case .nutritionTracking: return "fork.knife"
        case .dailySupplements: return "pills"
        case .workoutSupplements: return "bolt.heart"
        case .dailyTasks: return "checklist"
        case .goals: return "target"
        case .habits: return "arrow.triangle.2.circlepath"
        case .workoutTracking: return "figure.strengthtraining.traditional"
        case .weightsTracking: return "dumbbell.fill"
        case .expenses: return "dollarsign.circle"
        case .sports: return "sportscourt"
        case .itinerary: return "airplane"
        }
    }

    var description: String {
        switch self {
        case .accountSetup: return "Hey! Good to see you."
        case .nutritionTracking: return "Let's set up nutrition for you or you could set up your own!"
        case .dailySupplements: return "What lifestyle supplements do you take daily?"
        case .workoutSupplements: return "Do you take any workout supplements?"
        case .dailyTasks: return "We could set up daily tasks for you too!"
        case .goals: return "Are there any goals you want to keep track of?"
        case .habits: return "Are there any Habits you want to get into a routine with?"
        case .workoutTracking: return "Let’s build that muscle!"
        case .weightsTracking: return "Choose which body parts you want to track for weights."
        case .expenses: return "Yeah we know! We could help you manage your expenses!"
        case .sports: return "What sports do you want to track your performance in?"
        case .itinerary: return "Keep track of plans before you voyage around the world"
        }
    }

    var description2: String? {
        switch self {
          case .accountSetup: return "Let's get to know you."
          case .dailyTasks: return "What’s your daily routine like?"
          case .workoutTracking: return "Could you share your workout routine?"
          default: return nil
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



extension OnboardingViewModel {
    enum MacroField {
        case calories
        case protein
        case fats
        case carbohydrates
        case sodium
        case water
    }

        private struct MacroTargetsSnapshot {
        let calories: String
        let protein: String
        let carbohydrates: String
        let fats: String
        let sodium: String
        let water: String

        init(result: MacroCalculator.Result, overrideCalories: Int? = nil) {
            calories = String(overrideCalories ?? result.calories)
            protein = String(result.protein)
            carbohydrates = String(result.carbohydrates)
            fats = String(result.fats)
            sodium = String(result.sodiumMg)
            water = String(result.waterMl)
        }

        func value(for field: MacroField) -> String {
            switch field {
            case .calories: return calories
            case .protein: return protein
            case .fats: return fats
            case .carbohydrates: return carbohydrates
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

private struct KeyboardDismissBar: View {
    var isVisible: Bool
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isVisible)
            } else {
                EmptyView()
                    .frame(height: 0)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
