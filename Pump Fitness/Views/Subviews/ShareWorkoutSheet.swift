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
    
    @State private var sharePayload: ShareWorkoutPayload?
    
    // Toggles
    @State private var showCheckIn = true
    @State private var showSchedule = true
    @State private var showSummary = true
    @State private var showSupplements = true
    @State private var showWeights = true
    @State private var selectedBodyPartID: UUID?
    @State private var showProgress = true
    
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 24)

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
                        showSupplements: showSupplements,
                        showWeights: showWeights,
                        selectedBodyPartID: selectedBodyPartID,
                        showProgress: showProgress,
                        accentColor: accentColor
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
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
                        
                        ToggleRow(title: "Body Measurements", isOn: $showProgress, icon: "chart.xyaxis.line", color: .blue)
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 60)
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
        .navigationTitle("Share Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .onAppear {
            if selectedBodyPartID == nil, let first = weightGroups.first {
                selectedBodyPartID = first.id
            }
        }
    }
    
    @MainActor
    private func renderCurrentCard() -> UIImage? {
        // Render at a smaller resolution to keep UI responsive
        let width: CGFloat = 576
        let height: CGFloat = 1024 // 16:9 aspect ratio

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
        renderer.scale = 1.5
        renderer.isOpaque = true
        return renderer.uiImage
    }
    
    private func shareCurrentCard() {
        Task { @MainActor in
            // Render on main (ImageRenderer is safest on main), but at reduced size/scale to stay snappy
            let image = renderCurrentCard()
            guard let image else { return }
            let shareText = "Trackerio Summary - \(Date().formatted(date: .abbreviated, time: .omitted))"
            if let url = saveImageToTempPNG(image, prefix: "workout") {
                sharePayload = ShareWorkoutPayload(items: [url, shareText])
            } else {
                sharePayload = ShareWorkoutPayload(items: [image, shareText])
            }
        }
    }

    private func saveImageToTempPNG(_ image: UIImage, prefix: String = "share") -> URL? {
        guard let data = image.pngData() else { return nil }
        let tmp = FileManager.default.temporaryDirectory
        let filename = "\(prefix)-\(UUID().uuidString).png"
        let url = tmp.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
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
    
    var showSupplements: Bool
    var showWeights: Bool
    var selectedBodyPartID: UUID?
    var showProgress: Bool
    
    var accentColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKOUT STATS")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(1)

                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Spacer()
                PumpBranding()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(accentColor.opacity(0.05))
            
            VStack(spacing: 16) {
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
                    let displaySupplements: [Supplement] = {
                        if supplements.count > 4 {
                            var list = Array(supplements.prefix(3))
                            let moreCount = supplements.count - 3
                            let more = Supplement(id: "more-\(moreCount)", name: "+ \(moreCount) more")
                            list.append(more)
                            return list
                        } else {
                            return Array(supplements.prefix(4))
                        }
                    }()

                    SupplementsSection(
                        supplements: displaySupplements,
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
        .dynamicTypeSize(.medium)
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
                                Group {
                                    let icon = statusIcon(statuses[index])
                                    if !icon.isEmpty {
                                        Image(systemName: icon)
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                    }
                                }
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

            // First row: four items
            HStack(spacing: 8) {
                ForEach(Array(schedule.prefix(4))) { item in
                    VStack(spacing: 4) {
                        Text(item.day.prefix(3).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        let sessionNames = item.sessions.map { $0.name }
                        if sessionNames.isEmpty {
                            Text("Rest")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.5))
                        } else {
                            Text(sessionNames.joined(separator: ", "))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Second row: remaining days (Fri/Sat/Sun) spanning full width
            let remaining = Array(schedule.dropFirst(4).prefix(3))
            if !remaining.isEmpty {
                HStack(spacing: 8) {
                    ForEach(remaining) { item in
                        VStack(spacing: 4) {
                            Text(item.day.prefix(3).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            let sessionNames = item.sessions.map { $0.name }
                            if sessionNames.isEmpty {
                                Text("Rest")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary.opacity(0.5))
                            } else {
                                Text(sessionNames.joined(separator: ", "))
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

struct SummarySection: View {
    var summary: (calories: Double, steps: Double, distance: Double)
    var goals: (calories: Int, steps: Int, distance: Double)
    var color: Color
    var displayValues: (calories: Double, steps: Double, distance: Double) {
        return summary
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SectionHeader(title: "SUMMARY", icon: "figure.run", color: color)
                Spacer()
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

            let display: [WeightExerciseDefinition] = {
                if group.exercises.count > 6 {
                    var list = Array(group.exercises.prefix(5))
                    let moreCount = group.exercises.count - 5
                    list.append(WeightExerciseDefinition(id: UUID(), name: "+ \(moreCount) more"))
                    return list
                } else {
                    return Array(group.exercises.prefix(6))
                }
            }()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(display) { exercise in
                    let isMore = exercise.name.starts(with: "+ ")
                    let entry = entries.first(where: { $0.exerciseId == exercise.id })

                    Group {
                        if isMore {
                            // Placeholder showing how many more exercises exist
                            HStack {
                                Spacer()
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(minHeight: 72)
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)

                                Spacer()

                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(entry != nil ? "\(entry!.weight) \(entry!.unit)" : "--")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(color)

                                    Spacer()

                                    Text(entry != nil ? "\(entry!.sets) x \(entry!.reps)" : "--")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(minHeight: 72)
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }
}

struct ProgressSection: View {
    var entries: [WeeklyProgressEntry]
    var color: Color

    private var current: WeeklyProgressEntry? { entries.last }
    private var previousWeight: Double? { entries.count >= 2 ? entries[entries.count - 2].weight : nil }

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "BODY MEASUREMENTS", icon: "chart.xyaxis.line", color: color)

            HStack(spacing: 12) {
                SummaryCard(
                    value: current?.weight != nil ? String(format: "%.1f", current!.weight) : "--",
                    unit: "kg",
                    icon: "scalemass.fill",
                    color: .blue
                )

                SummaryCard(
                    value: current?.waterPercent != nil ? String(format: "%.1f", current!.waterPercent!) : "--",
                    unit: "water (%)",
                    icon: "drop.fill",
                    color: .cyan
                )

                SummaryCard(
                    value: current?.bodyFatPercent != nil ? String(format: "%.1f", current!.bodyFatPercent!) : "--",
                    unit: "fat (%)",
                    icon: "figure.arms.open",
                    color: .orange
                )
            }
        }
    }
}

struct ShareWorkoutPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
