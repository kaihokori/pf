import SwiftUI
import SwiftData
import HealthKit
import PhotosUI

private extension WorkoutTabView {
    func fetchDayTakenWorkoutSupplements() {
        dayFirestoreService.fetchDay(for: selectedDate, in: modelContext) { day in
            DispatchQueue.main.async {
                if let day = day {
                    dayTakenWorkoutSupplementIDs = Set(day.takenWorkoutSupplements)
                } else {
                    dayTakenWorkoutSupplementIDs = []
                }
            }
        }
    }
}

private struct MacroEditorSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
    }
}
// MARK: - Exercise Supplement Editor Sheet

struct ExerciseSupplementEditorSheet: View {
    @Binding var supplements: [Supplement]
    var tint: Color
    var onDone: () -> Void

    // local working state
    @State private var working: [Supplement] = []
    @State private var newName: String = ""
    @State private var newTarget: String = ""
    @State private var hasLoaded = false

    // presets available in Quick Add (some may not be selected initially)
    private var presets: [Supplement] {
        [
            Supplement(name: "Pre-workout", amountLabel: "1 scoop"),
            Supplement(name: "Creatine", amountLabel: "5 g"),
            Supplement(name: "Whey Protein", amountLabel: "30 g"),
            Supplement(name: "BCAA", amountLabel: "10 g"),
            Supplement(name: "Electrolytes", amountLabel: "1 scoop"),
            Supplement(name: "L-Carnitine", amountLabel: "500 mg")
        ]
    }

    private let maxTrackedSupplements = 12

    private var canAddMore: Bool { working.count < maxTrackedSupplements }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Tracked supplements
                        if !working.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                MacroEditorSectionHeader(title: "Tracked Supplements")
                                VStack(spacing: 12) {
                                    ForEach(Array(working.enumerated()), id: \.element.id) { idx, item in
                                        let binding = $working[idx]
                                        VStack(spacing: 8) {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(tint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: "pills.fill")
                                                            .foregroundStyle(tint)
                                                    )

                                                VStack(alignment: .leading, spacing: 6) {
                                                    TextField("Name", text: binding.name)
                                                        .font(.subheadline.weight(.semibold))
                                                    TextField("Amount or note (e.g. 5 g or 3 scoops)", text: Binding(
                                                        get: { binding.amountLabel.wrappedValue ?? "" },
                                                        set: { binding.amountLabel.wrappedValue = $0 }
                                                    ))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                Button(role: .destructive) {
                                                    removeSupplement(item.id)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding()
                                            .surfaceCard(12)
                                        }
                                    }
                                }
                            }
                        }

                        // Quick Add
                            if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    MacroEditorSectionHeader(title: "Quick Add")
                                    VStack(spacing: 12) {
                                        ForEach(presets.filter { !isPresetSelected($0) }, id: \.name) { preset in
                                            HStack(spacing: 14) {
                                                Circle()
                                                    .fill(tint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: "pills.fill")
                                                            .foregroundStyle(tint)
                                                    )

                                                VStack(alignment: .leading) {
                                                    Text(preset.name)
                                                        .font(.subheadline.weight(.semibold))
                                                    Text(preset.amountLabel ?? "")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                Button(action: { togglePreset(preset) }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.system(size: 24, weight: .semibold))
                                                        .foregroundStyle(tint)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(!canAddMore)
                                                .opacity(!canAddMore ? 0.3 : 1)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .surfaceCard(18)
                                        }
                                    }
                                }
                            }

                        // Custom composer
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Custom Supplement")
                            VStack(spacing: 12) {
                                TextField("Supplement name", text: $newName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .surfaceCard(16)

                                HStack(spacing: 12) {
                                    TextField("Amount or note (e.g. 5 g or 3 scoops)", text: $newTarget)
                                        .padding()
                                        .surfaceCard(16)

                                    Button(action: addCustomSupplement) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(tint)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAddCustom)
                                    .opacity(!canAddCustom ? 0.4 : 1)
                                }

                                Text("You can track up to \(maxTrackedSupplements) supplements.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Edit Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        supplements = working
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        guard !hasLoaded else { return }
        working = supplements
        hasLoaded = true
    }

    private func togglePreset(_ preset: Supplement) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: Supplement) -> Bool {
        working.contains { $0.name == preset.name }
    }

    private func removeSupplement(_ id: String) {
        // Find the supplement being removed
        guard let item = working.first(where: { $0.id == id }) else { return }
        // If it's a preset (by name), remove all with that name so preset returns to Quick Add
        if presets.contains(where: { $0.name == item.name }) {
            working.removeAll { $0.name == item.name }
        } else {
            working.removeAll { $0.id == item.id }
        }
    }

    private func addCustomSupplement() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = Supplement(name: trimmed, amountLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        working.append(new)
        newName = ""
        newTarget = ""
    }
}

