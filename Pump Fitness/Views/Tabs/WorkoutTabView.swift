import SwiftUI

struct WorkoutTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCalendar = false
    @State private var selectedDate = Date()
    @State private var showAccountsView = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 0) {
                        HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, profileImage: Image("profile"), onProfileTap: { showAccountsView = true })
                        
                        WorkoutSummaryComponent(
                            accentColorOverride: accentOverride
                        )
                        .padding(.top, 48)

                        Text("Daily Summary")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)

                        DailyActivitySummary()

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Up Next")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.leading, 18)
                                .padding(.top, 28)
                            UpNextSection(accentColor: accentOverride ?? .accentColor)
                            UpNextCheckInSection()
                        }
                        Spacer(minLength: 24)
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

struct WorkoutSummaryComponent: View {
    var accentColorOverride: Color?
    // Dummy data for preview/demo
    let totalWorkouts: Int = 4
    let totalDuration: String = "3 hrs 20 mins"
    let caloriesBurned: Int = 2200

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                SummaryItem(title: "Workouts", value: "\(totalWorkouts)", accentColor: accentColorOverride)
                Spacer()
                SummaryItem(title: "Duration", value: totalDuration, accentColor: accentColorOverride)
                Spacer()
                SummaryItem(title: "Calories", value: "\(caloriesBurned)", accentColor: accentColorOverride)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
        .padding(.bottom, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    let accentColor: Color?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(accentColor ?? .accentColor)
        }
    }
}

struct DailyActivitySummary: View {
    let caloriesBurned: Int = 620
    let caloriesGoal: Int = 800
    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12)
    ]

    private var clampedProgress: Double {
        min(max(Double(caloriesBurned) / Double(caloriesGoal), 0), 1)
    }

    private var progressPercentage: Int {
        Int(clampedProgress * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                let tint = Color.orange
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(tint.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(caloriesBurned) cal")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Goal \(caloriesGoal) cal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories Burned".uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        GeometryReader { proxy in
                            let width = proxy.size.width * clampedProgress
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.12))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(tint.opacity(0.85))
                                    .frame(width: max(width, 8))
                            }
                            .frame(height: 10)
                            .animation(.easeOut(duration: 0.35), value: clampedProgress)
                        }
                        .frame(height: 10)

                        Text("\(progressPercentage)% of goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 150)
                // .glassEffect(accentColorOverride == nil ? .regular.tint(tint.opacity(0.2)) : .regular, in: .rect(cornerRadius: 16.0))
                .glassEffect(in: .rect(cornerRadius: 16.0))
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Synced with Apple Health.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}

private struct ActivityStatCard: View {
    var title: String
    var value: String
    var detail: String
    var iconName: String
    var iconColor: Color
    var progress: Double
    var accentColorOverride: Color?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var progressPercentage: Int {
        Int(clampedProgress * 100)
    }

    var body: some View {
        
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

#Preview {
    WorkoutTabView()
        .environmentObject(ThemeManager())
}
