import SwiftUI
import SwiftData
import HealthKit
import PhotosUI
import TipKit
import Charts

private extension WorkoutTabView {
    func fetchDayTakenWorkoutSupplements() {
        // Optimistic load
        let localDay = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        dayTakenWorkoutSupplementIDs = Set(localDay.takenWorkoutSupplements)

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
    var isPro: Bool
    var onDone: () -> Void

    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    // local working state
    @State private var working: [Supplement] = []
    @State private var newName: String = ""
    @State private var newTarget: String = ""
    @State private var hasLoaded = false
    @State private var showProSubscription = false

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

    private let freeTrackedSupplements = 8

    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeTrackedSupplements
    }
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
                                                    .fill(effectiveTint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: "pills.fill")
                                                            .foregroundStyle(effectiveTint)
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
                                                    .fill(effectiveTint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: "pills.fill")
                                                            .foregroundStyle(effectiveTint)
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
                                                        .foregroundStyle(effectiveTint)
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

                        if !isPro {
                            Button(action: { showProSubscription = true }) {
                                HStack(alignment: .center) {
                                    Image(systemName: "sparkles")
                                        .font(.title3)
                                        .foregroundStyle(effectiveTint)
                                        .padding(.trailing, 8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Upgrade to Pro")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Unlock unlimited supplement slots + benefits")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .surfaceCard(16)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 4) {
                            Text("Source:")
                            .font(.footnote)
                            Link("National Institutes of Health (NIH)", destination: URL(string: "https://ods.od.nih.gov/factsheets/ExerciseAndAthleticPerformance-HealthProfessional/")!)
                                .foregroundColor(.blue)
                                .font(.footnote)
                            Spacer()
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
                                            .foregroundStyle(effectiveTint)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAddCustom)
                                    .opacity(!canAddCustom ? 0.4 : 1)
                                }

                                if !isPro {
                                    Text("You can track up to \(freeTrackedSupplements) supplements.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
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
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveTint: Color {
        if themeManager.selectedTheme == .multiColour { return tint }
        return themeManager.selectedTheme.accent(for: colorScheme)
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
    @Binding var sportConfigs: [SportConfig]
    @Binding var sportActivities: [SportActivityRecord]
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
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
    var isPro: Bool
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
    @State private var showProSheet = false
    @State private var showShareSheet = false
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
    @AppStorage("alerts.dailyCheckInEnabled") private var dailyCheckInAlertsEnabled: Bool = true
    @AppStorage("alerts.weeklyProgressTime") private var weeklyProgressTime: Double = 9 * 3600
    @AppStorage("alerts.dailyCheckInTime") private var dailyCheckInTime: Double = 18 * 3600
    @State private var showingAdjustSheet: Bool = false
    @State private var showSubmitDataSheet: Bool = false
    @State private var adjustTarget: String? = nil
    // raw HealthKit readings (kept separate from any manual adjustments)
    @State private var hkCaloriesValue: Double? = nil
    @State private var hkStepsValue: Double? = nil
    @State private var hkDistanceValue: Double? = nil
    @State private var hkValues: [ActivityMetricType: Double] = [:]

    @State private var showDailySummaryEditor = false

    @State private var bodyParts: [BodyPartWeights] = []
    @State private var showWeightsEditor = false
    @State private var isHydratingWeights: Bool = false
    @FocusState private var isWeightsInputFocused: UUID?
    
    @State private var showSportsEditor = false
    @State private var metricsEditorSportIndex: Int? = nil
    @State private var dataEntrySportIndex: Int? = nil
    @State private var editingSportRecord: SportActivityRecord? = nil
    private let historyDays: Int = 7
    @State private var dataEntryDefaultDate: Date? = nil
    @State private var hasLoadedTimeTrackingConfig = false
    @State private var currentDay: Day? = nil
    @State private var teamHistoryDays: [Day] = []
    @State private var hasLoadedSoloDay = false

    private var sportsEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No sports configured", systemImage: "sportscourt")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add sports using the Edit button to track activities and submit data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }

    // MARK: - Models

    struct SportActivity: Identifiable {
        let id = UUID()
        var recordId: String? = nil
        var date: Date
        // Running, Cycling, Swimming
        var distanceKm: Double? = nil
        var durationMin: Double? = nil
        var speedKmh: Double? = nil
        // Swimming
        var laps: Int? = nil
        // Team sports
        var attemptsMade: Int? = nil
        var attemptsMissed: Int? = nil
        var accuracy: Double? = nil
        // Martial arts
        var rounds: Int? = nil
        var roundDuration: Double? = nil
        var points: Int? = nil
        // Pilates/Yoga
        var holdTime: Double? = nil
        var poses: Int? = nil
        // Climbing
        var altitude: Double? = nil
        var timeToPeak: Double? = nil
        var restTime: Double? = nil

        // Custom values keyed by metric key for user-defined metrics.
        var customValues: [String: Double] = [:]

        // Computed properties
        var speedKmhComputed: Double? {
            if let distance = distanceKm, let duration = durationMin, duration > 0 {
                return distance / (duration / 60.0)
            }
            return nil
        }
        var accuracyComputed: Double? {
            if let made = attemptsMade, let missed = attemptsMissed, (made + missed) > 0 {
                return Double(made) / Double(made + missed) * 100.0
            }
            return nil
        }
    }

    struct SportMetric: Identifiable {
        let id = UUID()
        var key: String // e.g. "distanceKm", "durationMin", etc.
        var label: String // e.g. "Distance", "Duration"
        var unit: String // e.g. "km", "min"
        var color: Color
        var valueTransform: ((SportActivity) -> Double)? = nil // Optional custom transform
    }

    struct SportType: Identifiable {
        let id = UUID()
        var name: String
        var color: Color
        var activities: [SportActivity]
        var metrics: [SportMetric]
    }

    struct SportPreset: Identifiable {
        let id = UUID()
        var name: String
        var color: Color
        var metrics: [SportMetric]
    }

    struct SportMetricPreset: Identifiable {
        let id = UUID()
        var key: String
        var label: String
        var unit: String
        var color: Color
        var valueTransform: ((SportActivity) -> Double)? = nil

        func metric() -> SportMetric {
            SportMetric(key: key, label: label, unit: unit, color: color, valueTransform: valueTransform)
        }
    }

    private static let metricPresets: [SportMetricPreset] = [
        .init(key: "distanceKm", label: "Distance", unit: "km", color: .blue),
        .init(key: "durationMin", label: "Duration", unit: "min", color: .green),
        .init(key: "speedKmh", label: "Speed", unit: "km/h", color: .orange),
        .init(key: "speedKmhComputed", label: "Speed", unit: "km/h", color: .orange, valueTransform: { $0.speedKmhComputed ?? 0 }),
        .init(key: "laps", label: "Laps", unit: "laps", color: .purple),
        .init(key: "attemptsMade", label: "Attempts Made", unit: "count", color: .teal),
        .init(key: "attemptsMissed", label: "Attempts Missed", unit: "count", color: .red),
        .init(key: "accuracy", label: "Accuracy", unit: "%", color: .yellow),
        .init(key: "accuracyComputed", label: "Accuracy (calc)", unit: "%", color: .yellow, valueTransform: { $0.accuracyComputed ?? 0 }),
        .init(key: "rounds", label: "Rounds", unit: "rounds", color: .indigo),
        .init(key: "roundDuration", label: "Round Duration", unit: "min", color: .mint),
        .init(key: "points", label: "Points", unit: "pts", color: .pink),
        .init(key: "holdTime", label: "Hold Time", unit: "sec", color: .cyan),
        .init(key: "poses", label: "Poses", unit: "poses", color: .brown),
        .init(key: "altitude", label: "Altitude", unit: "m", color: .gray),
        .init(key: "timeToPeak", label: "Time to Peak", unit: "min", color: .blue.opacity(0.7)),
        .init(key: "restTime", label: "Rest Time", unit: "min", color: .green.opacity(0.7))
    ]

    private static var metricPresetByKey: [String: SportMetricPreset] {
        Dictionary(uniqueKeysWithValues: metricPresets.map { ($0.key, $0) })
    }

    private static func metrics(forKeys keys: [String]) -> [SportMetric] {
        keys.compactMap { metricPresetByKey[$0]?.metric() }
    }

    private static let sportPresets: [SportPreset] = [
        .init(name: "Running", color: .blue, metrics: metrics(forKeys: ["distanceKm", "durationMin", "speedKmhComputed"])),
        .init(name: "Cycling", color: .green, metrics: metrics(forKeys: ["distanceKm", "durationMin", "speedKmhComputed"])),
        .init(name: "Swimming", color: .purple, metrics: metrics(forKeys: ["distanceKm", "laps", "durationMin"])),
        .init(name: "Team Sports", color: .teal, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "attemptsMissed", "accuracyComputed"])),
        .init(name: "Martial Arts", color: .indigo, metrics: metrics(forKeys: ["rounds", "roundDuration", "points"])),
        .init(name: "Pilates/Yoga", color: .brown, metrics: metrics(forKeys: ["durationMin", "holdTime", "poses"])),
        .init(name: "Climbing", color: .gray, metrics: metrics(forKeys: ["altitude", "timeToPeak", "restTime", "durationMin"])),
        .init(name: "Padel", color: .pink, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "points"])),
        .init(name: "Tennis", color: .orange, metrics: metrics(forKeys: ["durationMin", "attemptsMade", "attemptsMissed", "accuracy", "points"]))
    ]

    @State private var sports: [SportType] = []

