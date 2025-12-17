//
//  RoutineTabView.swift
//  Pump Fitness
//
//  Created by Kyle Graham on 4/12/2025.
//

import SwiftUI
import SwiftData

fileprivate struct HabitItem: Identifiable {
    let id = UUID()
    var name: String
    var weeklyProgress: [HabitDayStatus]
    var colorHex: String = ""
}

private struct HabitsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var habits: [HabitItem]
    var onSave: ([HabitItem]) -> Void

    @State private var working: [HabitItem] = []
    @State private var newName: String = ""
    @State private var hasLoaded: Bool = false

    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: UUID?

    private let maxHabits = 3
    private var canAddMore: Bool { working.count < maxHabits }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private let palette: [Color] = [.purple, .orange, .pink, .teal, .mint, .yellow, .green]
    private var presets: [HabitItem] {
        [
            HabitItem(name: "Morning Stretch", weeklyProgress: Array(repeating: .notTracked, count: 7), colorHex: "#7A5FD1"),
            HabitItem(name: "Meditation", weeklyProgress: Array(repeating: .notTracked, count: 7), colorHex: "#4FB6C6"),
            HabitItem(name: "Read", weeklyProgress: Array(repeating: .notTracked, count: 7), colorHex: "#E39A3B")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Habits")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button {
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            Circle()
                                                .fill((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor).opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "checklist") .foregroundStyle((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor)))
                                        }
                                        .buttonStyle(.plain)

                                        TextField("Name", text: binding.name)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeHabit(working[idx].id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Quick Add
                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill((Color(hex: preset.colorHex) ?? Color.accentColor).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "checklist") .foregroundStyle((Color(hex: preset.colorHex) ?? Color.accentColor)))

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    // Custom composer
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Habit")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            HStack {
                                TextField("Habit name", text: $newName)
                                    .textInputAutocapitalization(.words)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                                Button(action: addCustomHabit) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAddCustom)
                                    .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("You can track up to \(maxHabits) habits.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = habits
        hasLoaded = true
    }

    private func removeHabit(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func addCustomHabit() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let idx = working.count
        let colorHex = palette[idx % palette.count].toHexString()
        let new = HabitItem(name: trimmed, weeklyProgress: Array(repeating: .notTracked, count: 7), colorHex: colorHex)
        working.append(new)
        newName = ""
    }

    private func togglePreset(_ preset: HabitItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            var new = preset
            // ensure color is set
            if new.colorHex.isEmpty {
                let idx = working.count
                new.colorHex = palette[idx % palette.count].toHexString()
            }
            working.append(new)
        }
    }

    private func isPresetSelected(_ preset: HabitItem) -> Bool {
        return working.contains { $0.name == preset.name }
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        // Ensure any habits without an explicit color get a palette color so main list matches editor
        for i in working.indices {
            if working[i].colorHex.isEmpty {
                working[i].colorHex = palette[i % palette.count].toHexString()
            }
        }
        onSave(working)
        dismiss()
    }
}

// MARK: - Weekly Sleep Helpers

private struct SleepDayEntry: Identifiable {
    let id = UUID()
    let date: Date
    var nightSeconds: TimeInterval
    var napSeconds: TimeInterval

    var totalSeconds: TimeInterval { nightSeconds + napSeconds }

    static func sampleEntries() -> [SleepDayEntry] {
        let cal = Calendar.current
        let today = Date()
        // build last 7 days
        let weekday = cal.component(.weekday, from: today)
        let startIndex = 2 // monday
        let offsetToStart = (weekday - startIndex + 7) % 7
        let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: cal.startOfDay(for: today)) ?? today

        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: startOfWeek) else { return nil }
            // make some variation
            let night = TimeInterval(6 * 3600 + (i % 3) * 1800) // 6:00, 6:30, 7:00
            let nap = TimeInterval((i % 4 == 0) ? 30 * 60 : 0)
            return SleepDayEntry(date: d, nightSeconds: night, napSeconds: nap)
        }
    }
}

private struct SleepDayColumn: View {
    let date: Date
    let tint: Color
    let nightSeconds: TimeInterval
    let napSeconds: TimeInterval
    let isFuture: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(shortWeekday(from: date))
                .font(.caption)
                .fontWeight(.semibold)

