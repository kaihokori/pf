import SwiftUI

private struct MacroEditorSummaryChip: View {
    let currentCount: Int
    let maxCount: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracked Macros")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(currentCount) / \(maxCount)")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            ProgressView(value: Double(currentCount), total: Double(maxCount))
                .tint(tint)
                .frame(width: 120)
        }
        .padding()
        .surfaceCard(18)
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
    @Binding var supplements: [SupplementItem]
    var tint: Color
    var onDone: () -> Void

    // local working state
    @State private var working: [SupplementItem] = []
    @State private var newName: String = ""
    @State private var newTarget: String = ""
    @State private var hasLoaded = false

    // presets available in Quick Add (some may not be selected initially)
    private var presets: [SupplementItem] {
        [
            SupplementItem(name: "Pre-workout", amountLabel: "1 scoop"),
            SupplementItem(name: "Creatine", amountLabel: "5 g"),
            SupplementItem(name: "BCAA", amountLabel: "10 g"),
            SupplementItem(name: "Whey Protein", amountLabel: "30 g"),
            SupplementItem(name: "Beta-Alanine", amountLabel: "3.2 g"),
            SupplementItem(name: "Electrolytes", amountLabel: "1 scoop")
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
                        // Summary chip
                        MacroEditorSummaryChip(
                            currentCount: working.count,
                            maxCount: maxTrackedSupplements,
                            tint: tint
                        )

                        // Tracked supplements
                        if !working.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                MacroEditorSectionHeader(title: "Tracked Supplements")
                                VStack(spacing: 12) {
                                    ForEach(Array(working.enumerated()), id: \ .element.id) { idx, item in
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
                                                        get: { binding.customLabel.wrappedValue ?? item.measurementDescription },
                                                        set: { binding.customLabel.wrappedValue = $0 }
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
                                        ForEach(presets.filter { !isPresetSelected($0) }, id: \ .name) { preset in
                                            HStack(spacing: 14) {
                                                Circle()
                                                    .fill(tint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: "chart.bar.fill")
                                                            .foregroundStyle(tint)
                                                    )

                                                VStack(alignment: .leading) {
                                                    Text(preset.name)
                                                        .font(.subheadline.weight(.semibold))
                                                    Text(preset.measurementDescription)
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

                                Text("Give it a name and amount, then tap plus to add it to your dashboard. You can track up to \(maxTrackedSupplements) supplements.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
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
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        guard !hasLoaded else { return }
        working = supplements
        hasLoaded = true
    }

    private func togglePreset(_ preset: SupplementItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: SupplementItem) -> Bool {
        working.contains { $0.name == preset.name }
    }

    private func removeSupplement(_ id: UUID) {
        // Find the supplement being removed
        guard let item = working.first(where: { $0.id == id }) else { return }
        // If it's a preset (by name), remove all with that name so preset returns to Quick Add
        if presets.contains(where: { $0.name == item.name }) {
            working.removeAll { $0.name == item.name }
        } else {
            working.removeAll { $0.id == id }
        }
    }

    private func addCustomSupplement() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = SupplementItem(name: trimmed, amountLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines), customLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        working.append(new)
        newName = ""
        newTarget = ""
    }
}

struct WorkoutTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var weeklyProgress: [CoachingWorkoutDayStatus] = [.checkIn, .checkIn, .notLogged, .checkIn, .rest, .notLogged, .notLogged]
    private let coachingCurrentDayIndex = 5
    @State private var supplements: [SupplementItem] = coachingDefaultSupplements
    @State private var showSupplementEditor = false
    
    // Daily summary sample values (moved from Nutrition tab)
    private let caloriesBurnedToday: Int = 620
    private let caloriesBurnGoal: Int = 800
    private let stepsTakenToday: Int = 8_500
    private let stepsGoalToday: Int = 10_000

    // New: walking and running distance (in meters)
    private let walkingDistanceToday: Double = 2_100 // meters
    private let walkingDistanceGoal: Double = 3_000 // meters
    private let runningDistanceToday: Double = 1_200 // meters
    private let runningDistanceGoal: Double = 2_000 // meters

    private var stepsProgress: Double {
        guard stepsGoalToday > 0 else { return 0 }
        return min(max(Double(stepsTakenToday) / Double(stepsGoalToday), 0), 1)
    }

    private var walkingProgress: Double {
        guard walkingDistanceGoal > 0 else { return 0 }
        return min(max(walkingDistanceToday / walkingDistanceGoal, 0), 1)
    }

    private var runningProgress: Double {
        guard runningDistanceGoal > 0 else { return 0 }
        return min(max(runningDistanceToday / runningDistanceGoal, 0), 1)
    }

    private var formattedStepsTaken: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsTakenToday)) ?? "\(stepsTakenToday)"
    }

    private var formattedStepsGoal: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsGoalToday)) ?? "\(stepsGoalToday)"
    }

    private var formattedWalkingDistance: String {
        String(format: "%.2f km", walkingDistanceToday / 1000)
    }

    private var formattedWalkingGoal: String {
        String(format: "Goal %.1f km", walkingDistanceGoal / 1000)
    }

    private var formattedRunningDistance: String {
        String(format: "%.2f km", runningDistanceToday / 1000)
    }

    private var formattedRunningGoal: String {
        String(format: "Goal %.1f km", runningDistanceGoal / 1000)
    }
    

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 0) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true })
                        .environmentObject(account)

                    Text("Schedule Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                    CoachingWorkoutProgressSection(
                        weeklyProgress: $weeklyProgress,
                        accentColor: accentOverride ?? .accentColor,
                        currentDayIndex: coachingCurrentDayIndex
                    )
                    
                    WeeklyWorkoutScheduleCard(
                        schedule: coachingWeeklySchedule,
                        accentColor: accentOverride ?? .accentColor
                    )
                    
                    HStack {
                        Text("Daily Summary")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Button {
                            // 
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
                        HStack(alignment: .top, spacing: 12) {
                            ActivityProgressCard(
                                title: "Calories Burned",
                                iconName: "flame.fill",
                                tint: accentOverride ?? .orange,
                                currentValueText: "\(caloriesBurnedToday)",
                                goalValueText: "Goal \(caloriesBurnGoal)",
                                progress: Double(caloriesBurnedToday) / Double(caloriesBurnGoal)
                            )
                            .frame(maxWidth: .infinity)

                            ActivityProgressCard(
                                title: "Steps Taken",
                                iconName: "figure.walk",
                                tint: accentOverride ?? .green,
                                currentValueText: "\(formattedStepsTaken)",
                                goalValueText: "Goal \(formattedStepsGoal)",
                                progress: stepsProgress
                            )
                            .frame(maxWidth: .infinity)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            ActivityProgressCard(
                                title: "Walking Distance",
                                iconName: "figure.walk",
                                tint: accentOverride ?? .blue,
                                currentValueText: formattedWalkingDistance,
                                goalValueText: formattedWalkingGoal,
                                progress: walkingProgress
                            )
                            .frame(maxWidth: .infinity)

                            ActivityProgressCard(
                                title: "Running Distance",
                                iconName: "figure.run",
                                tint: accentOverride ?? .pink,
                                currentValueText: formattedRunningDistance,
                                goalValueText: formattedRunningGoal,
                                progress: runningProgress
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

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

                    SupplementTrackingView(
                        accentColorOverride: .purple,
                        supplements: $supplements
                    )
                    .sheet(isPresented: $showSupplementEditor) {
                        ExerciseSupplementEditorSheet(
                            supplements: $supplements,
                            tint: .purple,
                            onDone: { showSupplementEditor = false }
                        )
                    }
                    
                    HStack {
                        Text("Weights Tracking")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { /* TODO: hook up edit handling */ }) {
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
                    WeightsTrackingSection()

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
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.inline)
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

private enum WorkoutDayStatus {
    case checkIn
    case rest
    case notLogged
    case offDay

    var timelineSymbol: String? {
        switch self {
        case .checkIn: return "circle.fill"
        case .rest: return "circle.fill"
        case .notLogged: return "circle"
        case .offDay: return nil
        }
    }

    var shouldHideTimelineNode: Bool {
        self == .offDay
    }

    var accentColor: Color {
        switch self {
        case .checkIn:
            return Color.yellow
        case .rest:
            return Color(.systemGray3)
        case .notLogged:
            return Color(.systemGray3)
        case .offDay:
            return .clear
        }
    }
}

private let coachingDefaultSupplements: [SupplementItem] = [
    SupplementItem(name: "Pre-workout", amountLabel: "1 scoop"),
    SupplementItem(name: "Creatine", amountLabel: "5 g"),
    SupplementItem(name: "BCAA", amountLabel: "10 g"),
    SupplementItem(name: "Whey Protein", amountLabel: "30 g"),
    SupplementItem(name: "Beta-Alanine", amountLabel: "3.2 g"),
    SupplementItem(name: "Electrolytes", amountLabel: "1 scoop")
]

// Sample weekly schedule for coaching tab
private let coachingWeeklySchedule: [WorkoutScheduleItem] = [
    .init(day: "Mon", sessions: [.init(name: "Chest", duration: "20 mins", isGymRelated: false)]),
    .init(day: "Tue", sessions: [.init(name: "Back", duration: "40 mins", isGymRelated: false)]),
    .init(day: "Wed", sessions: []),
    .init(day: "Thu", sessions: [.init(name: "Legs", duration: "30 mins", isGymRelated: true)]),
    .init(day: "Fri", sessions: [.init(name: "Shoulders", duration: "50 mins", isGymRelated: true)]),
    .init(day: "Sat", sessions: [.init(name: "Abs", duration: "30 mins", isGymRelated: false)]),
    .init(day: "Sun", sessions: [])
]

private enum CoachingWorkoutDayStatus {
    case checkIn
    case rest
    case notLogged
    case offDay

    var timelineSymbol: String? {
        switch self {
        case .checkIn: return "circle.fill"
        case .rest: return "circle.fill"
        case .notLogged: return "circle"
        case .offDay: return nil
        }
    }

    var shouldHideTimelineNode: Bool {
        self == .offDay
    }

    var accentColor: Color {
        switch self {
        case .checkIn:
            return Color.yellow
        case .rest:
            return Color(.systemGray3)
        case .notLogged:
            return Color(.systemGray3)
        case .offDay:
            return .clear
        }
    }
}

private struct CoachingWorkoutProgressTimelineView: View {
    let daySymbols: [String]
    let statuses: [CoachingWorkoutDayStatus]
    let accentColor: Color

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

    private func status(at index: Int) -> CoachingWorkoutDayStatus {
        guard statuses.indices.contains(index) else { return .notLogged }
        return statuses[index]
    }
}

private struct CoachingWorkoutProgressSection: View {
    @Binding var weeklyProgress: [CoachingWorkoutDayStatus]
    let accentColor: Color
    let currentDayIndex: Int

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        let tint = accentColor

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Daily Check-In")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { /* TODO: hook up edit handling */ }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }

            CoachingWorkoutProgressTimelineView(daySymbols: daySymbols, statuses: weeklyProgress, accentColor: tint)
                .padding(.bottom, -20)

            HStack(spacing: 12) {
                Button(action: { updateCurrentDay(with: .checkIn) }) {
                    Text("Check-In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CoachingWorkoutProgressButtonStyle(background: Color(.systemBackground)))

                Button(action: { updateCurrentDay(with: .rest) }) {
                    Text("Rest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CoachingWorkoutProgressButtonStyle(background: Color(.systemBackground)))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func updateCurrentDay(with status: CoachingWorkoutDayStatus) {
        guard weeklyProgress.indices.contains(currentDayIndex) else { return }
        weeklyProgress[currentDayIndex] = status
    }
}

private struct CoachingWorkoutProgressButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 12.0))
    }
}

// MARK: - Weekly schedule models & views moved from WorkoutTabView

struct WorkoutScheduleItem: Identifiable {
    let id = UUID()
    let day: String
    let sessions: [WorkoutSession]
}

struct WorkoutSession: Identifiable {
    let id = UUID()
    let name: String
    let duration: String?
    let isGymRelated: Bool

    init(name: String, duration: String? = nil, isGymRelated: Bool = true) {
        self.name = name
        self.duration = duration
        self.isGymRelated = isGymRelated
    }
}

private struct WeeklyWorkoutScheduleCard: View {
    let schedule: [WorkoutScheduleItem]
    let accentColor: Color

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
                HStack(alignment: .top, spacing: 12) {
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
                                        accentColor: Color.random().opacity(0.8)
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
            Text("Edit Weekly Schedule")
                .font(.title)
                .padding()
        }
    }
}

private struct WeeklySessionCard: View {
    let session: WorkoutSession
    let accentColor: Color

    var body: some View {
        Text(session.name)
            .font(.footnote)
            .fontWeight(.medium)
            .lineLimit(2)
            .frame(width: 70, alignment: .center)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(accentColor), in: .rect(cornerRadius: 12.0))
    }
}


// MARK: - Weights Tracking Section

private struct WeightExercise: Identifiable {
    let id = UUID()
    var name: String
    var weight: String
    var sets: String
    var reps: String
}

private struct BodyPartWeights: Identifiable {
    let id = UUID()
    var name: String
    var exercises: [WeightExercise]
    var isEditing: Bool = false
}

private struct WeightsTrackingSection: View {
    @State private var bodyParts: [BodyPartWeights] = [
        .init(
            name: "Chest",
            exercises: [
                WeightExercise(name: "Bench Press", weight: "", sets: "", reps: ""),
                WeightExercise(name: "", weight: "", sets: "", reps: "")
            ]
        )
    ]

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
                            .frame(width: 60, alignment: .center)

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
                                    .glassEffect(in: .rect(cornerRadius: 8.0))
                                    .frame(minWidth: 0, maxWidth: .infinity)

                                TextField("0", text: $exercise.weight)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .glassEffect(in: .rect(cornerRadius: 8.0))
                                    .frame(width: 60)

                                TextField("0", text: $exercise.sets)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .glassEffect(in: .rect(cornerRadius: 8.0))
                                    .frame(width: 40)

                                Text("x")
                                    .frame(width: 15)

                                TextField("0", text: $exercise.reps)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .glassEffect(in: .rect(cornerRadius: 8.0))
                                    .frame(width: 40)

                                if part.isEditing {
                                    Button {
                                        deleteExercise(bodyPartId: part.id, exerciseId: exercise.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.callout)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .glassEffect(in: .rect(cornerRadius: 18.0))
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
                                .glassEffect(in: .rect(cornerRadius: 18.0))
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