    init(
        sportConfigs: Binding<[SportConfig]>,
        sportActivities: Binding<[SportActivityRecord]>,
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
        isPro: Bool,
        lastWeightEntryByExerciseId: [UUID: WeightExerciseValue],
        onUpdateDailyActivity: @escaping (_ calories: Double?, _ steps: Double?, _ distance: Double?) -> Void,
        onUpdateDailyGoals: @escaping (_ calorieGoal: Int, _ stepsGoal: Int, _ distanceGoal: Double) -> Void,
        onUpdateWeightGroups: @escaping ([WeightGroupDefinition]) -> Void,
        onUpdateWeightEntries: @escaping ([WeightExerciseValue]) -> Void,
        onSelectCheckInStatus: @escaping (WorkoutCheckInStatus, Int?) -> Void,
        onUpdateAutoRestDays: @escaping (Set<Int>) -> Void,
        onClearWeekCheckIns: @escaping () -> Void
    ) {
        _sportConfigs = sportConfigs
        _sportActivities = sportActivities
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
        self.isPro = isPro
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true }, isPro: isPro)
                            .environmentObject(account)

                        Text("Schedule Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                        .id("dailyCheckIn")

                    DailyCheckInSection(
                        weeklyProgress: $weeklyCheckInStatuses,
                        accentColor: accentOverride ?? .accentColor,
                        currentDayIndex: currentDayIndex,
                        onEditRestDays: { showRestDaySheet = true },
                        onSelectStatus: { status in onSelectCheckInStatus(status, nil) },
                        onSelectStatusAtIndex: { status, idx in onSelectCheckInStatus(status, idx) }
                    )
                    .workoutTip(.dailyCheckIn, onStepChange: { step in
                        if step == 1 {
                            withAnimation {
                                proxy.scrollTo("dailyCheckIn", anchor: .top)
                            }
                        }
                    })

                    WeeklyWorkoutScheduleCard(
                        schedule: $workoutSchedule,
                        weightGroups: $weightGroups,
                        accentColor: accentOverride ?? .accentColor,
                        isPro: isPro,
                        onSave: { updated in
                            persistWorkoutSchedule(updated)
                        }
                    )
                    .workoutTip(.editSchedule, onStepChange: { step in
                        if step == 2 {
                            withAnimation {
                                proxy.scrollTo("workoutSupplements", anchor: .top)
                            }
                        }
                    })
                    
                    HStack {
                        Text("Daily Activity Summary")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)

                    Button {
                        showDailySummaryEditor = true
                    } label: {
                        Label("Change Goals", systemImage: "pencil")
                          .font(.callout.weight(.semibold))
                          .padding(.vertical, 18)
                          .frame(maxWidth: .infinity, minHeight: 52)
                          .glassEffect(in: .rect(cornerRadius: 16.0))
                          .contentShape(Rectangle())
                    }
                    .nutritionTip(.editCalorieGoal)
                    .padding(.top, 16)
                    .padding(.horizontal, 18)
                    .buttonStyle(.plain)

                    if account.dailySummaryMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("No daily summary metrics", systemImage: "checklist")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add metrics using the Edit button to start tracking your daily activity.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                    } else {
                        // Dynamic Metrics Grid
                        DailyMetricsGrid(
                            metrics: account.dailySummaryMetrics,
                            hkValues: hkValues,
                            manualAdjustmentProvider: manualAdjustment,
                            accentColor: accentOverride
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(accentOverride ?? .pink)
                            Text("Synced with Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showSubmitDataSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Spacer()
                                Label("Submit Data", systemImage: "paperplane.fill")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(accentOverride ?? .orange, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .padding(.horizontal, 18)
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 16.0))
                        .padding(.top, 16)
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
                        .workoutTip(.editSupplements, onStepChange: { step in
                            if step == 4 {
                                withAnimation {
                                    proxy.scrollTo("weightsTracking", anchor: .top)
                                }
                            }
                        })
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)
                    .id("workoutSupplements")
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
                    .workoutTip(.workoutSupplements, onStepChange: { step in
                        if step == 3 {
                            withAnimation {
                                proxy.scrollTo("workoutSupplements", anchor: .top)
                            }
                        }
                    })
                    .onAppear {
                        // Respect an explicitly-empty `workoutSupplements`; do not auto-seed defaults here.
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
                            isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty,
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
                        .workoutTip(.editTracking, onStepChange: { step in
                            if step == 6 {
                                withAnimation {
                                    proxy.scrollTo("weeklyProgress", anchor: .top)
                                }
                            }
                        })
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)
                    .id("weightsTracking")
                    
                    // Weights tracking section
                    WeightsTrackingSection(
                        bodyParts: $bodyParts,
                        focusBinding: $isWeightsInputFocused,
                        onTipStepChange: { step in
                            if step == 5 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("weightsTracking", anchor: .top)
                                    }
                                }
                            }
                        }
                    )

                    // MARK: - Weekly Progress Section
                    VStack(spacing: 0) {
                        HStack {
                            Text("Weekly Progress")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showAddSheet = true
                            } label: {
                                Label("Add", systemImage: "plus")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .workoutTip(.weeklyProgress)
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                        .opacity(isPro ? 1 : 0.5)
                        .blur(radius: isPro ? 0 : 4)
                        .disabled(!isPro)

                        WeeklyProgressCarousel(accentColorOverride: accentOverride,
                                                entries: $weeklyEntries,
                                                selectedEntry: $weeklySelectedEntry,
                                                showEditor: $weeklyShowEditor,
                                                previewImageEntry: $previewImageEntry)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .id("weeklyProgress")
                            .opacity(isPro ? 1 : 0.5)
                            .blur(radius: isPro ? 0 : 4)
                            .disabled(!isPro)
                            .overlay {
                                if !isPro {
                                    ZStack {
                                        Color.black.opacity(0.001) // Capture taps
                                            .onTapGesture {
                                                // Optional: Trigger upgrade flow
                                            }
                                        
                                        Button {
                                            showProSheet = true
                                        } label: {
                                            VStack(spacing: 8) {
                                                HStack {
                                                    let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                                    if let accent {
                                                        Image("logo")
                                                            .resizable()
                                                            .renderingMode(.template)
                                                            .foregroundStyle(accent)
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(height: 40)
                                                            .padding(.leading, 4)
                                                            .offset(y: 6)
                                                    } else {
                                                        Image("logo")
                                                            .resizable()
                                                            .renderingMode(.original)
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(height: 40)
                                                            .padding(.leading, 4)
                                                            .offset(y: 6)
                                                    }
                                                    
                                                    Text("PRO")
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(Color.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                                .fill(
                                                                    accent.map {
                                                                        LinearGradient(
                                                                            gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                                            startPoint: .topLeading,
                                                                            endPoint: .bottomTrailing
                                                                        )
                                                                    } ?? LinearGradient(
                                                                        gradient: Gradient(colors: [
                                                                            Color(red: 0.74, green: 0.43, blue: 0.97),
                                                                            Color(red: 0.83, green: 0.99, blue: 0.94)
                                                                        ]),
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    )
                                                                )
                                                        )
                                                        .offset(y: 6)
                                                }
                                                .padding(.bottom, 5)
                                                
                                                Text("Trackerio Pro")
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                
                                                Text("Upgrade to unlock Weekly Progress + More")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding()
                                            .glassEffect(in: .rect(cornerRadius: 16.0))
                                        }
                                        .buttonStyle(.plain)
                                        .sheet(isPresented: $showProSheet) {
                                            ProSubscriptionView()
                                        }
                                    }
                                }
                            }
                    }
                    
                    // Sports Tracking
                    VStack {
                        HStack {
                            Text("Sports Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showSportsEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .sportsTip(.editSports, isEnabled: isPro, onStepChange: { step in
                                if step == 4 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo("sportsTracking", anchor: .center)
                                        }
                                    }
                                }
                            })
                            .id("editSports")
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 38)
                        .padding(.bottom, 8)

                        if sports.isEmpty {
                            sportsEmptyState
                                .padding(.horizontal, 18)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(sports.enumerated()), id: \.offset) { idx, sport in
                                    let displayColor: Color = themeManager.selectedTheme == .multiColour ? sport.color : themeManager.selectedTheme.accent(for: colorScheme)
                                    VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(displayColor)
                                            .frame(width: 16, height: 16)

                                        Text(sport.name)
                                            .font(.callout.weight(.semibold))
                                            .multilineTextAlignment(.leading)

                                        Spacer()

                                        Button {
                                            metricsEditorSportIndex = idx
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.callout.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .glassEffect(in: .rect(cornerRadius: 14.0))
                                                .accessibilityLabel("Edit sport metrics")
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if idx == 0 {
                                        Button {
                                            dataEntrySportIndex = idx
                                            editingSportRecord = nil
                                            dataEntryDefaultDate = selectedDate
                                        } label: {
                                            HStack(spacing: 8) {
                                                Spacer()
                                                Label("Submit Data", systemImage: "paperplane.fill")
                                                    .font(.callout.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                            }
                                            .padding(.vertical, 18)
                                            .frame(maxWidth: .infinity, minHeight: 52)
                                            .background(displayColor, in: RoundedRectangle(cornerRadius: 18))
                                        }
                                        .sportsTip(.sportsTracking, isEnabled: isPro)
                                        .id("sportsTracking")
                                        .padding(.horizontal, 8)
                                        .buttonStyle(.plain)
                                        .contentShape(RoundedRectangle(cornerRadius: 16.0))
                                    } else {
                                        Button {
                                            dataEntrySportIndex = idx
                                            editingSportRecord = nil
                                            dataEntryDefaultDate = selectedDate
                                        } label: {
                                            HStack(spacing: 8) {
                                                Spacer()
                                                Label("Submit Data", systemImage: "paperplane.fill")
                                                    .font(.callout.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                            }
                                            .padding(.vertical, 18)
                                            .frame(maxWidth: .infinity, minHeight: 52)
                                            .background(displayColor, in: RoundedRectangle(cornerRadius: 18))
                                        }
                                        .padding(.horizontal, 8)
                                        .buttonStyle(.plain)
                                        .contentShape(RoundedRectangle(cornerRadius: 16.0))
                                    }

                                    if !sport.metrics.isEmpty {
                                        ForEach(sport.metrics) { metric in
                                            SportMetricGraph(
                                                metric: metric,
                                                activities: sport.activities,
                                                historyDays: historyDays,
                                                anchorDate: selectedDate,
                                                accentOverride: themeManager.selectedTheme == .multiColour ? nil : displayColor
                                            )
                                            .frame(height: 140)
                                            .padding(.bottom, 8)
                                        }
                                    }

                                    let weekDates = sportWeekDates(anchor: selectedDate)
                                    let sportRecords = sportActivities.filter { $0.sportName.lowercased() == sport.name.lowercased() }

                                    // Only include days that actually have records
                                    let daysWithRecords = weekDates.filter { d in
                                        sportRecords.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: d) })
                                    }

                                    if !daysWithRecords.isEmpty {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundStyle(.secondary)
                                            Text("Recent Records")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.top, 12)

                                        VStack(spacing: 12) {
                                            ForEach(daysWithRecords.reversed(), id: \.self) { day in
                                                let dayRecords = sportRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                                                ForEach(dayRecords.reversed(), id: \.id) { record in
                                                    SportRecordCard(
                                                        date: day,
                                                        record: record,
                                                        onEdit: {
                                                            editingSportRecord = record
                                                            dataEntrySportIndex = idx
                                                            dataEntryDefaultDate = record.date
                                                        },
                                                        onDelete: {
                                                            sportActivities.removeAll { $0.id == record.id }
                                                            rebuildSports()
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                    }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                            }
                            }
                            .padding(.top, -12)
                        }
                    }

                    // Live Games Tracking
                    LiveGamesTrackingView(selectedDate: $selectedDate)
                    .opacity(isPro ? 1 : 0.5)
                    .blur(radius: isPro ? 0 : 4)
                    .disabled(!isPro)
                    .overlay {
                        if !isPro {
                            ZStack {
                                Color.black.opacity(0.001) // Capture taps
                                    .onTapGesture {
                                        // Optional: Trigger upgrade flow
                                    }
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                        if let accent {
                                            Image("logo")
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundStyle(accent)
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 40)
                                                .padding(.leading, 4)
                                                .offset(y: 6)
                                        } else {
                                            Image("logo")
                                                .resizable()
                                                .renderingMode(.original)
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 40)
                                                .padding(.leading, 4)
                                                .offset(y: 6)
                                        }
                                        
                                        Text("PRO")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(
                                                        accent.map {
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        } ?? LinearGradient(
                                                            gradient: Gradient(colors: [
                                                                Color(red: 0.74, green: 0.43, blue: 0.97),
                                                                Color(red: 0.83, green: 0.99, blue: 0.94)
                                                            ]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            )
                                            .offset(y: 6)
                                    }
                                    .padding(.bottom, 5)
                                    
                                    Text("Trackerio Pro")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text("Upgrade to unlock Match Tracking + More")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                            }
                        }
                    }

                    // Coaching inquiry card
                    CoachingInquiryCTA()
                        .padding(.top, 24)
                    
                    ShareWorkoutCTA(accentColor: accentOverride ?? .accentColor) {
                        showShareSheet = true
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
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
        .sheet(isPresented: $showSubmitDataSheet) {
            DailyActivityEntrySheet(
                metrics: account.dailySummaryMetrics,
                hkValues: hkValues
            ) { type, isAdd, valString in
                handleAdjustAction(isAddition: isAdd, valueString: valString, target: type.id)
            }
            .presentationDetents([.large])
            .accentColor(accentOverride ?? .orange)
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
                },
                onDelete: {
                    if let idx = weeklyEntries.firstIndex(where: { $0.id == entry.id }) {
                        weeklyEntries.remove(at: idx)
                        persistWeeklyProgressEntries()
                        scheduleProgressReminder()
                    }
                    weeklySelectedEntry = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDailySummaryEditor) {
            DailySummaryEditorSheet(
                metrics: $account.dailySummaryMetrics,
                tint: accentOverride ?? .accentColor,
                isPro: isPro,
                onDone: {
                    do {
                        try modelContext.save()
                    } catch { print("Failed to save account changes: \(error)") }
                    accountFirestoreService.saveAccount(account) { _ in }
                    
                    // Request auth for potentially new metrics, then refresh
                    let types = account.dailySummaryMetrics.map { $0.type }
                    healthKitService.requestAuthorization(for: types) { ok in
                        DispatchQueue.main.async {
                            // Update authorized state so the "Connected" pill appears
                            healthKitAuthorized = ok
                            // If user cancels or denies, ok might be true/false depending on implementation
                            // but we treat valid auth object as success.
                            // Even if false, we try to refresh what we can.
                            refreshHealthKitValues()
                        }
                    }
                    
                    showDailySummaryEditor = false
                },
                onCancel: { showDailySummaryEditor = false }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWeightsEditor) {
            WeightsGroupEditorSheet(bodyParts: $bodyParts, isPro: isPro) { updated in
                bodyParts = updated
                showWeightsEditor = false
            }
        }
        .sheet(isPresented: $showShareSheet) {
            // Build today's schedule snapshots
            let todaysSessions: [WorkoutScheduleSnapshot] = (workoutSchedule.indices.contains(currentDayIndex) ? workoutSchedule[currentDayIndex].sessions : [])
                .map { s in WorkoutScheduleSnapshot(title: s.name, timeText: s.formattedTime) }

            let measurements = BodyMeasurements(
                lastWeightKg: weeklyEntries.last?.weight ?? account.weight,
                waterPercent: weeklyEntries.last?.waterPercent,
                fatPercent: weeklyEntries.last?.bodyFatPercent
            )

            let checkInStatusText: String = {
                guard weeklyCheckInStatuses.indices.contains(currentDayIndex) else { return "" }
                switch weeklyCheckInStatuses[currentDayIndex] {
                case .checkIn: return "Checked In"
                case .rest: return "Rest Day"
                case .notLogged: return ""
                }
            }()

            WorkoutShareSheet(
                accentColor: accentOverride ?? .accentColor,
                dailyCheckIn: checkInStatusText,
                dailySummary: DailySummarySnapshot(
                    calories: caloriesBurnedToday,
                    steps: stepsTakenToday,
                    distanceMeters: distanceTravelledToday
                ),
                schedule: todaysSessions,
                supplements: account.workoutSupplements,
                takenSupplements: dayTakenWorkoutSupplementIDs,
                weightGroups: weightGroups,
                weightEntries: weightEntries,
                measurements: measurements,
                trackedMetrics: account.dailySummaryMetrics,
                hkValues: hkValues,
                manualValues: {
                    var m: [ActivityMetricType: Double] = [:]
                    m[.calories] = max(0, caloriesBurnedToday - (hkValues[.calories] ?? 0))
                    m[.steps] = max(0, stepsTakenToday - (hkValues[.steps] ?? 0))
                    m[.distanceWalking] = max(0, distanceTravelledToday - (hkValues[.distanceWalking] ?? 0))
                    return m
                }()
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSportsEditor) {
            SportsEditorSheet(sports: $sports, presets: Self.sportPresets) { updated in
                sports = updated
                sportConfigs = configs(from: updated)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { metricsEditorSportIndex != nil },
                set: { newValue in if !newValue { metricsEditorSportIndex = nil } }
            )
        ) {
            if let idx = metricsEditorSportIndex, sports.indices.contains(idx) {
                SportMetricsEditorSheet(
                    sportName: sports[idx].name,
                    metrics: $sports[idx].metrics,
                    presets: Self.metricPresets,
                    accent: themeManager.selectedTheme == .multiColour ? sports[idx].color : themeManager.selectedTheme.accent(for: colorScheme)
                ) { updated in
                    sports[idx].metrics = updated
                    sportConfigs = configs(from: sports)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { dataEntrySportIndex != nil || editingSportRecord != nil },
                set: { newValue in if !newValue { dataEntrySportIndex = nil; editingSportRecord = nil; dataEntryDefaultDate = nil } }
            )
        ) {
            let idx: Int? = {
                if let i = dataEntrySportIndex { return i }
                if let record = editingSportRecord {
                    return sports.firstIndex { $0.name.lowercased() == record.sportName.lowercased() }
                }
                return nil
            }()

            if let idx, sports.indices.contains(idx) {
                let baseDate = dataEntryDefaultDate ?? editingSportRecord?.date ?? selectedDate
                let existingActivity = editingSportRecord.map { activity(from: $0) }
                SportDataEntrySheet(
                    sportName: sports[idx].name,
                    metrics: sports[idx].metrics,
                    defaultDate: baseDate,
                    accent: themeManager.selectedTheme == .multiColour ? sports[idx].color : themeManager.selectedTheme.accent(for: colorScheme),
                    existingActivity: existingActivity
                ) { activity in
                    let record = record(from: activity, metrics: sports[idx].metrics, sportName: sports[idx].name, color: sports[idx].color, existingId: activity.recordId)
                    if let existingId = activity.recordId, let existingIndex = sportActivities.firstIndex(where: { $0.id == existingId }) {
                        sportActivities[existingIndex] = record
                    } else {
                        sportActivities.append(record)
                    }
                    dataEntrySportIndex = nil
                    editingSportRecord = nil
                    dataEntryDefaultDate = nil
                    rebuildSports()
                } onCancel: {
                    dataEntrySportIndex = nil
                    editingSportRecord = nil
                    dataEntryDefaultDate = nil
                }
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            currentDay = nil
            hasLoadedSoloDay = false
            loadDayForSelectedDate()
            refreshHealthKitValues()
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
        .onAppear {
            rebuildSports()
            loadDayForSelectedDate()
        }
        .onChange(of: sportConfigs) { _, _ in rebuildSports() }
        .onChange(of: sportActivities) { _, _ in rebuildSports() }
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
            
            // Request auth for any existing metrics so we can read them immediately
            DispatchQueue.main.async {
                loadManualOverrides()
                let metrics = account.dailySummaryMetrics
                healthKitService.requestAuthorization(for: metrics.map { $0.type }) { _ in
                    refreshHealthKitValues()
                }
            }
        }
        .onAppear {
            reloadWeeklyProgressFromAccount()
            ensurePlaceholderIfNeeded(persist: false)
            refreshProgressFromRemote()
            refreshCheckInNotifications()
        }
        .onChange(of: weeklyCheckInStatuses) { _, _ in
            refreshCheckInNotifications()
        }
        .onChange(of: account.weeklyProgress) { _, _ in
            reloadWeeklyProgressFromAccount()
            ensurePlaceholderIfNeeded(persist: false)
            scheduleProgressReminder()
        }
        .onChange(of: autoRestDayIndices) { _, _ in
            refreshCheckInNotifications()
        }
        .onChange(of: dailyCheckInAlertsEnabled) { _, _ in
            refreshCheckInNotifications()
        }
        .onChange(of: weeklyProgressTime) { _, _ in
            scheduleProgressReminder()
        }
        .onChange(of: dailyCheckInTime) { _, _ in
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

    private struct SportRecordCard: View {
        let date: Date
        let record: SportActivityRecord
        let onEdit: () -> Void
        let onDelete: () -> Void

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            VStack(spacing: 0) {
                // Header with Date and Actions
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DateFormatter.sportWeekdayFull.string(from: date).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(DateFormatter.sportLongDate.string(from: date))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor.opacity(0.8))
                                .padding(8)
                                .background(Color.accentColor.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(8)
                                .background(.red.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemFill).opacity(0.5))

                // Content
                HStack(spacing: 0) {
                    if record.values.isEmpty {
                        Text("No metrics recorded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: .infinity), spacing: 8)], spacing: 8) {
                            ForEach(record.values, id: \.id) { val in
                                VStack(spacing: 2) {
                                    Text(val.label)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    Text(formatMetricValue(val))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.systemBackground).opacity(colorScheme == .dark ? 0.2 : 0.5))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(Color(UIColor.secondarySystemFill))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }

        private func formatMetricValue(_ value: SportMetricValue) -> String {
            let intVal = Int(value.value)
            let numberString: String
            if Double(intVal) == value.value {
                numberString = String(intVal)
            } else {
                numberString = String(format: "%.2f", value.value)
            }
            if value.unit.isEmpty { return numberString }
            return "\(numberString) \(value.unit)"
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
        
        // Reschedule notifications
        if UserDefaults.standard.object(forKey: "alerts.weeklyScheduleEnabled") as? Bool ?? true {
            NotificationsHelper.scheduleWeeklyScheduleNotifications(updated)
        } else {
            NotificationsHelper.removeWeeklyScheduleNotifications()
        }
    }

    func scheduleProgressReminder() {
        let baseDate = weeklyEntries.last?.date ?? Date()
        let nextDate = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate
        var components = Calendar.current.dateComponents([.weekday], from: nextDate)
        if components.weekday == nil {
            components.weekday = Calendar.current.component(.weekday, from: Date())
        }
        
        let progressTimeVal = UserDefaults.standard.object(forKey: "alerts.weeklyProgressTime") as? Double
        let progressTime = progressTimeVal ?? (9 * 3600)
        components.hour = Int(progressTime) / 3600
        components.minute = (Int(progressTime) % 3600) / 60

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
            content.title = "Weekly Progress Reminder"
            content.body = "Time to record your weekly progress."
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

        if persist {
            persistWeeklyProgressEntries()
        }

        if !weeklyEntries.isEmpty {
            scheduleProgressReminder()
        }
    }

    // Downsample + recompress photos to keep Firestore documents within limits.
    // Target ~60KB per image so multiple entries fit in 1MB Firestore limit.
    private func compressImageDataIfNeeded(_ data: Data?, maxBytes: Int = 60_000) -> Data? {
        guard let data, !data.isEmpty else { return data }

        // Even if small, we re-process to ensure resolution is appropriate for Base64 storage.
        guard let image = UIImage(data: data) else { return data }

        // Small width for progress tracking is sufficient.
        let targetWidth: CGFloat = 450
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        let targetSize = CGSize(width: targetWidth, height: targetHeight)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // Try a few quality levels.
        let qualities: [CGFloat] = [0.5, 0.4, 0.3, 0.2]
        for quality in qualities {
            if let compressed = scaledImage.jpegData(compressionQuality: quality), compressed.count <= maxBytes {
                return compressed
            }
        }

        return scaledImage.jpegData(compressionQuality: 0.15) ?? data
    }

    func persistWeeklyProgressEntries() {
        let filteredEntries = weeklyEntries.filter { entry in
            entry.weight != 0 || entry.waterPercent != nil || entry.bodyFatPercent != nil || entry.photoData != nil
        }

        var mergedById: [UUID: WeeklyProgressEntry] = [:]
        for entry in filteredEntries {
            mergedById[entry.id] = entry
        }

        let mergedEntries = mergedById.values.sorted { $0.date < $1.date }
        weeklyEntries = mergedEntries

        // Map to records with compressed images for persistence.
        let compressedRecords: [WeeklyProgressRecord] = mergedEntries.map {
            WeeklyProgressRecord(
                id: $0.id.uuidString,
                date: $0.date,
                weight: $0.weight,
                waterPercent: $0.waterPercent,
                bodyFatPercent: $0.bodyFatPercent,
                photoData: compressImageDataIfNeeded($0.photoData)
            )
        }

        // Update local SwiftData model.
        account.weeklyProgress = compressedRecords

        do {
            try modelContext.save()
        } catch {
            print("WorkoutTabView: failed to save weekly progress locally: \(error)")
        }

        guard !compressedRecords.isEmpty, let accountId = account.id else { return }

        // Phase 1: save metadata immediately.
        let metadataOnly = compressedRecords.map { record in
            WeeklyProgressRecord(
                id: record.id,
                date: record.date,
                weight: record.weight,
                waterPercent: record.waterPercent,
                bodyFatPercent: record.bodyFatPercent,
                photoData: nil
            )
        }

        accountFirestoreService.updateWeeklyProgress(withId: accountId, progress: metadataOnly) { success in
            if !success {
                print("WorkoutTabView: failed to sync weekly progress metadata to Firestore")
            }
        }

        // Phase 2: upload photos after a short delay.
        if compressedRecords.contains(where: { $0.photoData != nil }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                accountFirestoreService.updateWeeklyProgress(withId: accountId, progress: compressedRecords) { success in
                    if !success {
                        print("WorkoutTabView: failed to sync weekly progress photos to Firestore")
                    }
                }
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
                    // Merge remote with any richer local entries (e.g., local photo present when remote upload failed).
                    let localById = Dictionary(localProgress.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
                    let merged: [WeeklyProgressRecord] = remoteProgress.map { remote in
                        if let local = localById[remote.id] {
                            let photoData = local.photoData ?? remote.photoData
                            return WeeklyProgressRecord(
                                id: remote.id,
                                date: remote.date,
                                weight: remote.weight,
                                waterPercent: remote.waterPercent,
                                bodyFatPercent: remote.bodyFatPercent,
                                photoData: photoData
                            )
                        }
                        return remote
                    }

                    account.weeklyProgress = merged
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
                    print("WorkoutTabView: failed to cache remote weekly progress: \(error)")
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
        let change = isAddition ? val : -val
        let resolved = target ?? ""
        
        if let type = ActivityMetricType(rawValue: resolved) {
            DispatchQueue.main.async {
                switch type {
                case .steps:
                    stepsTakenToday += change
                    stepsTakenToday = max(0, stepsTakenToday)
                    persistActivityToDay(steps: stepsTakenToday)
                    saveManualOverride(key: "steps", value: stepsTakenToday)
                case .distanceWalking:
                    distanceTravelledToday += change
                    distanceTravelledToday = max(0, distanceTravelledToday)
                    persistActivityToDay(distance: distanceTravelledToday)
                    saveManualOverride(key: "walking", value: distanceTravelledToday)
                case .calories:
                    caloriesBurnedToday += change
                    caloriesBurnedToday = max(0, caloriesBurnedToday)
                    persistActivityToDay(calories: caloriesBurnedToday)
                    saveManualOverride(key: "calories", value: caloriesBurnedToday)
                default:
                    // Generic handling
                    let day = currentDay ?? Day.fetchOrCreate(for: selectedDate, in: modelContext)
                    var currentManual = day.activityMetricAdjustments.first(where: { $0.metricId == type.id })?.manualValue ?? 0
                    currentManual += change
                    
                    if let idx = day.activityMetricAdjustments.firstIndex(where: { $0.metricId == type.id }) {
                        day.activityMetricAdjustments[idx].manualValue = currentManual
                    } else {
                        let newAdj = SoloMetricValue(metricId: type.id, metricName: type.displayName, value: currentManual)
                        day.activityMetricAdjustments.append(newAdj)
                    }
                    
                    do {
                        try modelContext.save()
                        // Ensure view updates
                        self.currentDay = day
                    } catch {
                        print("Failed to save daily adjustments: \(error)")
                    }
                }
                
                self.syncMetricsToAccount()
            }
        }
    }

    func rebuildBodyPartsFromModel() {
        isHydratingWeights = true
        // Use the stored weight groups exactly as-is so an explicit empty
        // value isn't silently replaced by defaults.
        let resolvedGroups = weightGroups
        let entriesByExercise = Dictionary(weightEntries.map { ($0.exerciseId, $0) }, uniquingKeysWith: { (first, _) in first })
        let editingStates = Dictionary(bodyParts.map { ($0.id, $0.isEditing) }, uniquingKeysWith: { (first, _) in first })

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
            let isEditing = editingStates[group.id] ?? false
            return BodyPartWeights(id: group.id, name: group.name, exercises: exercises, isEditing: isEditing)
        }

        // Leave `bodyParts` empty if there are no stored groups so we don't
        // accidentally persist UI defaults back into the model.
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

    func refreshHealthKitValues(applyToState: Bool = true, persist: Bool = true) {
        let group = DispatchGroup()
        var newValues: [ActivityMetricType: Double] = [:]

        // Use selectedDate instead of hardcoded today
        let queryDate = selectedDate

        for type in ActivityMetricType.allCases {
            group.enter()
            healthKitService.fetchMetric(type: type, for: queryDate) { val in
                if let v = val {
                    newValues[type] = v
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Capture existing manual adjustments using OLD HK values before updating them
            let manualSteps = self.stepsTakenToday - (self.hkStepsValue ?? 0)
            let manualDistance = self.distanceTravelledToday - (self.hkDistanceValue ?? 0)
            let manualCalories = self.caloriesBurnedToday - (self.hkCaloriesValue ?? 0)

            self.hkValues = newValues
            
            // Sync legacy vars
            self.hkCaloriesValue = newValues[.calories]
            self.hkStepsValue = newValues[.steps]
            self.hkDistanceValue = newValues[.distanceWalking]
            
            if applyToState {
                if let s = newValues[.steps] { self.stepsTakenToday = s + manualSteps }
                if let d = newValues[.distanceWalking] { self.distanceTravelledToday = d + manualDistance }
                if let c = newValues[.calories] { self.caloriesBurnedToday = c + manualCalories }
                else if self.caloriesBurnedToday == 0 {
                    self.caloriesBurnedToday = self.estimateCaloriesFromAccount() + manualCalories
                }
                
                if persist {
                    self.onUpdateDailyActivity(self.caloriesBurnedToday, self.stepsTakenToday, self.distanceTravelledToday)
                }
                
                self.syncMetricsToAccount()
                self.syncActivityHKToDay(newValues)
            }
        }
    }
    
    private func syncActivityHKToDay(_ values: [ActivityMetricType: Double]) {
         let day = currentDay ?? Day.fetchOrCreate(for: selectedDate, in: modelContext)
         var changed = false
         var adjustments = day.activityMetricAdjustments
         
         for (type, val) in values {
             if let idx = adjustments.firstIndex(where: { $0.metricId == type.id }) {
                 if adjustments[idx].healthKitValue != val {
                     adjustments[idx].healthKitValue = val
                     changed = true
                 }
             } else {
                 var newEntry = SoloMetricValue(metricId: type.id, metricName: type.displayName, value: 0)
                 newEntry.healthKitValue = val
                 adjustments.append(newEntry)
                 changed = true
             }
         }
         
         if changed {
             day.activityMetricAdjustments = adjustments
             try? modelContext.save()
             // persistActivityToDay handles core metrics, but we might want to trigger full day save if possible.
             // But persistActivityToDay is specific to cal/steps/dist.
             // If we had dayFirestoreService here we would use it.
             // Since we modify 'day' (SwiftData), RootView should pick it up if observing.
         }
    }
    
    // Syncs the current calculated values (HK + manual) into the Account's dailySummaryMetrics list
    // and persists to Firestore so the 'value' field is populated in the database.
    private func syncMetricsToAccount() {
        var metrics = account.dailySummaryMetrics
        var changed = false
        
        for i in metrics.indices {
            let type = metrics[i].type
            let manual = manualAdjustment(for: type)
            let hk = hkValues[type] ?? 0
            
            if metrics[i].manualValue != manual || metrics[i].healthKitValue != hk {
                metrics[i].manualValue = manual
                metrics[i].healthKitValue = hk
                changed = true
            }
        }
        
        if changed {
            account.dailySummaryMetrics = metrics
            // Trigger Firestore save to ensure values appear in the DB
            accountFirestoreService.saveAccount(account) { _ in }
        }
    }

    func manualAdjustment(for type: ActivityMetricType) -> Double {
        switch type {
        case .steps:
            return stepsTakenToday - (hkStepsValue ?? 0)
        case .distanceWalking:
            return distanceTravelledToday - (hkDistanceValue ?? 0)
        case .calories:
            return caloriesBurnedToday - (hkCaloriesValue ?? 0)
        default:
            if let d = currentDay, Calendar.current.isDate(d.date, inSameDayAs: selectedDate) {
                return d.activityMetricAdjustments.first(where: { $0.metricId == type.id })?.manualValue ?? 0
            }
            
            // Fetch
            let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
            return day.activityMetricAdjustments.first(where: { $0.metricId == type.id })?.manualValue ?? 0
        }
    }
    
    func metricValueAndProgress(for metric: TrackedActivityMetric) -> (String, Double) {
        let hkVal = hkValues[metric.type] ?? 0
        let manualVal = manualAdjustment(for: metric.type)
        let total = hkVal + manualVal
        let goal = metric.goal > 0 ? metric.goal : 1
        
        // Formatting
        let formattedValue: String
        switch metric.type.aggregationStyle {
        case .sum:
            formattedValue = String(format: "%.0f", total)
        case .average:
            formattedValue = String(format: "%.1f", total)
        }
        
        let progress = total / goal
        return (formattedValue, min(progress, 1.0))
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
    @Binding var weightGroups: [WeightGroupDefinition]
    let accentColor: Color
    var isPro: Bool
    var onSave: ([WorkoutScheduleItem]) -> Void

    @State private var showEditSheet = false
    @State private var selectedSessionForDetail: WorkoutSession?
    @State private var selectedSessionDay: String? = nil
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

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
                                    Button {
                                        selectedSessionForDetail = session
                                        selectedSessionDay = day.day
                                    } label: {
                                        WeeklySessionCard(
                                            session: session,
                                            accentColor: effectiveAccent
                                        )
                                    }
                                    .buttonStyle(.plain)
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

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Tap an activity to view details.")
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .sheet(isPresented: $showEditSheet) {
            WorkoutScheduleEditorSheet(
                schedule: $schedule,
                availableGroups: weightGroups,
                accentColor: effectiveAccent,
                isPro: isPro
            ) { updated in
                schedule = updated
                onSave(updated)
                showEditSheet = false
            }
        }
        .sheet(item: $selectedSessionForDetail) { sessionCopy in
            WorkoutSessionDetailView(
                session: Binding(
                    get: { selectedSessionForDetail ?? sessionCopy },
                    set: { newVal in
                        selectedSessionForDetail = newVal
                        updateSessionInSchedule(newVal)
                    }
                ),
                allWeightGroups: $weightGroups,
                dayLabel: selectedSessionDay
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour { return accentColor }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private func updateSessionInSchedule(_ session: WorkoutSession) {
        for dayIndex in schedule.indices {
            if let idx = schedule[dayIndex].sessions.firstIndex(where: { $0.id == session.id }) {
                schedule[dayIndex].sessions[idx] = session
                onSave(schedule)
                return
            }
        }
    }
}

private struct WorkoutScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var schedule: [WorkoutScheduleItem]
    var availableGroups: [WeightGroupDefinition] = []
    var accentColor: Color
    var isPro: Bool
    var onSave: ([WorkoutScheduleItem]) -> Void

    @State private var working: [WorkoutScheduleItem] = []

    @State private var newName: String = ""
    @State private var newColorHex: String = ""
    @State private var newHour: Int = 9
    @State private var newMinute: Int = 0
    @State private var selectedDayIndex: Int = 0

    @State private var showColorPickerSheet = false
    @State private var colorPickerTarget: (dayIndex: Int, sessionId: UUID)? = nil
    @State private var showProSubscription = false
    @FocusState private var focusedDescriptionID: UUID?
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // Limits
    private let freeSessionsLimit = 8
    private var canAddMore: Bool {
        if isPro { return true }
        let totalSessions = working.flatMap { $0.sessions }.count
        return totalSessions < freeSessionsLimit
    }

    private var presets: [WorkoutSession] {
        [
            WorkoutSession(name: "Chest", colorHex: "#D84A4A"),
            WorkoutSession(name: "Back", colorHex: "#4A7BD0"),
            WorkoutSession(name: "Shoulders", colorHex: "#E39A3B"),
            WorkoutSession(name: "Legs", colorHex: "#7A5FD1"),
            WorkoutSession(name: "Core", colorHex: "#4CAF6A"),
            WorkoutSession(name: "Yoga", colorHex: "#4FB6C6"),
            WorkoutSession(name: "Pilates", colorHex: "#C85FA8"),
            WorkoutSession(name: "Hyrox", colorHex: "#7A5FD1"),
            WorkoutSession(name: "Crossfit", colorHex: "#D84A4A"),
            WorkoutSession(name: "Meditate", colorHex: "#E6C84F"),
            WorkoutSession(name: "Cardio", colorHex: "#E39A3B"),
            WorkoutSession(name: "Run", colorHex: "#4CAF6A")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Current schedule by day
                    VStack(alignment: .leading, spacing: 16) {
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
                                                        guard themeManager.selectedTheme == .multiColour else { return }
                                                        colorPickerTarget = (dayIndex, sessionId)
                                                        showColorPickerSheet = true
                                                    } label: {
                                                        let sessionColor: Color = themeManager.selectedTheme == .multiColour ? (Color(hex: binding.colorHex.wrappedValue) ?? accentColor) : themeManager.selectedTheme.accent(for: colorScheme)

                                                        Circle()
                                                            .fill(sessionColor.opacity(0.18))
                                                            .frame(width: 40, height: 40)
                                                            .overlay(
                                                                Image(systemName: "figure.run")
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                    .foregroundStyle(sessionColor)
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                    .disabled(themeManager.selectedTheme != .multiColour)
                                                    .editSheetTip(.editWeeklyScheduleColor)

                                                    VStack(alignment: .leading, spacing: 6) {
                                                        TextField("Activity", text: binding.name)
                                                            .font(.subheadline.weight(.semibold))
                                                        
                                                        TextField("Description (e.g. Focus on form)", text: binding.description, axis: .vertical)
                                                            .focused($focusedDescriptionID, equals: sessionId)
                                                            .lineLimit(1...4)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                        
                                                        if !availableGroups.isEmpty {
                                                            Menu {
                                                                ForEach(availableGroups) { group in
                                                                    Button {
                                                                        if binding.linkedWeightGroupIds.wrappedValue.contains(group.id) {
                                                                            binding.linkedWeightGroupIds.wrappedValue.removeAll { $0 == group.id }
                                                                        } else {
                                                                            binding.linkedWeightGroupIds.wrappedValue.append(group.id)
                                                                        }
                                                                    } label: {
                                                                        if binding.linkedWeightGroupIds.wrappedValue.contains(group.id) {
                                                                            Label(group.name, systemImage: "checkmark")
                                                                        } else {
                                                                            Text(group.name)
                                                                        }
                                                                    }
                                                                }
                                                            } label: {
                                                                HStack(spacing: 6) {
                                                                    Image(systemName: "link")
                                                                        .font(.caption)
                                                                        .fontWeight(.medium)
                                                                    let linkedCount = binding.linkedWeightGroupIds.wrappedValue.count
                                                                    Text(linkedCount == 0 ? "Link Group" : (linkedCount == 1 ? "1 Group Linked" : "\(linkedCount) Groups Linked"))
                                                                        .font(.caption)
                                                                        .fontWeight(.medium)
                                                                }
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                                                                .foregroundColor(.primary)
                                                                
                                                            }
                                                            .buttonStyle(.plain)
                                                        }

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
                                                            .tint(effectiveAccent)
                                                            
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
                                        let presetColor: Color = themeManager.selectedTheme == .multiColour ? (Color(hex: preset.colorHex) ?? accentColor) : themeManager.selectedTheme.accent(for: colorScheme)

                                        Circle()
                                            .fill(presetColor.opacity(0.18))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Image(systemName: "figure.run")
                                                    .foregroundStyle(presetColor)
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
                                                .foregroundStyle(effectiveAccent)
                                                .opacity(!canAddMore ? 0.3 : 1.0)
                                        }
                                        .disabled(!canAddMore)
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock unlimited sessions + benefits")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .surfaceCard(16)
                        }
                        .buttonStyle(.plain)
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

                            if !isPro {
                                Text("You can add up to \(freeSessionsLimit) sessions.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("You can add activities to any day.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
            .safeAreaInset(edge: .bottom) {
                SimpleKeyboardDismissBar(
                    isVisible: focusedDescriptionID != nil,
                    tint: effectiveAccent,
                    onDismiss: { focusedDescriptionID = nil }
                )
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
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour { return accentColor }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedDayIndex < working.count
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
        guard canAddMore else { return }
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

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedColor: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: session.colorHex) ?? accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
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

private struct WorkoutSessionDetailView: View {
    @Binding var session: WorkoutSession
    @Binding var allWeightGroups: [WeightGroupDefinition]
    var dayLabel: String?
    
    @State private var workingBodyParts: [BodyPartWeights] = []
    @FocusState private var focusedField: UUID?
    @FocusState private var isDescriptionFocused: Bool
    @State private var hasLoaded = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: session.colorHex) ?? themeManager.selectedTheme.accent(for: colorScheme)
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 16) {
                        Circle()
                            .fill(effectiveAccent.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "figure.run")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(effectiveAccent)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.name)
                                .font(.title2.weight(.bold))
                            HStack(spacing: 6) {
                                if let day = dayLabel {
                                    Text("\(day) •")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text(session.formattedTime)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "text.alignleft")
                            .font(.headline)
                            .foregroundStyle(effectiveAccent)

                        TextField("Description (e.g. Focus on form)", text: $session.description, axis: .vertical)
                            .focused($isDescriptionFocused)
                            .lineLimit(3...6)
                            .font(.body)
                            .padding(12)
                            .glassEffect(in: .rect(cornerRadius: 12.0))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    
                    // Weight Groups
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Weight Groups", systemImage: "dumbbell.fill")
                                .font(.headline)
                                .foregroundStyle(effectiveAccent)
                            Spacer()
                            Menu {
                                ForEach(allWeightGroups) { group in
                                    Button {
                                        toggleLink(group: group)
                                    } label: {
                                        if session.linkedWeightGroupIds.contains(group.id) {
                                            Label(group.name, systemImage: "checkmark")
                                        } else {
                                            Text(group.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    let linkedCount = session.linkedWeightGroupIds.count
                                    Text(linkedCount == 0 ? "Link Group" : (linkedCount == 1 ? "1 Group Linked" : "\(linkedCount) Groups Linked"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if workingBodyParts.isEmpty {
                             Text("No body parts linked.")
                                 .font(.caption)
                                 .foregroundStyle(.secondary)
                                 .padding(.horizontal)
                        } else {
                            WeightsTrackingSection(
                                bodyParts: $workingBodyParts,
                                focusBinding: $focusedField
                            )
                            .padding(.top, -8)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.top, -16)
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ZStack(alignment: .bottom) {
                    KeyboardDismissBar(
                        isVisible: focusedField != nil,
                        selectedUnit: activeUnit,
                        tint: effectiveAccent,
                        onDismiss: { focusedField = nil },
                        onSelectUnit: { updateUnit($0) }
                    )
                    SimpleKeyboardDismissBar(
                        isVisible: isDescriptionFocused,
                        tint: effectiveAccent,
                        onDismiss: { isDescriptionFocused = false }
                    )
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(focusedField != nil || isDescriptionFocused)
        .onAppear(perform: loadInitial)
        .onChange(of: workingBodyParts) { _, newVal in
            syncChanges(newVal)
        }
    }
    
    private var activeUnit: String? {
       for part in workingBodyParts {
           if let ex = part.exercises.first(where: { $0.id == focusedField }) {
               return ex.unit
           }
       }
       return nil
    }
    
    private func updateUnit(_ unit: String) {
       for partIdx in workingBodyParts.indices {
           if let exIdx = workingBodyParts[partIdx].exercises.firstIndex(where: { $0.id == focusedField }) {
               workingBodyParts[partIdx].exercises[exIdx].unit = unit
           }
       }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        
        let linkedGroups = allWeightGroups.filter { session.linkedWeightGroupIds.contains($0.id) }
        workingBodyParts = linkedGroups.map { group in
            BodyPartWeights(
                id: group.id,
                name: group.name,
                exercises: group.exercises.map { def in
                    WeightExercise(
                        id: def.id,
                        name: def.name,
                        weight: def.targetWeight ?? "",
                        unit: "kg",
                        sets: def.targetSets ?? "",
                        reps: def.targetReps ?? "",
                        placeholderWeight: def.targetWeight ?? "",
                        placeholderSets: def.targetSets ?? "",
                        placeholderReps: def.targetReps ?? ""
                    )
                }
            )
        }
        hasLoaded = true
    }
    
    private func toggleLink(group: WeightGroupDefinition) {
        if session.linkedWeightGroupIds.contains(group.id) {
            session.linkedWeightGroupIds.removeAll { $0 == group.id }
            withAnimation {
                workingBodyParts.removeAll { $0.id == group.id }
            }
        } else {
            session.linkedWeightGroupIds.append(group.id)
            // Add to working body parts
            let newPart = BodyPartWeights(
                id: group.id,
                name: group.name,
                exercises: group.exercises.map { def in
                    WeightExercise(
                        id: def.id,
                        name: def.name,
                        weight: def.targetWeight ?? "",
                        unit: "kg",
                        sets: def.targetSets ?? "",
                        reps: def.targetReps ?? ""
                    )
                }
            )
            withAnimation {
                workingBodyParts.append(newPart)
            }
        }
    }
    
    private func syncChanges(_ parts: [BodyPartWeights]) {
        for part in parts {
            if let index = allWeightGroups.firstIndex(where: { $0.id == part.id }) {
                // Update definition
                allWeightGroups[index].name = part.name
                allWeightGroups[index].exercises = part.exercises.map { ex in
                    WeightExerciseDefinition(
                        id: ex.id,
                        name: ex.name,
                        targetWeight: ex.weight, 
                        targetSets: ex.sets,
                        targetReps: ex.reps
                    )
                }
            }
        }
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
                let nodeColor: Color = {
                    switch status {
                    case .checkIn:
                        return accentColor
                    case .rest, .notLogged:
                        return Color(.systemGray3)
                    }
                }()

                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .frame(height: symbolSize)
                    .foregroundStyle(nodeColor)
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
                                    selectedTint: effectiveTint
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

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveTint: Color {
        if themeManager.selectedTheme == .multiColour {
            return tint
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
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
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var bodyParts: [BodyPartWeights]
    var isPro: Bool
    var onSave: ([BodyPartWeights]) -> Void

    @State private var working: [BodyPartWeights] = []
    @State private var newName: String = ""
    @State private var hasLoaded = false
    @State private var showProSubscription = false

    private let presets: [String] = ["Chest", "Back", "Legs", "Biceps", "Triceps", "Shoulders", "Abs", "Glutes", "Upper Body", "Lower Body", "Full Body"]
    private let maxTracked = 6

    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < maxTracked
    }
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

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock unlimited group slots + benefits")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .surfaceCard(16)
                        }
                        .buttonStyle(.plain)
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

                            if !isPro {
                                Text("You can track up to \(maxTracked) groups.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
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
    var onTipStepChange: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if bodyParts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No weight groups yet", systemImage: "list.bullet.rectangle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Add weight groups in the Edit screen to track them here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }

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
                                    $part.isEditing.wrappedValue = false
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
                                // Toggle editing state for this body part (mutate the binding)
                                $part.isEditing.wrappedValue.toggle()
                            } label: {
                                Group {
                                    if part.isEditing {
                                        Image(systemName: "checkmark")
                                            .font(.callout)
                                            .accessibilityLabel("Done")
                                    } else {
                                        Image(systemName: "pencil")
                                            .font(.callout)
                                            .accessibilityLabel("Edit")
                                    }
                                }
                                .padding(10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18.0))
                                .contentShape(Rectangle())
                                .frame(minWidth: 44, minHeight: 44)
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
                        if part.id == bodyParts.first?.id {
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
                            .workoutTip(.weightsTracking, onStepChange: onTipStepChange)
                        } else {
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
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 18)
                    .background(Color.clear)
                }
            }
        }
        .padding(.vertical, 12)
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

private struct SimpleKeyboardDismissBar: View {
    var isVisible: Bool
    var tint: Color
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
                            .foregroundStyle(tint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

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
                            .foregroundStyle(tint)
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
    var onDelete: (() -> Void)? = nil

    init(
        tint: Color = .accentColor,
        initialEntry: WeeklyProgressEntry? = nil,
        onSave: @escaping (WeeklyProgressEntry) -> Void,
        onCancel: @escaping () -> Void = {},
        onDelete: (() -> Void)? = nil
    ) {
        self.tint = tint
        self.initialEntry = initialEntry
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete

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
                            range: Date.distantPast...Date(),
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

                        if initialEntry != nil {
                            Button {
                                onDelete?()
                            } label: {
                                Text("Delete Entry")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .padding(.top, 12)
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

// MARK: - Sports & Metrics Editors

private struct SportsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sports: [WorkoutTabView.SportType]
    let presets: [WorkoutTabView.SportPreset]
    var onSave: ([WorkoutTabView.SportType]) -> Void

    @State private var working: [WorkoutTabView.SportType] = []
    @State private var newName: String = ""
    @State private var newColor: Color = .accentColor
    @State private var hasLoaded = false
    @State private var showColorPickerSheet = false
    @State private var colorPickerSportID: UUID? = nil
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var availablePresets: [WorkoutTabView.SportPreset] {
        presets.filter { preset in
            !working.contains { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tracked sports
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Sports")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, sport in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            guard themeManager.selectedTheme == .multiColour else { return }
                                            colorPickerSportID = sport.id
                                            showColorPickerSheet = true
                                        }) {
                                            let displayColor: Color = themeManager.selectedTheme == .multiColour ? binding.color.wrappedValue : themeManager.selectedTheme.accent(for: colorScheme)

                                            Circle()
                                                .fill(displayColor.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "sportscourt")
                                                        .foregroundStyle(displayColor)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(themeManager.selectedTheme != .multiColour)

                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeSport(sport.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(12)
                                }
                            }
                        }
                    }

                    // Quick Add
                    if !availablePresets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(availablePresets) { preset in
                                    HStack(spacing: 14) {
                                        let presetColor: Color = themeManager.selectedTheme == .multiColour ? preset.color : themeManager.selectedTheme.accent(for: colorScheme)

                                        Circle()
                                            .fill(presetColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "sportscourt")
                                                    .foregroundStyle(presetColor)
                                            )

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(preset.metrics.count) default values")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            addPreset(preset)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(themeManager.selectedTheme == .multiColour ? preset.color : themeManager.selectedTheme.accent(for: colorScheme))
                                        }
                                        .buttonStyle(.plain)
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
                        MacroEditorSectionHeader(title: "Custom Sports")
                        HStack(spacing: 12) {
                            TextField("Sport name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            Button(action: addCustomSport) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(themeManager.selectedTheme == .multiColour ? newColor : themeManager.selectedTheme.accent(for: colorScheme))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAddCustomSport)
                            .opacity(!canAddCustomSport ? 0.4 : 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Sports")
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


    private var canAddCustomSport: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = sports
        hasLoaded = true
    }

    private func addPreset(_ preset: WorkoutTabView.SportPreset) {
        working.append(
            WorkoutTabView.SportType(
                name: preset.name,
                color: preset.color,
                activities: [],
                metrics: preset.metrics
            )
        )
    }

    private func addCustomSport() {
        guard canAddCustomSport else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        working.append(
            WorkoutTabView.SportType(
                name: trimmed,
                color: newColor,
                activities: [],
                metrics: []
            )
        )
        newName = ""
    }

    private func removeSport(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func applyColor(hex: String) {
        guard let target = colorPickerSportID else { return }
        guard let idx = working.firstIndex(where: { $0.id == target }) else { return }
        if let col = Color(hex: hex) {
            working[idx].color = col
        }
    }

    private func donePressed() {
        sports = working
        onSave(working)
        dismiss()
    }
}

private struct SportMetricsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sportName: String
    @Binding var metrics: [WorkoutTabView.SportMetric]
    let presets: [WorkoutTabView.SportMetricPreset]
    var accent: Color
    var onSave: ([WorkoutTabView.SportMetric]) -> Void

    @State private var working: [WorkoutTabView.SportMetric] = []
    @State private var newName: String = ""
    @State private var newUnit: String = ""
    @State private var newColor: Color = .accentColor
    @State private var hasLoaded = false
    @State private var showColorPickerSheet = false
    @State private var colorPickerMetricID: UUID? = nil
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var availablePresets: [WorkoutTabView.SportMetricPreset] {
        let existingKeys = Set(working.map { $0.key })
        return presets.filter { !existingKeys.contains($0.key) }
    }

    private var canAddCustomMetric: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Values")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, metric in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            guard themeManager.selectedTheme == .multiColour else { return }
                                            colorPickerMetricID = metric.id
                                            showColorPickerSheet = true
                                        }) {
                                            let displayColor: Color = themeManager.selectedTheme == .multiColour ? binding.color.wrappedValue : themeManager.selectedTheme.accent(for: colorScheme)

                                            Circle()
                                                .fill(displayColor.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "chart.bar.fill")
                                                        .foregroundStyle(displayColor)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(themeManager.selectedTheme != .multiColour)

                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Name", text: binding.label)
                                                .font(.subheadline.weight(.semibold))
                                            TextField("Unit (e.g. km, min)", text: binding.unit)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeMetric(metric.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(14)
                                }
                            }
                        }
                    }

                    if !availablePresets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(availablePresets) { preset in
                                    let presetColor: Color = themeManager.selectedTheme == .multiColour ? preset.color : themeManager.selectedTheme.accent(for: colorScheme)
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(presetColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "chart.bar.fill")
                                                    .foregroundStyle(presetColor)
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.label)
                                                .font(.subheadline.weight(.semibold))
                                            Text(preset.unit)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            addPreset(preset)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(presetColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Values")
                        VStack(spacing: 12) {
                            TextField("Value name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)
                            HStack(spacing: 12) {
                                TextField("Unit (e.g. pts, km)", text: $newUnit)
                                    .padding()
                                    .surfaceCard(16)
                                
                                Button(action: addCustomMetric) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(themeManager.selectedTheme == .multiColour ? newColor : themeManager.selectedTheme.accent(for: colorScheme))
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustomMetric)
                                .opacity(!canAddCustomMetric ? 0.4 : 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit \(sportName) Values")
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

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = metrics
        newColor = accent
        hasLoaded = true
    }

    private func addPreset(_ preset: WorkoutTabView.SportMetricPreset) {
        working.append(preset.metric())
    }

    private func addCustomMetric() {
        guard canAddCustomMetric else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = newUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = WorkoutTabView.SportMetric(
            key: "custom-\(UUID().uuidString)",
            label: trimmedName,
            unit: trimmedUnit,
            color: newColor,
            valueTransform: nil
        )
        working.append(custom)
        newName = ""
        newUnit = ""
    }

    private func applyColor(hex: String) {
        guard let target = colorPickerMetricID else { return }
        guard let idx = working.firstIndex(where: { $0.id == target }) else { return }
        if let col = Color(hex: hex) {
            working[idx].color = col
        }
    }

    private func removeMetric(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func donePressed() {
        metrics = working
        onSave(working)
        dismiss()
    }
}

private struct SportDataEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let sportName: String
    let metrics: [WorkoutTabView.SportMetric]
    let defaultDate: Date
    let accent: Color
    var onSave: (WorkoutTabView.SportActivity) -> Void
    var onCancel: () -> Void

    @State private var selectedDate: Date
    @State private var currentMonth: Date
    @State private var valueInputs: [UUID: String]
    @State private var showMonthPicker: Bool = false
    @State private var showYearPicker: Bool = false

    private let calendar = Calendar.current
    private let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var existingActivity: WorkoutTabView.SportActivity?
    private var existingRecordId: String? { existingActivity?.recordId }

    init(
        sportName: String,
        metrics: [WorkoutTabView.SportMetric],
        defaultDate: Date,
        accent: Color,
        existingActivity: WorkoutTabView.SportActivity? = nil,
        onSave: @escaping (WorkoutTabView.SportActivity) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sportName = sportName
        self.metrics = metrics
        self.defaultDate = defaultDate
        self.accent = accent
        self.existingActivity = existingActivity
        self.onSave = onSave
        self.onCancel = onCancel

        let baseDate = Calendar.current.startOfDay(for: existingActivity?.date ?? defaultDate)
        _selectedDate = State(initialValue: baseDate)
        _currentMonth = State(initialValue: baseDate)

        let initialInputs: [UUID: String]
        if let activity = existingActivity {
            initialInputs = Dictionary(uniqueKeysWithValues: metrics.map { metric in
                let val = Self.value(for: metric, in: activity)
                return (metric.id, Self.displayString(for: val))
            })
        } else {
            initialInputs = Dictionary(uniqueKeysWithValues: metrics.map { ($0.id, "") })
        }
        _valueInputs = State(initialValue: initialInputs)
    }

    private var canSave: Bool {
        metrics.allSatisfy { metric in
            if let text = valueInputs[metric.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return Double(text) != nil
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    dateSection
                    valuesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Submit Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                HStack {
                    Button(action: { withAnimation(.easeInOut) { shiftMonth(-1) } }) {
                        Image(systemName: "chevron.left")
                    }
                    .padding(.leading, 12)

                    Spacer()

                    Text(monthYearString(currentMonth))
                        .font(.headline)
                        .onTapGesture { toggleMonthYearPickers() }

                    Spacer()

                    Button(action: { withAnimation(.easeInOut) { shiftMonth(1) } }) {
                        Image(systemName: "chevron.right")
                    }
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 10)

                if showYearPicker {
                    yearPicker
                } else if showMonthPicker {
                    monthPicker
                } else {
                    calendarGrid
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Values")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 12) {
                ForEach(metrics) { metric in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.label)
                                .font(.subheadline.weight(.semibold))
                            TextField("Enter \(metric.unit)", text: binding(for: metric))
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.none)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.08))
                                )
                        }

                        Text(metric.unit)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
                }
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(daysOfWeek, id: \.self) { dow in
                    Text(dow)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            let days = daysInMonth(currentMonth)
            // Compute first weekday index with Monday as the first column.
            // Calendar.weekday: 1 = Sunday, 2 = Monday, ...
            // Map so Monday -> 0, Tuesday -> 1, ..., Sunday -> 6
            let firstWeekday = (calendar.component(.weekday, from: firstOfMonth(currentMonth)) + 5) % 7

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<(days + firstWeekday), id: \.self) { i in
                    if i < firstWeekday {
                        Color.clear.frame(height: 32)
                    } else {
                        let dayNum = i - firstWeekday + 1
                        let date = dateForDay(dayNum, in: currentMonth)
                        Button(action: { select(date) }) {
                            Text("\(dayNum)")
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(calendar.isDate(date, inSameDayAs: selectedDate) ? accent.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? accent : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var monthPicker: some View {
        let months = DateFormatter().monthSymbols ?? []
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(months.indices, id: \.self) { idx in
                    Button(action: {
                        var comps = calendar.dateComponents([.year, .day], from: currentMonth)
                        comps.month = idx + 1
                        if let newDate = calendar.date(from: comps) {
                            currentMonth = newDate
                        }
                        showMonthPicker = false
                    }) {
                        Text(months[idx])
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(calendar.component(.month, from: currentMonth) == idx + 1 ? accent.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(maxHeight: 340)
    }

    private var yearPicker: some View {
        let currentYear = calendar.component(.year, from: currentMonth)
        let years = (currentYear - 50...currentYear + 10).map { $0 }
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(years, id: \.self) { year in
                    Button(action: {
                        var comps = calendar.dateComponents([.month, .day], from: currentMonth)
                        comps.year = year
                        if let newDate = calendar.date(from: comps) {
                            currentMonth = newDate
                        }
                        showYearPicker = false
                    }) {
                        Text("\(year)")
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(calendar.component(.year, from: currentMonth) == year ? accent.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(maxHeight: 340)
    }

    private func binding(for metric: WorkoutTabView.SportMetric) -> Binding<String> {
        Binding(
            get: { valueInputs[metric.id] ?? "" },
            set: { valueInputs[metric.id] = $0 }
        )
    }

    private static func value(for metric: WorkoutTabView.SportMetric, in activity: WorkoutTabView.SportActivity) -> Double {
        switch metric.key {
        case "distanceKm": return activity.distanceKm ?? 0
        case "durationMin": return activity.durationMin ?? 0
        case "speedKmh": return activity.speedKmh ?? activity.speedKmhComputed ?? 0
        case "speedKmhComputed": return activity.speedKmhComputed ?? activity.speedKmh ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? activity.accuracy ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return activity.customValues[metric.key] ?? 0
        }
    }

    private static func displayString(for value: Double) -> String {
        if value == 0 { return "" }
        let intVal = Int(value)
        if Double(intVal) == value {
            return String(intVal)
        }
        return String(format: "%.2f", value)
    }

    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func toggleMonthYearPickers() {
        if showMonthPicker {
            showMonthPicker = false
            showYearPicker = true
        } else if showYearPicker {
            showYearPicker = false
        } else {
            showMonthPicker = true
        }
    }

    private func save() {
        guard let activity = buildActivity() else { return }
        onSave(activity)
        dismiss()
    }

    private func buildActivity() -> WorkoutTabView.SportActivity? {
        var activity = WorkoutTabView.SportActivity(recordId: existingRecordId, date: selectedDate)

        for metric in metrics {
            guard let text = valueInputs[metric.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let value = Double(text) else { return nil }

            switch metric.key {
            case "distanceKm": activity.distanceKm = value
            case "durationMin": activity.durationMin = value
            case "speedKmh": activity.speedKmh = value
            case "speedKmhComputed": activity.speedKmh = value
            case "laps": activity.laps = Int(value)
            case "attemptsMade": activity.attemptsMade = Int(value)
            case "attemptsMissed": activity.attemptsMissed = Int(value)
            case "accuracy": activity.accuracy = value
            case "accuracyComputed": activity.accuracy = value
            case "rounds": activity.rounds = Int(value)
            case "roundDuration": activity.roundDuration = value
            case "points": activity.points = Int(value)
            case "holdTime": activity.holdTime = value
            case "poses": activity.poses = Int(value)
            case "altitude": activity.altitude = value
            case "timeToPeak": activity.timeToPeak = value
            case "restTime": activity.restTime = value
            default:
                activity.customValues[metric.key] = value
            }
        }

        return activity
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func dateForDay(_ day: Int, in month: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: month)
        comps.day = day
        return calendar.date(from: comps) ?? month
    }
}

// MARK: - Modular Metric Graph

struct SportMetricGraph: View {
    let metric: WorkoutTabView.SportMetric
    let activities: [WorkoutTabView.SportActivity]
    let historyDays: Int
    let anchorDate: Date
    var accentOverride: Color? = nil

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: anchorDate) }

    private var displayDates: [Date] {
        let anchor = cal.startOfDay(for: anchorDate)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)
        comps.weekday = 2 // Monday
        guard let startOfWeek = cal.date(from: comps) else { return [] }
        return (0..<historyDays).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: startOfWeek))
        }
    }

    private func value(for activity: WorkoutTabView.SportActivity) -> Double {
        if let transform = metric.valueTransform {
            return transform(activity)
        }
        // Fallback: use key-based lookup
        switch metric.key {
        case "distanceKm": return activity.distanceKm ?? 0
        case "durationMin": return activity.durationMin ?? 0
        case "speedKmh": return activity.speedKmh ?? 0
        case "speedKmhComputed": return activity.speedKmhComputed ?? activity.speedKmh ?? 0
        case "laps": return Double(activity.laps ?? 0)
        case "attemptsMade": return Double(activity.attemptsMade ?? 0)
        case "attemptsMissed": return Double(activity.attemptsMissed ?? 0)
        case "accuracy": return activity.accuracy ?? activity.accuracyComputed ?? 0
        case "accuracyComputed": return activity.accuracyComputed ?? activity.accuracy ?? 0
        case "rounds": return Double(activity.rounds ?? 0)
        case "roundDuration": return activity.roundDuration ?? 0
        case "points": return Double(activity.points ?? 0)
        case "holdTime": return activity.holdTime ?? 0
        case "poses": return Double(activity.poses ?? 0)
        case "altitude": return activity.altitude ?? 0
        case "timeToPeak": return activity.timeToPeak ?? 0
        case "restTime": return activity.restTime ?? 0
        default: return activity.customValues[metric.key] ?? 0
        }
    }

    private var dailyTotals: [(date: Date, total: Double)] {
        let grouped = Dictionary(grouping: activities) { cal.startOfDay(for: $0.date) }
        return displayDates.map { day in
            let items = grouped[day] ?? []
            let maxValue = items.map { value(for: $0) }.max() ?? 0
            return (date: day, total: maxValue)
        }
    }

    var body: some View {
        let displayColor = accentOverride ?? metric.color
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(metric.label) (\(metric.unit))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(displayColor)
                
                Spacer()
            }
            .padding(.bottom, 4)

            Chart {
                ForEach(dailyTotals, id: \.date) { item in
                    BarMark(
                        x: .value("Day", DateFormatter.shortDate.string(from: item.date)),
                        y: .value(metric.label, item.total)
                    )
                    .foregroundStyle(displayColor)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                let labels = displayDates.enumerated().compactMap { idx, d in
                    (idx % max(1, historyDays / 6) == 0) ? DateFormatter.shortDate.string(from: d) : nil
                }
                AxisMarks(values: labels) { value in
                    AxisGridLine()
                    AxisValueLabel() {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}

private extension WorkoutTabView {
    func configs(from sports: [SportType]) -> [SportConfig] {
        sports.map { sport in
            SportConfig(
                id: sport.id,
                name: sport.name,
                colorHex: sport.color.toHexString(),
                metrics: sport.metrics.map { metric in
                    SportMetricConfig(
                        id: metric.id,
                        key: metric.key,
                        label: metric.label,
                        unit: metric.unit,
                        colorHex: metric.color.toHexString()
                    )
                }
            )
        }
    }

    func sportsFromConfigs(_ configs: [SportConfig], fallbackActivities: [SportType]) -> [SportType] {
        let fallbackByName = Dictionary(uniqueKeysWithValues: fallbackActivities.map { ($0.name.lowercased(), $0.activities) })
        return configs.map { config in
            let color = Color(hex: config.colorHex) ?? .accentColor
            let activities = fallbackByName[config.name.lowercased()] ?? []
            return SportType(
                name: config.name,
                color: color,
                activities: activities,
                metrics: config.metrics.map { metric in
                    SportMetric(
                        key: metric.key,
                        label: metric.label,
                        unit: metric.unit,
                        color: Color(hex: metric.colorHex) ?? color,
                        valueTransform: Self.metricPresetByKey[metric.key]?.valueTransform
                    )
                }
            )
        }
    }
}

private extension DateFormatter {
    static var shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d" // weekday short + day number (Mon 22)
        return df
    }()

    static var shortHour: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "ha"
        return df
    }()

    static var shortDay: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static var sportWeekdayFull: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df
    }()

    static var sportLongDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df
    }()
}

// MARK: - Sports Tips

@available(iOS 17.0, *)
struct SportsTips {
    @Parameter
    static var currentStep: Int = 0

    struct WeatherTip: Tip {
        var title: Text { Text("Weather") }
        var message: Text? { Text("Check the weather forecast to plan your outdoor activities.") }
        var image: Image? { Image(systemName: "cloud.sun.fill") }
        
        var rules: [Rule] {
            #Rule(SportsTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Finish")
        }
    }

    struct EditSportsTip: Tip {
        var title: Text { Text("Edit Sports") }
        var message: Text? { Text("Tap Edit to add and remove sports you play.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(SportsTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct SportsTrackingTip: Tip {
        var title: Text { Text("Sports Tracking") }
        var message: Text? { Text("Tap Submit Data to manually add values to keep track of.") }
        var image: Image? { Image(systemName: "sportscourt.fill") }
        
        var rules: [Rule] {
            #Rule(SportsTips.$currentStep) { $0 == 4 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}

enum SportsTipType {
    case editSports
    case sportsTracking
    case weather
}

extension View {
    @ViewBuilder
    func sportsTip(_ type: SportsTipType, isEnabled: Bool = true, onStepChange: ((Int) -> Void)? = nil) -> some View {
        if #available(iOS 17.0, *), isEnabled {
            self.background {
                Color.clear
                    .applySportsTip(type, onStepChange: onStepChange)
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func applySportsTip(_ type: SportsTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        switch type {
        case .weather:
            self.popoverTip(SportsTips.WeatherTip()) { action in
                if action.id == "next" {
                    SportsTips.currentStep = 1
                    onStepChange?(1)
                }
            }
        case .editSports:
            self.popoverTip(SportsTips.EditSportsTip()) { action in
                if action.id == "next" {
                    SportsTips.currentStep = 4
                    onStepChange?(4)
                }
            }
        case .sportsTracking:
            self.popoverTip(SportsTips.SportsTrackingTip()) { action in
                if action.id == "finish" {
                    SportsTips.currentStep = 5
                    onStepChange?(5)
                }
            }
        }
    }
}

// MARK: - Sports Tracking Helpers

private extension WorkoutTabView {
    func rebuildSports() {
        self.sports = sportConfigs.map { config in
            let metrics = config.metrics.map { m -> SportMetric in
                SportMetric(
                    key: m.key,
                    label: m.label,
                    unit: m.unit,
                    color: Color(hex: m.colorHex) ?? .blue,
                    valueTransform: nil
                )
            }
            
            let metricsWithLogic = metrics.map { m -> SportMetric in
                if let preset = Self.metricPresets.first(where: { $0.key == m.key }) {
                    var mutable = m
                    mutable.valueTransform = preset.valueTransform
                    return mutable
                }
                return m
            }

            let activities = sportActivities.filter { $0.sportName == config.name }.map { activity(from: $0) }
            
            return SportType(
                name: config.name,
                color: Color(hex: config.colorHex) ?? .blue,
                activities: activities,
                metrics: metricsWithLogic
            )
        }
    }

    func activity(from record: SportActivityRecord) -> SportActivity {
        var activity = SportActivity(date: record.date)
        activity.recordId = record.id
        
        for val in record.values {
            switch val.key {
            case "distanceKm": activity.distanceKm = val.value
            case "durationMin": activity.durationMin = val.value
            case "speedKmh": activity.speedKmh = val.value
            case "laps": activity.laps = Int(val.value)
            case "attemptsMade": activity.attemptsMade = Int(val.value)
            case "attemptsMissed": activity.attemptsMissed = Int(val.value)
            case "accuracy": activity.accuracy = val.value
            case "rounds": activity.rounds = Int(val.value)
            case "roundDuration": activity.roundDuration = val.value
            case "points": activity.points = Int(val.value)
            case "holdTime": activity.holdTime = val.value
            case "poses": activity.poses = Int(val.value)
            case "altitude": activity.altitude = val.value
            case "timeToPeak": activity.timeToPeak = val.value
            case "restTime": activity.restTime = val.value
            default: activity.customValues[val.key] = val.value
            }
        }
        return activity
    }

    func record(from activity: SportActivity, metrics: [SportMetric], sportName: String, color: Color, existingId: String? = nil) -> SportActivityRecord {
        let values: [SportMetricValue] = metrics.compactMap { metric in
            if metric.key.hasSuffix("Computed") { return nil }
            
            let val: Double? = {
                switch metric.key {
                case "distanceKm": return activity.distanceKm
                case "durationMin": return activity.durationMin
                case "speedKmh": return activity.speedKmh
                case "laps": return activity.laps.map(Double.init)
                case "attemptsMade": return activity.attemptsMade.map(Double.init)
                case "attemptsMissed": return activity.attemptsMissed.map(Double.init)
                case "accuracy": return activity.accuracy
                case "rounds": return activity.rounds.map(Double.init)
                case "roundDuration": return activity.roundDuration
                case "points": return activity.points.map(Double.init)
                case "holdTime": return activity.holdTime
                case "poses": return activity.poses.map(Double.init)
                case "altitude": return activity.altitude
                case "timeToPeak": return activity.timeToPeak
                case "restTime": return activity.restTime
                default: return activity.customValues[metric.key]
                }
            }()
            
            guard let v = val else { return nil }
            return SportMetricValue(key: metric.key, label: metric.label, unit: metric.unit, colorHex: metric.color.toHex() ?? "#000000", value: v)
        }
        
        return SportActivityRecord(
            id: existingId ?? UUID().uuidString,
            sportName: sportName,
            colorHex: color.toHex() ?? "#0000FF",
            date: activity.date,
            values: values
        )
    }

    func sportWeekDates(anchor: Date) -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: anchor) }
    }
    
    func loadDayForSelectedDate() {
        let localDay = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        self.currentDay = localDay
        
        dayFirestoreService.fetchDay(for: selectedDate, in: modelContext) { fetched in
            DispatchQueue.main.async {
                if let fetched {
                    self.currentDay = fetched
                }
            }
        }
    }
}