            if isFuture {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Upcoming")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                Spacer()
            } else {
                VStack(spacing: 8) {
                    // Night sleep (hours)
                    SleepIndicatorRow(label: "Night", color: .indigo, seconds: nightSeconds)

                    // Nap sleep (minutes)
                    SleepIndicatorRow(label: "Nap", color: .cyan, seconds: napSeconds)

                    // Total
                    SleepIndicatorRow(label: "Total", color: tint, seconds: nightSeconds + napSeconds)
                }
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 180, height: 140)
        .liquidGlass(cornerRadius: 14)
    }

    private struct SleepIndicatorRow: View {
        var label: String
        var color: Color
        var seconds: TimeInterval
        private var displayText: String {
            let total = Int(seconds)
            let h = total / 3600
            let m = (total % 3600) / 60
            if h > 0 { return String(format: "%dh %02dm", h, m) }
            return String(format: "%dm", m)
        }

        var body: some View {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func shortWeekday(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "E"
        return df.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm", m)
    }
}

struct RoutineTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("activityTimers.json") private var storedActivityTimersJSON: String = ""
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @State private var showAccountsView = false
    @State private var dailyTaskItems: [DailyTaskItem] = []
    @State private var activityTimers: [ActivityTimerItem] = ActivityTimerItem.defaultTimers
    @State private var goals: [GoalItem] = GoalItem.sampleDefaults()
    @State private var groceryItems: [GroceryItem] = GroceryItem.sampleItems()
    @State private var expenseCategories: [ExpenseCategory] = ExpenseCategory.defaultCategories()
    @State private var currentDay: Day?

    @State private var habitItems: [HabitItem] = [
        HabitItem(name: "Morning Stretch", weeklyProgress: [.tracked, .tracked, .notTracked, .tracked, .notTracked, .notTracked, .notTracked]),
        HabitItem(name: "Meditation", weeklyProgress: [.notTracked, .tracked, .notTracked, .tracked, .notTracked, .notTracked, .notTracked]),
        HabitItem(name: "Read", weeklyProgress: [.tracked, .tracked, .tracked, .tracked, .tracked, .notTracked, .notTracked])
    ]

    @State private var showWeeklySleep: Bool = false
    @State private var weekStartsOnMonday: Bool = true
    @State private var weeklySleepEntries: [SleepDayEntry] = SleepDayEntry.sampleEntries()
    @State private var showDailyTasksEditor: Bool = false
    @State private var showActivityTimersEditor: Bool = false
    @State private var showGoalsEditor: Bool = false
    @State private var showHabitsEditor: Bool = false
    @State private var showGroceryListEditor: Bool = false
    @State private var showExpenseCategoriesEditor: Bool = false
    @State private var hasLoadedActivityTimers: Bool = false

    private let dayService = DayFirestoreService()
    private let accountService = AccountFirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollView {
                    VStack(spacing: 0) {
                        HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true })
                            .environmentObject(account)

                        HStack {
                            Text("Daily Tasks")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                    showDailyTasksEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                        
                        DailyTasksSection(
                            accentColorOverride: accentOverride,
                            tasks: $dailyTaskItems,
                            onToggle: { id, isCompleted in
                                handleTaskToggle(id: id, isCompleted: isCompleted)
                            },
                            onRemove: { id in
                                handleTaskRemove(id: id)
                            }
                        )
                        .padding(.bottom, -30)
                        
                        HStack {
                            Text("Activity Timers")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showActivityTimersEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                        
                        ActivityTimersSection(accentColorOverride: accentOverride, timers: activityTimers)

                        HStack {
                            Text("Goals")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showGoalsEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        GoalsSection(accentColorOverride: accentOverride, goals: $goals)

                        HStack {
                            Text("Habits")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showHabitsEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)
                        .padding(.horizontal, 18)

                        HabitTrackingSection(
                            habits: $habitItems,
                            accentColor: accentOverride ?? .accentColor
                        )

                        HStack {
                            Text("Sleep Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)
                        .padding(.horizontal, 18)

                        SleepTrackingSection(accentColor: accentOverride)

                        VStack(alignment: .leading, spacing: 16) {
                            // New collapsible Weekly Sleep section (Macro-style layout adapted for sleep)
                            HStack {
                                Spacer()
                                Label("Weekly Sleep", systemImage: "bed.double.fill")
                                    .font(.callout.weight(.semibold))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showWeeklySleep.toggle()
                                }
                            }

                            if showWeeklySleep {
                                VStack(alignment: .leading, spacing: 10) {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            let cal = Calendar.current
                                            let today = Date()
                                            let weekday = cal.component(.weekday, from: today) // 1 = Sunday
                                            let startIndex = weekStartsOnMonday ? 2 : 1
                                            let offsetToStart = (weekday - startIndex + 7) % 7
                                            let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: cal.startOfDay(for: today)) ?? today

                                            let weekDates: [Date] = (0..<7).compactMap { i in
                                                cal.date(byAdding: .day, value: i, to: startOfWeek)
                                            }

                                            ForEach(weekDates, id: \.self) { day in
                                                // Determine whether this day should be considered a "future" day
                                                let weekday = Calendar.current.component(.weekday, from: day) // 1 = Sunday
                                                let isFutureDay = weekday >= 5

                                                if let entry = weeklySleepEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                                                    // Use existing entry values
                                                    SleepDayColumn(date: day, tint: workoutTimelineAccent, nightSeconds: entry.nightSeconds, napSeconds: entry.napSeconds, isFuture: isFutureDay)
                                                } else {
                                                    // Fallback sample values based on day ordinal
                                                    let idx = Calendar.current.ordinality(of: .day, in: .year, for: day) ?? 0
                                                    let night = 7 * 3600 - (idx % 3) * 600
                                                    let nap = (idx % 4 == 0) ? 30 * 60 : 0
                                                    SleepDayColumn(date: day, tint: workoutTimelineAccent, nightSeconds: TimeInterval(night), napSeconds: TimeInterval(nap), isFuture: isFutureDay)
                                                }
                                            }
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
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                        HStack {
                            Text("Grocery List")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showGroceryListEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)
                        .padding(.horizontal, 18)

                        GroceryListSection(accentColorOverride: accentOverride, items: $groceryItems)

                        HStack {
                            Text("Expense Tracker")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showExpenseCategoriesEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 48)
                        .padding(.horizontal, 18)

                        ExpenseTrackerSection(accentColorOverride: accentOverride, categories: expenseCategories)

                        ShareProgressCTA(accentColor: accentOverride ?? .accentColor)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                            .padding(.top, 48)
                    }
                }
                if showCalendar {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showCalendar = false }
                    CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
                }
            }
            .sheet(isPresented: $showDailyTasksEditor) {
                DailyTasksEditorView(tasks: $dailyTaskItems, onSave: applyTaskEditorChanges)
            }
            .sheet(isPresented: $showActivityTimersEditor) {
                ActivityTimersEditorView(timers: $activityTimers, onSave: applyActivityTimerChanges)
            }
            .sheet(isPresented: $showGoalsEditor) {
                GoalsEditorView(goals: $goals, onSave: applyGoalsEditorChanges)
            }
            .sheet(isPresented: $showGroceryListEditor) {
                GroceryListEditorView(items: $groceryItems, onSave: applyGroceryListChanges)
            }
            .sheet(isPresented: $showHabitsEditor) {
                HabitsEditorView(habits: $habitItems, onSave: applyHabitsEditorChanges)
            }
            .sheet(isPresented: $showExpenseCategoriesEditor) {
                ExpenseCategoriesEditorView(categories: $expenseCategories, onSave: applyExpenseCategoryChanges)
            }
            .navigationDestination(isPresented: $showAccountsView) {
                AccountsView(account: $account)
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
        .onAppear {
            loadDailyTasks()
            loadActivityTimersFromStorage()
        }
        .onChange(of: selectedDate) { _, _ in
            loadDailyTasks()
        }
        .onChange(of: account.dailyTasks) { _, _ in
            rebuildDailyTaskItems(using: currentDay)
        }
    }
}

// MARK: - Habit Tracking Views

private struct DailyTasksEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [DailyTaskItem]
    var onSave: ([DailyTaskItem]) -> Void
    @State private var working: [DailyTaskItem] = []
    @State private var newName: String = ""
    @State private var newTimeDate: Date = Date()
    @State private var hasLoaded: Bool = false
    
    
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: String?

    private var presets: [DailyTaskItem] {
        [
            DailyTaskItem(name: "Wake Up", time: "07:00", colorHex: "#FF0000"),
            DailyTaskItem(name: "Coffee", time: "08:00", colorHex: "#FF7F00"),
            DailyTaskItem(name: "Stretch", time: "09:00", colorHex: "#7F00FF"),
            DailyTaskItem(name: "Lunch", time: "12:30", colorHex: "#00FF00"),
            DailyTaskItem(name: "Workout", time: "18:00", colorHex: "#FFFF00")
        ]
    }

    private let maxTracked = 12
    private var canAddMore: Bool { working.count < maxTracked }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tracked tasks
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Tasks")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button {
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            Circle()
                                                .fill((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor).opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "checklist") .foregroundStyle((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor)))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            TextField("Name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack(spacing: 8) {
                                                // Time picker (hour and minute)
                                                DatePicker("", selection: Binding<Date>(
                                                    get: {
                                                        parseTimeString(binding.time.wrappedValue)
                                                    }, set: { newDate in
                                                        binding.time.wrappedValue = formatTime(newDate)
                                                    }
                                                ), displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                                .datePickerStyle(.compact)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                                // Repeat toggle placed next to the time picker
                                                Button(action: { binding.repeats.wrappedValue.toggle() }) {
                                                    if binding.repeats.wrappedValue {
                                                        Image(systemName: "lock")
                                                            .foregroundStyle(Color.accentColor)
                                                    } else {
                                                        Image(systemName: "lock.open")
                                                            .foregroundStyle(binding.repeats.wrappedValue ? Color.accentColor : .secondary)
                                                    }
                                                }
                                                .buttonStyle(.plain)

                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeTask(working[idx].id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // Upgrade CTA
                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock unlimited tasks + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

                    // Quick Add
                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill((Color(hex: preset.colorHex) ?? Color.accentColor).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "checklist") .foregroundStyle((Color(hex: preset.colorHex) ?? Color.accentColor)))

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text(preset.time)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    // Custom composer
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Task")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            TextField("Task name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            HStack(spacing: 12) {
                                DatePicker("", selection: $newTimeDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                                Button(action: addCustomTask) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("You can track up to \(maxTracked) tasks.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Daily Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = tasks.isEmpty ? DailyTaskItem.defaultTasks : tasks
        hasLoaded = true
    }

    // MARK: - Time parsing/format helpers
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "HH:mm"
        return df
    }

    private func parseTimeString(_ s: String) -> Date {
        if let d = timeFormatter.date(from: s) {
            return d
        }
        return Date()
    }

    private func formatTime(_ d: Date) -> String {
        return timeFormatter.string(from: d)
    }

    private func togglePreset(_ preset: DailyTaskItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            var newTask = preset
            newTask.colorHex = ""
            working.append(newTask)
        }
    }

    private func isPresetSelected(_ preset: DailyTaskItem) -> Bool {
        return working.contains { $0.name == preset.name }
    }

    private func removeTask(_ id: String) {
        working.removeAll { $0.id == id }
    }

    private func addCustomTask() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let t = formatTime(newTimeDate)
        let new = DailyTaskItem(name: trimmed, time: t, colorHex: "")
        working.append(new)
        newName = ""
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        onSave(working)
        dismiss()
    }
}

