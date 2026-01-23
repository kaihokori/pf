import SwiftUI

struct SobrietyEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    
    var date: Date
    var metrics: [SobrietyMetric]
    var initialEntries: [SobrietyEntry] = []
    var onSave: ([SobrietyEntry]) -> Void
    
    // Local state to hold user choices (metricID -> isSober?)
    @State private var selections: [UUID: Bool] = [:]
    @State private var selectedMetricID: UUID?
    
    private var selectedMetric: SobrietyMetric? {
        metrics.first { $0.id == selectedMetricID }
    }
    
    private func metricColor(_ metric: SobrietyMetric) -> Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: metric.colorHex) ?? .accentColor
        } else {
            return themeManager.selectedTheme.accent(for: colorScheme)
        }
    }
    
    private func systemImage(for metric: SobrietyMetric) -> String {
        switch metric.type {
        case .alcohol: return "wineglass.fill"
        case .smoking: return "hand.raised.fill"
        case .custom: return "star.fill"
        }
    }
    
    private func statusLabels(for metric: SobrietyMetric) -> (success: String, failure: String) {
        switch metric.type {
        case .alcohol:
            return ("Stayed Sober", "Slipped Up")
        case .smoking:
            return ("Smoke Free", "Smoked")
        case .custom:
            return ("Goal Met", "Slipped Up")
        }
    }
    
    enum SobrietyStatus: String, CaseIterable, Identifiable {
        case sober
        case slipped
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Header
                    Text("Log for \(formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top)

                    // Metric Selection
                    if !metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Challenge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(metrics) { metric in
                                    Button {
                                        withAnimation {
                                            selectedMetricID = metric.id
                                        }
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: systemImage(for: metric))
                                                .font(.title2)
                                            Text(metric.displayName)
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
                                                .fill(selectedMetricID == metric.id ? metricColor(metric) : Color.secondary.opacity(0.1))
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
                        let labels = statusLabels(for: selected)
                        
                        // Current Status Section
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Log")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                if let isSober = selections[selected.id] {
                                    Text(isSober ? labels.success : labels.failure)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(isSober ? .green : .red)
                                } else {
                                     Text("Not Logged")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: systemImage(for: selected))
                                .font(.title)
                                .foregroundStyle(metricColor(selected).opacity(0.8))
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Update Status Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Update Log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 0) {
                                ForEach(SobrietyStatus.allCases) { status in
                                    let isSober = (status == .sober)
                                    let isSelected = selections[selected.id] == isSober
                                    let label = isSober ? labels.success : labels.failure
                                    
                                    Button {
                                        withAnimation {
                                            if isSelected {
                                                selections.removeValue(forKey: selected.id)
                                            } else {
                                                selections[selected.id] = isSober
                                            }
                                        }
                                    } label: {
                                        Text(label)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isSelected ? metricColor(selected) : Color.clear)
                                            .foregroundStyle(isSelected ? .white : .primary)
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
                        Text("No challenges active. Please add them in the Edit Sobriety sheet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Sobriety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if selectedMetricID == nil, let first = metrics.first {
                selectedMetricID = first.id
            }
            
            // Pre-fill selections from initialEntries
            for entry in initialEntries {
                if let isSober = entry.isSober {
                    selections[entry.metricID] = isSober
                }
            }
        }
    }
    
    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
    
    private func save() {
        let entries = selections.compactMap { (metricID, isSober) -> SobrietyEntry? in
            return SobrietyEntry(metricID: metricID, isSober: isSober, date: date)
        }
        onSave(entries)
        dismiss()
    }
}
