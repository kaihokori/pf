import SwiftUI
import UIKit
import Photos
import SwiftData
import Charts

struct ShareWorkoutSheet: View {
    // Data Inputs
    var weeklyCheckInStatuses: [WorkoutCheckInStatus]
    var workoutSchedule: [WorkoutScheduleItem]
    var dailySummary: (calories: Double, steps: Double, distance: Double)
    var dailyGoals: (calories: Int, steps: Int, distance: Double)
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var weeklyProgress: [WeeklyProgressEntry]
    var accentColor: Color
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Toggles
    @State private var showCheckIn = true
    @State private var showSchedule = true
    @State private var showSummary = true
    @State private var summaryMode: SummaryMode = .today
    @State private var showSupplements = true
    @State private var showWeights = true
    @State private var selectedBodyPartID: UUID?
    @State private var showProgress = true
    
    enum SummaryMode: String, CaseIterable, Identifiable {
        case today = "Today"
        case weekAvg = "Week Avg"
        case weekTotal = "Week Total"
        var id: Self { self }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                Text("Share Workout Stats")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Card Preview
                    CustomizableWorkoutShareCard(
                        weeklyCheckInStatuses: weeklyCheckInStatuses,
                        workoutSchedule: workoutSchedule,
                        dailySummary: dailySummary,
                        dailyGoals: dailyGoals,
                        supplements: supplements,
                        takenSupplements: takenSupplements,
                        weightGroups: weightGroups,
                        weightEntries: weightEntries,
                        weeklyProgress: weeklyProgress,
                        showCheckIn: showCheckIn,
                        showSchedule: showSchedule,
                        showSummary: showSummary,
                        summaryMode: summaryMode,
                        showSupplements: showSupplements,
                        showWeights: showWeights,
                        selectedBodyPartID: selectedBodyPartID,
                        showProgress: showProgress,
                        accentColor: accentColor
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
                    
                    // Controls
                    VStack(spacing: 0) {
                        ToggleRow(title: "Weekly Check-In", isOn: $showCheckIn, icon: "checkmark.circle.fill", color: .green)
                        Divider().padding(.leading, 44)
                        
                        ToggleRow(title: "Weekly Schedule", isOn: $showSchedule, icon: "calendar", color: .blue)
                        Divider().padding(.leading, 44)
                        
                        VStack(spacing: 0) {
                            ToggleRow(title: "Daily Summary", isOn: $showSummary, icon: "figure.run", color: .orange)
                            if showSummary {
                                Picker("Summary Mode", selection: $summaryMode) {
                                    ForEach(SummaryMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }
                        Divider().padding(.leading, 44)
                        
                        if !supplements.isEmpty {
                            ToggleRow(title: "Supplements", isOn: $showSupplements, icon: "pills.fill", color: .purple)
                            Divider().padding(.leading, 44)
                        }
                        
                        VStack(spacing: 0) {
                            ToggleRow(title: "Weights Tracking", isOn: $showWeights, icon: "dumbbell.fill", color: .red)
                            if showWeights && !weightGroups.isEmpty {
                                Menu {
                                    ForEach(weightGroups) { group in
                                        Button(group.name) {
                                            selectedBodyPartID = group.id
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Body Part")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(weightGroups.first(where: { $0.id == selectedBodyPartID })?.name ?? "Select")
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        Divider().padding(.leading, 44)
                        
                        ToggleRow(title: "Workout Progress", isOn: $showProgress, icon: "chart.xyaxis.line", color: .blue)
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
            
            // Share Button
            VStack {
                Button {
                    shareCurrentCard()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Share")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        LinearGradient(colors: [accentColor, accentColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 20)
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
        }
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .onAppear {
            if selectedBodyPartID == nil, let first = weightGroups.first {
                selectedBodyPartID = first.id
            }
        }
    }
    
    @MainActor
    private func renderCurrentCard() -> UIImage? {
        let width: CGFloat = 375
        let height: CGFloat = 667 // 9:16 aspect ratio
        
        let renderView = ZStack {
            Color(UIColor.systemBackground)
            
            CustomizableWorkoutShareCard(
                weeklyCheckInStatuses: weeklyCheckInStatuses,
                workoutSchedule: workoutSchedule,
                dailySummary: dailySummary,
                dailyGoals: dailyGoals,
                supplements: supplements,
                takenSupplements: takenSupplements,
                weightGroups: weightGroups,
                weightEntries: weightEntries,
                weeklyProgress: weeklyProgress,
                showCheckIn: showCheckIn,
                showSchedule: showSchedule,
                showSummary: showSummary,
                summaryMode: summaryMode,
                showSupplements: showSupplements,
                showWeights: showWeights,
                selectedBodyPartID: selectedBodyPartID,
                showProgress: showProgress,
                accentColor: accentColor
            )
            .padding()
        }
        .frame(width: width, height: height)
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        return renderer.uiImage
    }
    
    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        shareItems = [image]
        showShareSheet = true
    }
}

struct CustomizableWorkoutShareCard: View {
    var weeklyCheckInStatuses: [WorkoutCheckInStatus]
    var workoutSchedule: [WorkoutScheduleItem]
    var dailySummary: (calories: Double, steps: Double, distance: Double)
    var dailyGoals: (calories: Int, steps: Int, distance: Double)
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var weeklyProgress: [WeeklyProgressEntry]
    
    var showCheckIn: Bool
    var showSchedule: Bool
    var showSummary: Bool
    var summaryMode: ShareWorkoutSheet.SummaryMode
    var showSupplements: Bool
    var showWeights: Bool
    var selectedBodyPartID: UUID?
    var showProgress: Bool
    
    var accentColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORKOUT STATS")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(1)
                    
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                Spacer()
                PumpBranding()
            }
            .padding(24)
            .background(accentColor.opacity(0.05))
            
            VStack(spacing: 24) {
                if showCheckIn {
                    CheckInSection(statuses: weeklyCheckInStatuses, color: .green)
                }
                
                if showSchedule {
                    ScheduleSection(schedule: workoutSchedule, color: .blue)
                }
                
                if showSummary {
                    SummarySection(
                        summary: dailySummary,
                        goals: dailyGoals,
                        mode: summaryMode,
                        color: .orange
                    )
                }
                
                if showWeights, let groupID = selectedBodyPartID, let group = weightGroups.first(where: { $0.id == groupID }) {
                    WeightsSection(
                        group: group,
                        entries: weightEntries,
                        color: .red
                    )
                }
                
                if showSupplements && !supplements.isEmpty {
                    SupplementsSection(
                        supplements: supplements,
                        takenIDs: takenSupplements,
                        color: .purple
                    )
                }
                
                if showProgress {
                    ProgressSection(entries: weeklyProgress, color: .blue)
                }
            }
            .padding(24)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Sections

struct CheckInSection: View {
    var statuses: [WorkoutCheckInStatus]
    var color: Color
    
    let days = ["M", "T", "W", "T", "F", "S", "S"]
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "WEEKLY CHECK-IN", icon: "checkmark.circle.fill", color: color)
            
            HStack(spacing: 0) {
                ForEach(0..<min(statuses.count, 7), id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(days[index])
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Circle()
                            .fill(statusColor(statuses[index]))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: statusIcon(statuses[index]))
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    func statusColor(_ status: WorkoutCheckInStatus) -> Color {
        switch status {
        case .checkIn: return color
        case .rest: return .blue.opacity(0.5)
        case .notLogged: return Color(UIColor.systemGray5)
        }
    }
    
    func statusIcon(_ status: WorkoutCheckInStatus) -> String {
        switch status {
        case .checkIn: return "checkmark"
        case .rest: return "zzz"
        case .notLogged: return ""
        }
    }
}

struct ScheduleSection: View {
    var schedule: [WorkoutScheduleItem]
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "WEEKLY SCHEDULE", icon: "calendar", color: color)
            
            VStack(spacing: 8) {
                ForEach(schedule) { item in
                    HStack {
                        Text(item.day.prefix(3).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                        
                        if let session = item.sessions.first {
                            Text(session.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("Rest")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }
}

struct SummarySection: View {
    var summary: (calories: Double, steps: Double, distance: Double)
    var goals: (calories: Int, steps: Int, distance: Double)
    var mode: ShareWorkoutSheet.SummaryMode
    var color: Color
    
    var displayValues: (calories: Double, steps: Double, distance: Double) {
        switch mode {
        case .today:
            return summary
        case .weekAvg:
            // Mocking avg as current for now, or divide by day of week index
            return summary // Placeholder logic
        case .weekTotal:
            // Mocking total as current * day index
            return summary // Placeholder logic
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                SectionHeader(title: "SUMMARY", icon: "figure.run", color: color)
                Spacer()
                Text(mode.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                SummaryCard(
                    value: "\(Int(displayValues.calories))",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
                SummaryCard(
                    value: "\(Int(displayValues.steps))",
                    unit: "steps",
                    icon: "figure.walk",
                    color: .green
                )
                SummaryCard(
                    value: String(format: "%.1f", displayValues.distance / 1000),
                    unit: "km",
                    icon: "map.fill",
                    color: .blue
                )
            }
        }
    }
}

struct SummaryCard: View {
    var value: String
    var unit: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WeightsSection: View {
    var group: WeightGroupDefinition
    var entries: [WeightExerciseValue]
    var color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: group.name.uppercased(), icon: "dumbbell.fill", color: color)
            
            VStack(spacing: 12) {
                ForEach(group.exercises) { exercise in
                    if let entry = entries.first(where: { $0.exerciseId == exercise.id }) {
                        HStack {
                            Text(exercise.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(entry.weight) \(entry.unit)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(color)
                                Text("\(entry.sets) x \(entry.reps)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

struct ProgressSection: View {
    var entries: [WeeklyProgressEntry]
    var color: Color
    
    var currentWeight: Double {
        entries.last?.weight ?? 0
    }
    
    var previousWeight: Double {
        guard entries.count >= 2 else { return 0 }
        return entries[entries.count - 2].weight
    }
    
    var diff: Double {
        guard previousWeight > 0 else { return 0 }
        return currentWeight - previousWeight
    }
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "BODY WEIGHT PROGRESS", icon: "chart.xyaxis.line", color: color)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", currentWeight))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if diff != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: diff < 0 ? "arrow.down" : "arrow.up")
                        Text(String(format: "%.1f kg", abs(diff)))
                    }
                    .font(.headline)
                    .foregroundStyle(diff < 0 ? .green : .red) // Assuming weight loss is good, adjust if needed
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (diff < 0 ? Color.green : Color.red).opacity(0.1)
                    )
                    .clipShape(Capsule())
                } else {
                    Text("No Change")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(previousWeight > 0 ? String(format: "%.1f kg", previousWeight) : "--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
