import SwiftUI
import Charts
import Combine

// MARK: - Models

enum RecoveryCategory: String, CaseIterable, Codable, Identifiable {
    case sauna = "Sauna"
    case coldPlunge = "Cold Plunge"
    case spa = "Spa"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .sauna: return "flame.fill"
        case .coldPlunge: return "snowflake"
        case .spa: return "sparkles"
        }
    }
}

enum SaunaType: String, CaseIterable, Codable, Identifiable {
    case infrared = "Infrared"
    case steam = "Steam"
    case dry = "Dry"
    case custom = "Other"
    var id: String { rawValue }
}

enum ColdPlungeType: String, CaseIterable, Codable, Identifiable {
    case coldPlunge = "Cold Plunge"
    case iceBath = "Ice Bath"
    case cryotherapy = "Cryotherapy Chamber"
    case hydrotherapy = "Hydrotherapy"
    case custom = "Other"
    var id: String { rawValue }
}

enum SpaType: String, CaseIterable, Codable, Identifiable {
    case massage = "Massage"
    case physiotherapy = "Physiotherapy"
    case chiropractic = "Chiropractic"
    case deepTissue = "Deep Tissue"
    case compression = "Compression"
    case redLight = "Red Light Therapy"
    case jacuzzi = "Jacuzzi"
    case cryotherapy = "Cryotherapy"
    case floating = "Floating Chamber"
    case cupping = "Cupping"
    case dryNeedling = "Dry Needling"
    case custom = "Other"
    var id: String { rawValue }
}

enum SpaBodyPart: String, CaseIterable, Codable, Identifiable {
    case back = "Back"
    case shoulder = "Shoulder"
    case legs = "Legs"
    case feet = "Feet"
    case head = "Head"
    case fullBody = "Full Body"
    var id: String { rawValue }
}

struct RecoverySession: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var category: RecoveryCategory
    var durationSeconds: TimeInterval
    
    var saunaType: SaunaType?
    var coldPlungeType: ColdPlungeType?
    var spaType: SpaType?
    
    var temperature: Double?
    var hydrationTimerSeconds: TimeInterval?
    var bodyPart: SpaBodyPart?
    
    var customType: String?
}

// MARK: - View

struct RecoveryTrackingSection: View {
    var accentColorOverride: Color?
    private var tint: Color { accentColorOverride ?? .accentColor }
    
    @AppStorage("recovery.visibleCategories.json") private var visibleCategoriesJSON: String = ""
    @AppStorage("recovery.sessions.json") private var sessionsJSON: String = ""
    
    @State private var visibleCategories: Set<RecoveryCategory> = [.sauna, .coldPlunge, .spa]
    @State private var sessions: [RecoverySession] = []
    @State private var showEditSheet = false
    
    init(accentColorOverride: Color? = nil) {
        self.accentColorOverride = accentColorOverride
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recovery Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 48)