struct WorkoutTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @Binding var caloriesBurnGoal: Int
    @Binding var stepsGoal: Int
    @Binding var distanceGoal: Double
    @Binding var caloriesBurnedToday: Double
    @Binding var stepsTakenToday: Double
    @Binding var distanceTravelledToday: Double
    @Binding var weightGroups: [WeightGroupDefinition]
    @Binding var weightEntries: [WeightExerciseValue]
    @Binding var weeklyCheckInStatuses: [WorkoutCheckInStatus]
    @Binding var autoRestDayIndices: Set<Int>
    // Weekly progress state (persisted via Account + Firestore)
    @State private var weeklyEntries: [WeeklyProgressEntry] = []
    @State private var weeklySelectedEntry: WeeklyProgressEntry? = nil
    @State private var weeklyShowEditor: Bool = false
    @State private var previewImageEntry: WeeklyProgressEntry? = nil
    @State private var showAddSheet = false
    @State private var showRestDaySheet = false
    var lastWeightEntryByExerciseId: [UUID: WeightExerciseValue]
    var onUpdateDailyActivity: (_ calories: Double?, _ steps: Double?, _ distance: Double?) -> Void
    var onUpdateDailyGoals: (_ calorieGoal: Int, _ stepsGoal: Int, _ distanceGoal: Double) -> Void
    var onUpdateWeightGroups: ([WeightGroupDefinition]) -> Void
    var onUpdateWeightEntries: ([WeightExerciseValue]) -> Void
    var onSelectCheckInStatus: (WorkoutCheckInStatus, Int?) -> Void
    var onUpdateAutoRestDays: (Set<Int>) -> Void
    var onClearWeekCheckIns: () -> Void
    @State private var showAccountsView = false
    @State private var workoutSchedule: [WorkoutScheduleItem] = WorkoutScheduleItem.defaults
    // Use Account.workoutSupplements as the canonical source of workout supplement definitions
    // no local supplement store — use `account.workoutSupplements`
    @State private var showSupplementEditor = false
    private let accountFirestoreService = AccountFirestoreService()
    @State private var dayTakenWorkoutSupplementIDs: Set<String> = []
    private let dayFirestoreService = DayFirestoreService()
    private let healthKitService = HealthKitService()
    @State private var healthKitAuthorized: Bool = false
    @AppStorage("alerts.weeklyProgressEnabled") private var weeklyProgressAlertsEnabled: Bool = true
    @AppStorage("alerts.dailyCheckInEnabled") private var dailyCheckInAlertsEnabled: Bool = false
    @State private var showingAdjustSheet: Bool = false
    @State private var adjustTarget: String? = nil
    // raw HealthKit readings (kept separate from any manual adjustments)
    @State private var hkCaloriesValue: Double? = nil
    @State private var hkStepsValue: Double? = nil
    @State private var hkDistanceValue: Double? = nil

    @State private var showDailySummaryEditor = false

    @State private var bodyParts: [BodyPartWeights] = []
    @State private var showWeightsEditor = false
    @State private var isHydratingWeights: Bool = false
    @FocusState private var isWeightsInputFocused: UUID?

    init(
        account: Binding<Account>,
        selectedDate: Binding<Date>,
        caloriesBurnGoal: Binding<Int>,
        stepsGoal: Binding<Int>,
        distanceGoal: Binding<Double>,
        caloriesBurnedToday: Binding<Double>,
        stepsTakenToday: Binding<Double>,
        distanceTravelledToday: Binding<Double>,
        weightGroups: Binding<[WeightGroupDefinition]>,
        weightEntries: Binding<[WeightExerciseValue]>,
        weeklyCheckInStatuses: Binding<[WorkoutCheckInStatus]>,
        autoRestDayIndices: Binding<Set<Int>>,
        lastWeightEntryByExerciseId: [UUID: WeightExerciseValue],
        onUpdateDailyActivity: @escaping (_ calories: Double?, _ steps: Double?, _ distance: Double?) -> Void,
        onUpdateDailyGoals: @escaping (_ calorieGoal: Int, _ stepsGoal: Int, _ distanceGoal: Double) -> Void,
        onUpdateWeightGroups: @escaping ([WeightGroupDefinition]) -> Void,
        onUpdateWeightEntries: @escaping ([WeightExerciseValue]) -> Void,
        onSelectCheckInStatus: @escaping (WorkoutCheckInStatus, Int?) -> Void,
        onUpdateAutoRestDays: @escaping (Set<Int>) -> Void,
        onClearWeekCheckIns: @escaping () -> Void
    ) {
        _account = account
        _selectedDate = selectedDate
        _caloriesBurnGoal = caloriesBurnGoal
        _stepsGoal = stepsGoal
        _distanceGoal = distanceGoal
        _caloriesBurnedToday = caloriesBurnedToday
        _stepsTakenToday = stepsTakenToday
        _distanceTravelledToday = distanceTravelledToday
        _weightGroups = weightGroups
        _weightEntries = weightEntries
        _weeklyCheckInStatuses = weeklyCheckInStatuses
        _autoRestDayIndices = autoRestDayIndices
        self.lastWeightEntryByExerciseId = lastWeightEntryByExerciseId
        self.onUpdateDailyActivity = onUpdateDailyActivity
        self.onUpdateDailyGoals = onUpdateDailyGoals
        self.onUpdateWeightGroups = onUpdateWeightGroups
        self.onUpdateWeightEntries = onUpdateWeightEntries
        self.onSelectCheckInStatus = onSelectCheckInStatus
        self.onUpdateAutoRestDays = onUpdateAutoRestDays
        self.onClearWeekCheckIns = onClearWeekCheckIns
    }

    private var stepsProgress: Double {
        guard stepsGoal > 0 else { return 0 }
        return min(max(Double(stepsTakenToday) / Double(stepsGoal), 0), 1)
    }

    private var walkingProgress: Double {
        guard distanceGoal > 0 else { return 0 }
        return min(max(distanceTravelledToday / distanceGoal, 0), 1)
    }

    private var formattedStepsTaken: String {
        NumberFormatter.withComma.string(from: NSNumber(value: Int(stepsTakenToday))) ?? "\(Int(stepsTakenToday))"
    }

    private var formattedStepsGoal: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsGoal)) ?? "\(stepsGoal)"
    }

    private var formattedWalkingDistance: String {
        String(format: "%.2f km", distanceTravelledToday / 1000)
    }

    private var formattedWalkingGoal: String {
        String(format: "Goal %.1f km", distanceGoal / 1000)
    }

    private var currentDayIndex: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        return (weekday + 5) % 7 // anchor to Monday = 0
    }

    private var lastWeightPlaceholderVersion: String {
        lastWeightEntryByExerciseId
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { "\($0.key.uuidString)|\($0.value.weight)|\($0.value.sets)|\($0.value.reps)" }
            .joined(separator: ",")
    }

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                LazyVStack(spacing: 0) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true })
                        .environmentObject(account)

                    Text("Schedule Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                    DailyCheckInSection(
                        weeklyProgress: $weeklyCheckInStatuses,
                        accentColor: accentOverride ?? .accentColor,
                        currentDayIndex: currentDayIndex,
                        onEditRestDays: { showRestDaySheet = true },
                        onSelectStatus: { status in onSelectCheckInStatus(status, nil) },
                        onSelectStatusAtIndex: { status, idx in onSelectCheckInStatus(status, idx) }
                    )

                    WeeklyWorkoutScheduleCard(
                        schedule: $workoutSchedule,
                        accentColor: accentOverride ?? .accentColor,
                        onSave: { updated in
                            persistWorkoutSchedule(updated)
                        }
                    )
                    
                    HStack {
                        Text("Daily Summary")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            showDailySummaryEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(in: .rect(cornerRadius: 18.0))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)

                    // Two rows of two cards each for summary
                    VStack(spacing: 12) {
                        // First row: Calories spans full width
                        ActivityProgressCard(
                            title: "Calories Burned",
                            iconName: "flame.fill",
                            tint: accentOverride ?? .orange,
                            currentValueText: "\(Int(caloriesBurnedToday))",
                            goalValueText: "Goal \(caloriesBurnGoal)",
                            progress: min(Double(caloriesBurnedToday) / Double(caloriesBurnGoal), 1.0)
                        )
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            adjustTarget = "calories"
                            refreshHealthKitValues()
                            showingAdjustSheet = true
                        }

                        // Second row: Steps and Distance
                        HStack(alignment: .top, spacing: 12) {
                            ActivityProgressCard(
                                title: "Steps Taken",
                                iconName: "figure.walk",
                                tint: accentOverride ?? .green,
                                currentValueText: "\(formattedStepsTaken)",
                                goalValueText: "Goal \(formattedStepsGoal)",
                                progress: stepsProgress
                            )
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                adjustTarget = "steps"
                                refreshHealthKitValues()
                                showingAdjustSheet = true
                            }

                            ActivityProgressCard(
                                title: "Distance Travelled",
                                iconName: "point.bottomleft.forward.to.point.topright.filled.scurvepath",
                                tint: accentOverride ?? .blue,
                                currentValueText: formattedWalkingDistance,
                                goalValueText: formattedWalkingGoal,
                                progress: walkingProgress
                            )
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                adjustTarget = "walking"
                                refreshHealthKitValues()
                                showingAdjustSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    if healthKitAuthorized, let hkStepsValue, hkStepsValue > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Synced with Apple Health.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                    }
                    
                    HStack {
                        Text("Workout Supplement Tracking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { showSupplementEditor = true }) {
                            Label("Edit", systemImage: "pencil")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(in: .rect(cornerRadius: 18.0))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)
                    // Tappable cards: if HealthKit not authorized, allow manual adjust
                    .onTapGesture { /* noop */ }
                    SupplementTrackingView(
                        accentColorOverride: .purple,
                        supplements: account.workoutSupplements,
                        takenSupplementIDs: $dayTakenWorkoutSupplementIDs,
                        onToggle: { supplement in
                            // optimistic UI update
                            var newSet = dayTakenWorkoutSupplementIDs
                            if newSet.contains(supplement.id) {
                                newSet.remove(supplement.id)
                            } else {
                                newSet.insert(supplement.id)
                            }
                            dayTakenWorkoutSupplementIDs = newSet

                            // persist canonical array to Day and Firestore
                            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
                            day.takenWorkoutSupplements = Array(newSet)
                            do {
                                try modelContext.save()
                            } catch {
                                print("WorkoutTabView: failed to save Day after toggling workout supplement: \(error)")
                            }
                            dayFirestoreService.updateDayFields(["takenWorkoutSupplements": day.takenWorkoutSupplements], for: day) { success in
                                if !success { print("WorkoutTabView: failed to sync takenWorkoutSupplements to Firestore") }
                            }
                        },
                        onRemove: { supp in
                            account.workoutSupplements.removeAll { $0.id == supp.id }
                            do {
                                try modelContext.save()
                            } catch {
                                print("WorkoutTabView: failed to save Account after removing workout supplement: \(error)")
                            }
                            accountFirestoreService.saveAccount(account) { success in
                                if !success { print("WorkoutTabView: failed to sync workout supplements to Firestore") }
                            }
                        }
                    )
                    .onAppear {
                        // Seed account supplements with coaching defaults if empty
                        if account.workoutSupplements.isEmpty {
                            account.workoutSupplements = coachingDefaultSupplements
                            do {
                                try modelContext.save()
                            } catch {
                                print("WorkoutTabView: failed to save Account after seeding workout supplements: \(error)")
                            }
                            accountFirestoreService.saveAccount(account) { success in
                                if !success { print("WorkoutTabView: failed to sync seeded workout supplements to Firestore") }
                            }
                        }
                        fetchDayTakenWorkoutSupplements()
                    }
                    .onChange(of: selectedDate) { _, _ in
                        fetchDayTakenWorkoutSupplements()
                    }
                    .sheet(isPresented: $showSupplementEditor) {
                        let supplementsBinding = Binding<[Supplement]>(
                            get: { account.workoutSupplements },
                            set: { newValue in
                                account.workoutSupplements = newValue
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("WorkoutTabView: failed to save Account after editing workout supplements: \(error)")
                                }
                                accountFirestoreService.saveAccount(account) { success in
                                    if !success { print("WorkoutTabView: failed to sync workout supplements to Firestore") }
                                }
                            }
                        )

                        ExerciseSupplementEditorSheet(
                            supplements: supplementsBinding,
                            tint: .purple,
                            onDone: { showSupplementEditor = false }
                        )
                    }
                    
                    HStack {
                        Text("Weights Tracking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { showWeightsEditor = true }) {
                            Label("Edit", systemImage: "pencil")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .glassEffect(in: .rect(cornerRadius: 18.0))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)
                    
                    // Weights tracking section
                    WeightsTrackingSection(
                        bodyParts: $bodyParts,
                        focusBinding: $isWeightsInputFocused
                    )

                    // HStack {
                    //     Text("Weekly Progress")
                    //         .font(.title3)
                    //         .fontWeight(.semibold)
                    //         .foregroundStyle(.primary)

                    //     Spacer()

                    //     Button {
                    //         showAddSheet = true
                    //     } label: {
                    //         Label("Add", systemImage: "plus")
                    //             .font(.callout)
                    //             .fontWeight(.medium)
                    //             .padding(.horizontal, 12)
                    //             .padding(.vertical, 8)
                    //             .glassEffect(in: .rect(cornerRadius: 18.0))
                    //     }
                    //     .buttonStyle(.plain)
                    // }
                    // .frame(maxWidth: .infinity)
                    // .padding(.horizontal, 18)
                    // .padding(.top, 48)

                    // WeeklyProgressCarousel(accentColorOverride: accentOverride,
                    //                         entries: $weeklyEntries,
                    //                         selectedEntry: $weeklySelectedEntry,
                    //                         showEditor: $weeklyShowEditor,
                    //                         previewImageEntry: $previewImageEntry)
                    //     .padding(.horizontal, 18)
                    //     .padding(.top, 12)

                    // Coaching inquiry card
                    CoachingInquiryCTA()
                        .padding(.top, 48)

                    ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                }
            }
            if showCalendar {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { showCalendar = false }
                CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
            }
        }
        .navigationDestination(isPresented: $showAccountsView) {
            AccountsView(account: $account)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            WeeklyProgressAddSheet(
                tint: accentOverride ?? .accentColor,
                onSave: { entry in
                    weeklyEntries.append(entry)
                    weeklyEntries.sort { $0.date < $1.date }
                    persistWeeklyProgressEntries()
                    scheduleProgressReminder()
                    showAddSheet = false
                },
                onCancel: {
                    showAddSheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRestDaySheet) {
            RestDayPickerSheet(
                initialAutoRestDayIndices: autoRestDayIndices,
                tint: accentOverride ?? .accentColor,
                onClearWeek: { onClearWeekCheckIns() }
            ) { newSet in
                autoRestDayIndices = newSet
                onUpdateAutoRestDays(newSet)
                showRestDaySheet = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAdjustSheet) {
            let hkVal: Double? = {
                switch adjustTarget {
                case "steps": return hkStepsValue
                case "walking": return hkDistanceValue
                case "calories": return hkCaloriesValue
                default: return nil
                }
            }()

            ActivityAdjustSheet(
                activityName: adjustTarget ?? "",
                unit: unitForTarget(adjustTarget),
                hkValue: hkVal,
                initialValue: "0"
            ) { isAdd, value in
                handleAdjustAction(isAddition: isAdd, valueString: value, target: adjustTarget)
                showingAdjustSheet = false
            }
        }
        .sheet(item: $weeklySelectedEntry) { entry in
            WeeklyProgressAddSheet(
                tint: accentOverride ?? .accentColor,
                initialEntry: entry,
                onSave: { updatedEntry in
                    if let idx = weeklyEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                        weeklyEntries[idx] = updatedEntry
                    }
                    weeklyEntries.sort { $0.date < $1.date }
                    persistWeeklyProgressEntries()
                    scheduleProgressReminder()
                    weeklySelectedEntry = nil
                },
                onCancel: {
                    weeklySelectedEntry = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDailySummaryEditor) {
            DailySummaryGoalSheet(
                calorieGoal: $caloriesBurnGoal,
                stepsGoal: $stepsGoal,
                distanceGoal: $distanceGoal,
                tint: accentOverride ?? .accentColor,
                onCancel: { showDailySummaryEditor = false },
                onDone: {
                    onUpdateDailyGoals(caloriesBurnGoal, stepsGoal, distanceGoal)
                    showDailySummaryEditor = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showWeightsEditor) {
            WeightsGroupEditorSheet(bodyParts: $bodyParts) { updated in
                bodyParts = updated
                showWeightsEditor = false
            }
        }
        .onChange(of: weightGroups) { _, _ in rebuildBodyPartsFromModel() }
        .onChange(of: weightEntries) { _, _ in rebuildBodyPartsFromModel() }
        .onChange(of: lastWeightPlaceholderVersion) { _, _ in rebuildBodyPartsFromModel() }
        .onChange(of: account.workoutSchedule) { _, _ in hydrateWorkoutScheduleFromAccount() }
        .onChange(of: bodyParts) { _, _ in persistBodyPartsChanges() }
        .onChange(of: isWeightsInputFocused) { _, newValue in
            if newValue == nil {
                // clear selection when no field is focused
            }
        }
        .safeAreaInset(edge: .bottom) {
            KeyboardDismissBar(
                isVisible: isWeightsInputFocused != nil,
                selectedUnit: activeExerciseUnit,
                tint: accentOverride ?? .accentColor,
                onDismiss: { isWeightsInputFocused = nil },
                onSelectUnit: { unit in
                    updateActiveExerciseUnit(to: unit)
                }
            )
        }
        .onAppear {
            rebuildBodyPartsFromModel()
            hydrateWorkoutScheduleFromAccount()
            // request HealthKit authorization and load values
            healthKitService.requestAuthorization { ok in
                DispatchQueue.main.async {
                    healthKitAuthorized = ok
                    if ok {
                        refreshHealthKitValues()
                    } else {
                        // load any manual overrides for today
                        loadManualOverrides()
                    }
                }
            }
        }
        .onAppear {
            reloadWeeklyProgressFromAccount()
            ensurePlaceholderIfNeeded(persist: true)
            refreshProgressFromRemote()
            refreshCheckInNotifications()
        }
        .onChange(of: account.weeklyProgress) { _, _ in
            reloadWeeklyProgressFromAccount()
            ensurePlaceholderIfNeeded(persist: false)
            scheduleProgressReminder()
        }
        .onChange(of: weeklyCheckInStatuses) { _, _ in
            refreshCheckInNotifications()
        }
        .onChange(of: autoRestDayIndices) { _, _ in
            refreshCheckInNotifications()
        }
        .onChange(of: dailyCheckInAlertsEnabled) { _, _ in
            refreshCheckInNotifications()
        }
        
        .fullScreenCover(item: $previewImageEntry) { entry in
            ZStack {
                Color.black.ignoresSafeArea()
                if let data = entry.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    Image("placeholder")
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }

                // Close button in the top-right corner
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            previewImageEntry = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .opacity(0.95)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 18)
                        .padding(.top, 44)
                    }
                    Spacer()
                }
            }
        }
    }

    func refreshCheckInNotifications() {
        if dailyCheckInAlertsEnabled {
            let completedIndices = Set(weeklyCheckInStatuses.enumerated().compactMap { idx, status in
                (status == .checkIn || status == .rest) ? idx : nil
            })
            NotificationsHelper.scheduleDailyCheckInNotifications(autoRestIndices: autoRestDayIndices, completedIndices: completedIndices)
        } else {
            NotificationsHelper.removeDailyCheckInNotifications()
        }
    }

    func hydrateWorkoutScheduleFromAccount() {
        let resolved = account.workoutSchedule.isEmpty ? WorkoutScheduleItem.defaults : account.workoutSchedule
        workoutSchedule = resolved
    }

    func persistWorkoutSchedule(_ updated: [WorkoutScheduleItem]) {
        workoutSchedule = updated
        account.workoutSchedule = updated
        do {
            try modelContext.save()
        } catch {
            print("WorkoutTabView: failed to save workout schedule locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if !success {
                print("WorkoutTabView: failed to sync workout schedule to Firestore")
            }
        }
    }

    func scheduleProgressReminder() {
        let baseDate = weeklyEntries.last?.date ?? Date()
        let nextDate = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate
        var components = Calendar.current.dateComponents([.weekday], from: nextDate)
        if components.weekday == nil {
            components.weekday = Calendar.current.component(.weekday, from: Date())
        }
        components.hour = 9
        components.minute = 0

        let requestId = "weekly-progress-photo-reminder"
        let center = UNUserNotificationCenter.current()

        // Respect user's preference for weekly progress reminders
        if !weeklyProgressAlertsEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [requestId])
            return
        }

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard error == nil, granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: [requestId])

            let content = UNMutableNotificationContent()
            content.title = "Weekly Progress Photo"
            content.body = "Time to capture this week's progress photo at 9 AM."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
            center.add(request) { addError in
                if let addError = addError {
                    print("NutritionTabView: failed to schedule reminder: \(addError)")
                }
            }
        }
    }

    func reloadWeeklyProgressFromAccount() {
        weeklyEntries = account.weeklyProgress
            .map {
                WeeklyProgressEntry(
                    id: UUID(uuidString: $0.id) ?? UUID(),
                    date: $0.date,
                    weight: $0.weight,
                    waterPercent: $0.waterPercent,
                    bodyFatPercent: $0.bodyFatPercent,
                    photoData: $0.photoData
                )
            }
            .sorted { $0.date < $1.date }
    }

    func ensurePlaceholderIfNeeded(persist: Bool) {
        weeklyEntries.sort { $0.date < $1.date }

        // Do not create placeholder entries; only persist real data.
        if persist {
            persistWeeklyProgressEntries()
        }

        if !weeklyEntries.isEmpty {
            scheduleProgressReminder()
        }
    }

    // Downsample + recompress photos to keep Firestore documents within limits and avoid invalid nested entity errors.
    private func compressImageDataIfNeeded(_ data: Data?, maxBytes: Int = 450_000) -> Data? {
        guard let data, !data.isEmpty else { return data }

        // If already under the limit, keep as-is.
        if data.count <= maxBytes { return data }

        guard let image = UIImage(data: data) else { return data }

        // Downscale to a reasonable portrait size to shrink payloads.
        let targetWidth: CGFloat = 900
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        let targetSize = CGSize(width: targetWidth, height: targetHeight)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Try a few quality levels to stay under the byte cap.
        let qualities: [CGFloat] = [0.6, 0.5, 0.4, 0.3]
        for quality in qualities {
            if let compressed = scaledImage.jpegData(compressionQuality: quality), compressed.count <= maxBytes {
                return compressed
            }
        }

        // Fallback: return the smallest attempt even if still large.
        return scaledImage.jpegData(compressionQuality: 0.25) ?? data
    }

    func persistWeeklyProgressEntries() {
        let filteredEntries = weeklyEntries.filter { entry in
            entry.weight != 0 || entry.waterPercent != nil || entry.bodyFatPercent != nil || entry.photoData != nil
        }

        var mergedById: [UUID: WeeklyProgressEntry] = [:]

        // Start with locally edited entries.
        for entry in filteredEntries {
            mergedById[entry.id] = entry
        }

        // Preserve any existing account entries that aren't currently in memory to avoid accidental overwrites.
        for record in account.weeklyProgress {
            let uuid = UUID(uuidString: record.id) ?? UUID()
            if mergedById[uuid] == nil {
                mergedById[uuid] = WeeklyProgressEntry(
                    id: uuid,
                    date: record.date,
                    weight: record.weight,
                    waterPercent: record.waterPercent,
                    bodyFatPercent: record.bodyFatPercent,
                    photoData: record.photoData
                )
            }
        }

        let mergedEntries = mergedById.values.sorted { $0.date < $1.date }
        weeklyEntries = mergedEntries

        account.weeklyProgress = mergedEntries.map {
            WeeklyProgressRecord(
                id: $0.id.uuidString,
                date: $0.date,
                weight: $0.weight,
                waterPercent: $0.waterPercent,
                bodyFatPercent: $0.bodyFatPercent,
                photoData: compressImageDataIfNeeded($0.photoData)
            )
        }

        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save weekly progress locally: \(error)")
        }

        guard !mergedEntries.isEmpty else { return }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("NutritionTabView: failed to sync weekly progress to Firestore")
            }
        }
    }

    func refreshProgressFromRemote() {
        guard let id = account.id else { return }
        accountFirestoreService.fetchAccount(withId: id) { fetched in
            guard let fetched else { return }
            DispatchQueue.main.async {
                if !fetched.workoutSchedule.isEmpty {
                    account.workoutSchedule = fetched.workoutSchedule
                    workoutSchedule = fetched.workoutSchedule
                }

                let remoteProgress = fetched.weeklyProgress
                let localProgress = account.weeklyProgress

                if !remoteProgress.isEmpty {
                    // Prefer remote when it actually has data.
                    account.weeklyProgress = remoteProgress
                    reloadWeeklyProgressFromAccount()
                    ensurePlaceholderIfNeeded(persist: false)
                } else if !localProgress.isEmpty {
                    // Preserve local entries instead of wiping them with an empty payload.
                    reloadWeeklyProgressFromAccount()
                    persistWeeklyProgressEntries()
                } else {
                    weeklyEntries.removeAll()
                }
                do {
                    try modelContext.save()
                } catch {
                    print("NutritionTabView: failed to cache remote weekly progress: \(error)")
                }
            }
        }
    }
}

