import SwiftUI
import SwiftData

struct RecoveryEntrySheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var existingEntry: RecoveryEntry?
    var onSave: (RecoveryEntry) -> Void
    var onDelete: ((RecoveryEntry) -> Void)?
    
    @State private var selectedType: RecoveryType = .sauna
    @State private var durationString: String = "15"
    @State private var temperatureString: String = ""
    @State private var notes: String = ""
    
    init(existingEntry: RecoveryEntry? = nil, onSave: @escaping (RecoveryEntry) -> Void, onDelete: ((RecoveryEntry) -> Void)? = nil) {
        self.existingEntry = existingEntry
        self.onSave = onSave
        self.onDelete = onDelete
        
        if let entry = existingEntry {
            _selectedType = State(initialValue: entry.type)
            _durationString = State(initialValue: "\(entry.durationSeconds / 60)")
            _temperatureString = State(initialValue: entry.temperature.map { String(format: "%.0f", $0) } ?? "")
            _notes = State(initialValue: entry.notes ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Type Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recovery Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(RecoveryType.allCases, id: \.self) { recoveryType in
                                Button {
                                    withAnimation {
                                        selectedType = recoveryType
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: recoveryType.icon)
                                            .font(.title2)
                                        Text(recoveryType.rawValue)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .foregroundStyle(selectedType == recoveryType ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedType == recoveryType ? selectedType.color : Color.secondary.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedType == recoveryType ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Duration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            TextField("0", text: $durationString)
                                .font(.system(size: 32, weight: .bold))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.leading)
                                .frame(height: 50)
                            
                            Text("MIN")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .padding(.horizontal)

                    // Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        VStack(spacing: 16) {
                            HStack {
                                Text("Temperature")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("Optional", text: $temperatureString)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.body.weight(.medium))
                                Text("°")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("How did it feel?", text: $notes, axis: .vertical)
                                    .font(.body)
                                    .lineLimit(3...5)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    if existingEntry != nil {
                        Button(role: .destructive) {
                            if let entry = existingEntry {
                                onDelete?(entry)
                                dismiss()
                            }
                        } label: {
                            Text("Delete Entry")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(existingEntry == nil ? "Log Recovery" : "Edit Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let durationMin = Int(durationString) ?? 0
                        let durationSec = durationMin * 60
                        let tempVal = Double(temperatureString)
                        let newEntry = RecoveryEntry(
                            id: existingEntry?.id ?? UUID().uuidString,
                            type: selectedType,
                            durationSeconds: durationSec,
                            temperature: tempVal,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(newEntry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(durationString.isEmpty || Int(durationString) == nil)
                }
            }
        }
    }
}