private struct ActivityTimersEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var timers: [ActivityTimerItem]
    var onSave: ([ActivityTimerItem]) -> Void
    @State private var working: [ActivityTimerItem] = []
    @State private var newName: String = ""
    @State private var customHours: String = ""
    @State private var customMinutes: String = ""
    @State private var hasLoaded: Bool = false
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: String?

    static let maxFreeTimers = 2

    private let minDuration = 10
    private let maxDuration = 180

    private var canAddMore: Bool { working.count < Self.maxFreeTimers }
    private var customDurationMinutes: Int? {
        let hours = Int(customHours) ?? 0
        let minutes = Int(customMinutes) ?? 0
        guard hours >= 0, minutes >= 0 else { return nil }
        let total = hours * 60 + minutes
        guard total > 0 else { return nil }
        return clampDuration(total)
    }
    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (customDurationMinutes ?? 0) >= minDuration
    }

    private var presets: [ActivityTimerItem] {
        [
            ActivityTimerItem(name: "Workout", startTime: Date(), durationMinutes: 60, colorHex: "#E39A3B"),
            ActivityTimerItem(name: "Evening Walk", startTime: Date(), durationMinutes: 45, colorHex: "#4FB6C6"),
            ActivityTimerItem(name: "Stretch Break", startTime: Date(), durationMinutes: 20, colorHex: "#7A5FD1")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Timers")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Button {
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            Circle()
                                                .fill((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor).opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "clock") .foregroundStyle((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor)))
                                        }
                                        .buttonStyle(.plain)

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextField("Name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack(spacing: 12) {
                                                HStack {
                                                    TextField("Hours", text: hourBinding(for: binding))
                                                        .keyboardType(.numberPad)
                                                        .textFieldStyle(.plain)
                                                    Text("hrs")
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding()
                                                .surfaceCard(16)
                                                .frame(maxWidth: .infinity)

                                                HStack {
                                                    TextField("Minutes", text: minuteBinding(for: binding))
                                                        .keyboardType(.numberPad)
                                                        .textFieldStyle(.plain)
                                                    Text("min")
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding()
                                                .surfaceCard(16)
                                                .frame(maxWidth: .infinity)
                                            }
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeTimer(working[idx].id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock unlimited timers + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill((Color(hex: preset.colorHex) ?? Color.accentColor).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "clock") .foregroundStyle((Color(hex: preset.colorHex) ?? Color.accentColor)))

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("Duration \(preset.durationMinutes) min")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Timer")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            TextField("Timer name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                            HStack(spacing: 12) {
                                HStack {
                                    TextField("Hours", text: $customHours)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                    Text("hrs")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(16)
                                .frame(maxWidth: .infinity)

                                HStack {
                                    TextField("Minutes", text: $customMinutes)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                    Text("min")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(16)
                                .frame(maxWidth: .infinity)

                                Button(action: addCustomTimer) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            Text("You can create up to \(Self.maxFreeTimers) timers.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Activity Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = timers.isEmpty ? Array(ActivityTimerItem.defaultTimers.prefix(Self.maxFreeTimers)) : Array(timers.prefix(Self.maxFreeTimers))
        hasLoaded = true
    }

    private func splitDuration(_ minutes: Int) -> (hours: Int, minutes: Int) {
        let clamped = max(0, minutes)
        return (clamped / 60, clamped % 60)
    }

    private func clampDuration(_ minutes: Int) -> Int {
        min(max(minutes, minDuration), maxDuration)
    }

    private func hourBinding(for binding: Binding<ActivityTimerItem>) -> Binding<String> {
        Binding {
            let parts = splitDuration(binding.durationMinutes.wrappedValue)
            return String(parts.hours)
        } set: { newValue in
            let hours = max(0, Int(newValue) ?? 0)
            let currentParts = splitDuration(binding.durationMinutes.wrappedValue)
            binding.durationMinutes.wrappedValue = clampDuration(hours * 60 + currentParts.minutes)
        }
    }

    private func minuteBinding(for binding: Binding<ActivityTimerItem>) -> Binding<String> {
        Binding {
            let parts = splitDuration(binding.durationMinutes.wrappedValue)
            return String(parts.minutes)
        } set: { newValue in
            let minutes = max(0, min(59, Int(newValue) ?? 0))
            let currentParts = splitDuration(binding.durationMinutes.wrappedValue)
            binding.durationMinutes.wrappedValue = clampDuration(currentParts.hours * 60 + minutes)
        }
    }

    private func togglePreset(_ preset: ActivityTimerItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: ActivityTimerItem) -> Bool {
        working.contains { $0.name == preset.name }
    }

    private func removeTimer(_ id: String) {
        working.removeAll { $0.id == id }
    }

    private func addCustomTimer() {
        guard canAddCustom, let duration = customDurationMinutes else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newTimer = ActivityTimerItem(name: trimmed, startTime: Date(), durationMinutes: duration, colorHex: "#4CAF6A")
        working.append(newTimer)
        newName = ""
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        onSave(Array(working.prefix(Self.maxFreeTimers)))
        dismiss()
    }
}

private struct GoalsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var goals: [GoalItem]
    var onSave: ([GoalItem]) -> Void
    @State private var working: [GoalItem] = []
    @State private var newName: String = ""
    @State private var newNote: String = ""
    @State private var newDate: Date = Date()
    @State private var hasLoaded: Bool = false
    private let maxGoals: Int = 8

    private var presets: [GoalItem] {
        let cal = Calendar.current
        let today = Date()
        let in3 = cal.date(byAdding: .day, value: 3, to: today) ?? today
        let in14 = cal.date(byAdding: .day, value: 14, to: today) ?? today
        return [
            GoalItem(title: "10 min Walk", note: "Quick cardio", dueDate: today),
            GoalItem(title: "Read 10 pages", note: "Evening habit", dueDate: in3),
            GoalItem(title: "Prep healthy lunch", note: "Meal prep", dueDate: in14)
        ]
    }

    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canAddMore: Bool { working.count < maxGoals }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Goals")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, goal in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "target") .foregroundStyle(Color.accentColor))

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextField("Name", text: binding.title)
                                                .font(.subheadline.weight(.semibold))

                                            TextField("Note (optional)", text: binding.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            DatePicker("Due", selection: binding.dueDate, displayedComponents: .date)
                                                .labelsHidden()
                                                // .datePickerStyle(.compact)
                                                // .frame(maxWidth: .infinity, alignment: .leading)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeGoal(goal.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock more goal slots + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

                    // Quick Add
                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "target") .foregroundStyle(Color.accentColor))

                                        VStack(alignment: .leading) {
                                            Text(preset.title)
                                                .font(.subheadline.weight(.semibold))
                                            if !preset.note.isEmpty {
                                                Text(preset.note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Goal")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            HStack {
                                TextField("Goal name", text: $newName)
                                    .textInputAutocapitalization(.sentences)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                                DatePicker("Due Date", selection: $newDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }

                            HStack {
                                TextField("Note (optional)", text: $newNote)
                                    .textInputAutocapitalization(.sentences)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                                Button(action: addGoal) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }
                        }
                        Text("You can create up to \(maxGoals) goals.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = goals
        hasLoaded = true
    }

    private func addGoal() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let goal = GoalItem(title: trimmed, note: newNote, isCompleted: false, dueDate: newDate)
        working.append(goal)
        newName = ""
        newNote = ""
    }

    private func togglePreset(_ preset: GoalItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.title == preset.title }
        } else if canAddMore {
            var new = preset
            // ensure a fresh id
            new = GoalItem(title: new.title, note: new.note, isCompleted: false, dueDate: new.dueDate)
            working.append(new)
        }
    }

    private func isPresetSelected(_ preset: GoalItem) -> Bool {
        return working.contains { $0.title == preset.title }
    }

    private func removeGoal(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func donePressed() {
        onSave(working)
        dismiss()
    }
}

private struct GroceryListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [GroceryItem]
    var onSave: ([GroceryItem]) -> Void

    @State private var working: [GroceryItem] = []
    @State private var newName: String = ""
    @State private var newNote: String = ""
    @State private var hasLoaded: Bool = false

    private let maxItems: Int = 8

    private var presets: [GroceryItem] {
        [
            GroceryItem(title: "Greek Yogurt", note: "32 oz tub"),
            GroceryItem(title: "Blueberries", note: "1 pint"),
            GroceryItem(title: "Brown Rice", note: "2 lb bag")
        ]
    }

    private var canAddMore: Bool { working.count < maxItems }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracked Items")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, item in
                                    let binding = $working[idx]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "cart") .foregroundStyle(Color.accentColor))

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextField("Item name", text: binding.title)
                                                .font(.subheadline.weight(.semibold))

                                            TextField("Note (optional)", text: binding.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(role: .destructive) {
                                            removeItem(item.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    Button(action: { /* TODO: present upgrade flow */ }) {
                        HStack(alignment: .center) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .padding(.trailing, 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Text("Unlock more grocery slots + other benefits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .surfaceCard(16)
                    }
                    .buttonStyle(.plain)

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "cart") .foregroundStyle(Color.accentColor))

                                        VStack(alignment: .leading) {
                                            Text(preset.title)
                                                .font(.subheadline.weight(.semibold))
                                            if !preset.note.isEmpty {
                                                Text(preset.note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Item")
                            .font(.subheadline.weight(.semibold))

                        VStack(spacing: 12) {
                            TextField("Item name", text: $newName)
                                .textInputAutocapitalization(.sentences)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                            HStack {
                                TextField("Note (optional)", text: $newNote)
                                    .textInputAutocapitalization(.sentences)
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                                Button(action: addItem) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }
                        }
                        Text("You can create up to \(maxItems) items.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = items
        hasLoaded = true
    }

    private func removeItem(_ id: UUID) {
        working.removeAll { $0.id == id }
    }

    private func addItem() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = GroceryItem(title: trimmed, note: newNote)
        working.append(item)
        newName = ""
        newNote = ""
    }

    private func togglePreset(_ preset: GroceryItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.title == preset.title }
        } else if canAddMore {
            var new = preset
            new = GroceryItem(title: new.title, note: new.note, isChecked: false)
            working.append(new)
        }
    }

    private func isPresetSelected(_ preset: GroceryItem) -> Bool {
        return working.contains { $0.title == preset.title }
    }

    private func donePressed() {
        onSave(Array(working.prefix(maxItems)))
        dismiss()
    }
}

private struct ExpenseCategoriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var categories: [ExpenseCategory]
    var onSave: ([ExpenseCategory]) -> Void

    @State private var working: [ExpenseCategory] = []
    @State private var hasLoaded: Bool = false
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: Int?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tracked Categories")
                        .font(.subheadline.weight(.semibold))

                    VStack(spacing: 12) {
                        ForEach(Array(working.enumerated()), id: \.element.id) { idx, category in
                            let binding = $working[idx]
                            HStack(spacing: 12) {
                                Button {
                                    colorPickerTargetId = category.id
                                    showColorPickerSheet = true
                                } label: {
                                    Circle()
                                        .fill((Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor).opacity(0.2))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Category #\(category.id + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    TextField("Name", text: binding.name)
                                        .font(.subheadline.weight(.semibold))
                                        .textInputAutocapitalization(.words)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitial)
        .sheet(isPresented: $showColorPickerSheet) {
            ColorPickerSheet { hex in
                applyColor(hex: hex)
                showColorPickerSheet = false
            } onCancel: {
                showColorPickerSheet = false
            }
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        working = categories.sorted { $0.id < $1.id }
        hasLoaded = true
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        onSave(working)
        dismiss()
    }
}

// MARK: - Daily task persistence
extension RoutineTabView {
    private func applyGoalsEditorChanges(_ items: [GoalItem]) {
        goals = items
    }

    private func applyGroceryListChanges(_ items: [GroceryItem]) {
        groceryItems = Array(items.prefix(8))
    }

    private func applyExpenseCategoryChanges(_ items: [ExpenseCategory]) {
        let defaults = ExpenseCategory.defaultCategories()
        var normalized: [ExpenseCategory] = []

        for idx in 0..<defaults.count {
            if let incoming = items.first(where: { $0.id == idx }) {
                let trimmedName = incoming.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = trimmedName.isEmpty ? defaults[idx].name : trimmedName
                let resolvedColor = incoming.colorHex.isEmpty ? defaults[idx].colorHex : incoming.colorHex
                normalized.append(ExpenseCategory(id: idx, name: resolvedName, colorHex: resolvedColor))
            } else {
                normalized.append(defaults[idx])
            }
        }

        expenseCategories = normalized
    }

    private func applyActivityTimerChanges(_ items: [ActivityTimerItem]) {
        let trimmed = Array(items.prefix(ActivityTimersEditorView.maxFreeTimers))
        activityTimers = trimmed
        persistActivityTimers(trimmed)
    }

    private func applyHabitsEditorChanges(_ items: [HabitItem]) {
        habitItems = Array(items.prefix(3))
    }

    private func loadDailyTasks() {
        dayService.fetchDay(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros) { day in
            DispatchQueue.main.async {
                let resolvedDay = day ?? Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros)
                currentDay = resolvedDay
                pruneCompletions(for: resolvedDay)
                rebuildDailyTaskItems(using: resolvedDay)
            }
        }
    }

    private func loadActivityTimersFromStorage() {
        guard !hasLoadedActivityTimers else { return }
        defer { hasLoadedActivityTimers = true }
        guard !storedActivityTimersJSON.isEmpty, let data = storedActivityTimersJSON.data(using: .utf8) else {
            persistActivityTimers(activityTimers)
            return
        }
        if let decoded = try? JSONDecoder().decode([ActivityTimerItem].self, from: data) {
            activityTimers = decoded
        }
    }

    private func persistActivityTimers(_ items: [ActivityTimerItem]) {
        if let data = try? JSONEncoder().encode(items), let json = String(data: data, encoding: .utf8) {
            storedActivityTimersJSON = json
        }
    }

    
    private func rebuildDailyTaskItems(using day: Day?) {
        let completions = day?.dailyTaskCompletions ?? []
        let accent = accentOverride ?? .accentColor
        let items = account.dailyTasks.compactMap { def -> DailyTaskItem? in
            let completion = completions.first(where: { $0.id == def.id })
            if !def.repeats && completion == nil {
                return nil
            }

            let colorHex = def.colorHex.isEmpty ? accent.toHexString() : def.colorHex
            return DailyTaskItem(
                id: def.id,
                name: def.name,
                time: def.time,
                colorHex: colorHex,
                isCompleted: completion?.isCompleted ?? false,
                repeats: def.repeats
            )
        }
        .sorted { $0.time < $1.time }

        dailyTaskItems = items
    }

    private func ensureCurrentDay() -> Day {
        if let day = currentDay {
            return day
        }
        let created = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros)
        currentDay = created
        return created
    }

    private func applyTaskEditorChanges(_ items: [DailyTaskItem]) {
        let definitions = items.map { item in
            DailyTaskDefinition(id: item.id, name: item.name, time: item.time, colorHex: item.colorHex, repeats: item.repeats)
        }

        account.dailyTasks = definitions
        persistAccount()

        let day = ensureCurrentDay()
        let allowedIds = Set(definitions.map { $0.id })
        var completions = day.dailyTaskCompletions.filter { allowedIds.contains($0.id) }

        let nonRepeatingIds = definitions.filter { !$0.repeats }.map { $0.id }
        for id in nonRepeatingIds where !completions.contains(where: { $0.id == id }) {
            completions.append(DailyTaskCompletion(id: id, isCompleted: false))
        }

        day.dailyTaskCompletions = completions
        persistDay(day)
        rebuildDailyTaskItems(using: currentDay)
    }

    private func handleTaskToggle(id: String, isCompleted: Bool) {
        let day = ensureCurrentDay()
        if let idx = day.dailyTaskCompletions.firstIndex(where: { $0.id == id }) {
            day.dailyTaskCompletions[idx].isCompleted = isCompleted
        } else {
            day.dailyTaskCompletions.append(DailyTaskCompletion(id: id, isCompleted: isCompleted))
        }
        persistDay(day)
    }

    private func handleTaskRemove(id: String) {
        account.dailyTasks.removeAll { $0.id == id }
        persistAccount()

        if let day = currentDay {
            day.dailyTaskCompletions.removeAll { $0.id == id }
            persistDay(day)
        }

        dailyTaskItems.removeAll { $0.id == id }
    }

    private func pruneCompletions(for day: Day) {
        let allowedIds = Set(account.dailyTasks.map { $0.id })
        day.dailyTaskCompletions.removeAll { !allowedIds.contains($0.id) }
    }

    private func persistDay(_ day: Day) {
        do {
            try modelContext.save()
        } catch {
            print("RoutineTabView: failed to save Day locally: \(error)")
        }

        dayService.saveDay(day) { success in
            if !success {
                print("RoutineTabView: failed to sync Day to Firestore for date=\(day.date)")
            }
        }
    }

    private func persistAccount() {
        do {
            try modelContext.save()
        } catch {
            print("RoutineTabView: failed to save Account locally: \(error)")
        }

        accountService.saveAccount(account) { success in
            if !success {
                print("RoutineTabView: failed to sync Account daily tasks to Firestore")
            }
        }
    }
}

private enum HabitDayStatus {
    case tracked
    case notTracked

    var timelineSymbol: String? {
        switch self {
        case .tracked: return "circle.fill"
        case .notTracked: return "circle"
        }
    }

    var shouldHideTimelineNode: Bool { false }

    var accentColor: Color {
        switch self {
        case .tracked:
            return Color.accentColor
        case .notTracked:
            return Color(.systemGray3)
        }
    }
}

private struct HabitProgressTimelineView: View {
    let daySymbols: [String]
    let statuses: [HabitDayStatus]
    let accentColor: Color

    private let nodeHeight: CGFloat = 56
    private let symbolSize: CGFloat = 20
    private let connectorColor = Color.black.opacity(0.55)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    let totalWidth = proxy.size.width
                    let safeCount = max(daySymbols.count, 1)
                    let cellWidth = totalWidth / CGFloat(safeCount)
                    let connectorWidth = max(cellWidth - symbolSize, 0)
                    let yPosition = symbolSize / 2

                    ForEach(0..<max(daySymbols.count - 1, 0), id: \.self) { index in
                        if shouldDrawConnector(at: index) {
                            Rectangle()
                                .fill(connectorColor)
                                .frame(width: connectorWidth, height: 1)
                                .position(x: cellWidth * (CGFloat(index) + 1), y: yPosition)
                        }
                    }
                }
                .frame(height: nodeHeight)
                .allowsHitTesting(false)

                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(daySymbols.enumerated()), id: \.0) { index, label in
                        timelineNode(for: index, label: label)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineNode(for index: Int, label: String) -> some View {
        let status = statuses.indices.contains(index) ? statuses[index] : .notTracked
        let isHidden = status.shouldHideTimelineNode
        VStack(spacing: 6) {
            if let symbol = status.timelineSymbol {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .frame(height: symbolSize)
                    .foregroundStyle(status == .tracked ? accentColor : Color(.systemGray3))
                    .fixedSize()
            } else {
                Color.clear.frame(height: symbolSize)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .frame(height: nodeHeight, alignment: .top)
        .opacity(isHidden ? 0 : 1)
    }

    private func shouldDrawConnector(at index: Int) -> Bool {
        let current = status(at: index)
        let next = status(at: index + 1)
        return !current.shouldHideTimelineNode && !next.shouldHideTimelineNode
    }

    private func status(at index: Int) -> HabitDayStatus {
        guard statuses.indices.contains(index) else { return .notTracked }
        return statuses[index]
    }
}

private struct HabitTrackingSection: View {
    @Binding var habits: [HabitItem]
    let accentColor: Color
    let currentDayIndex: Int = Calendar.current.component(.weekday, from: Date()) - 1

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
    VStack(alignment: .leading, spacing: 12) {
            let palette: [Color] = [.purple, .orange, .pink, .teal, .mint, .yellow, .green]
            ForEach(habits.indices, id: \.self) { idx in
                let habit = habits[idx]
                let rowColor: Color = {
                    if !habit.colorHex.isEmpty, let c = Color(hex: habit.colorHex) {
                        return c
                    }
                    return palette[idx % palette.count]
                }()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(habit.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.bottom, 8)

                        HabitProgressTimelineView(daySymbols: daySymbols, statuses: habit.weeklyProgress, accentColor: rowColor)
                            .frame(height: 60)
                    }

                    Button(action: { checkIn(habitId: habit.id) }) {
                        Image(systemName: (habit.weeklyProgress.indices.contains(currentDayIndex) && habit.weeklyProgress[currentDayIndex] == .tracked) ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle((habit.weeklyProgress.indices.contains(currentDayIndex) && habit.weeklyProgress[currentDayIndex] == .tracked) ? rowColor : Color(.systemGray3))
                    }
                    .buttonStyle(HabitCompactButtonStyle(background: Color(.systemBackground)))
                }
                .padding(.top, 6)
                .background(Color.clear)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func checkIn(habitId: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitId }) else { return }
        guard habits[idx].weeklyProgress.indices.contains(currentDayIndex) else { return }
        let current = habits[idx].weeklyProgress[currentDayIndex]
        switch current {
        case .tracked:
            // tapping again removes the tracked mark for today
            habits[idx].weeklyProgress[currentDayIndex] = .notTracked
        default:
            habits[idx].weeklyProgress[currentDayIndex] = .tracked
        }
    }
}

private struct HabitTrackingButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 12.0))
    }
}

private struct HabitCompactButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .glassEffect(in: .rect(cornerRadius: 12.0))
    }
}

private extension RoutineTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .routine)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    var workoutTimelineAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color.yellow
        }
        return accentOverride ?? .accentColor
    }
}