// MARK: - Manual adjust sheet
struct ActivityAdjustSheet: View {
    @Environment(\.dismiss) private var dismiss
    let activityName: String
    let unit: String
    let hkValue: Double?
    @State var inputValue: String
    var handleAction: (_ isAddition: Bool, _ value: String) -> Void

    init(activityName: String, unit: String, hkValue: Double? = nil, initialValue: String = "0", handleAction: @escaping (_ isAddition: Bool, _ value: String) -> Void) {
        self.activityName = activityName
        self.unit = unit
        self.hkValue = hkValue
        self._inputValue = State(initialValue: initialValue)
        self.handleAction = handleAction
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Progress")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter the amount to add or remove from today's total.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let hk = hkValue {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HealthKit")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(Int(hk)) \(unit)")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 8) {
                    TextField("0", text: $inputValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    Text("\(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .surfaceCard(16)

                HStack(spacing: 16) {
                    Button(action: { handleAction(false, inputValue); dismiss() }) {
                        Label("Remove", systemImage: "minus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: { handleAction(true, inputValue); dismiss() }) {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.42), .medium])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .keyboardDismissToolbar()
        }
    }
}

// helpers
private extension WorkoutTabView {
    func unitForTarget(_ target: String?) -> String {
        switch target {
        case "steps": return "steps"
        case "walking": return "m"
        case "calories": return "cal"
        default: return ""
        }
    }

    var activeExerciseUnit: String? {
        guard let focusedId = isWeightsInputFocused else { return nil }
        for part in bodyParts {
            if let match = part.exercises.first(where: { $0.id == focusedId }) {
                return match.unit
            }
        }
        return nil
    }

    func updateActiveExerciseUnit(to unit: String) {
        guard let focusedId = isWeightsInputFocused else { return }
        for partIndex in bodyParts.indices {
            if let exerciseIndex = bodyParts[partIndex].exercises.firstIndex(where: { $0.id == focusedId }) {
                bodyParts[partIndex].exercises[exerciseIndex].unit = unit
                break
            }
        }
    }

    func handleAdjustAction(isAddition: Bool, valueString: String, target: String?) {
        guard let val = Double(valueString) else { return }
        switch target {
        case "steps":
            stepsTakenToday += (isAddition ? val : -val)
            persistActivityToDay(steps: stepsTakenToday)
        case "walking":
            distanceTravelledToday += (isAddition ? val : -val)
            persistActivityToDay(distance: distanceTravelledToday)
        case "calories":
            caloriesBurnedToday += (isAddition ? val : -val)
            persistActivityToDay(calories: caloriesBurnedToday)
        default:
            break
        }
    }

    func rebuildBodyPartsFromModel() {
        isHydratingWeights = true
        let resolvedGroups = weightGroups.isEmpty ? WeightGroupDefinition.defaults : weightGroups
        let entriesByExercise = Dictionary(uniqueKeysWithValues: weightEntries.map { ($0.exerciseId, $0) })

        bodyParts = resolvedGroups.map { group in
            let exercises = group.exercises.map { def -> WeightExercise in
                let entry = entriesByExercise[def.id]
                let placeholder = lastWeightEntryByExerciseId[def.id]
                return WeightExercise(
                    id: def.id,
                    name: def.name,
                    weight: entry?.weight ?? "",
                    unit: entry?.unit ?? "kg",
                    sets: entry?.sets ?? "",
                    reps: entry?.reps ?? "",
                    placeholderWeight: placeholder?.weight ?? "",
                    placeholderSets: placeholder?.sets ?? "",
                    placeholderReps: placeholder?.reps ?? ""
                )
            }
            return BodyPartWeights(id: group.id, name: group.name, exercises: exercises)
        }

        if bodyParts.isEmpty {
            bodyParts = BodyPartWeights.defaultGroups
        }
        isHydratingWeights = false
    }

    func persistBodyPartsChanges() {
        guard !isHydratingWeights else { return }

        let newGroups = bodyParts.map { part in
            WeightGroupDefinition(
                id: part.id,
                name: part.name,
                exercises: part.exercises.map { WeightExerciseDefinition(id: $0.id, name: $0.name) }
            )
        }

        if newGroups != weightGroups {
            weightGroups = newGroups
            onUpdateWeightGroups(newGroups)
        }

        let newEntries: [WeightExerciseValue] = bodyParts.flatMap { part in
            part.exercises.compactMap { exercise -> WeightExerciseValue? in
                let hasContent = !exercise.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !exercise.sets.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !exercise.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                guard hasContent else { return nil }
                return WeightExerciseValue(
                    id: exercise.id.uuidString,
                    groupId: part.id,
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    weight: exercise.weight,
                    unit: exercise.unit,
                    sets: exercise.sets,
                    reps: exercise.reps
                )
            }
        }

        if newEntries != weightEntries {
            weightEntries = newEntries
            onUpdateWeightEntries(newEntries)
        }
    }

    func dateKey(for date: Date) -> String {
        let localCal = Calendar.current
        let components = localCal.dateComponents([.year, .month, .day], from: date)
        
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = utcCal.date(from: components) ?? utcCal.startOfDay(for: date)
        
        let fmt = DateFormatter()
        fmt.calendar = utcCal
        fmt.timeZone = utcCal.timeZone
        fmt.dateFormat = "dd-MM-yyyy"
        return fmt.string(from: dayStart)
    }

    func manualKey(_ metric: String) -> String {
        "manual.\(dateKey(for: selectedDate)).\(metric)"
    }

    func saveManualOverride(key: String, value: Double) {
        // legacy: keep in UserDefaults for quick fallback, but persist canonical state to Day+Firestore
        UserDefaults.standard.set(value, forKey: manualKey(key))
    }

    func loadManualOverrides() {
        // Prefer local Day values (persisted in Core Data). Fall back to UserDefaults if Day not present.
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        stepsTakenToday = day.stepsTaken
        distanceTravelledToday = day.distanceTravelled
        caloriesBurnedToday = day.caloriesBurned
        // If Day had no values, fallback to UserDefaults or estimate
        if stepsTakenToday == 0 {
            let steps = UserDefaults.standard.double(forKey: manualKey("steps"))
            if steps > 0 { stepsTakenToday = steps }
        }
        if distanceTravelledToday == 0 {
            let walking = UserDefaults.standard.double(forKey: manualKey("walking"))
            if walking > 0 { distanceTravelledToday = walking }
        }
        if caloriesBurnedToday == 0 {
            let cals = UserDefaults.standard.double(forKey: manualKey("calories"))
            if cals > 0 { caloriesBurnedToday = cals }
            else { caloriesBurnedToday = estimateCaloriesFromAccount() }
        }
    }

    func refreshHealthKitValues() {
        healthKitService.fetchTodaySteps { v in
            DispatchQueue.main.async {
                if let v = v {
                    hkStepsValue = v
                    stepsTakenToday = v
                } else {
                    hkStepsValue = nil
                }
            }
        }
        healthKitService.fetchTodayDistance { v in
            DispatchQueue.main.async {
                if let v = v {
                    hkDistanceValue = v
                    // treat fetched distance as walking distance for display simplicity
                    distanceTravelledToday = v
                } else {
                    hkDistanceValue = nil
                }
            }
        }
        healthKitService.fetchTodayActiveEnergy { v in
            DispatchQueue.main.async {
                if let v = v { caloriesBurnedToday = v }
                else { caloriesBurnedToday = estimateCaloriesFromAccount() }

                onUpdateDailyActivity(caloriesBurnedToday, stepsTakenToday, distanceTravelledToday)
            }
        }
    }

    func persistActivityToDay(calories: Double? = nil, steps: Double? = nil, distance: Double? = nil) {
        onUpdateDailyActivity(calories, steps, distance)
    }

    func estimateCaloriesFromAccount() -> Double {
        // crude estimate using steps + distances + account fields
        let weight = account.weight ?? 70.0
        let height = account.height ?? 170.0
        let age: Int = {
            if let dob = account.dateOfBirth {
                let comps = Calendar.current.dateComponents([.year], from: dob, to: Date())
                return comps.year ?? 30
            }
            return 30
        }()
        let genderFactor: Double = {
            let g = account.gender?.lowercased() ?? ""
            if g.starts(with: "f") || g == "female" { return -161 }
            return 5
        }()
        _ = 10.0 * (account.weight ?? weight) + 6.25 * (account.height ?? height) - 5.0 * Double(age) + genderFactor

        // distance-based estimates (kcal per km per kg approx)
        let walkKm = distanceTravelledToday / 1000.0
        let walkCals = walkKm * (account.weight ?? weight) * 0.7
        let stepCals = stepsTakenToday * 0.04

        let active = max(stepCals, walkCals)
        // ensure at least a small active component
        return max(active, 0)
    }
}

private extension WorkoutTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .workout)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
}

private let coachingDefaultSupplements: [Supplement] = [
    Supplement(name: "Pre-workout", amountLabel: "1 scoop"),
    Supplement(name: "Creatine", amountLabel: "5 g"),
    Supplement(name: "Whey Protein", amountLabel: "30 g"),
    Supplement(name: "BCAA", amountLabel: "10 g"),
    Supplement(name: "Electrolytes", amountLabel: "1 scoop")
]

// MARK: - Weekly schedule views

private struct WeeklyWorkoutScheduleCard: View {
    @Binding var schedule: [WorkoutScheduleItem]
    let accentColor: Color
    var onSave: ([WorkoutScheduleItem]) -> Void

    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Schedule")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showEditSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(schedule) { day in
                        VStack(spacing: 10) {
                            Text(day.day)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .padding(.top, 2)
                            VStack(spacing: 8) {
                                ForEach(day.sessions) { session in
                                    WeeklySessionCard(
                                        session: session,
                                        accentColor: accentColor
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .frame(width: 80)
                        .background(Color.clear)
                    }
                }
                .padding()
            }
            .frame(minHeight: 200)
            .glassEffect(in: .rect(cornerRadius: 12.0))
            .overlay(
                RoundedRectangle(cornerRadius: 12.0)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 4)
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .sheet(isPresented: $showEditSheet) {
            WorkoutScheduleEditorSheet(
                schedule: $schedule,
                accentColor: accentColor
            ) { updated in
                schedule = updated
                onSave(updated)
                showEditSheet = false
            }
        }
    }
}

private struct WorkoutScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var schedule: [WorkoutScheduleItem]
    var accentColor: Color
    var onSave: ([WorkoutScheduleItem]) -> Void

