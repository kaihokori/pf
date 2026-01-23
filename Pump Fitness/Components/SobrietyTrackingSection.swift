import SwiftUI
import SwiftData

struct SobrietyTrackingSection: View {
    @Binding var account: Account
    @Binding var selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    // Day service to save logs
    private let dayService = DayFirestoreService()
    
    @State private var showEditor = false
    @State private var showEntrySheet = false
    
    // We need to fetch Day objects for the whole month to fill the calendar
    @State private var monthDays: [Date: Day] = [:]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sobriety Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    showEditor = true
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
            .padding(.horizontal, 18)
            .padding(.top, 48)
            .padding(.bottom, 16)
            
            if account.sobrietyMetrics.filter({ $0.isEnabled }).isEmpty {
                // Empty state
                VStack(alignment: .leading, spacing: 8) {
                    Label("No challenges set up yet", systemImage: "drop.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Add sobriety challenges with the Edit button to start tracking your progress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 16.0))
                .padding(.horizontal, 18)
            } else {
                // Calendar Grid
                SobrietyCalendarView(
                    selectedDate: $selectedDate,
                    monthDays: monthDays,
                    metrics: account.sobrietyMetrics.filter { $0.isEnabled }
                )
                .padding(.horizontal, 18)
                
                // Log Button
                Button {
                    showEntrySheet = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Log Progress", systemImage: "plus.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(
                        themeManager.selectedTheme == .multiColour
                            ? Color.green
                            : themeManager.selectedTheme.accent(for: colorScheme)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 24)
            }
        }
        .onAppear {
            refreshMonthData()
        }
        .onChange(of: selectedDate) { _, _ in
            refreshMonthData()
        }
        .sheet(isPresented: $showEditor) {
            SobrietyEditorSheet(account: $account)
        }
        .sheet(isPresented: $showEntrySheet) {
            let currentDay = monthDays.values.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) })
            SobrietyEntrySheet(
                date: selectedDate,
                metrics: account.sobrietyMetrics.filter { $0.isEnabled },
                initialEntries: currentDay?.sobrietyEntries ?? [],
                onSave: { entries in
                    saveEntries(entries)
                }
            )
        }
    }
    
    private func refreshMonthData() {
        // Fetch all days in current month
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else { return }
        
        var newDays: [Date: Day] = [:]
        
        // Optimize: Fetch range from SwiftData if possible, but fetching one by one is safe for now (max 31 items)
        for dayOffset in range {
             if let date = calendar.date(byAdding: .day, value: dayOffset - 1, to: startOfMonth) {
                 // Fetch from SwiftData context synchronously
                 let day = Day.fetchOrCreate(for: date, in: modelContext) 
                 newDays[date] = day
             }
        }
        monthDays = newDays
    }
    
    private func saveEntries(_ entries: [SobrietyEntry]) {
        // Update current day
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        
        // Merge entries
        var currentEntries = day.sobrietyEntries
        for entry in entries {
            currentEntries.removeAll { $0.metricID == entry.metricID }
            currentEntries.append(entry)
        }
        day.sobrietyEntries = currentEntries
        
        // Save to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
         
        // Update local cache for immediate UI refresh
        monthDays[day.date] = day
        // force refresh?
        
        // Save to Firestore
        dayService.saveDay(day) { success in 
            if success {
                DispatchQueue.main.async {
                    refreshMonthData() // Refresh UI
                }
            }
        }
    }
}

struct SobrietyCalendarView: View {
    @Binding var selectedDate: Date
    var monthDays: [Date: Day]
    var metrics: [SobrietyMetric]
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Weekday Headers
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            
            // Days Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(daysInMonth(), id: \.self) { dateObj in
                    if let date = dateObj {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            dayData: monthDays.values.first(where: { calendar.isDate($0.date, inSameDayAs: date) }), // Simple linear search is fine for 30 items
                            metrics: metrics
                        )
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
    
    private func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) // 1 = Sunday
        let offset = firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for dayOffset in range {
            if let date = calendar.date(byAdding: .day, value: dayOffset - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        return days
    }
}

struct DayCell: View {
    var date: Date
    var isSelected: Bool
    var dayData: Day?
    var metrics: [SobrietyMetric]
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                }
                
                // Content
                ZStack {
                    if let day = dayData {
                        let entries = day.sobrietyEntries
                        
                        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                            let ringIndex = CGFloat(index)
                            // Inset logic: Outer is 0. Inner is higher.
                            // Max diameter 36. 
                            let inset = ringIndex * 4 // spacing between rings
                            
                            RingView(
                                color: Color(hex: metric.colorHex) ?? .blue,
                                status: status(for: metric, in: entries),
                                inset: inset
                            )
                        }
                    } else {
                        // Empty rings placeholder?
                        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                           let inset = CGFloat(index) * 4
                           Circle()
                                .inset(by: inset)
                                .stroke(Color.secondary.opacity(0.1), lineWidth: 2.5)
                        }
                    }
                }
                .frame(width: 32, height: 32)
                
            }
            .frame(width: 40, height: 40)
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
    }
    
    enum Status {
        case success
        case failed
        case empty
    }
    
    private func status(for metric: SobrietyMetric, in entries: [SobrietyEntry]) -> Status {
        guard let entry = entries.first(where: { $0.metricID == metric.id }) else { return .empty }
        if let sober = entry.isSober {
            return sober ? .success : .failed
        }
        return .empty
    }
    
    struct RingView: View {
        var color: Color
        var status: Status
        var inset: CGFloat
        
        var body: some View {
            switch status {
            case .success:
                Circle()
                    .inset(by: inset)
                    .stroke(color, lineWidth: 3)
            case .failed:
                // Dashed or low opacity
                 Circle()
                    .inset(by: inset)
                    .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [2, 4]))
            case .empty:
                Circle()
                    .inset(by: inset)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 3)
            }
        }
    }
}
