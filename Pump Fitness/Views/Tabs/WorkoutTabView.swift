import SwiftUI

struct WorkoutTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var weeklyProgress: [CoachingWorkoutDayStatus] = [.checkIn, .checkIn, .notLogged, .checkIn, .rest, .notLogged, .notLogged]
    private let coachingCurrentDayIndex = 5
    @State private var supplements: [SupplementItem] = coachingDefaultSupplements
    

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
                        accentColorOverride: .purple,
                        supplements: $supplements
                    )
                    
                    Text("Weights Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                    
                    // Weights tracking section
                    WeightsTrackingSection()

                    Text("Sports Tracking")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                    SportsTrackingSection()

                    ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.inline)
        // Weights-related sheets removed
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
    SupplementItem(name: "Protein Water", amountLabel: "30 g"),
    SupplementItem(name: "Beta-Alanine", amountLabel: "3.2 g"),
    SupplementItem(name: "Caffeine", amountLabel: "200 mg"),
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
                                .surfaceCard(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onSubmit {
                                    part.isEditing = false
                                }
                        } else {
                            Text(part.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                            if part.isEditing {
                                Button {
                                    deleteBodyPart(id: part.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.callout)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(in: .rect(cornerRadius: 18.0))
                                        .accessibilityLabel("Delete Body Part")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)

                    // Column labels
                    HStack(spacing: 12) {
                        Text("Exercise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .center)

                        Text("Sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .center)

                        Text("X")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 15, alignment: .center)

                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .center)
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
                                    .surfaceCard(8)
                                    .frame(minWidth: 0, maxWidth: .infinity)

                                TextField("0", text: $exercise.weight)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .surfaceCard(8)
                                    .frame(width: 60)

                                TextField("0", text: $exercise.sets)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .surfaceCard(8)
                                    .frame(width: 40)

                                Text("X")
                                    .frame(width: 15)

                                TextField("0", text: $exercise.reps)
                                    .keyboardType(.numberPad)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .surfaceCard(8)
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

            // Add new body part
            Button {
                addBodyPart()
            } label: {
                Label("Add Body Part", systemImage: "plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(.black), in: .rect(cornerRadius: 16.0))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.horizontal, 18)
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

    private func deleteBodyPart(id: UUID) {
        guard let index = bodyParts.firstIndex(where: { $0.id == id }) else { return }
        bodyParts.remove(at: index)
    }

    private func addBodyPart() {
        bodyParts.append(
            BodyPartWeights(name: "New Body Part", exercises: [])
        )
    }
}

#Preview {
    WorkoutTabView()
        .environmentObject(ThemeManager())
}
