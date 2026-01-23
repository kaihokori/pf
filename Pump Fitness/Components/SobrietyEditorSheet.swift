import SwiftUI

struct SobrietyEditorSheet: View {
    @Binding var account: Account
    
    init(account: Binding<Account>) {
        self._account = account
    }

    @Environment(\.dismiss) private var dismiss
    
    // Working state
    @State private var workingMetrics: [SobrietyMetric] = []
    
    // Custom challenge creation
    @State private var newCustomName: String = ""
    
    // Color picking
    @State private var showColorPicker = false
    @State private var pickingColorForID: UUID?
    
    // Section header utility
    private struct SectionHeader: View {
        var title: String
        var body: some View {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }
    
    private var accountService = AccountFirestoreService()
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Tracked Challenges
                    if !trackedMetrics.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Tracked Challenges")
                            VStack(spacing: 12) {
                                ForEach(trackedMetrics) { metric in
                                    HStack(spacing: 12) {
                                        // Color Icon (Tappable)
                                        Button {
                                            pickingColorForID = metric.id
                                            showColorPicker = true
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: metric.colorHex) ?? .accentColor)
                                                .opacity(0.15)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "checkmark.shield.fill") // or better icon
                                                        .foregroundStyle(Color(hex: metric.colorHex) ?? .accentColor)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            if metric.type == .custom {
                                                TextField("Challenge Name", text: binding(for: metric).customName.bound)
                                                    .font(.subheadline.weight(.semibold))
                                            } else {
                                                Text(metric.displayName)
                                                    .font(.subheadline.weight(.semibold))
                                            }
                                            
                                            Text(metric.type == .alcohol || metric.type == .smoking ? "Standard Challenge" : "Custom Goal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(role: .destructive) {
                                            disableMetric(metric.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .surfaceCard(12)
                                }
                            }
                        }
                    }
                    
                    // Quick Add Presets (Alcohol & Smoking)
                    if !availablePresets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(availablePresets, id: \.self) { type in
                                    HStack(spacing: 14) {
                                        // Preview color for preset
                                        let presetColorHex: String = {
                                            switch type {
                                            case .alcohol: return "#AF52DE"
                                            case .smoking: return "#007AFF"
                                            default: return "#32ADE6"
                                            }
                                        }()
                                        let presetColor = Color(hex: presetColorHex) ?? .blue
                                        
                                        Circle()
                                            .fill(presetColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "checkmark.shield.fill")
                                                    .foregroundStyle(presetColor)
                                            )
                                        
                                        VStack(alignment: .leading) {
                                            Text(type.rawValue)
                                                .font(.subheadline.weight(.semibold))
                                            Text("Standard Challenge")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            enablePreset(type)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }
                    
                    // Custom Challenge
                    // Limit to adding one custom challenge: checking if we already have an enabled custom challenge
                    if !hasActiveCustomChallenge {
                        VStack(alignment: .leading, spacing: 12) {
                             SectionHeader(title: "Custom Challenge")
                             VStack(spacing: 12) {
                                 HStack(spacing: 12) {
                                     TextField("Challenge Name (e.g. Gambling)", text: $newCustomName)
                                         .padding()
                                         .surfaceCard(16)
                                     
                                     Button {
                                         addCustomMetric()
                                     } label: {
                                         Image(systemName: "plus.circle.fill")
                                             .font(.system(size: 28, weight: .semibold))
                                             .foregroundStyle(Color.accentColor)
                                     }
                                     .buttonStyle(.plain)
                                     .disabled(newCustomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                     .opacity(newCustomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                                 }
                             }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Addiction Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet { hex in
                    if let id = pickingColorForID, let idx = workingMetrics.firstIndex(where: { $0.id == id }) {
                        workingMetrics[idx].colorHex = hex
                    }
                    showColorPicker = false
                } onCancel: {
                    showColorPicker = false
                }
                .presentationDetents([.height(180)])
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var trackedMetrics: [SobrietyMetric] {
        workingMetrics.filter { $0.isEnabled }
    }
    
    var availablePresets: [SobrietyType] {
        // Only fixed types
        [.alcohol, .smoking].filter { type in
            !workingMetrics.contains { $0.type == type && $0.isEnabled }
        }
    }
    
    var hasActiveCustomChallenge: Bool {
        workingMetrics.contains { $0.type == .custom && $0.isEnabled }
    }
    
    // MARK: - Logic
    
    private func binding(for metric: SobrietyMetric) -> Binding<SobrietyMetric> {
        guard let idx = workingMetrics.firstIndex(where: { $0.id == metric.id }) else {
            // Should not happen if iteration is correct, but safe fallback
            return .constant(metric)
        }
        return $workingMetrics[idx]
    }
    
    private func loadSettings() {
        if workingMetrics.isEmpty {
            workingMetrics = account.sobrietyMetrics
        }
    }
    
    private func save() {
        account.sobrietyMetrics = workingMetrics
        accountService.saveAccount(account) { _ in }
        dismiss()
    }
    
    private func disableMetric(_ id: UUID) {
        if let idx = workingMetrics.firstIndex(where: { $0.id == id }) {
            workingMetrics[idx].isEnabled = false
            // Note: We keep it in the array but disabled to preserve history unless user wants to delete?
            // "Remove" in UI usually implies disabling for now.
        }
    }
    
    private func enablePreset(_ type: SobrietyType) {
        // Check if we already have this metric (disabled)
        if let idx = workingMetrics.firstIndex(where: { $0.type == type }) {
            workingMetrics[idx].isEnabled = true
        } else {
            // Create new
            let new = SobrietyMetric(type: type, isEnabled: true)
            workingMetrics.append(new)
        }
    }
    
    private func addCustomMetric() {
        let trimmed = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let new = SobrietyMetric(type: .custom, customName: trimmed, isEnabled: true)
        workingMetrics.append(new)
        newCustomName = ""
    }
}

// Helper for Optional String Binding
extension Binding where Value == String? {
    var bound: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0 }
        )
    }
}