    @State private var working: [WorkoutScheduleItem] = []

    @State private var newName: String = ""
    @State private var newColorHex: String = ""
    @State private var newHour: Int = 9
    @State private var newMinute: Int = 0
    @State private var selectedDayIndex: Int = 0

    @State private var showColorPickerSheet = false
    @State private var colorPickerTarget: (dayIndex: Int, sessionId: UUID)? = nil

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var presets: [WorkoutSession] {
        [
            WorkoutSession(name: "Chest"),
            WorkoutSession(name: "Back"),
            WorkoutSession(name: "Shoulder"),
            WorkoutSession(name: "Legs"),
            WorkoutSession(name: "Core"),
            WorkoutSession(name: "Yoga"),
            WorkoutSession(name: "Pilates"),
            WorkoutSession(name: "Hyrox"),
            WorkoutSession(name: "Crossfit"),
            WorkoutSession(name: "Meditate"),
            WorkoutSession(name: "Cardio"),
            WorkoutSession(name: "Run")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Current schedule by day
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tracked Schedule")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 14) {
                            ForEach(Array(working.enumerated()), id: \.element.id) { dayIndex, day in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(day.day)
                                            .font(.callout.weight(.semibold))
                                            .textCase(.uppercase)
                                        Spacer()
                                        if !day.sessions.isEmpty {
                                            Text("\(day.sessions.count)" + (day.sessions.count == 1 ? " activity" : " activities"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if day.sessions.isEmpty {
                                        Text("No activities added yet.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(Array(day.sessions.enumerated()), id: \.element.id) { sessionIndex, _ in
                                                let binding = $working[dayIndex].sessions[sessionIndex]
                                                let sessionId = working[dayIndex].sessions[sessionIndex].id
                                                HStack(spacing: 12) {
                                                    Button {
                                                        colorPickerTarget = (dayIndex, sessionId)
                                                        showColorPickerSheet = true
                                                    } label: {
                                                        Circle()
                                                            .fill((Color(hex: binding.colorHex.wrappedValue) ?? accentColor).opacity(0.18))
                                                            .frame(width: 40, height: 40)
                                                            .overlay(
                                                                Image(systemName: "figure.run")
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                    .foregroundStyle(Color(hex: binding.colorHex.wrappedValue) ?? accentColor)
                                                            )
                                                    }
                                                    .buttonStyle(.plain)

                                                    VStack(alignment: .leading, spacing: 6) {
                                                        TextField("Activity", text: binding.name)
                                                            .font(.subheadline.weight(.semibold))

                                                        HStack(spacing: 8) {
                                                            DatePicker(
                                                                "",
                                                                selection: Binding<Date>(
                                                                    get: { binding.wrappedValue.dateForToday },
                                                                    set: { newValue in
                                                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                                                        binding.hour.wrappedValue = comps.hour ?? binding.hour.wrappedValue
                                                                        binding.minute.wrappedValue = comps.minute ?? binding.minute.wrappedValue
                                                                    }
                                                                ),
                                                                displayedComponents: .hourAndMinute
                                                            )
                                                            .labelsHidden()
                                                            .tint(accentColor)
                                                            
                                                            Menu {
                                                                ForEach(Array(daySymbols.enumerated()), id: \.0) { moveIndex, label in
                                                                    Button(label) {
                                                                        moveSession(from: dayIndex, sessionIndex: sessionIndex, to: moveIndex)
                                                                    }
                                                                }
                                                            } label: {
                                                                HStack(spacing: 6) {
                                                                    Image(systemName: "arrow.left.arrow.right")
                                                                        .font(.system(size: 14, weight: .semibold))
                                                                    Text("Move")
                                                                        .font(.caption)
                                                                }
                                                                .foregroundStyle(.secondary)
                                                            }
                                                            .buttonStyle(.plain)

                                                            Spacer()
                                                        }
                                                    }

                                                    Spacer()

                                                    Button(role: .destructive) {
                                                        removeSession(dayIndex: dayIndex, sessionId: sessionId)
                                                    } label: {
                                                        Image(systemName: "trash")
                                                            .foregroundStyle(.red)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                                .padding()
                                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Quick Add presets
                    if !presets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets, id: \.id) { preset in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill((Color(hex: preset.colorHex) ?? accentColor).opacity(0.18))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Image(systemName: "figure.run")
                                                    .foregroundStyle(Color(hex: preset.colorHex) ?? accentColor)
                                                    .font(.system(size: 18, weight: .semibold))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                        }

                                        Spacer()

                                        Menu {
                                            ForEach(Array(daySymbols.enumerated()), id: \.0) { dayIdx, label in
                                                Button(label) { addPreset(preset, to: dayIdx) }
                                            }
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 28, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }

                    // Custom activity composer
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Activity")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            HStack {
                                TextField("Activity name", text: $newName)
                                  .textInputAutocapitalization(.words)
                                  .padding()
                                  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                
                                Menu {
                                    ForEach(Array(daySymbols.enumerated()), id: \.0) { idx, label in
                                        Button(label) {
                                            selectedDayIndex = idx
                                            addCustomActivity()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(accentColor)
                                        .opacity(!canAddCustom ? 0.4 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                            }

                            DatePicker(
                                "",
                                selection: Binding<Date>(
                                    get: { newActivityDate },
                                    set: { newValue in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                        newHour = comps.hour ?? newHour
                                        newMinute = comps.minute ?? newMinute
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .tint(accentColor)

                            Text("You can add activities to any day.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Weekly Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }

    private var canAddCustom: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedDayIndex < working.count
    }

    private var newActivityDate: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = newHour
        comps.minute = newMinute
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func loadInitial() {
        working = schedule.isEmpty ? WorkoutScheduleItem.defaults : schedule
    }

    private func addPreset(_ preset: WorkoutSession, to dayIndex: Int) {
        guard working.indices.contains(dayIndex) else { return }
        working[dayIndex].sessions.append(preset)
    }

    private func addCustomActivity() {
        guard canAddCustom, working.indices.contains(selectedDayIndex) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newSession = WorkoutSession(
            name: trimmed,
            colorHex: newColorHex,
            hour: newHour,
            minute: newMinute
        )
        working[selectedDayIndex].sessions.append(newSession)
        newName = ""
        newColorHex = ""
        newHour = 9
        newMinute = 0
    }

    private func removeSession(dayIndex: Int, sessionId: UUID) {
        guard working.indices.contains(dayIndex) else { return }
        working[dayIndex].sessions.removeAll { $0.id == sessionId }
    }

    private func moveSession(from dayIndex: Int, sessionIndex: Int, to targetDayIndex: Int) {
        guard working.indices.contains(dayIndex), working.indices.contains(targetDayIndex),
              working[dayIndex].sessions.indices.contains(sessionIndex) else { return }
        let session = working[dayIndex].sessions.remove(at: sessionIndex)
        working[targetDayIndex].sessions.append(session)
    }

    private func applyColor(hex: String) {
        if let target = colorPickerTarget,
           working.indices.contains(target.dayIndex),
           let idx = working[target.dayIndex].sessions.firstIndex(where: { $0.id == target.sessionId }) {
            working[target.dayIndex].sessions[idx].colorHex = hex
            return
        }
        // Fallback for new custom activity color selection
        newColorHex = hex
    }

    private func saveChanges() {
        schedule = working
        onSave(working)
        dismiss()
    }
}

private struct WeeklySessionCard: View {
    let session: WorkoutSession
    let accentColor: Color

    private var resolvedColor: Color {
        Color(hex: session.colorHex) ?? accentColor
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(session.name)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Text(session.formattedTime)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(resolvedColor), in: .rect(cornerRadius: 12.0))
    }
}

// MARK: - Daily Check-In UI (UI-only, no persistence)

private extension WorkoutCheckInStatus {
    var timelineSymbol: String? {
        switch self {
        case .checkIn: return "circle.fill"
        case .rest: return "circle.fill"
        case .notLogged: return "circle"
        }
    }

    var shouldHideTimelineNode: Bool { false }

    var accentColor: Color {
        switch self {
        case .checkIn:
            return Color.yellow
        case .rest:
            return Color(.systemGray3)
        case .notLogged:
            return Color(.systemGray3)
        }
    }
}

private struct DailyCheckInTimelineView: View {
    let daySymbols: [String]
    let statuses: [WorkoutCheckInStatus]
    let accentColor: Color
    var onNodeTap: ((Int) -> Void)? = nil

    private let nodeHeight: CGFloat = 56
    private let symbolSize: CGFloat = 20
    private let connectorColor = Color.black.opacity(0.55)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    let totalWidth = proxy.size.width
                    let safeCount = max(daySymbols.count, 1)
                    let cellWidth = totalWidth / CGFloat(safeCount)
                    let connectorWidth = max(cellWidth - symbolSize, 0)
                    let yPosition = symbolSize / 2

                    ForEach(0..<max(daySymbols.count - 1, 0), id: \.self) { index in
                        if shouldDrawConnector(at: index) {
                            Rectangle()
                                .fill(connectorColor)
                                .frame(width: connectorWidth, height: 1)
                                .position(x: cellWidth * (CGFloat(index) + 1), y: yPosition)
                        }
                    }
                }
                .frame(height: nodeHeight)
                .allowsHitTesting(false)

                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(daySymbols.enumerated()), id: \.0) { index, label in
                        timelineNode(for: index, label: label)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onNodeTap?(index)
                            }
                    }
                }
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func timelineNode(for index: Int, label: String) -> some View {
        let status = statuses.indices.contains(index) ? statuses[index] : .notLogged
        let isHidden = status.shouldHideTimelineNode
        VStack(spacing: 6) {
            if let symbol = status.timelineSymbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .frame(height: symbolSize)
                    .foregroundStyle(status.accentColor)
                    .fixedSize()
            } else {
                Color.clear.frame(height: symbolSize)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .frame(height: nodeHeight, alignment: .top)
        .opacity(isHidden ? 0 : 1)
    }

    private func shouldDrawConnector(at index: Int) -> Bool {
        let current = status(at: index)
        let next = status(at: index + 1)
        return !current.shouldHideTimelineNode && !next.shouldHideTimelineNode
    }

    private func status(at index: Int) -> WorkoutCheckInStatus {
        guard statuses.indices.contains(index) else { return .notLogged }
        return statuses[index]
    }
}

private struct DailyCheckInSection: View {
    @Binding var weeklyProgress: [WorkoutCheckInStatus]
    let accentColor: Color
    let currentDayIndex: Int
    var onEditRestDays: () -> Void
    var onSelectStatus: (WorkoutCheckInStatus) -> Void
    var onSelectStatusAtIndex: (WorkoutCheckInStatus, Int) -> Void

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        let tint = accentColor

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Daily Check-In")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { onEditRestDays() }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }

            DailyCheckInTimelineView(daySymbols: daySymbols, statuses: weeklyProgress, accentColor: tint, onNodeTap: { index in
                nodeTapped(at: index)
            })
                .padding(.bottom, -20)

            HStack(spacing: 12) {
                Button(action: { updateStatus(.checkIn) }) {
                    Text("Check-In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DailyCheckInButtonStyle(background: .regularMaterial))

                Button(action: { updateStatus(.rest) }) {
                    Text("Rest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DailyCheckInButtonStyle(background: .regularMaterial))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func updateStatus(_ status: WorkoutCheckInStatus) {
        guard weeklyProgress.indices.contains(currentDayIndex) else { return }
        weeklyProgress[currentDayIndex] = status
        onSelectStatus(status)
    }

    private func nodeTapped(at index: Int) {
        guard weeklyProgress.indices.contains(index) else { return }
        let current = weeklyProgress[index]
        switch current {
        case .checkIn, .rest:
            weeklyProgress[index] = .notLogged
            onSelectStatusAtIndex(.notLogged, index)
        case .notLogged:
            break
        }
    }
}

private struct DailyCheckInButtonStyle: ButtonStyle {
    let background: Material

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .glassEffect(in: .rect(cornerRadius: 12.0))
    }
}

private struct RestDayPickerSheet: View {
    var initialAutoRestDayIndices: Set<Int>
    var tint: Color
    var onClearWeek: () -> Void
    var onDone: (Set<Int>) -> Void

    @State private var workingIndices: Set<Int> = []

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Days")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(Array(daySymbols.enumerated()), id: \.0) { index, label in
                                SelectablePillComponent(
                                    label: label,
                                    isSelected: workingIndices.contains(index),
                                    selectedTint: tint
                                ) {
                                    toggleDay(at: index)
                                }
                            }
                        }
                    }

                    Text("Pick which days should default to Rest at the start of each week. Those days will be marked grey in your weekly timeline.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Edit Rest Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(workingIndices)
                    }
                    .fontWeight(.semibold)
                }
                // ToolbarItem(placement: .bottomBar) {
                //     Button(role: .destructive) {
                //         onClearWeek()
                //     } label: {
                //         Label("Clear This Week", systemImage: "trash")
                //     }
                // }
            }
        }
        .onAppear { workingIndices = initialAutoRestDayIndices }
    }

    @Environment(\.dismiss) private var dismiss

    private func toggleDay(at index: Int) {
        if workingIndices.contains(index) {
            workingIndices.remove(index)
        } else {
            workingIndices.insert(index)
        }
    }
}


// MARK: - Weights Tracking Section

private struct WeightExercise: Identifiable, Equatable {
    var id: UUID
    var name: String
    var weight: String
    var unit: String
    var sets: String
    var reps: String
    var placeholderWeight: String
    var placeholderSets: String
    var placeholderReps: String

    init(
        id: UUID = UUID(),
        name: String,
        weight: String = "",
        unit: String = "kg",
        sets: String = "",
        reps: String = "",
        placeholderWeight: String = "",
        placeholderSets: String = "",
        placeholderReps: String = ""
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.unit = unit
        self.sets = sets
        self.reps = reps
        self.placeholderWeight = placeholderWeight
        self.placeholderSets = placeholderSets
        self.placeholderReps = placeholderReps
    }
}

private struct BodyPartWeights: Identifiable, Equatable {
    var id: UUID
    var name: String
    var exercises: [WeightExercise]
    var isEditing: Bool = false

    init(id: UUID = UUID(), name: String, exercises: [WeightExercise], isEditing: Bool = false) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.isEditing = isEditing
    }
}

private extension BodyPartWeights {
    static var defaultGroups: [BodyPartWeights] {
        WeightGroupDefinition.defaults.map { group in
            BodyPartWeights(
                id: group.id,
                name: group.name,
                exercises: group.exercises.map { WeightExercise(id: $0.id, name: $0.name, unit: "kg") }
            )
        }
    }
}

private struct DailySummaryGoalSheet: View {
    @Binding var calorieGoal: Int
    @Binding var stepsGoal: Int
    @Binding var distanceGoal: Double
    var tint: Color
    var onCancel: () -> Void
    var onDone: () -> Void

    @State private var calorieText: String = ""
    @State private var stepsText: String = ""
    @State private var distanceText: String = ""
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calorie Burn Goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Calories", text: $calorieText)
                            .keyboardType(.numberPad)
                            .padding()
                            .surfaceCard(16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Steps Goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Steps", text: $stepsText)
                            .keyboardType(.numberPad)
                            .padding()
                            .surfaceCard(16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distance Goal (m)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Meters", text: $distanceText)
                            .keyboardType(.numberPad)
                            .padding()
                            .surfaceCard(16)

                        Text("Distance goal is stored in meters; display converts to km in the summary cards.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Edit Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyChanges()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(tint)
        .keyboardDismissToolbar()
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        calorieText = String(calorieGoal)
        stepsText = String(stepsGoal)
        distanceText = String(Int(distanceGoal))
        hasLoaded = true
    }

    private func applyChanges() {
        if let cals = Int(calorieText.trimmingCharacters(in: .whitespacesAndNewlines)), cals > 0 {
            calorieGoal = cals
        }
        if let steps = Int(stepsText.trimmingCharacters(in: .whitespacesAndNewlines)), steps > 0 {
            stepsGoal = steps
        }
        if let dist = Double(distanceText.trimmingCharacters(in: .whitespacesAndNewlines)), dist > 0 {
            distanceGoal = dist
        }
    }
}

private struct WeightsGroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bodyParts: [BodyPartWeights]
    var onSave: ([BodyPartWeights]) -> Void

    @State private var working: [BodyPartWeights] = []
    @State private var newName: String = ""
    @State private var hasLoaded = false

    private let presets: [String] = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body"]
    private let maxTracked = 12

    private var canAddMore: Bool { working.count < maxTracked }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Groups")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "dumbbell")
                                                .foregroundStyle(Color.accentColor))

                                        VStack {
                                            TextField("Body part", text: binding.name)
                                            .font(.subheadline.weight(.semibold))

                                            HStack {
                                                  Menu {
                                                    Button("Top") { moveGroupToTop(idx) }
                                                    Button("Up") { moveGroupUp(idx) }
                                                    Button("Down") { moveGroupDown(idx) }
                                                    Button("Bottom") { moveGroupToBottom(idx) }
                                                } label: {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "arrow.up.arrow.down")
                                                            .font(.system(size: 14, weight: .semibold))
                                                        Text("Move")
                                                            .font(.caption)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                                .padding(.trailing, 4)

                                                Spacer()
                                            }
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeGroup(working[idx].id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .surfaceCard(16)
                                }
                            }
                        }
                    }

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.self) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "dumbbell")
                                                .foregroundStyle(Color.accentColor))

                                        Text(preset)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Group")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("Group name", text: $newName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomGroup) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("You can track up to \(maxTracked) groups.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Weight Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { donePressed() }
                        .fontWeight(.semibold)
                }
            }
        }
        .keyboardDismissToolbar()
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = bodyParts.isEmpty ? BodyPartWeights.defaultGroups : bodyParts
        hasLoaded = true
    }

    private func togglePreset(_ name: String) {
        if isPresetSelected(name) {
            working.removeAll { $0.name == name }
        } else if canAddMore {
            working.append(.init(name: name, exercises: []))
        }
    }

    private func isPresetSelected(_ name: String) -> Bool {
        working.contains { $0.name == name }
    }

    private func addCustomGroup() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        working.append(.init(name: trimmed, exercises: []))
        newName = ""
    }

    private func removeGroup(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func moveGroupUp(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        working.swapAt(index, index - 1)
    }

    private func moveGroupDown(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        working.swapAt(index, index + 1)
    }

    private func moveGroupToTop(_ index: Int) {
        guard working.indices.contains(index), index > 0 else { return }
        let item = working.remove(at: index)
        working.insert(item, at: 0)
    }

    private func moveGroupToBottom(_ index: Int) {
        guard working.indices.contains(index), index < working.count - 1 else { return }
        let item = working.remove(at: index)
        working.append(item)
    }

    private func donePressed() {
        bodyParts = working
        onSave(working)
        dismiss()
    }
}

