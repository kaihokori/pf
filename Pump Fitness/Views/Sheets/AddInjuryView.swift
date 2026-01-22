import SwiftUI

struct AddInjuryView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var injuries: [Injury]
    var injuryToEdit: Injury?
    var selectedDate: Date = Date()
    var tint: Color = .blue
    var onSave: (() -> Void)?
    
    @State private var name: String = ""
    @State private var dos: String = ""
    @State private var donts: String = ""
    @State private var selectedPart: BodyPart = .chest // Default value
    
    // Calendar Config
    @State private var recoveryDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showYearPicker = false
    @State private var showMonthPicker = false
    @Namespace private var calendarAnim
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["M", "T", "W", "T", "F", "S", "S"]

    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case dos, donts
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Location Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Injury Location")
                            
                            // Body Diagram Visualization
                            BodyDiagramView(injuries: [previewInjury], selectedDate: selectedDate)
                                .frame(height: 200)
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
                            }
                        }

                        // Recovery Date Section
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("Expected Recovery Date")

                            VStack(spacing: 0) {
                                // Month/Year Picker logic
                                HStack {
                                    Button(action: {
                                        withAnimation(.easeInOut) {
                                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                    }
                                    .padding(.leading, 15)
                                    Spacer()
                                    Text(monthYearString(currentMonth))
                                        .font(.headline)
                                        .matchedGeometryEffect(id: "monthLabel", in: calendarAnim)
                                        .onTapGesture { withAnimation { showMonthPicker.toggle() } }
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.easeInOut) {
                                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding(.trailing, 15)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .padding(.top, 16)

                                if showYearPicker {
                                    // Year Picker
                                    let currentYear = calendar.component(.year, from: currentMonth)
                                    let years = (currentYear-50...currentYear+10).map { $0 }
                                    ScrollView {
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                            ForEach(years, id: \.self) { year in
                                                Button(action: {
                                                    var comps = calendar.dateComponents([.month, .day], from: currentMonth)
                                                    comps.year = year
                                                    if let newDate = calendar.date(from: comps) {
                                                        currentMonth = newDate
                                                    }
                                                    showYearPicker = false
                                                }) {
                                                    Text("\(year)")
                                                        .font(.body)
                                                        .frame(maxWidth: .infinity, minHeight: 32)
                                                        .background(calendar.component(.year, from: currentMonth) == year ? tint.opacity(0.2) : Color.clear)
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                    .frame(maxHeight: 340)
                                } else if showMonthPicker {
                                    // Month Picker
                                    let months = DateFormatter().monthSymbols ?? []
                                    ScrollView {
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                            ForEach(months.indices, id: \.self) { idx in
                                                Button(action: {
                                                    var comps = calendar.dateComponents([.year, .day], from: currentMonth)
                                                    comps.month = idx + 1
                                                    if let newDate = calendar.date(from: comps) {
                                                        currentMonth = newDate
                                                    }
                                                    showMonthPicker = false
                                                }) {
                                                    Text(months[idx])
                                                        .font(.body)
                                                        .frame(maxWidth: .infinity, minHeight: 32)
                                                        .background(calendar.component(.month, from: currentMonth) == idx + 1 ? tint.opacity(0.2) : Color.clear)
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                    .frame(maxHeight: 340)
                                } else {
                                    // Calendar Days
                                    HStack {
                                        ForEach(daysOfWeek, id: \.self) { dow in
                                            Text(dow)
                                                .font(.caption)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                    let days = daysInMonth(currentMonth)
                                    // Compute first weekday index with Monday as the first column.
                                    // Calendar.weekday: 1 = Sunday, 2 = Monday, ...
                                    // Map so Monday -> 0, Tuesday -> 1, ..., Sunday -> 6
                                    let firstWeekday = (calendar.component(.weekday, from: firstOfMonth(currentMonth)) + 5) % 7
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                        ForEach(0..<(days + firstWeekday), id: \.self) { i in
                                            if i < firstWeekday {
                                                Color.clear.frame(height: 32)
                                            } else {
                                                let dayNum = i - firstWeekday + 1
                                                let date = dateForDay(dayNum, in: currentMonth)
                                                Button(action: {
                                                    withAnimation(.easeInOut) {
                                                        recoveryDate = date
                                                    }
                                                }) {
                                                    Text("\(dayNum)")
                                                        .frame(maxWidth: .infinity, minHeight: 32)
                                                        .background(calendar.isDate(date, inSameDayAs: recoveryDate) ? tint.opacity(0.2) : Color.clear)
                                                        .clipShape(Circle())
                                                }
                                                .foregroundStyle(calendar.isDate(date, inSameDayAs: recoveryDate) ? tint : .primary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 16)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                            .padding(.vertical, 6)
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
                    // durationDays = Double(injury.durationDays)
                    if let date = Calendar.current.date(byAdding: .day, value: injury.durationDays, to: injury.dateOccurred) {
                        recoveryDate = date
                    }
                    dos = injury.dos
                    donts = injury.donts
                    if let part = injury.bodyPart {
                        selectedPart = part
                    }
                } else {
                    recoveryDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
                }
                currentMonth = recoveryDate
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
        let startDate = injuryToEdit?.dateOccurred ?? selectedDate
        let duration = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: recoveryDate)).day ?? 0
        return Injury(
            name: "Preview",
            dateOccurred: startDate,
            durationDays: max(0, duration),
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
        let startDate = injuryToEdit?.dateOccurred ?? selectedDate
        let duration = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: recoveryDate)).day ?? 0
        let finalDuration = max(0, duration)
        
        if let original = injuryToEdit, let index = injuries.firstIndex(where: { $0.id == original.id }) {
            // Update existing
            var updated = original
            updated.name = name
            updated.durationDays = finalDuration
            updated.dos = dos
            updated.donts = donts
            updated.bodyPart = selectedPart
            // We presumably don't update dateOccurred unless we add a field for it
            injuries[index] = updated
        } else {
            // Create new
            let injury = Injury(
                name: name,
                dateOccurred: startDate,
                durationDays: finalDuration,
                dos: dos,
                donts: donts,
                // Keep generic location as fallback if ever needed, but rely on bodyPart
                locationX: 0.5,
                locationY: 0.5,
                isFront: true, // Defaulting to true as we removed back toggle
                bodyPart: selectedPart
            )
            injuries.append(injury)
        onSave?()
        }
        dismiss()
    }

    // MARK: - Calendar Helpers
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth(_ date: Date) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }

    private func firstOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)!
    }

    private func dateForDay(_ day: Int, in date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = day
        return calendar.date(from: components)!
    }
}

private struct SimpleKeyboardDismissBar: View {
    var isVisible: Bool
    var tint: Color
    var onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            
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
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
