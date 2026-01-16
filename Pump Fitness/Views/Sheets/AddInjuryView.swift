import SwiftUI

struct AddInjuryView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var injuries: [Injury]
    var injuryToEdit: Injury?
    var tint: Color = .blue
    
    @State private var name: String = ""
    @State private var durationDays: Double = 7
    @State private var dos: String = ""
    @State private var donts: String = ""
    @State private var selectedPart: BodyPart = .chest // Default value
    
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case dos, donts
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Location Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Injury Location")
                            
                            // Body Diagram Visualization
                            BodyDiagramView(injuries: [previewInjury], selectedDate: Date())
                                .frame(height: 300)
                                .padding()
                                .surfaceCard(24, shadowOpacity: 0.1)
                            
                            // Body Part Selector (grouped menu)
                            HStack {
                                Text("Body Part")
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Menu {
                                    // Group: Head & Neck
                                    Group {
                                        Text("Head & Neck")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Divider()
                                        Button("Head") { selectedPart = .head }
                                        Button("Neck") { selectedPart = .neck }
                                    }

                                    // Group: Torso
                                    Group {
                                        Divider()
                                        Text("Torso")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Chest") { selectedPart = .chest }
                                        Button("Abdomen") { selectedPart = .abdomen }
                                        Button("Upper Back") { selectedPart = .upperBack }
                                        Button("Lower Back") { selectedPart = .lowerBack }
                                        Button("Hips") { selectedPart = .hips }
                                    }

                                    // Group: Shoulders & Arms
                                    Group {
                                        Divider()
                                        Text("Shoulders & Arms")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Left Shoulder") { selectedPart = .leftShoulder }
                                        Button("Right Shoulder") { selectedPart = .rightShoulder }
                                        Button("Left Upper Arm") { selectedPart = .leftUpperArm }
                                        Button("Right Upper Arm") { selectedPart = .rightUpperArm }
                                        Button("Left Forearm") { selectedPart = .leftForearm }
                                        Button("Right Forearm") { selectedPart = .rightForearm }
                                        Button("Left Hand") { selectedPart = .leftHand }
                                        Button("Right Hand") { selectedPart = .rightHand }
                                    }

                                    // Group: Hips, Glutes & Hamstrings
                                    Group {
                                        Divider()
                                        Text("Hips & Glutes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Left Glute") { selectedPart = .leftGlute }
                                        Button("Right Glute") { selectedPart = .rightGlute }
                                        Button("Left Hamstring") { selectedPart = .leftHamstring }
                                        Button("Right Hamstring") { selectedPart = .rightHamstring }
                                    }

                                    // Group: Legs & Feet
                                    Group {
                                        Divider()
                                        Text("Legs & Feet")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Left Thigh") { selectedPart = .leftThigh }
                                        Button("Right Thigh") { selectedPart = .rightThigh }
                                        Button("Left Shin") { selectedPart = .leftShin }
                                        Button("Right Shin") { selectedPart = .rightShin }
                                        Button("Left Calf") { selectedPart = .leftCalf }
                                        Button("Right Calf") { selectedPart = .rightCalf }
                                        Button("Left Foot") { selectedPart = .leftFoot }
                                        Button("Right Foot") { selectedPart = .rightFoot }
                                    }

                                    // Group: Misc / Back Muscles
                                    Group {
                                        Divider()
                                        Text("Back Muscles")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Button("Trapezius") { selectedPart = .trapezius }
                                        Button("Lats") { selectedPart = .lats }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(selectedPart.displayName)
                                            .foregroundStyle(.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                            .surfaceCard(16)
                        }

                        // Details Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Details")
                            
                            VStack(spacing: 12) {
                                TextField("Injury Name (e.g. Sprained Ankle)", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .surfaceCard(16)
                                
                                // Duration Slider
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Estimated Recovery")
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(Int(durationDays)) days")
                                            .font(.subheadline)
                                            .foregroundStyle(tint)
                                            .bold()
                                    }
                                    
                                    Slider(value: $durationDays, in: 1...60, step: 1)
                                        .tint(tint)
                                }
                                .padding()
                                .surfaceCard(16)
                            }
                        }
                        
                        // Recovery Guide Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Recovery Guide")
                            
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What can you do?")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    TextField("e.g. Light Walking", text: $dos, axis: .vertical)
                                        .focused($focusedField, equals: .dos)
                                        .lineLimit(2...4)
                                        .padding()
                                        .surfaceCard(16)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What should you avoid?")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    TextField("e.g. High Impact Running", text: $donts, axis: .vertical)
                                        .focused($focusedField, equals: .donts)
                                        .lineLimit(2...4)
                                        .padding()
                                        .surfaceCard(16)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                
                SimpleKeyboardDismissBar(
                    isVisible: focusedField != nil,
                    tint: tint,
                    onDismiss: { focusedField = nil }
                )
            }
            .navigationTitle(injuryToEdit == nil ? "Log Injury" : "Edit Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInjury()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSubmit ? tint : Color.gray)
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                if let injury = injuryToEdit {
                    name = injury.name
                    durationDays = Double(injury.durationDays)
                    dos = injury.dos
                    donts = injury.donts
                    if let part = injury.bodyPart {
                        selectedPart = part
                    }
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
    
    var previewInjury: Injury {
        Injury(
            name: "Preview",
            dateOccurred: Date(), // Preview assuming today so intensity reflects duration
            durationDays: Int(durationDays),
            dos: "",
            donts: "",
            locationX: 0,
            locationY: 0,
            isFront: true,
            bodyPart: selectedPart
        )
    }
    
    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func saveInjury() {
        if let original = injuryToEdit, let index = injuries.firstIndex(where: { $0.id == original.id }) {
            // Update existing
            var updated = original
            updated.name = name
            updated.durationDays = Int(durationDays)
            updated.dos = dos
            updated.donts = donts
            updated.bodyPart = selectedPart
            // We presumably don't update dateOccurred unless we add a field for it
            injuries[index] = updated
        } else {
            // Create new
            let injury = Injury(
                name: name,
                dateOccurred: Date(),
                durationDays: Int(durationDays),
                dos: dos,
                donts: donts,
                // Keep generic location as fallback if ever needed, but rely on bodyPart
                locationX: 0.5,
                locationY: 0.5,
                isFront: true, // Defaulting to true as we removed back toggle
                bodyPart: selectedPart
            )
            injuries.append(injury)
        }
        dismiss()
    }
}

private struct SimpleKeyboardDismissBar: View {
    var isVisible: Bool
    var tint: Color
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if isVisible {
                HStack {
                    Spacer()

                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "keyboard.chevron.compact.down")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                            .foregroundStyle(tint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
