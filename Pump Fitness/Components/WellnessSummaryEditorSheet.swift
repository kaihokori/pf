import SwiftUI

struct WellnessSummaryEditorSheet: View {
    @Binding var metrics: [TrackedWellnessMetric]
    var tint: Color
    var isPro: Bool = true
    var onDone: () -> Void
    var onCancel: () -> Void

    @State private var workingMetrics: [TrackedWellnessMetric] = []
    @State private var hasLoadedState = false
    @State private var editingColorIndex: Int?
    
    private let healthKitService = HealthKitService()

    private var availableMetrics: [WellnessMetricType] {
        let trackedTypes = Set(workingMetrics.map { $0.type })
        return WellnessMetricType.allCases.filter { !trackedTypes.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Tracked Metrics
                    if !workingMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Wellness Metrics")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                ForEach(Array(workingMetrics.enumerated()), id: \.element.id) { idx, item in
                                    let binding = $workingMetrics[idx]
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            Button {
                                                editingColorIndex = idx
                                            } label: {
                                                Circle()
                                                    .fill(Color(hex: item.colorHex)?.opacity(0.15) ?? tint.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Image(systemName: item.type.systemImage)
                                                            .foregroundStyle(Color(hex: item.colorHex) ?? tint)
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.type.displayName)
                                                    .font(.subheadline.weight(.semibold))
                                                
                                                HStack(spacing: 4) {
                                                    Text("Goal:")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    TextField("Goal", value: binding.goal, format: .number)
                                                        .keyboardType(.decimalPad)
                                                        .font(.caption.weight(.medium))
                                                        .frame(width: 80)
                                                    
                                                    Text(item.unit)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer()

                                            Button(role: .destructive) {
                                                removeMetric(item.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }

                    // Quick Add
                    if !availableMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                ForEach(availableMetrics, id: \.self) { type in
                                    let typeColor = colorForType(type)
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(typeColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: type.systemImage)
                                                    .foregroundStyle(typeColor)
                                            )

                                        VStack(alignment: .leading) {
                                            Text(type.displayName)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(Int(type.defaultGoal)) \(type.unit)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { addMetric(type) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(typeColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(18)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Wellness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        metrics = workingMetrics
                        healthKitService.requestAuthorization(wellnessMetrics: metrics.map { $0.type }) { _ in
                            DispatchQueue.main.async {
                                onDone()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
        .sheet(isPresented: Binding<Bool>(
            get: { editingColorIndex != nil },
            set: { if !$0 { editingColorIndex = nil } }
        )) {
            if let idx = editingColorIndex {
                ColorPickerSheet(onSelect: { hex in
                    workingMetrics[idx].colorHex = hex
                    editingColorIndex = nil
                }, onCancel: {
                    editingColorIndex = nil
                })
                .presentationDetents([.fraction(0.4)])
            }
        }
    }

    private func loadInitialState() {
        guard !hasLoadedState else { return }
        workingMetrics = metrics
        hasLoadedState = true
    }

    private func removeMetric(_ id: UUID) {
        workingMetrics.removeAll { $0.id == id }
    }

    private func addMetric(_ type: WellnessMetricType) {
        let color = colorForType(type)
        let newMetric = TrackedWellnessMetric(
            type: type,
            goal: type.defaultGoal,
            colorHex: color.toHexString()
        )
        workingMetrics.append(newMetric)
    }
    
    private func colorForType(_ type: WellnessMetricType) -> Color {
        let defaults = ColorPalette.defaultColors
        let allCases = WellnessMetricType.allCases
        let index = (allCases.firstIndex(of: type) ?? 0) % defaults.count
        return Color(hex: defaults[index]) ?? .accentColor
    }
}