private struct WeightsTrackingSection: View {
    @Binding var bodyParts: [BodyPartWeights]
    var focusBinding: FocusState<UUID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // One section per body part
            ForEach($bodyParts) { $part in
                VStack(alignment: .leading, spacing: 12) {
                    // Header row: editable body part name + delete button
                    HStack {
                        if part.isEditing {
                            TextField("Body Part", text: $part.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .textInputAutocapitalization(.words)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .glassEffect(in: .rect(cornerRadius: 8.0))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 40)
                                .focused(focusBinding, equals: part.id)
                                .onSubmit {
                                    part.isEditing = false
                                }
                        } else {
                            Text(part.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 40)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button {
                                // Toggle editing state for this body part
                                part.isEditing.toggle()
                            } label: {
                                if part.isEditing {
                                    Image(systemName: "checkmark")
                                        .font(.callout)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                        .accessibilityLabel("Done")
                                } else {
                                    Image(systemName: "pencil")
                                        .font(.callout)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                        .accessibilityLabel("Edit")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)

                    // Column labels
                    HStack(spacing: 4) {
                        Text("Exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .center)

                        Text("Sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .center)

                        Text("x")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 15, alignment: .center)

                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .center)

                        if part.isEditing {
                            Color.clear.frame(width: 44)
                        }
                    }
                    .padding(.horizontal, 18)

                    // Exercise rows
                    VStack(spacing: 8) {
                        ForEach($part.exercises) { $exercise in
                            HStack(spacing: 4) {
                                TextField("Name", text: $exercise.name)
                                    .textInputAutocapitalization(.words)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8.0))
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                        .focused(focusBinding, equals: exercise.id)

                                TextField(exercise.placeholderWeight.isEmpty ? "0" : exercise.placeholderWeight, text: $exercise.weight)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 6)
                                    .padding(.leading, 8)
                                    .padding(.trailing, 28) // leave room for unit suffix
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8.0))
                                    .frame(width: 80)
                                    .focused(focusBinding, equals: exercise.id)
                                    // focus is handled by FocusState equals binding; no explicit tap handler needed
                                    .overlay(alignment: .trailing) {
                                        Text(exercise.unit.uppercased())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.trailing, 8)
                                    }

                                TextField(exercise.placeholderSets.isEmpty ? "0" : exercise.placeholderSets, text: $exercise.sets)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8.0))
                                    .frame(width: 40)
                                    .focused(focusBinding, equals: exercise.id)

