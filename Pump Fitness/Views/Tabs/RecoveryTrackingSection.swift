import SwiftUI
import Charts
import Combine

import SwiftData

// MARK: - View

struct RecoveryTrackingSection: View {
    var date: Date
    var accentColorOverride: Color?
    private var tint: Color { accentColorOverride ?? .accentColor }
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    
    @Query private var days: [Day]
    private var day: Day? { days.first }
    
    @State private var visibleCategories: Set<RecoveryCategory> = []
    @State private var showEditSheet = false
    
    // Keyboard / Overlay state passed from parent
    @Binding var isKeyboardVisible: Bool
    @Binding var keyboardUnit: String
    @Binding var onUnitChange: ((String) -> Void)?
    @Binding var onDismiss: (() -> Void)?
    
    @Binding var isSimpleKeyboardVisible: Bool
    @Binding var onSimpleDismiss: (() -> Void)?
    
    init(
        date: Date,
        accentColorOverride: Color? = nil,
        isKeyboardVisible: Binding<Bool> = .constant(false),
        keyboardUnit: Binding<String> = .constant("°F"),
        onUnitChange: Binding<((String) -> Void)?> = .constant(nil),
        onDismiss: Binding<(() -> Void)?> = .constant(nil),
        isSimpleKeyboardVisible: Binding<Bool> = .constant(false),
        onSimpleDismiss: Binding<(() -> Void)?> = .constant(nil)
    ) {
        self.date = date
        self.accentColorOverride = accentColorOverride
        _isKeyboardVisible = isKeyboardVisible
        _keyboardUnit = keyboardUnit
        _onUnitChange = onUnitChange
        _onDismiss = onDismiss
        _isSimpleKeyboardVisible = isSimpleKeyboardVisible
        _onSimpleDismiss = onSimpleDismiss
        
        let localCal = Calendar.current
        let components = localCal.dateComponents([.year, .month, .day], from: date)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let dayStart = utcCal.date(from: components) ?? utcCal.startOfDay(for: date)
        
        _days = Query(filter: #Predicate<Day> { $0.date == dayStart })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recovery Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 48)
            
            if visibleCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No Recovery Categories", systemImage: "figure.walk.motion")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tap Edit to add recovery tracking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal)
            } else {
                ForEach(RecoveryCategory.allCases.filter { visibleCategories.contains($0) }) { category in
                    let catSessions = (day?.recoverySessions ?? []).filter { $0.category == category }
                    let sectionTint: Color = (themeManager.selectedTheme == .multiColour) ? colorFor(category) : tint

                    VStack(spacing: 12) {
                        RecoveryCategoryCard(
                            category: category,
                            tint: sectionTint,
                            isKeyboardVisible: $isKeyboardVisible,
                            keyboardUnit: $keyboardUnit,
                            onUnitChange: $onUnitChange,
                            onDismiss: $onDismiss,
                            isSimpleKeyboardVisible: $isSimpleKeyboardVisible,
                            onSimpleDismiss: $onSimpleDismiss,
                            onSave: saveSession
                        )

                        if !catSessions.isEmpty {
                            RecoverySummarySection(
                                category: category,
                                sessions: catSessions,
                                tint: sectionTint,
                                onDelete: deleteSession
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear(perform: loadData)
        .sheet(isPresented: $showEditSheet) {
            RecoveryEditSheet(visibleCategories: $visibleCategories, tint: tint) {
                saveSettings()
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private func loadData() {
        let saved = account.recoveryCategories.compactMap { RecoveryCategory(rawValue: $0) }
        if saved.isEmpty {
            // Default only if list was never set (empty list might be intentional but let's assume default for now if none found)
            if account.recoveryCategories.isEmpty {
                 visibleCategories = [.sauna, .coldPlunge, .spa]
            } else {
                 visibleCategories = []
            }
        } else {
            visibleCategories = Set(saved)
        }
    }
    
    private func saveSettings() {
        account.recoveryCategories = Array(visibleCategories).map { $0.rawValue }
        AccountFirestoreService().saveAccount(account) { _ in }
    }
    
    private func saveSession(_ session: RecoverySession) {
        let targetDay: Day
        if let d = day {
            targetDay = d
        } else {
            targetDay = Day.fetchOrCreate(for: date, in: modelContext)
        }
        
        targetDay.recoverySessions.append(session)
        DayFirestoreService().saveDay(targetDay) { _ in }
    }
    
    private func deleteSession(_ id: UUID) {
        guard let targetDay = day else { return }
        if let index = targetDay.recoverySessions.firstIndex(where: { $0.id == id }) {
            targetDay.recoverySessions.remove(at: index)
            DayFirestoreService().saveDay(targetDay) { _ in }
        }
    }

    private func colorFor(_ category: RecoveryCategory) -> Color {
        switch category {
        case .sauna:
            // Warm red-orange
            return Color(red: 1.0, green: 0.35, blue: 0.20)
        case .coldPlunge:
            // Ice blue
            return Color(red: 0.0, green: 0.72, blue: 0.92)
        case .spa:
            // Orange-yellow
            return Color(red: 1.0, green: 0.80, blue: 0.20)
        }
    }
}

// MARK: - Subviews

fileprivate struct RecoveryEditSheet: View {
    @Binding var visibleCategories: Set<RecoveryCategory>
    var tint: Color
    var onDone: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var workingCategories: Set<RecoveryCategory> = []
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tracked Categories
                    if !workingCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            RecoveryEditSectionHeader(title: "Tracked Recovery")
                            
                            VStack(spacing: 12) {
                                ForEach(RecoveryCategory.allCases.filter { workingCategories.contains($0) }) { category in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(tint.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: category.icon)
                                                    .foregroundStyle(tint)
                                            )
                                        
                                        Text(category.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                        
                                        Spacer()
                                        
                                        Button(role: .destructive) {
                                            _ = workingCategories.remove(category)
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
                    
                    // Quick Add
                    let available = RecoveryCategory.allCases.filter { !workingCategories.contains($0) }
                    if !available.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            RecoveryEditSectionHeader(title: "Quick Add")
                            
                            VStack(spacing: 12) {
                                ForEach(available) { category in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(tint.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: category.icon)
                                                    .foregroundStyle(tint)
                                            )
                                        
                                        Text(category.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            _ = workingCategories.insert(category)
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(tint)
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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        visibleCategories = workingCategories
                        onDone()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            workingCategories = visibleCategories
        }
    }
}

fileprivate struct RecoveryEditSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

fileprivate struct RecoveryCategoryCard: View {
    let category: RecoveryCategory
    let tint: Color
    @Binding var isKeyboardVisible: Bool
    @Binding var keyboardUnit: String
    @Binding var onUnitChange: ((String) -> Void)?
    @Binding var onDismiss: (() -> Void)?
    @Binding var isSimpleKeyboardVisible: Bool
    @Binding var onSimpleDismiss: (() -> Void)?
    let onSave: (RecoverySession) -> Void
    
    // Inputs (Defaults)
    @State private var tempString: String = "180" // Default F
    @State private var tempUnit: String = "°F"
    @FocusState private var isTempFocused: Bool
    @FocusState private var isHrStartFocused: Bool
    @FocusState private var isHrEndFocused: Bool
    @State private var durationMinutes: Double = 15
    @State private var hydrationMinutes: Double = 5
    
    @State private var startHrString: String = ""
    @State private var endHrString: String = ""
    @State private var selectedSaunaType: SaunaType = .dry
    @State private var selectedPlungeType: ColdPlungeType = .iceBath
    @State private var selectedSpaType: SpaType = .massage
    @State private var selectedBodyPart: SpaBodyPart = .fullBody
    @State private var customType: String = ""
    @State private var showExplainer = false
    
    @AppStorage("alerts.recoveryTimersEnabled") private var recoveryTimersAlertsEnabled: Bool = true
    
    // Active State
    @State private var isRunning = false
    @State private var activeSessionId = UUID()
    @State private var timeRemaining: TimeInterval = 0
    @State private var hydrationTimeRemaining: TimeInterval = 0
    @State private var startDate: Date?
    
    // Timer
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var isTimerBased: Bool {
        return category == .sauna || category == .coldPlunge
    }

    private var isCustomSelected: Bool {
        switch category {
        case .sauna: return selectedSaunaType == .custom
        case .coldPlunge: return selectedPlungeType == .custom
        case .spa: return selectedSpaType == .custom
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(tint.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
            }
            .padding(16)
            
            configView
            
            if isTimerBased {
                timerActionArea
            } else {
                Button(action: startOrLog) {
                    HStack {
                        Text(category == .spa ? "Log Session" : "Start Timer")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }

            if category != .spa {
                Button(action: { showExplainer = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Tap for Explanation and Source")
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding([.leading, .bottom], 12)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal)
        .onChange(of: isTempFocused) { _, focused in
            if focused {
                keyboardUnit = tempUnit
                onDismiss = { isTempFocused = false }
                onUnitChange = { unit in
                    if unit != tempUnit {
                         if let val = Double(tempString) {
                             let converted = unit == "°F" ? (val * 9/5 + 32) : ((val - 32) * 5/9)
                             tempString = String(format: "%.0f", converted)
                         }
                        tempUnit = unit
                        keyboardUnit = unit
                    }
                }
                isKeyboardVisible = true
            } else {
                // When focus is lost, we delay briefly to allow focus to transfer
                // to another field if applicable, or for the parent to handle dismissal logic.
                // However, simplistic "turn off" works if no other field grabbed it.
                // But we don't want to turn it off if we just swapped units.
                // The parent manages visibility via bindings.
                // We'll trust the parent or just let it stay until dismissed by "Done" or scroll?
                // Actually, standard keyboard behavior is it stays until dismissed.
                // But here we might want to hide it if we tapped outside.
                // We can set isKeyboardVisible = false here immediately.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                     if !isTempFocused && isKeyboardVisible {
                         // Check if another field took over?
                         // We can't easily check global focus.
                         // But if we just became unfocused, we can signal visibility off.
                         // The issue is if we tap from one field to another in a different card.
                         // We shouldn't hide it.
                         // For now, let's behave reactively.
                         isKeyboardVisible = false
                     }
                }
            }
        }
        .onChange(of: isHrStartFocused) { _, focused in
            if focused {
                onSimpleDismiss = { isHrStartFocused = false }
                isSimpleKeyboardVisible = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !isHrStartFocused && !isHrEndFocused && isSimpleKeyboardVisible {
                        isSimpleKeyboardVisible = false
                    }
                }
            }
        }
        .onChange(of: isHrEndFocused) { _, focused in
            if focused {
                onSimpleDismiss = { isHrEndFocused = false }
                isSimpleKeyboardVisible = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !isHrStartFocused && !isHrEndFocused && isSimpleKeyboardVisible {
                        isSimpleKeyboardVisible = false
                    }
                }
            }
        }
        .sheet(isPresented: $showExplainer) {
            NavigationStack {
                if category == .sauna {
                    RecoveryCardioExplainer()
                        .navigationTitle("Recovery Cardio Benefits")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showExplainer = false
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                } else {
                    RecoveryMetabolicExplainer()
                        .navigationTitle("Recovery Metabolic Benefits")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showExplainer = false
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: recoveryTimersAlertsEnabled) { _, enabled in
            if isRunning, let start = startDate {
                if enabled {
                    let endDate = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
                    if endDate > Date() {
                        NotificationsHelper.scheduleRecoveryTimerNotification(id: activeSessionId.uuidString, category: category.rawValue, endDate: endDate)
                    }
                } else {
                    NotificationsHelper.removeRecoveryTimerNotification(id: activeSessionId.uuidString)
                }
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                finishSession()
            }
            
            if category == .sauna {
                if hydrationTimeRemaining > 0 {
                    hydrationTimeRemaining -= 1
                } else {
                    hydrationTimeRemaining = hydrationMinutes * 60 
                }
            }
        }
    }
    
    // MARK: - Configuration View
    private var configView: some View {
        VStack(spacing: 20) {
            // Type Selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    typeSelectionContent
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            
            if isCustomSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CUSTOM TYPE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter description", text: $customType)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
            }
            
            // Input Fields
            VStack(spacing: 16) {
                if category == .sauna || category == .coldPlunge {
                    HStack(spacing: 16) {
                        // Temp Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TEMP (\(tempUnit))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            TextField("0", text: $tempString)
                                .focused($isTempFocused)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(height: 44)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // HR Start Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HR (START)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            TextField("--", text: $startHrString)
                                .focused($isHrStartFocused)
                                .keyboardType(.numberPad)
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(height: 44)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Duration Input for Sauna/Cold Plunge
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TIMER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("\(Int(durationMinutes))")
                                .font(.system(size: 20, weight: .semibold))
                            Text("min")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Stepper("", value: $durationMinutes, in: 1...20, step: 1)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // Duration Input for Spa
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DURATION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("\(Int(durationMinutes))")
                                .font(.system(size: 20, weight: .semibold))
                            Text("min")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Stepper("", value: $durationMinutes, in: 1...360, step: 5)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Secondary Options (Hydration / Body Part)
            if category == .sauna {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HYDRATION REMINDER")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Every \(Int(hydrationMinutes)) min")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Stepper("", value: $hydrationMinutes, in: 1...60, step: 1)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
            }
            
            if category == .spa {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BODY PART")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Menu {
                        ForEach(SpaBodyPart.allCases) { part in
                            Button(part.rawValue) { selectedBodyPart = part }
                        }
                    } label: {
                        HStack {
                            Text(selectedBodyPart.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
                
                BodyDiagramView(injuries: [], highlightedParts: selectedBodyPart.mappedBodyParts)
                    .frame(height: 150)
                    .padding(.vertical, 8)
            }
            
            
            // Action Button Removed (Moved to body)

        }
    }
    
    @ViewBuilder
    private var typeSelectionContent: some View {
        switch category {
        case .sauna:
            selectablePillGroup(items: SaunaType.allCases, selection: $selectedSaunaType)
        case .coldPlunge:
            selectablePillGroup(items: ColdPlungeType.allCases, selection: $selectedPlungeType)
        case .spa:
            selectablePillGroup(items: SpaType.allCases, selection: $selectedSpaType)
        }
    }
    
    private func selectablePillGroup<T: Identifiable & Equatable & RawRepresentable>(items: [T], selection: Binding<T>) -> some View where T.RawValue == String {
        ForEach(items) { item in
            Button {
                selection.wrappedValue = item
            } label: {
                Text(item.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(selection.wrappedValue == item ? tint : Color.clear)
                    .foregroundStyle(selection.wrappedValue == item ? .white : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(selection.wrappedValue == item ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var totalDuration: TimeInterval {
        max(1, durationMinutes * 60)
    }

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let current = isRunning ? timeRemaining : totalDuration
        return 1.0 - (current / totalDuration)
    }

    private var timerActionArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 24) {
                // Circle Timer
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.15), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: isRunning ? (1.0 - (timeRemaining / totalDuration)) : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timeRemaining)
                    
                    VStack(spacing: 2) {
                        Text(isRunning ? "Remaining" : "Duration")
                            .font(.system(size: 10, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        
                        Text(timeString(from: isRunning ? timeRemaining : totalDuration))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 84, height: 84)
                
                // Controls
                VStack(spacing: 0) {
                    if isRunning {
                        runningControls
                    } else {
                        idleControls
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 84) 
            }
            .padding(20)
        }
    }
    
    private var runningControls: some View {
        VStack(spacing: 12) {
            // Metrics Row
            HStack {
                if category == .sauna {
                     HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                        Text(timeString(from: hydrationTimeRemaining))
                            .monospacedDigit()
                     }
                     .font(.caption.weight(.medium))
                     .foregroundStyle(.blue)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 4)
                     .background(Color.blue.opacity(0.1))
                     .clipShape(Capsule())
                } else {
                    Spacer()
                }
                
                if category == .sauna { Spacer() }
                
                HStack(spacing: 6) {
                    Text("HR (END)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("--", text: $endHrString)
                        .focused($isHrEndFocused)
                        .keyboardType(.numberPad)
                        .font(.callout.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 24)
            
            // Buttons Row
            HStack(spacing: 10) {
                Button(action: stopSession) {
                    Text("Cancel")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: finishSession) {
                    Text("Finish")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(height: 38)
        }
    }
    
    private var idleControls: some View {
        Button(action: startOrLog) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.subheadline)
                Text("Start Timer")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.vertical, 14) // Center vertically in the 84 height
    }
    
    // MARK: - Logic
    
    private func startOrLog() {
        if category == .spa {
            let session = RecoverySession(
                date: Date(),
                category: .spa,
                durationSeconds: durationMinutes * 60,
                saunaType: nil,
                coldPlungeType: nil,
                spaType: selectedSpaType,
                temperature: nil,
                hydrationTimerSeconds: nil,
                heartRateBefore: nil,
                heartRateAfter: nil,
                bodyPart: selectedBodyPart,
                customType: (isCustomSelected && !customType.isEmpty) ? customType : nil
            )
            onSave(session)
        } else {
            let duration = durationMinutes * 60
            timeRemaining = duration
            hydrationTimeRemaining = hydrationMinutes * 60
            isRunning = true
            startDate = Date()
            activeSessionId = UUID()
            
            if recoveryTimersAlertsEnabled {
                let endDate = Date().addingTimeInterval(duration)
                NotificationsHelper.scheduleRecoveryTimerNotification(id: activeSessionId.uuidString, category: category.rawValue, endDate: endDate)
            }
        }
    }
    
    private func stopSession() {
        NotificationsHelper.removeRecoveryTimerNotification(id: activeSessionId.uuidString)
        isRunning = false
    }
    
    private func finishSession() {
        NotificationsHelper.removeRecoveryTimerNotification(id: activeSessionId.uuidString)
        isRunning = false
        // Calculate based on configured, since we don't track elapsed if cancelled/early finish simply
        let duration = durationMinutes * 60 
        
        var temp: Double?
        if let t = Double(tempString) { temp = t }
        
        let hrBefore = Int(startHrString)
        let hrAfter = Int(endHrString)
        
        let session = RecoverySession(
            date: Date(),
            category: category,
            durationSeconds: duration,
            saunaType: category == .sauna ? selectedSaunaType : nil,
            coldPlungeType: category == .coldPlunge ? selectedPlungeType : nil,
            spaType: nil,
            temperature: temp,
            hydrationTimerSeconds: category == .sauna ? hydrationMinutes * 60 : nil,
            heartRateBefore: hrBefore,
            heartRateAfter: hrAfter,
            bodyPart: nil,
            customType: (isCustomSelected && !customType.isEmpty) ? customType : nil
        )
        onSave(session)
        
        // Reset Inputs
        endHrString = ""
        startHrString = ""
        // Keep temp and other settings as they likely don't change often
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}





fileprivate struct RecoverySummarySection: View {
    let category: RecoveryCategory
    let sessions: [RecoverySession]
    let tint: Color
    let onDelete: (UUID) -> Void
    
    @State private var showWeekly: Bool = false
    
    private var last7Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Show last 7 days ending today
        return (0..<7).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Collapsible Header
            HStack {
                Spacer()
                Label("\(category.rawValue) Summary", systemImage: category.icon)
                    .font(.callout.weight(.semibold))
                Image(systemName: showWeekly ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showWeekly.toggle()
                }
            }

            if showWeekly {
                VStack(spacing: 24) {
                    // Start of Graph
                    Chart {
                        ForEach(last7Days, id: \.self) { day in
                            let dailyTotal = sessions
                                .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                                .reduce(0) { $0 + $1.durationSeconds }
                            
                            BarMark(
                                x: .value("Day", DateFormatter.shortDate.string(from: day)),
                                y: .value("Minutes", dailyTotal / 60)
                            )
                            .foregroundStyle(tint.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        let labels = last7Days.map { DateFormatter.shortDate.string(from: $0) }
                        AxisMarks(values: labels) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 150)
                    
                    // Detail List
                    VStack(spacing: 0) {
                        let daysWithSessions = last7Days.reversed().filter { day in
                            sessions.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
                        }

                        ForEach(daysWithSessions, id: \.self) { day in
                            let daySessions = sessions
                                .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                                .sorted { $0.date > $1.date }

                            Section(header:
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(DateFormatter.weekdayFull.string(from: day))
                                            .font(.subheadline.weight(.semibold))
                                        Text(DateFormatter.longDate.string(from: day))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(daySessions.reduce(0) { $0 + $1.durationSeconds } / 60)) min")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.vertical, 8)
                            ) {
                                ForEach(daySessions) { session in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            // Primary Type Label
                                            if let type = session.saunaType?.rawValue ?? session.coldPlungeType?.rawValue ?? session.spaType?.rawValue {
                                                if type == "Other", let customName = session.customType, !customName.isEmpty {
                                                    Text("\(customName) (Other)")
                                                        .font(.subheadline)
                                                } else {
                                                    Text(type)
                                                        .font(.subheadline)
                                                }
                                            } else if let custom = session.customType {
                                                Text(custom)
                                                    .font(.subheadline)
                                            } else {
                                                Text(session.category.rawValue)
                                                    .font(.subheadline)
                                            }

                                            // Detail metrics
                                            HStack(spacing: 4) {
                                                Text("\(Int(session.durationSeconds / 60)) min")
                                                if let temp = session.temperature {
                                                    Text("• \(Int(temp))°")
                                                }
                                                if let part = session.bodyPart?.rawValue {
                                                    Text("• \(part)")
                                                }
                                                // Heart Rate display
                                                if let start = session.heartRateBefore, let end = session.heartRateAfter {
                                                     Text("• HR: \(start)→\(end)")
                                                } else if let start = session.heartRateBefore {
                                                     Text("• HR: \(start)")
                                                } else if let end = session.heartRateAfter {
                                                     Text("• HR End: \(end)")
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(DateFormatter.time.string(from: session.date))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Menu {
                                            Button("Delete", role: .destructive) {
                                                onDelete(session.id)
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.callout)
                                                .foregroundStyle(.primary)
                                        }
                                        .menuStyle(.borderlessButton)
                                        .padding(.leading, 8)
                                    }
                                    .padding(.vertical, 8)

                                    if session.id != daySessions.last?.id {
                                        Divider()
                                    }
                                }
                            }

                            if day != daysWithSessions.last {
                                Divider().padding(.vertical, 12)
                            }
                        }

                        if sessions.isEmpty {
                            Text("No recorded sessions this week.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 16)
    }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d"
        return df
    }()

    static let weekdayFull: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df
    }()
    
    static let longDate: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df
    }()

    static let time: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
}

extension SpaBodyPart {
    var mappedBodyParts: Set<BodyPart> {
        switch self {
        case .back: return [.upperBack, .lowerBack, .trapezius, .lats]
        case .shoulder: return [.leftShoulder, .rightShoulder]
        case .legs: return [.leftThigh, .rightThigh, .leftShin, .rightShin, .leftHamstring, .rightHamstring, .leftCalf, .rightCalf, .leftGlute, .rightGlute]
        case .feet: return [.leftFoot, .rightFoot]
        case .head: return [.head, .neck]
        case .fullBody: return Set(BodyPart.allCases)
        }
    }
}
