import SwiftUI
import UIKit

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

struct BodyMeasurements {
    var lastWeightKg: Double?
    var waterPercent: Double?
    var fatPercent: Double?
}

struct WorkoutShareSheet: View {
    var accentColor: Color
    var dailyCheckIn: String
    var schedule: [WorkoutScheduleSnapshot]
    var supplements: [Supplement]
    var takenSupplements: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var measurements: BodyMeasurements

    @Environment(\.dismiss) private var dismiss

    @State private var showSchedule = true
    @State private var showSupplements = true
    @State private var showWeights = true
    @State private var showMeasurements = true

    @State private var selectedWeightGroupId: UUID? = nil
    @State private var sharePayload: WorkoutSharePayload?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)

                    Text("Share Workout Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
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

                        if showWeights {
                            HStack(spacing: 8) {
                                Text("Select body part")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Picker(selection: $selectedWeightGroupId) {
                                    ForEach(weightGroups, id: \.id) { group in
                                        Text(group.name).tag(Optional(group.id))
                                    }
                                } label: {
                                    EmptyView()
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 20)
                        }

                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                            WorkoutShareCard(
                                accentColor: accentColor,
                                checkInText: dailyCheckIn,
                                schedule: schedule,
                                supplements: supplements,
                                takenIDs: takenSupplements,
                                weightGroups: weightGroups,
                                weightEntries: weightEntries,
                                selectedWeightGroupId: $selectedWeightGroupId,
                                measurements: measurements,
                                showSchedule: showSchedule,
                                showSupplements: showSupplements,
                                showWeights: showWeights,
                                showMeasurements: showMeasurements,
                                isExporting: false
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
                schedule: schedule,
                supplements: supplements,
                takenIDs: takenSupplements,
                weightGroups: weightGroups,
                weightEntries: weightEntries,
                selectedWeightGroupId: .constant(selectedWeightGroupId),
                measurements: measurements,
                showSchedule: showSchedule,
                showSupplements: showSupplements,
                showWeights: showWeights,
                showMeasurements: showMeasurements,
                isExporting: true
            )
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        renderer.isOpaque = false
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
    var schedule: [WorkoutScheduleSnapshot]
    var supplements: [Supplement]
    var takenIDs: Set<String>
    var weightGroups: [WeightGroupDefinition]
    var weightEntries: [WeightExerciseValue]
    var selectedWeightGroupId: Binding<UUID?>
    var measurements: BodyMeasurements

    var showSchedule: Bool
    var showSupplements: Bool
    var showWeights: Bool
    var showMeasurements: Bool

    var isExporting: Bool

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
                if showSchedule && !schedule.isEmpty {
                    WorkoutScheduleSection(items: schedule, checkInText: checkInText)
                }

                if showSupplements && !supplements.isEmpty {
                    WorkoutSupplementsSection(supplements: supplements, takenIDs: takenIDs, color: .green)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "TODAY'S SCHEDULE", icon: "calendar", color: .blue)
                Spacer()
                // Status: Checked In / Rest Day / Not Logged
                Text(statusText(from: checkInText))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
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

private struct WorkoutSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