                                Text("x")
                                    .frame(width: 15)

                                TextField(exercise.placeholderReps.isEmpty ? "0" : exercise.placeholderReps, text: $exercise.reps)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8.0))
                                    .frame(width: 40)
                                    .focused(focusBinding, equals: exercise.id)

                                if part.isEditing {
                                    Button {
                                        deleteExercise(bodyPartId: part.id, exerciseId: exercise.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.callout)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18.0))
                                            .accessibilityLabel("Delete")
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    EmptyView()
                                }
                            }
                        }

                        // Add Exercise button at the bottom
                        Button {
                            addExercise(to: part.id)
                        } label: {
                            Label("Add Exercise", systemImage: "plus.circle")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18.0))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 18)
                    .background(Color.clear)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 12)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // MARK: - Actions

    private func addExercise(to bodyPartId: UUID) {
        guard let index = bodyParts.firstIndex(where: { $0.id == bodyPartId }) else { return }
        bodyParts[index].exercises.append(
            WeightExercise(name: "", weight: "", sets: "", reps: "")
        )
    }

    private func deleteExercise(bodyPartId: UUID, exerciseId: UUID) {
        guard let partIndex = bodyParts.firstIndex(where: { $0.id == bodyPartId }) else { return }
        guard let exerciseIndex = bodyParts[partIndex].exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        bodyParts[partIndex].exercises.remove(at: exerciseIndex)
    }

}

