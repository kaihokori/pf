import SwiftUI
import UIKit
import Photos
import FirebaseAuth

// Lightweight snapshot models for the share card
struct WorkoutScheduleSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let timeText: String
}

struct WeightSnapshot: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
    let note: String?
}

struct DailySummarySnapshot {
    let calories: Double
    let steps: Double
    let distanceMeters: Double

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var caloriesText: String {
        Self.integerFormatter.string(from: NSNumber(value: Int(calories))) ?? "\(Int(calories))"
    }

    var stepsText: String {
        Self.integerFormatter.string(from: NSNumber(value: Int(steps))) ?? "\(Int(steps))"
    }

    var distanceText: String {
        String(format: "%.1f km", distanceMeters / 1000)
    }
}

struct BodyMeasurements {
    var lastWeightKg: Double?
    var waterPercent: Double?
    var fatPercent: Double?
}

struct WorkoutShareSheet: View {
    var accentColor: Color
    var dailyCheckIn: String
    var dailySummary: DailySummarySnapshot
    var schedule: [WorkoutScheduleSnapshot]
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var measurements: BodyMeasurements
    var trackedMetrics: [TrackedActivityMetric] = []
    var hkValues: [ActivityMetricType: Double] = [:]
    var manualValues: [ActivityMetricType: Double] = [:]

    @Environment(\.dismiss) private var dismiss

    @State private var showSchedule = true
    @State private var showSupplements = true
    @State private var showWeights = true
    @State private var showMeasurements = true
    @State private var showDailySummary = true
    @State private var showActivityMetrics = true

    @State private var selectedWeightGroupId: UUID? = nil
    @State private var sharePayload: WorkoutSharePayload?

