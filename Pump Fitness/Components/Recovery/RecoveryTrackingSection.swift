import SwiftUI
import SwiftData

struct RecoveryTrackingSection: View {
    var selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var recoveryEntries: [RecoveryEntry] = []
    @State private var showEntrySheet = false
    @State private var editingEntry: RecoveryEntry?
    @State private var showWeeklyStats = false
    
    private let dayFirestoreService = DayFirestoreService()

    private var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recovery Tracking")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: { 
                    editingEntry = nil
                    showEntrySheet = true
                 }) {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            
            if recoveryEntries.isEmpty {
                Button {
                    editingEntry = nil
                    showEntrySheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No Recovery Actions Logged", systemImage: "plus.circle")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Tap to add your first recovery activity for this day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 12) {
                    ForEach(recoveryEntries) { entry in
                        Button {
                            editingEntry = entry
                            showEntrySheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: entry.type.icon)
                                    .font(.title2)
                                    .foregroundStyle(accentOverride ?? entry.type.color)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.type.rawValue)
                                        .font(.headline)
                                    if let notes = entry.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(entry.durationSeconds / 60) min")
                                        .font(.subheadline.weight(.medium))
                                    if let temp = entry.temperature {
                                        Text(String(format: "%.0f°", temp))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical)
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal, 18)
            }
            
            // Weekly Summary Toggle
            if !recoveryEntries.isEmpty || showWeeklyStats {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        Label("Weekly Stats", systemImage: "chart.bar.xaxis")
                            .font(.callout.weight(.semibold))
                        Image(systemName: showWeeklyStats ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showWeeklyStats.toggle()
                        }
                    }
                    
                    if showWeeklyStats {
                        VStack(alignment: .leading, spacing: 10) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                WeeklyRecoverySummary(selectedDate: selectedDate, currentEntries: recoveryEntries)
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
                .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 20)
        .onAppear { refreshData() }
        .onChange(of: selectedDate) { refreshData() }
        .sheet(isPresented: $showEntrySheet) {
            RecoveryEntrySheet(
                existingEntry: editingEntry,
                onSave: { entry in
                    saveEntry(entry)
                },
                onDelete: { entry in
                    deleteEntry(entry)
                }
            )
        }
    }
    
    private func refreshData() {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        recoveryEntries = day.recoveryEntries
    }
    
    private func saveEntry(_ entry: RecoveryEntry) {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        if let index = day.recoveryEntries.firstIndex(where: { $0.id == entry.id }) {
            day.recoveryEntries[index] = entry
        } else {
            day.recoveryEntries.append(entry)
        }
        
        // Optimistic UI update
        recoveryEntries = day.recoveryEntries
        
        // Save to Firestore
        dayFirestoreService.saveDay(day) { success in
            if !success { print("Failed to save recovery entry") }
        }
    }
    
    private func deleteEntry(_ entry: RecoveryEntry) {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext)
        day.recoveryEntries.removeAll(where: { $0.id == entry.id })
        
        recoveryEntries = day.recoveryEntries
        
        dayFirestoreService.saveDay(day) { success in
             if !success { print("Failed to delete recovery entry") }
        }
    }
}

struct WeeklyRecoverySummary: View {
    var selectedDate: Date
    var currentEntries: [RecoveryEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var weeklyData: [Date: [RecoveryEntry]] = [:]
    
    private var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(weekDates, id: \.self) { date in
                recoveryBar(for: date)
            }
        }
        .padding(.vertical, 8)
        .onAppear { loadWeekData() }
        .onChange(of: selectedDate) { loadWeekData() }
    }

    @ViewBuilder
    private func recoveryBar(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let entries = isSelected ? currentEntries : (weeklyData[Calendar.current.startOfDay(for: date)] ?? [])
        let totalMinutes = entries.reduce(0) { $0 + Double($1.durationSeconds) / 60.0 }
        
        VStack(spacing: 6) {
            Spacer()
            if totalMinutes > 0 {
                // Stacked bar
                VStack(spacing: 2) {
                    let sorted = entries.sorted { $0.type.rawValue < $1.type.rawValue }
                    ForEach(sorted) { entry in
                        Rectangle()
                            .fill(accentOverride ?? entry.type.color)
                            .frame(height: max(3, CGFloat(entry.durationSeconds) / 60.0 * 1.5))
                    }
                }
                .frame(width: 8)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 4, height: 4)
            }
            
            Text(dayLabel(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 40)
        .frame(height: 120)
    }
    
    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = selectedDate
        let weekday = cal.component(.weekday, from: today)
        let firstWeekday = cal.firstWeekday
        let offset = (weekday - firstWeekday + 7) % 7
        let startOfWeek = cal.date(byAdding: .day, value: -offset, to: today)!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private func dayLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE d"
        fmt.locale = Locale.current
        return fmt.string(from: date)
    }
    
    private func loadWeekData() {
        let dates = weekDates
        for date in dates {
            if !Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                let day = Day.fetchOrCreate(for: date, in: modelContext)
                weeklyData[Calendar.current.startOfDay(for: date)] = day.recoveryEntries
            }
        }
    }
}
