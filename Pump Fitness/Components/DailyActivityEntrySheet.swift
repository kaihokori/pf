import SwiftUI

struct DailyActivityEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var hkCalories: Double?
    var hkSteps: Double?
    var hkDistance: Double?
    
    var onSave: (_ activityType: String, _ isAddition: Bool, _ value: String) -> Void
    
    @State private var selectedActivity: ActivityMetric = .calories
    @State private var selectedOperation: ActivityOperation = .add
    @State private var inputValue: String = ""
    
    enum ActivityMetric: String, CaseIterable, Identifiable {
        case calories = "Calories"
        case steps = "Steps"
        case distance = "Distance"
        
        var id: String { rawValue }
        
        var systemImage: String {
            switch self {
            case .calories: return "flame.fill"
            case .steps: return "figure.walk"
            case .distance: return "point.bottomleft.forward.to.point.topright.filled.scurvepath"
            }
        }
        
        var unit: String {
            switch self {
            case .calories: return "cal"
            case .steps: return "steps"
            case .distance: return "m"
            }
        }
        
        var targetString: String {
            switch self {
            case .calories: return "calories"
            case .steps: return "steps"
            case .distance: return "walking"
            }
        }
    }
    
    enum ActivityOperation: String, CaseIterable, Identifiable {
        case add = "Add"
        case remove = "Remove"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Metric Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Metric")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            ForEach(ActivityMetric.allCases) { metric in
                                Button {
                                    withAnimation {
                                        selectedActivity = metric
                                        inputValue = ""
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: metric.systemImage)
                                            .font(.title2)
                                        Text(metric.rawValue)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(selectedActivity == metric ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedActivity == metric ? Color.accentColor : Color.secondary.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedActivity == metric ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
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
                            
                            Text(selectedActivity.unit)
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
                                        .background(selectedOperation == op ? Color.accentColor : Color.clear)
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
                    
                    // HealthKit Data Display
                    if let hkValue = currentHKValue {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HealthKit Data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(hkValue)) \(selectedActivity.unit)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Submit Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedActivity.targetString, selectedOperation == .add, inputValue)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(inputValue.isEmpty || Double(inputValue) == nil)
                }
            }
        }
    }
    
    private var currentHKValue: Double? {
        switch selectedActivity {
        case .calories: return hkCalories
        case .steps: return hkSteps
        case .distance: return hkDistance
        }
    }
}

#Preview {
    DailyActivityEntrySheet(
        hkCalories: 450,
        hkSteps: 3200,
        hkDistance: 2500,
        onSave: { _, _, _ in }
    )
    .tint(.blue)
}