            Button {
                showEditSheet = true
            } label: {
                Label("Change Goal", systemImage: "pencil")
                  .font(.callout.weight(.semibold))
                  .padding(.vertical, 18)
                  .frame(maxWidth: .infinity, minHeight: 52)
                  .glassEffect(in: .rect(cornerRadius: 16.0))
                  .contentShape(Rectangle())
            }
            .nutritionTip(.editCalorieGoal)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .buttonStyle(.plain)
            
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
                    VStack(spacing: 12) {
                        RecoveryCategoryCard(
                            category: category,
                            tint: tint,
                            onSave: saveSession
                        )
                        
                        RecoverySummarySection(
                            category: category,
                            sessions: sessions.filter { $0.category == category },
                            tint: tint,
                            onDelete: deleteSession
                        )
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
        if let data = visibleCategoriesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([RecoveryCategory].self, from: data) {
            visibleCategories = Set(decoded)
        }
        
        if let data = sessionsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([RecoverySession].self, from: data) {
            sessions = decoded
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(Array(visibleCategories)),
           let str = String(data: data, encoding: .utf8) {
            visibleCategoriesJSON = str
        }
    }
    
    private func saveSession(_ session: RecoverySession) {
        sessions.append(session)
        if let data = try? JSONEncoder().encode(sessions),
           let str = String(data: data, encoding: .utf8) {
            sessionsJSON = str
        }
    }
    
    private func deleteSession(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions.remove(at: index)
            if let data = try? JSONEncoder().encode(sessions),
               let str = String(data: data, encoding: .utf8) {
                sessionsJSON = str
            }
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
    let onSave: (RecoverySession) -> Void
    
    // Inputs (Defaults)
    @State private var tempString: String = "180" // Default F
    @State private var durationMinutes: Double = 15
    @State private var hydrationMinutes: Double = 5
    
    @State private var selectedSaunaType: SaunaType = .dry
    @State private var selectedPlungeType: ColdPlungeType = .iceBath
    @State private var selectedSpaType: SpaType = .massage
    @State private var selectedBodyPart: SpaBodyPart = .fullBody
    @State private var customType: String = ""
    
    // Active State
    @State private var isRunning = false
    @State private var timeRemaining: TimeInterval = 0
    @State private var hydrationTimeRemaining: TimeInterval = 0
    @State private var startDate: Date?
    
    // Timer
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var isTimerBased: Bool {
        return category == .sauna || category == .coldPlunge
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
            
            if isRunning && isTimerBased {
                activeView
                    .transition(.opacity)
            } else {
                configView
                    .transition(.opacity)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal)
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
            
            // Input Fields
            HStack(alignment: .top, spacing: 16) {
                // Temp Input
                if category == .sauna || category == .coldPlunge {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEMP (°F)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        TextField("0", text: $tempString)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(height: 50)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(width: 100)
                }
                
                // Duration Input
                VStack(alignment: .leading, spacing: 8) {
                    Text(category == .spa ? "DURATION" : "TIMER")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("\(Int(durationMinutes))")
                            .font(.system(size: 24, weight: .semibold))
                        Text("min")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                        
                        Spacer()
                        
                        Stepper("", value: $durationMinutes, in: 1...180, step: 5)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
            }
            
            // Action Button
            Button(action: startOrLog) {
                HStack {
                    if category != .spa {
                        Image(systemName: "play.fill")
                            .font(.subheadline)
                    }
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
    
    // MARK: - Active View (Timer)
    private var activeView: some View {
        VStack(spacing: 32) {
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("REMAINING")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text(timeString(from: timeRemaining))
                        .font(.system(size: 44, weight: .light, design: .monospaced))
                        .foregroundStyle(timeRemaining < 60 ? .red : .primary)
                }
                
                if category == .sauna {
                    VStack(spacing: 8) {
                        Text("HYDRATE IN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text(timeString(from: hydrationTimeRemaining))
                            .font(.system(size: 44, weight: .light, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.top, 10)
            
            HStack(spacing: 16) {
                Button(action: stopSession) {
                    Text("Cancel")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button(action: {
                    finishSession()
                }) {
                    Text("Finish")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Logic
    
    private func startOrLog() {
        if category == .spa {
            let session = RecoverySession(
                date: Date(),
                category: .spa,
                durationSeconds: durationMinutes * 60,
                spaType: selectedSpaType,
                startBodyPart: selectedBodyPart,
                customType: customType.isEmpty ? nil : customType
            )
            onSave(session)
        } else {
            timeRemaining = durationMinutes * 60
            hydrationTimeRemaining = hydrationMinutes * 60
            isRunning = true
            startDate = Date()
        }
    }
    
    private func stopSession() {
        isRunning = false
    }
    
    private func finishSession() {
        isRunning = false
        // Calculate based on configured, since we don't track elapsed if cancelled/early finish simply
        let duration = durationMinutes * 60 
        
        var temp: Double?
        if let t = Double(tempString) { temp = t }
        
        let session = RecoverySession(
            date: Date(),
            category: category,
            durationSeconds: duration,
            saunaType: category == .sauna ? selectedSaunaType : nil,
            coldPlungeType: category == .coldPlunge ? selectedPlungeType : nil,
            temperature: temp,
            hydrationTimerSeconds: category == .sauna ? hydrationMinutes * 60 : nil,
            customType: customType.isEmpty ? nil : customType
        )
        onSave(session)
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

extension RecoverySession {
    init(date: Date, category: RecoveryCategory, durationSeconds: TimeInterval, spaType: SpaType, startBodyPart: SpaBodyPart, customType: String?) {
        self.date = date
        self.category = category
        self.durationSeconds = durationSeconds
        self.spaType = spaType
        self.bodyPart = startBodyPart
        self.customType = customType
        
        // Initialize other properties to nil
        self.saunaType = nil
        self.coldPlungeType = nil
        self.temperature = nil
        self.hydrationTimerSeconds = nil
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
                    .frame(height: 200)
                    
                    // Detail List
                    VStack(spacing: 0) {
                        ForEach(last7Days.reversed(), id: \.self) { day in
                            let daySessions = sessions
                                .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                                .sorted { $0.date > $1.date }
                            
                            if !daySessions.isEmpty {
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
                                                    Text(type)
                                                        .font(.subheadline)
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
                                
                                if day != last7Days.first {
                                    Divider().padding(.vertical, 12)
                                }
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
