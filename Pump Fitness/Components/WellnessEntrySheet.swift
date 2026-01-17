import SwiftUI

struct WellnessEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var metrics: [TrackedWellnessMetric]
    var hkValues: [WellnessMetricType: Double]
    
    var onSave: (_ metricType: WellnessMetricType, _ isAddition: Bool, _ value: String) -> Void
    
    @State private var selectedMetricID: UUID?
    @State private var selectedOperation: ActivityOperation = .add
    @State private var inputValue: String = ""
    
    private var selectedMetric: TrackedWellnessMetric? {
        metrics.first { $0.id == selectedMetricID }
    }
    
    private func formattedValue(_ val: Double, for type: WellnessMetricType) -> String {
        switch type {
        case .oxygenSaturation, .bloodAlcohol:
             // Assuming val is 0.0-1.0 from HK percent units, we show percent
             return String(format: "%.1f", val * 100)
        case .uvIndex, .heartRate, .sexualActivity:
            return "\(Int(val))"
        default:
            return String(format: "%.1f", val)
        }
    }
    
    enum ActivityOperation: String, CaseIterable, Identifiable {
        case add = "Add" // Or "Auto-Fill" / "Log"
        case remove = "Remove"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Metric Selection
                    if !metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Metric")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(metrics) { metric in
                                    Button {
                                        withAnimation {
                                            selectedMetricID = metric.id
                                            inputValue = ""
                                        }
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: metric.type.systemImage)
                                                .font(.title2)
                                            Text(metric.type.displayName)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .foregroundStyle(selectedMetricID == metric.id ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedMetricID == metric.id ? (Color(hex: metric.colorHex) ?? .accentColor) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(selectedMetricID == metric.id ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if let selected = selectedMetric {
                        // Current Status Section
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current HealthKit Value")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                if let hkVal = hkValues[selected.type] {
                                    Text("\(formattedValue(hkVal, for: selected.type)) \(selected.unit)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                } else {
                                     Text("-- \(selected.unit)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Input Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Enter Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 12) {
                                TextField("0", text: $inputValue)
                                    .font(.system(size: 32, weight: .bold))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .frame(height: 50)
                                
                                Text(selected.unit)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                            
                            // Operation Toggle
                            HStack(spacing: 0) {
                                ForEach(ActivityOperation.allCases) { op in
                                    Button {
                                        withAnimation {
                                            selectedOperation = op
                                        }
                                    } label: {
                                        Text(op.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selectedOperation == op ? (Color(hex: selected.colorHex) ?? .accentColor) : Color.clear)
                                            .foregroundStyle(selectedOperation == op ? .white : .primary)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        
                    } else {
                        Text("No metrics available. Please add metrics in the Edit Wellness sheet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Submit Wellness Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let selected = selectedMetric {
                            onSave(selected.type, selectedOperation == .add, inputValue)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedMetric == nil || inputValue.isEmpty || Double(inputValue) == nil)
                }
            }
        }
        .onAppear {
            if selectedMetricID == nil, let first = metrics.first {
                selectedMetricID = first.id
            }
        }
    }
}