// Safe-area inset dismiss bar that naturally sits above the keyboard.
private struct KeyboardDismissBar: View {
    var isVisible: Bool
    var selectedUnit: String?
    var tint: Color
    var onDismiss: () -> Void
    var onSelectUnit: (String) -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 12) {
                    ForEach(["kg", "lbs"], id: \.self) { unit in
                        let isSelected = selectedUnit?.lowercased() == unit
                        Button {
                            onSelectUnit(unit)
                        } label: {
                            Text(unit.uppercased())
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                                .foregroundStyle(isSelected ? tint : .primary)
                        }
                        .buttonStyle(.plain)
                    }

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

private struct WeeklyProgressCarousel: View {
    var accentColorOverride: Color?

    @Binding var entries: [WeeklyProgressEntry]
    @Binding var selectedEntry: WeeklyProgressEntry?
    @Binding var showEditor: Bool
    @Binding var previewImageEntry: WeeklyProgressEntry?
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "E, d MMM"
        return f
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let tint = accentColorOverride ?? .accentColor

                    ForEach(entries) { entry in
                        VStack(alignment: .center, spacing: 8) {
                            // Date centered at top
                            Text(dateFormatter.string(from: entry.date))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)

                            Spacer()

                            // Weight shown only when present
                            if entry.weight > 0 {
                                Text(String(format: "%.1f kg", entry.weight))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            } else {
                                Text("No data yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            // Optional additional info — reserve a fixed height so absence
                            // of both values doesn't shift the weight vertically.
                            HStack(spacing: 10) {
                                if let water = entry.waterPercent {
                                    HStack(spacing: 6) {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(tint)
                                        Text(String(format: "%.0f%%", water))
                                    }
                                }

                                if let bf = entry.bodyFatPercent {
                                    HStack(spacing: 6) {
                                        Image(systemName: "scalemass")
                                            .foregroundStyle(tint)
                                        Text(String(format: "%.1f%%", bf))
                                    }
                                }

                                // If neither metric is present, add an invisible placeholder
                                // that preserves the row height to avoid layout shifts.
                                if entry.waterPercent == nil && entry.bodyFatPercent == nil {
                                    Color.clear
                                        .frame(height: 18)
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 18)

                            // Photo (placed under the additional info)
                            if let data = entry.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        previewImageEntry = entry
                                    }
                                    .accessibilityLabel("Progress photo")
                                    .padding(.top, 6)
                            } else {
                                // Rounded Rectangle placeholder with .glassEffect
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 180, height: 240)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text("No Photo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                                    .padding(.top, 6)
                            }

                            HStack {
                                Spacer()
                                Button {
                                    selectedEntry = entry
                                    showEditor = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }
                        .padding(16)
                        .frame(width: 220)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .id(entry.id)
                    }

                    // Upcoming tile: shows next expected entry date (last entry date + 7 days)
                    VStack(alignment: .center, spacing: 8) {
                        Text("Upcoming")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        Spacer()

                        // Compute next expected date (7 days after last entry)
                        let baseDate = entries.last?.date ?? Date()
                        let nextDate = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate

                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 28))
                                .foregroundStyle(tint)

                            Text("Next expected:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(dateFormatter.string(from: nextDate))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .frame(width: 220)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .id("weekly-upcoming")
                }
                .padding(.vertical, 6)
                .padding(.leading, 2)
            }
            .onAppear {
                if let last = entries.last {
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
            .onChange(of: entries) { _, newEntries in
                if let last = newEntries.last {
                    withAnimation(.easeOut) {
                        proxy.scrollTo(last.id, anchor: .trailing)
                    }
                }
            }
        }
    }
}

private struct WeeklyProgressAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var weightText: String = ""
    @State private var waterText: String = ""
    @State private var bodyFatText: String = ""

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil

    var tint: Color = .accentColor
    var initialEntry: WeeklyProgressEntry? = nil
    var onSave: (WeeklyProgressEntry) -> Void
    var onCancel: () -> Void = {}

    init(
        tint: Color = .accentColor,
        initialEntry: WeeklyProgressEntry? = nil,
        onSave: @escaping (WeeklyProgressEntry) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.tint = tint
        self.initialEntry = initialEntry
        self.onSave = onSave
        self.onCancel = onCancel

        _date = State(initialValue: initialEntry?.date ?? Date())
        _weightText = State(initialValue: initialEntry != nil ? String(format: "%.1f", initialEntry!.weight) : "")
        _waterText = State(initialValue: initialEntry?.waterPercent != nil ? String(format: "%.0f", initialEntry!.waterPercent!) : "")
        _bodyFatText = State(initialValue: initialEntry?.bodyFatPercent != nil ? String(format: "%.1f", initialEntry!.bodyFatPercent!) : "")
        _photoData = State(initialValue: initialEntry?.photoData)
        _photoItem = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        
                        DateComponent(
                            date: Binding(
                                get: { date },
                                set: { date = $0 }
                            ),
                            range: PumpDateRange.birthdate
                        )
                        .surfaceCard(12)
                    }


                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("Weight", text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .surfaceCard(16)
                        .frame(maxWidth: .infinity)
                    }

                    HStack {
                        // Water % input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Body Water")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("e.g. 50", text: $waterText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }

                        Spacer()

                        // Body fat % input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Body Fat")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("e.g. 18.5", text: $bodyFatText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Photo controls: Upload/Replace (PhotosPicker) and Remove
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            let uploadLabel = (photoData == nil) ? "Upload" : "Replace"

                            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                                SelectablePillComponent(
                                    label: uploadLabel,
                                    isSelected: false,
                                    selectedTint: tint
                                ) {
                                    // PhotosPicker will present the picker when tapped
                                }
                                .allowsHitTesting(false)
                            }

                            if photoData != nil {
                                SelectablePillComponent(
                                    label: "Remove",
                                    isSelected: false,
                                    selectedTint: tint
                                ) {
                                    photoData = nil
                                    photoItem = nil
                                }
                            }
                        }
                        .padding(.bottom, 8)

                        if let data = photoData, let ui = UIImage(data: data) {
                            HStack {
                                Spacer()
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 240)
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                Spacer()
                            }
                            .padding(.top, 6)
                        } else {
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 180, height: 240)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(tint.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text("No photo")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                                Spacer()
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle(initialEntry != nil ? "Edit Progress" : "Add Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let weight = Double(weightText) ?? 0
                        let water = Double(waterText)
                        let bf = Double(bodyFatText)
                        let entry = WeeklyProgressEntry(
                            id: initialEntry?.id ?? UUID(),
                            date: date,
                            weight: weight,
                            waterPercent: water,
                            bodyFatPercent: bf,
                            photoData: photoData
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
        }
    }
}