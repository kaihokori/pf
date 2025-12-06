import SwiftUI

struct IgnoreView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false
    @State private var weeklyProgress: [WorkoutDayStatus] = [.checkIn, .checkIn, .notLogged, .checkIn, .rest, .notLogged, .notLogged]

    private let currentDayIndex = 5
    private let weeklySchedule: [WorkoutScheduleItem] = [
        .init(day: "Mon", sessions: [.init(name: "Chest", duration: "45 mins")]),
        .init(day: "Tue", sessions: [
            .init(name: "Back", duration: "60 mins"),
            .init(name: "Cardio", duration: "30 mins"),
            .init(name: "Yoga", duration: "40 mins")
        ]),
        .init(day: "Wed", sessions: []),
        .init(day: "Thu", sessions: [.init(name: "Legs", duration: "50 mins")]),
        .init(day: "Fri", sessions: [.init(name: "Shoulders", duration: "45 mins")]),
        .init(day: "Sat", sessions: [
            .init(name: "Abs", duration: "20 mins"),
            .init(name: "Hyrox", duration: "90 mins")
        ]),
        .init(day: "Sun", sessions: [])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 0) {
                        HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, profileImage: Image("profile"), onProfileTap: { showAccountsView = true })

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
                AccountsView()
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
    }
}


// Weekly schedule UI/types moved to IgnoreViewView.swift

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


private struct WorkoutProgressTimelineView: View {
    let daySymbols: [String]
    let statuses: [WorkoutDayStatus]
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

    private func status(at index: Int) -> WorkoutDayStatus {
        guard statuses.indices.contains(index) else { return .notLogged }
        return statuses[index]
    }
}

private struct WorkoutProgressSection: View {
    @Binding var weeklyProgress: [WorkoutDayStatus]
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

            WorkoutProgressTimelineView(daySymbols: daySymbols, statuses: weeklyProgress, accentColor: tint)
            .padding(.bottom, -20)

            HStack(spacing: 12) {
                Button(action: { updateCurrentDay(with: .checkIn) }) {
                    Text("Check-In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutProgressButtonStyle(background: Color(.systemBackground)))

                Button(action: { updateCurrentDay(with: .rest) }) {
                    Text("Rest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WorkoutProgressButtonStyle(background: Color(.systemBackground)))
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 32)
    }

    private func updateCurrentDay(with status: WorkoutDayStatus) {
        guard weeklyProgress.indices.contains(currentDayIndex) else { return }
        weeklyProgress[currentDayIndex] = status
    }
}
struct UpNextSection: View {
    let accentColor: Color
    // Dummy data for preview/demo
    let workoutName: String = "Push Day"
    let estimatedDuration: String = "45 mins"
    let exerciseCount: Int = 6

    var body: some View {
        Button(action: { /* Start workout action */ }) {
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
                    Text(workoutName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    HStack(spacing: 12) {
                        Text(estimatedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(exerciseCount) exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
        .buttonStyle(.plain)
    }
}

struct UpNextCheckInSection: View {
    let checkInName: String = "Check-In"
    let estimatedDuration: String = "2 mins"
    let checkInType: String = "Weight, Photos"

    var body: some View {
        Button(action: { /* Start check-in action */ }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.purple)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkInName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    HStack(spacing: 12) {
                        Text(estimatedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(checkInType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutProgressButtonStyle: ButtonStyle {
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

private extension IgnoreView {
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

    var workoutTimelineAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color.yellow
        }
        return accentOverride ?? .accentColor
    }
}

private struct WeeklySplitCarousel: View {
    let schedule: [WorkoutScheduleItem]
    let accentColor: Color

    @State private var currentIndex: Int = 0

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(schedule.indices, id: \ .self) { index in
                VStack(spacing: 16) {
                    Text(schedule[index].day)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 16)

                    ForEach(schedule[index].sessions) { session in
                        ActivityRow(session: session, accentColor: accentColor)
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .frame(height: 300) // Adjust height as needed
        .padding(.horizontal, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.top, 28)
    }
}

private struct ActivityRow: View {
    let session: WorkoutSession
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "figure.strengthtraining.traditional") // Replace with appropriate symbol logic
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                if session.isGymRelated {
                    HStack(spacing: 12) {
                        Text(session.duration ?? "Unknown duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("") // Placeholder for exercise count or other details
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(session.duration ?? "Unknown duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}



extension Color {
    static func random() -> Color {
        return Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}

// Workout uses the shared `SupplementTrackingView` component. Provide workout-specific defaults.
private let workoutDefaultSupplements: [SupplementItem] = [
    SupplementItem(name: "Pre-Workout", amountLabel: "1 scoop"),
    SupplementItem(name: "Creatine", amountLabel: "5 g"),
    SupplementItem(name: "BCAA", amountLabel: "10 g"),
    SupplementItem(name: "Protein Powder", amountLabel: "30 g"),
    SupplementItem(name: "Beta-Alanine", amountLabel: "3.2 g"),
    SupplementItem(name: "Caffeine", amountLabel: "200 mg"),
    SupplementItem(name: "Electrolytes", amountLabel: "1 scoop")
]
