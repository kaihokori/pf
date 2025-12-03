import SwiftUI

struct CoachingTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var showWeightsEditSheet = false
    @State private var weeklyProgress: [CoachingWorkoutDayStatus] = [.checkIn, .checkIn, .notLogged, .checkIn, .rest, .notLogged, .notLogged]
    private let coachingCurrentDayIndex = 5
    @State private var weightActivities: [WeightActivity] = {
        let gymSessions = coachingWeeklySchedule.flatMap { $0.sessions }.filter { $0.isGymRelated }
        var seen = Set<String>()
        var activities: [WeightActivity] = []
        for s in gymSessions {
            if seen.contains(s.name) { continue }
            seen.insert(s.name)
            activities.append(WeightActivity(name: s.name, exercises: []))
        }
        return activities
    }()
    @State private var editingActivityIndex: Int? = nil

    var body: some View {
        ZStack {
            backgroundView
            ScrollView {
                VStack(spacing: 0) {
                    HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, profileImage: Image("profile"), onProfileTap: { showAccountsView = true })

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
                    
                    Text("Workout Supplement Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                    SupplementTrackingView(
                        accentColorOverride: accentOverride,
                        initialSupplements: coachingDefaultSupplements
                    )
                    HStack {
                        Text("Weights Tracking")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            showWeightsEditSheet = true
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
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 48)
                    .padding(.bottom, 6)

                    WeightsTrackingSection(activities: weightActivities, accentColor: accentOverride ?? .accentColor) { selected in
                        if let idx = weightActivities.firstIndex(where: { $0.id == selected.id }) {
                            editingActivityIndex = idx
                        }
                    }
                }
            }
        }
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWeightsEditSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Edit Weights Tracking")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()

                    Text("")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()
                }
                .navigationBarItems(trailing: Button("Done") { showWeightsEditSheet = false })
            }
        }
        .sheet(isPresented: Binding(get: { editingActivityIndex != nil }, set: { if !$0 { editingActivityIndex = nil } })) {
            if let idx = editingActivityIndex, weightActivities.indices.contains(idx) {
                WeightActivityEditor(activity: $weightActivities[idx]) {
                    editingActivityIndex = nil
                }
            } else {
                // Fallback empty view
                EmptyView()
            }
        }
    }
}

private extension CoachingTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .coaching)
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

private let coachingDefaultSupplements: [SupplementItem] = [
    SupplementItem(name: "Pre-workout", amount: 1, unit: .scoop),
    SupplementItem(name: "Creatine", amount: 5, unit: .gram),
    SupplementItem(name: "BCAA", amount: 10, unit: .gram),
    SupplementItem(name: "Protein Water", amount: 30, unit: .gram),
    SupplementItem(name: "Beta-Alanine", amount: 3.2, unit: .gram),
    SupplementItem(name: "Caffeine", amount: 200, unit: .milligram),
    SupplementItem(name: "Electrolytes", amount: 1, unit: .scoop)
]

// Sample weekly schedule for coaching tab
private let coachingWeeklySchedule: [WorkoutScheduleItem] = [
    .init(day: "Mon", sessions: [.init(name: "Mobility", duration: "20 mins", isGymRelated: false)]),
    .init(day: "Tue", sessions: [.init(name: "Technique", duration: "40 mins", isGymRelated: false)]),
    .init(day: "Wed", sessions: []),
    .init(day: "Thu", sessions: [.init(name: "Conditioning", duration: "30 mins", isGymRelated: true)]),
    .init(day: "Fri", sessions: [.init(name: "Strength", duration: "50 mins", isGymRelated: true)]),
    .init(day: "Sat", sessions: [.init(name: "Active Recovery", duration: "30 mins", isGymRelated: false)]),
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 18.0)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
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
            .background(
                RoundedRectangle(cornerRadius: 12.0)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
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
                        .frame(width: 85, alignment: .top)
                        .background(Color.clear)
                    }
                }
                .padding()
            }
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

// MARK: - Weights Tracking

private struct ExerciseRecord: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var weight: String
    var reps: String
    var sets: String
}

private struct WeightActivity: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var exercises: [ExerciseRecord]
}

private struct WeightsTrackingSection: View {
    let activities: [WeightActivity]
    let accentColor: Color
    let onSelect: (WeightActivity) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(activities) { activity in
                Button(action: { onSelect(activity) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundColor(accentColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text(activity.exercises.isEmpty ? "No exercises" : "\(activity.exercises.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.title2)
                    }
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}

private struct WeightActivityEditor: View {
    @Binding var activity: WeightActivity
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Column headers
                HStack(spacing: 12) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 120, alignment: .leading)

                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)

                    Text("Reps x Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Spacer()
                    Text("")
                        .frame(width: 28)
                }
                .padding(.horizontal, 18)

                // Exercises — single-line rows
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($activity.exercises) { exerciseBinding in
                            HStack(spacing: 12) {
                                TextField("Exercise", text: exerciseBinding.name)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 120)

                                TextField("Wt", text: exerciseBinding.weight)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 72)
                                    .keyboardType(.numbersAndPunctuation)

                                HStack(spacing: 6) {
                                    TextField("Reps", text: exerciseBinding.reps)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 52)
                                        .keyboardType(.numberPad)
                                    Text("X")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    TextField("Sets", text: exerciseBinding.sets)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 52)
                                        .keyboardType(.numberPad)
                                }
                                .frame(width: 120, alignment: .leading)

                                Spacer()

                                Button(role: .destructive) {
                                    // Remove by id from the parent binding
                                    let idToRemove = exerciseBinding.wrappedValue.id
                                    if let removeIdx = activity.exercises.firstIndex(where: { $0.id == idToRemove }) {
                                        _ = withAnimation {
                                            activity.exercises.remove(at: removeIdx)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 28)
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Add exercise button
                Button(action: {
                    let new = ExerciseRecord(name: "Exercise", weight: "0", reps: "0", sets: "0")
                    activity.exercises.append(new)
                }) {
                    Label("Add Exercise", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(in: .rect(cornerRadius: 12.0))
                        .padding(.horizontal, 18)
                }
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle(activity.name)
            .navigationBarItems(trailing: Button("Done") { onDone() })
        }
    }
}

#Preview {
    CoachingTabView()
        .environmentObject(ThemeManager())
}