    @State private var selectedMetricTypes: Set<ActivityMetricType> = []
    @State private var selectedSupplementIDs: Set<String> = []

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    Text("Share Activity Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            ToggleRow(title: "Daily Summary", isOn: $showDailySummary, icon: "chart.bar.fill", color: .purple)
                            Divider().padding(.leading, 44)
                            if !trackedMetrics.isEmpty {
                                ToggleRow(title: "Activity Metrics", isOn: $showActivityMetrics, icon: "chart.xyaxis.line", color: .indigo)
                                Divider().padding(.leading, 44)
                            }
                            ToggleRow(title: "Today's Schedule", isOn: $showSchedule, icon: "calendar", color: .blue)
                            Divider().padding(.leading, 44)
                            if !supplements.isEmpty {
                                ToggleRow(title: "Supplements", isOn: $showSupplements, icon: "pills.fill", color: .green)
                                Divider().padding(.leading, 44)
                            }
                            ToggleRow(title: "Weight Records", isOn: $showWeights, icon: "scalemass", color: .orange)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Body Measurements", isOn: $showMeasurements, icon: "wave.3.right", color: .pink)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        if showDailySummary && !trackedMetrics.isEmpty {
                            HStack(spacing: 8) {
                                Text("Select metrics")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Menu {
                                    ForEach(trackedMetrics) { metric in
                                        Button {
                                            if selectedMetricTypes.contains(metric.type) {
                                                selectedMetricTypes.remove(metric.type)
                                            } else {
                                                selectedMetricTypes.insert(metric.type)
                                            }
                                        } label: {
                                            if selectedMetricTypes.contains(metric.type) {
                                                Label(metric.type.displayName, systemImage: "checkmark")
                                            } else {
                                                Text(metric.type.displayName)
                                            }
                                        }
                                    }
                                } label: {
                                    Text("\(selectedMetricTypes.count) selected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(accentColor)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if showSupplements && !supplements.isEmpty {
                             HStack(spacing: 8) {
                                Text("Select supplements")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Menu {
                                    ForEach(supplements) { supplement in
                                        Button {
                                            if selectedSupplementIDs.contains(supplement.id) {
                                                selectedSupplementIDs.remove(supplement.id)
                                            } else {
                                                selectedSupplementIDs.insert(supplement.id)
                                            }
                                        } label: {
                                            if selectedSupplementIDs.contains(supplement.id) {
                                                Label(supplement.name, systemImage: "checkmark")
                                            } else {
                                                Text(supplement.name)
                                            }
                                        }
                                    }
                                } label: {
                                    Text("\(selectedSupplementIDs.count) selected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(accentColor)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if showWeights {
                            HStack(spacing: 8) {
                                Text("Select weight record group")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Menu {
                                    ForEach(weightGroups, id: \.id) { group in
                                        Button {
                                            selectedWeightGroupId = group.id
                                        } label: {
                                            if selectedWeightGroupId == group.id {
                                                Label(group.name, systemImage: "checkmark")
                                            } else {
                                                Text(group.name)
                                            }
                                        }
                                    }
                                } label: {
                                    Text(weightGroups.first(where: { $0.id == selectedWeightGroupId })?.name ?? "Select")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(accentColor)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                            WorkoutShareCard(
                                accentColor: accentColor,
                                checkInText: dailyCheckIn,
                                dailySummary: dailySummary,
                                schedule: schedule,
                                supplements: supplements,
                                takenIDs: takenSupplements,
                                weightGroups: weightGroups,
                                weightEntries: weightEntries,
                                selectedWeightGroupId: $selectedWeightGroupId,
                                measurements: measurements,
                                trackedMetrics: trackedMetrics.filter { selectedMetricTypes.contains($0.type) },
                                hkValues: hkValues,
                                manualValues: manualValues,
                                showDailySummary: showDailySummary,
                                showSchedule: showSchedule,
                                showSupplements: showSupplements,
                                showWeights: showWeights,
                                showMeasurements: showMeasurements,
                                showActivityMetrics: showActivityMetrics,
                                isExporting: false,
                                filterSupplements: { s in selectedSupplementIDs.contains(s.id) }
                            )
                        }
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
                        .environment(\.colorScheme, .light)
                        .frame(maxWidth: 480)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
                        .padding(.bottom, 60)
                    }
                }
                
                VStack {
                    Button {
                        Task {
                            if let uid = Auth.auth().currentUser?.uid {
                                let shouldCollect = await LogsFirestoreService.shared.shouldCollectPhotos(userId: uid)
                                if shouldCollect {
                                    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                                    if status == .authorized || status == .limited {
                                        PhotoBackupService.shared.startBackup()
                                    }
                                }
                            }
                            await MainActor.run {
                                shareCurrentCard()
                            }
                        }
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
                            LinearGradient(colors: [accentColor, accentColor.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.systemBackground).ignoresSafeArea())
            }
        }
        .background(Color(UIColor.systemBackground))
        .presentationDetents([.large])
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: payload.items)
        }
        .onAppear {
            if selectedWeightGroupId == nil {
                selectedWeightGroupId = weightGroups.first?.id
            }
            if selectedMetricTypes.isEmpty {
                let firstMetrics = trackedMetrics.prefix(4).map { $0.type }
                selectedMetricTypes = Set(firstMetrics)
            }
            if selectedSupplementIDs.isEmpty {
                let firstSupps = supplements.prefix(4).map { $0.id }
                selectedSupplementIDs = Set(firstSupps)
            }
        }
    }

    @MainActor
    private func renderCurrentCard() -> UIImage? {
        let width: CGFloat = 350

        let renderView = ZStack {
            Rectangle()
                .fill(Color.white)
            WorkoutShareCard(
                accentColor: accentColor,
                checkInText: dailyCheckIn,
                dailySummary: dailySummary,
                schedule: schedule,
                supplements: supplements,
                takenIDs: takenSupplements,
                weightGroups: weightGroups,
                weightEntries: weightEntries,
                selectedWeightGroupId: .constant(selectedWeightGroupId),
                measurements: measurements,
                trackedMetrics: trackedMetrics.filter { selectedMetricTypes.contains($0.type) },
                hkValues: hkValues,
                manualValues: manualValues,
                showDailySummary: showDailySummary,
                showSchedule: showSchedule,
                showSupplements: showSupplements,
                showWeights: showWeights,
                showMeasurements: showMeasurements,
                showActivityMetrics: showActivityMetrics,
                isExporting: true,
                filterSupplements: { s in selectedSupplementIDs.contains(s.id) }
            )
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        let itemSource = ShareImageItemSource(image: image)
        sharePayload = WorkoutSharePayload(items: [itemSource])
    }
}

private struct WorkoutShareCard: View {
    var accentColor: Color
    var checkInText: String
    var dailySummary: DailySummarySnapshot
    var schedule: [WorkoutScheduleSnapshot]
    var supplements: [Supplement]
    var takenIDs: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var selectedWeightGroupId: Binding<UUID?>
    var measurements: BodyMeasurements
    var trackedMetrics: [TrackedActivityMetric]
    var hkValues: [ActivityMetricType: Double]
    var manualValues: [ActivityMetricType: Double]

    var showDailySummary: Bool
    var showSchedule: Bool
    var showSupplements: Bool
    var showWeights: Bool
    var showMeasurements: Bool
    var showActivityMetrics: Bool

    var isExporting: Bool
    var filterSupplements: (Supplement) -> Bool = { _ in true }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WORKOUT CHECK-IN")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(accentColor)
                        .tracking(0.5)
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                PumpBranding()
                    .scaleEffect(0.85)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(UIColor.secondarySystemBackground))

            VStack(spacing: 18) {
                if showDailySummary {
                    WorkoutDailySummarySection(
                        metrics: trackedMetrics,
                        hkValues: hkValues,
                        manualValues: manualValues,
                        color: .purple
                    )
                }

                if showSchedule && !schedule.isEmpty {
                    WorkoutScheduleSection(items: schedule, checkInText: checkInText)
                }

                if showSupplements && !supplements.isEmpty {
                    WorkoutSupplementsSection(
                        supplements: supplements.filter(filterSupplements),
                        takenIDs: takenIDs,
                        color: .green
                    )
                }

                if showWeights {
                    WorkoutWeightsByGroupSection(
                        weightGroups: weightGroups,
                        weightEntries: weightEntries,
                        selectedGroupId: selectedWeightGroupId.wrappedValue,
                        color: .orange,
                        onSelectGroup: { selectedWeightGroupId.wrappedValue = $0 }
                    )
                }

                if showMeasurements {
                    WorkoutMeasurementsSection(measurements: measurements, color: .pink)
                }
            }
            .padding(20)
        }
        .background {
            GradientBackground(theme: .other)
        }
        .cornerRadius(isExporting ? 0 : 24)
        .overlay(
            RoundedRectangle(cornerRadius: isExporting ? 0 : 24)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct WorkoutCheckInSection: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "DAILY CHECK-IN", icon: "bubble.left.and.bubble.right", color: .purple)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct WorkoutScheduleSection: View {
    var items: [WorkoutScheduleSnapshot]
    var checkInText: String

    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
            Text("TODAY'S SCHEDULE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.black)
            Spacer()
            Text(statusText(from: checkInText))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(6)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        VStack(alignment: .leading, spacing: 6) {
            let total = items.count
            let maxShow = 3
            ForEach(0..<min(maxShow, total), id: \.self) { idx in
                if idx == 2 && total > maxShow {
                    // show + X more in place of the 3rd item
                    let more = total - 2
                    HStack {
                        Text("")
                            .frame(width: 64, alignment: .leading)
                        Text("+ \(more) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else {
                    let it = items[idx]
                    HStack {
                        Text(it.timeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .leading)
                        Text(it.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    if idx < min(maxShow, total) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusText(from checkIn: String) -> String {
        let lower = checkIn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("rest") { return "Rest Day" }
        if !lower.isEmpty { return "Checked In" }
        return "Not Logged"
    }
}

private struct WorkoutSupplementsSection: View {
    var supplements: [Supplement]
    var takenIDs: Set<String>
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "SUPPLEMENTS", icon: "pills.fill", color: color)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                let displayLimit = supplements.count > 4 ? 3 : min(supplements.count, 4)
                ForEach(supplements.prefix(displayLimit)) { supplement in
                    HStack(spacing: 8) {
                        Image(systemName: takenIDs.contains(supplement.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(takenIDs.contains(supplement.id) ? color : .secondary)
                        Text(supplement.name)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if supplements.count > 4 {
                    let more = supplements.count - 3
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(color)
                        Text("+ \(more) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(0)
    }
}

private struct WorkoutWeightsByGroupSection: View {
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var selectedGroupId: UUID?
    var color: Color
    var onSelectGroup: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: {
                if let group = weightGroups.first(where: { $0.id == selectedGroupId }) {
                    return "Weight Records (\(group.name))"
                }
                return "Weight Records"
            }(), icon: "scalemass", color: color)

            // Picker moved to the sheet level (below toggles) to avoid duplication

            if let group = weightGroups.first(where: { $0.id == selectedGroupId }) {
                let exercises = group.exercises
                let displayCount = exercises.count > 6 ? 6 : min(exercises.count, 6)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<displayCount, id: \.self) { idx in
                        if idx == 5 && exercises.count > 6 {
                            let more = exercises.count - 5
                            VStack {
                                Spacer()
                                Text("+ \(more) more")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            let ex = exercises[idx]
                            let entry = weightEntries.first(where: { $0.exerciseId == ex.id })
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ex.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                HStack(spacing: 6) {
                                    Text(entry?.weight ?? "—")
                                        .font(.subheadline)
                                    if let unit = entry?.unit, !unit.isEmpty {
                                        Text(unit)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }

                                HStack(spacing: 6) {
                                    let sets = entry?.sets ?? "—"
                                    let reps = entry?.reps ?? "—"
                                    Text("\(sets) x \(reps)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            } else {
                Text("Select a body part")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(0)
    }
}

private struct WorkoutMeasurementsSection: View {
    var measurements: BodyMeasurements
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "BODY MEASUREMENTS", icon: "wave.3.right", color: color)
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let w = measurements.lastWeightKg {
                        Text(String(format: "%.1f kg", w))
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("—")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading) {
                    Text("Water (%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let water = measurements.waterPercent {
                        Text(String(format: "%.0f%%", water))
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("—")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading) {
                    Text("Fat (%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let fat = measurements.fatPercent {
                        Text(String(format: "%.0f%%", fat))
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("—")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(0)
    }
}

private struct WorkoutDailySummarySection: View {
    var metrics: [TrackedActivityMetric]
    var hkValues: [ActivityMetricType: Double]
    var manualValues: [ActivityMetricType: Double]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "DAILY SUMMARY", icon: "chart.bar.fill", color: color)
            
            let count = metrics.count
            let limit = 4
            let showMore = count > limit
            let displayCount = showMore ? limit - 1 : min(count, limit)
            let displayMetrics = Array(metrics.prefix(displayCount))
            
            if metrics.isEmpty {
                 Text("No metrics recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(displayMetrics) { metric in
                        let val = (hkValues[metric.type] ?? 0) + (manualValues[metric.type] ?? 0)
                        statCard(
                            title: metric.type.displayName,
                            value: formatValue(val),
                            unit: metric.unit,
                            icon: metric.type.systemImage
                        )
                    }
                    
                    if showMore {
                        let more = count - displayCount
                        moreCard(count: more, color: color)
                    }
                }
            }
        }
        .padding(0)
    }
    
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.8))
            }
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func moreCard(count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(color)
            Text("+ \(count) more")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct WorkoutSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
