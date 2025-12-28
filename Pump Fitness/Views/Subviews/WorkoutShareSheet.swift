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
    var weights: [WeightSnapshot]
    var measurements: BodyMeasurements

    @Environment(\.dismiss) private var dismiss

    @State private var showCheckIn = true
    @State private var showSchedule = true
    @State private var showSupplements = true
    @State private var showWeights = true
    @State private var showMeasurements = true

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
                            ToggleRow(title: "Daily Check-In", isOn: $showCheckIn, icon: "bubble.left.and.bubble.right", color: .purple)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Today's Schedule", isOn: $showSchedule, icon: "calendar", color: .blue)
                            Divider().padding(.leading, 44)
                            if !supplements.isEmpty {
                                ToggleRow(title: "Supplements", isOn: $showSupplements, icon: "pills.fill", color: .green)
                                Divider().padding(.leading, 44)
                            }
                            ToggleRow(title: "Weights", isOn: $showWeights, icon: "scalemass", color: .orange)
                            Divider().padding(.leading, 44)
                            ToggleRow(title: "Body Measurements", isOn: $showMeasurements, icon: "wave.3.right", color: .pink)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        WorkoutShareCard(
                            accentColor: accentColor,
                            checkInText: dailyCheckIn,
                            schedule: schedule,
                            supplements: supplements,
                            takenIDs: takenSupplements,
                            weights: weights,
                            measurements: measurements,
                            showCheckIn: showCheckIn,
                            showSchedule: showSchedule,
                            showSupplements: showSupplements,
                            showWeights: showWeights,
                            showMeasurements: showMeasurements,
                            isExporting: false
                        )
                        .dynamicTypeSize(.medium)
                        .environment(\.sizeCategory, .medium)
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
    }

    @MainActor
    private func renderCurrentCard() -> UIImage? {
        let width: CGFloat = 540

        let renderView = WorkoutShareCard(
            accentColor: accentColor,
            checkInText: dailyCheckIn,
            schedule: schedule,
            supplements: supplements,
            takenIDs: takenSupplements,
            weights: weights,
            measurements: measurements,
            showCheckIn: showCheckIn,
            showSchedule: showSchedule,
            showSupplements: showSupplements,
            showWeights: showWeights,
            showMeasurements: showMeasurements,
            isExporting: true
        )
        .frame(width: width)
        .frame(maxHeight: 960)
        .dynamicTypeSize(.medium)
        .environment(\.sizeCategory, .medium)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    private func shareCurrentCard() {
        guard let image = renderCurrentCard() else { return }
        sharePayload = WorkoutSharePayload(items: [image])
    }
}

private struct WorkoutShareCard: View {
    var accentColor: Color
    var checkInText: String
    var schedule: [WorkoutScheduleSnapshot]
    var supplements: [Supplement]
    var takenIDs: Set<String>
    var weights: [WeightSnapshot]
    var measurements: BodyMeasurements

    var showCheckIn: Bool
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
            .background(accentColor.opacity(0.05))

            VStack(spacing: 18) {
                if showCheckIn {
                    WorkoutCheckInSection(text: checkInText)
                }

                if showSchedule && !schedule.isEmpty {
                    WorkoutScheduleSection(items: schedule)
                }

                if showSupplements && !supplements.isEmpty {
                    WorkoutSupplementsSection(supplements: supplements, takenIDs: takenIDs, color: .green)
                }

                if showWeights && !weights.isEmpty {
                    WorkoutWeightsSection(weights: weights, color: .orange)
                }

                if showMeasurements {
                    WorkoutMeasurementsSection(measurements: measurements, color: .pink)
                }
            }
            .padding(20)
        }
        .background {
            if isExporting {
                Color.clear
            } else {
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.74, green: 0.43, blue: 0.97).opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: max(0, geo.size.height * 0.4))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "TODAY'S SCHEDULE", icon: "calendar", color: .blue)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.prefix(6)) { it in
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
                    Divider()
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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

private struct WorkoutWeightsSection: View {
    var weights: [WeightSnapshot]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "WEIGHTS", icon: "scalemass", color: color)
            VStack(spacing: 6) {
                ForEach(weights.prefix(6)) { w in
                    HStack {
                        Text(w.date, format: .dateTime.month().day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Text(String(format: "%.1f kg", w.weightKg))
                            .font(.subheadline.weight(.semibold))
                        if let note = w.note {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
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

                VStack(alignment: .leading) {
                    Text("Water")
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

                VStack(alignment: .leading) {
                    Text("Fat")
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

                Spacer()
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
