//
//  RoutineTabView.swift
//  Trackerio
//
//  Created by Kyle Graham on 4/12/2025.
//

import SwiftUI
import SwiftData
import UserNotifications
import TipKit

fileprivate struct HabitItem: Identifiable {
    var id: UUID
    var name: String
    var weeklyProgress: [HabitDayStatus]
    var colorHex: String = ""

    init(id: UUID = UUID(), name: String, weeklyProgress: [HabitDayStatus], colorHex: String = "") {
        self.id = id
        self.name = name
        self.weeklyProgress = weeklyProgress
        self.colorHex = colorHex
    }
}

private struct HabitsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var habits: [HabitItem]
    var isPro: Bool
    var onSave: ([HabitItem]) -> Void

    @State private var working: [HabitItem] = []
    @State private var newName: String = ""
    @State private var hasLoaded: Bool = false

    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: UUID?
    @State private var showProSubscription: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    private let freeHabits = 3
    private let proHabits = 8
    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeHabits
    }
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
                                            // Only allow color picking in multiColour theme
                                            guard themeManager.selectedTheme == .multiColour else { return }
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            let resolved = Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor
                                            let effective = themeManager.selectedTheme == .multiColour ? resolved : themeManager.selectedTheme.accent(for: colorScheme)
                                            Circle()
                                                .fill(effective.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "checklist") .foregroundStyle(effective))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(themeManager.selectedTheme != .multiColour)
                                        .opacity(themeManager.selectedTheme == .multiColour ? 1 : 0.9)

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
                                        let presetResolved = Color(hex: preset.colorHex) ?? Color.accentColor
                                        let presetEffective = themeManager.selectedTheme == .multiColour ? presetResolved : themeManager.selectedTheme.accent(for: colorScheme)
                                        Circle()
                                            .fill(presetEffective.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "checklist") .foregroundStyle(presetEffective))

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

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock unlimited habit slots + benefits")
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

                            if !isPro {
                                Text("You can track up to \(freeHabits) habits.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
            // Only present the color picker when using multiColour theme
            if themeManager.selectedTheme == .multiColour {
                ColorPickerSheet { hex in
                    applyColor(hex: hex)
                    showColorPickerSheet = false
                } onCancel: {
                    showColorPickerSheet = false
                }
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
            } else {
                // Fallback empty view to satisfy sheet when theme disallows color picking
                EmptyView()
            }
        }
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
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

struct RoutineTabView: View {
    @Binding var account: Account
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @Binding var goals: [GoalItem]
    @Binding var habits: [HabitDefinition]
    @Binding var groceryItems: [GroceryItem]
    @Binding var activityTimers: [ActivityTimerItem]
    @Binding var expenseCurrencySymbol: String
    @Binding var expenseCategories: [ExpenseCategory]
    @Binding var expenseEntries: [ExpenseEntry]
    @Binding var nightSleepSeconds: TimeInterval
    @Binding var napSleepSeconds: TimeInterval
    var isPro: Bool
    var onUpdateActivityTimers: ([ActivityTimerItem]) -> Void
    var onUpdateHabits: ([HabitDefinition]) -> Void
    var onUpdateGoals: ([GoalItem]) -> Void
    var onUpdateGroceryItems: ([GroceryItem]) -> Void
    var onUpdateExpenseCategories: ([ExpenseCategory], String) -> Void
    var onSaveExpenseEntry: (ExpenseEntry) -> Void
    var onDeleteExpenseEntry: (UUID) -> Void
    var onUpdateSleep: (TimeInterval, TimeInterval) -> Void
    var onLiveSleepUpdate: (TimeInterval, TimeInterval) -> Void
    @State private var showAccountsView = false
    @State private var showProSheet = false
    @State private var dailyTaskItems: [DailyTaskItem] = []
    @State private var currentDay: Day?

    @State private var habitItems: [HabitItem] = []
    @State private var watchedEntertainmentItems: [WatchedEntertainmentItem] = []
    @State private var showEntertainmentLog = false

    @State private var weekStartsOnMonday: Bool = true
    @State private var showDailyTasksEditor: Bool = false
    @State private var showActivityTimersEditor: Bool = false
    @State private var showGoalsEditor: Bool = false
    @State private var showHabitsEditor: Bool = false
    @State private var showGroceryListEditor: Bool = false
    @State private var showExpenseCategoriesEditor: Bool = false
    @State private var showMusicSourcesSheet: Bool = false
    @State private var showRoutineShareSheet: Bool = false
    @AppStorage("alerts.dailyTasksEnabled") private var dailyTasksAlertsEnabled: Bool = true
    @AppStorage("alerts.habitsEnabled") private var habitsAlertsEnabled: Bool = true
    @AppStorage("alerts.habitsTime") private var habitsTime: Double = 9 * 3600

    private let dayService = DayFirestoreService()
    private let accountService = AccountFirestoreService()

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            HeaderComponent(showCalendar: $showCalendar, selectedDate: $selectedDate, onProfileTap: { showAccountsView = true }, isPro: isPro)
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
                            .routineTip(.editTasks, onStepChange: { step in
                                if step == 2 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo("goals", anchor: .top)
                                        }
                                    }
                                }
                            })
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 38)
                        .id("dailyTasks")
                        
                        DailyTasksSection(
                            accentColorOverride: accentOverride,
                            tasks: $dailyTaskItems,
                            onToggle: { id, isCompleted in
                                handleTaskToggle(id: id, isCompleted: isCompleted)
                            },
                            onRemove: { id in
                                handleTaskRemove(id: id)
                            },
                            day: $currentDay
                        )
                        .routineTip(.dailyTasks)
                        .padding(.bottom, -10)
                        
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
                        .padding(.top, 38)
                        
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
                            .routineTip(.editGoals, onStepChange: { step in
                                if step == 4 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo("habits", anchor: .top)
                                        }
                                    }
                                }
                            })
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 38)
                        .id("goals")

                        GoalsSection(accentColorOverride: accentOverride, goals: $goals)
                            .routineTip(.goals)

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
                        .padding(.top, 38)
                        .padding(.horizontal, 18)
                        .id("habits")

                        HabitTrackingSection(
                            habits: $habitItems,
                            accentColor: accentOverride ?? .accentColor,
                            currentDayIndex: weekdayIndex(for: selectedDate),
                            onToggle: { habitId, isCompleted in
                                handleHabitToggle(habitId: habitId, isCompleted: isCompleted)
                            }
                        )
                        .routineTip(.habits, onStepChange: { step in
                            if step == 5 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("expenseTracker", anchor: .top)
                                    }
                                }
                            }
                        })
                        
                        HStack {
                            Text("Music Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            // Button {
                            //     showMusicSourcesSheet = true
                            // } label: {
                            //     Label("Manage", systemImage: "gear")
                            //         .font(.callout)
                            //         .fontWeight(.medium)
                            //         .padding(.horizontal, 12)
                            //         .padding(.vertical, 8)
                            //         .glassEffect(in: .rect(cornerRadius: 18.0))
                            // }
                            // .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 38)
                        .padding(.horizontal, 18)

                        MusicTrackingSection()
                            .padding(.horizontal, 18)
                            .padding(.top, 12)

                        HStack {
                            Text("Entertainment Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 38)
                        .padding(.horizontal, 18)

                        Button {
                            showEntertainmentLog = true
                        } label: {
                            Label("Log Watched", systemImage: "plus")
                              .font(.callout.weight(.semibold))
                              .padding(.vertical, 18)
                              .frame(maxWidth: .infinity, minHeight: 52)
                              .glassEffect(in: .rect(cornerRadius: 16.0))
                              .contentShape(Rectangle())
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 18)
                        .buttonStyle(.plain)

                        EntertainmentTrackingSection(watchedItems: $watchedEntertainmentItems)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 8)
                        .glassEffect(in: .rect(cornerRadius: 16.0))
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .sheet(isPresented: $showEntertainmentLog) {
                            LogWatchedSheet(isPresented: $showEntertainmentLog) { newItem in
                                watchedEntertainmentItems.append(newItem)
                            }
                        }


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
                        .padding(.top, 38)
                        .padding(.horizontal, 18)
                        .id("groceryList")

                        GroceryListSection(accentColorOverride: accentOverride, items: $groceryItems)

                        // MARK: - Expense Tracker Section
                        VStack(spacing: 0) {
                            HStack {
                                Text("Expense Tracking")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .routineTip(.expenseTracker)

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
                                .routineTip(.editCategories)
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 38)
                            .padding(.horizontal, 18)
                            .id("expenseTracker")

                            ExpenseTrackerSection(
                                accentColorOverride: accentOverride,
                                currencySymbol: expenseCurrencySymbol,
                                categories: $expenseCategories,
                                weekEntries: $expenseEntries,
                                anchorDate: selectedDate,
                                onSaveEntry: { entry in
                                    onSaveExpenseEntry(entry)
                                },
                                onDeleteEntry: { id in
                                    onDeleteExpenseEntry(id)
                                }
                            )
                        }
                        .opacity(isPro ? 1 : 0.5)
                        .blur(radius: isPro ? 0 : 4)
                        .disabled(!isPro)
                        .overlay {
                            if !isPro {
                                ZStack {
                                    Color.black.opacity(0.001) // Capture taps
                                        .onTapGesture {
                                            // Optional: Trigger upgrade flow
                                        }
                                    Button {
                                        showProSheet = true
                                    } label: {
                                        VStack(spacing: 8) {
                                            HStack {
                                                let accent = themeManager.selectedTheme == .multiColour ? nil : themeManager.selectedTheme.accent(for: colorScheme)

                                                if let accent {
                                                    Image("logo")
                                                        .resizable()
                                                        .renderingMode(.template)
                                                        .foregroundStyle(accent)
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(height: 40)
                                                        .padding(.leading, 4)
                                                        .offset(y: 6)
                                                } else {
                                                    Image("logo")
                                                        .resizable()
                                                        .renderingMode(.original)
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(height: 40)
                                                        .padding(.leading, 4)
                                                        .offset(y: 6)
                                                }
                                                
                                                Text("PRO")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(Color.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                            .fill(
                                                                accent.map {
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [$0, $0.opacity(0.85)]),
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    )
                                                                } ?? LinearGradient(
                                                                    gradient: Gradient(colors: [
                                                                        Color(red: 0.74, green: 0.43, blue: 0.97),
                                                                        Color(red: 0.83, green: 0.99, blue: 0.94)
                                                                    ]),
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                )
                                                            )
                                                    )
                                                    .offset(y: 6)
                                            }
                                            .padding(.bottom, 5)

                                            Text("Trackerio Pro")
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            Text("Upgrade to unlock Expenses + More")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .glassEffect(in: .rect(cornerRadius: 16.0))
                                    }
                                    .buttonStyle(.plain)
                                    .sheet(isPresented: $showProSheet) {
                                        ProSubscriptionView()
                                    }
                                }
                            }
                        }

                        // Share Routine CTA (styled like ShareProgressCTA)
                        Button {
                            showRoutineShareSheet = true
                        } label: {
                            let accent = accentOverride ?? .accentColor
                            let gradientColors = [accent, accent.opacity(0.75), accent.opacity(0.35)]
                            let glowColor = accent.opacity(0.45)

                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Share Routine Stats")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text("Highlight your achievements!")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white.opacity(0.85))
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(accent.opacity(0.25))
                                    .clipShape(Circle())
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(
                                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: glowColor, radius: 18, x: 0, y: 18)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
                }
                if showCalendar {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { showCalendar = false }
                    CalendarComponent(selectedDate: $selectedDate, showCalendar: $showCalendar)
                }
            }
            .navigationDestination(isPresented: $showAccountsView) {
                AccountsView(account: $account)
                    .toolbar(.hidden, for: .tabBar)
            }
            .sheet(isPresented: $showDailyTasksEditor) {
                DailyTasksEditorView(tasks: $dailyTaskItems, isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty, onSave: applyTaskEditorChanges)
            }
            .sheet(isPresented: $showActivityTimersEditor) {
                ActivityTimersEditorView(timers: $activityTimers, isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty, onSave: applyActivityTimerChanges)
            }
            .sheet(isPresented: $showGoalsEditor) {
                GoalsEditorView(goals: $goals, isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty, onSave: applyGoalsEditorChanges)
            }
            .sheet(isPresented: $showGroceryListEditor) {
                GroceryListEditorView(items: $groceryItems, onSave: applyGroceryListChanges)
            }
            .sheet(isPresented: $showHabitsEditor) {
                HabitsEditorView(habits: $habitItems, isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty, onSave: applyHabitsEditorChanges)
            }
            .sheet(isPresented: $showExpenseCategoriesEditor) {
                ExpenseCategoriesEditorView(categories: $expenseCategories, currencySymbol: $expenseCurrencySymbol, onSave: applyExpenseCategoryChanges)
            }
            .sheet(isPresented: $showMusicSourcesSheet) {
                MusicSourcesSheet()
            }
            .sheet(isPresented: $showRoutineShareSheet) {
                RoutineShareSheet(
                    accentColor: accentOverride ?? .accentColor,
                    taskCompletionPercent: routineTaskCompletionPercent(),
                    completedGoals: routineCompletedGoalsSnapshot(),
                    habitStatuses: routineHabitSnapshots(),
                    expenseBars: routineExpenseBars(),
                    expenseCategories: expenseCategories
                )
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
        .onAppear {
            loadDailyTasks()
            loadHabitWeek()
            refreshNotifications()
        }
        .onChange(of: selectedDate) { _, _ in
            loadDailyTasks()
            loadHabitWeek()
        }
        .onChange(of: account.id) { _, _ in
            rebuildDailyTaskItems(using: currentDay)
        }
        .onChange(of: account.dailyTasks) { _, _ in
            rebuildDailyTaskItems(using: currentDay)
        }
        .onChange(of: habits) { _, newValue in
            rebuildHabits(using: newValue)
            onUpdateHabits(newValue)
            loadHabitWeek()
        }
        .onChange(of: groceryItems) { _, newValue in
            onUpdateGroceryItems(newValue)
        }
        .onChange(of: goals) { _, newValue in
            onUpdateGoals(newValue)
        }
        .onChange(of: habitsTime) { _, _ in
            refreshNotifications()
        }
        
    }
}

// MARK: - Habit Tracking Views

private struct DailyTasksEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [DailyTaskItem]
    var isPro: Bool
    var onSave: ([DailyTaskItem]) -> Void
    @State private var working: [DailyTaskItem] = []
    @State private var newName: String = ""
    @State private var newTimeDate: Date = Date()
    @State private var hasLoaded: Bool = false
    @State private var showProSubscription: Bool = false
    
    
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: String?

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme

    private var presets: [DailyTaskItem] {
        [
            DailyTaskItem(name: "Wake Up", time: "07:00", colorHex: "#D84A4A"),
            DailyTaskItem(name: "Coffee", time: "08:00", colorHex: "#E39A3B"),
            DailyTaskItem(name: "Stretch", time: "09:00", colorHex: "#4A7BD0"),
            DailyTaskItem(name: "Lunch", time: "12:30", colorHex: "#4CAF6A"),
            DailyTaskItem(name: "Workout", time: "18:00", colorHex: "#E6C84F")
        ]
    }

    private let freeTracked = 12
    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeTracked
    }
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
                                            guard themeManager.selectedTheme == .multiColour else { return }
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            let resolved = Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor
                                            let effective = themeManager.selectedTheme == .multiColour ? resolved : themeManager.selectedTheme.accent(for: colorScheme)
                                            Circle()
                                                .fill(effective.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "checklist") .foregroundStyle(effective))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(themeManager.selectedTheme != .multiColour)
                                        .opacity(themeManager.selectedTheme == .multiColour ? 1 : 0.95)
                                        
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

                    // Quick Add
                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        let presetResolved = Color(hex: preset.colorHex) ?? Color.accentColor
                                        let presetEffective = themeManager.selectedTheme == .multiColour ? presetResolved : themeManager.selectedTheme.accent(for: colorScheme)
                                        Circle()
                                            .fill(presetEffective.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "checklist") .foregroundStyle(presetEffective))

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text(preset.time)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            let plusColor = themeManager.selectedTheme == .multiColour ? Color.accentColor : themeManager.selectedTheme.accent(for: colorScheme)
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(plusColor)
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

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
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
                                    let plusColor = themeManager.selectedTheme == .multiColour ? Color.accentColor : themeManager.selectedTheme.accent(for: colorScheme)
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(plusColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            if !isPro {
                                Text("You can track up to \(freeTracked) tasks.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
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
            if themeManager.selectedTheme == .multiColour {
                ColorPickerSheet { hex in
                    applyColor(hex: hex)
                    showColorPickerSheet = false
                } onCancel: {
                    showColorPickerSheet = false
                }
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        // Preserve an explicitly empty `tasks` selection — do not replace with defaults.
        working = tasks
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
            working.append(preset)
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
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @Binding var timers: [ActivityTimerItem]
    var isPro: Bool
    var onSave: ([ActivityTimerItem]) -> Void
    @State private var working: [ActivityTimerItem] = []
    @State private var newName: String = ""
    @State private var customHours: String = ""
    @State private var customMinutes: String = ""
    @State private var hasLoaded: Bool = false
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: String?
    @State private var showProSubscription: Bool = false

    private let minDuration = 10
    private let maxDuration = 180

    private let freeTimersAllowed = 2
    private let proTimersAllowed = 6
    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeTimersAllowed
    }
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
                                            guard themeManager.selectedTheme == .multiColour else { return }
                                            colorPickerTargetId = working[idx].id
                                            showColorPickerSheet = true
                                        } label: {
                                            let resolved = Color(hex: binding.colorHex.wrappedValue) ?? Color.accentColor
                                            let effective = themeManager.selectedTheme == .multiColour ? resolved : themeManager.selectedTheme.accent(for: colorScheme)
                                            Circle()
                                                .fill(effective.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(Image(systemName: "clock") .foregroundStyle(effective))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(themeManager.selectedTheme != .multiColour)
                                        .opacity(themeManager.selectedTheme == .multiColour ? 1 : 0.95)

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextField("Name", text: binding.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack(spacing: 12) {
                                                HStack {
                                                    TextField("0", text: hourBinding(for: binding))
                                                        .keyboardType(.numberPad)
                                                        .textFieldStyle(.plain)
                                                    Text("hrs")
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding()
                                                .surfaceCard(16)
                                                .frame(maxWidth: .infinity)

                                                HStack {
                                                    TextField("0  ", text: minuteBinding(for: binding))
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

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        let presetResolved = Color(hex: preset.colorHex) ?? Color.accentColor
                                        let presetEffective = themeManager.selectedTheme == .multiColour ? presetResolved : themeManager.selectedTheme.accent(for: colorScheme)
                                        Circle()
                                            .fill(presetEffective.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(Image(systemName: "clock") .foregroundStyle(presetEffective))

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("Duration \(preset.durationMinutes) min")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            let plusColor = themeManager.selectedTheme == .multiColour ? Color.accentColor : themeManager.selectedTheme.accent(for: colorScheme)
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(plusColor)
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

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock unlimited grocery slots + other benefits")
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
                                    TextField("0", text: $customHours)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                    Text("hrs")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(16)
                                .frame(maxWidth: .infinity)

                                HStack {
                                    TextField("0", text: $customMinutes)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                    Text("min")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(16)
                                .frame(maxWidth: .infinity)

                                Button(action: addCustomTimer) {
                                    let plusColor = themeManager.selectedTheme == .multiColour ? Color.accentColor : themeManager.selectedTheme.accent(for: colorScheme)
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(plusColor)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                        }
                        if !isPro {
                            Text("You can track up to \(freeTimersAllowed) timers.")
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
            if themeManager.selectedTheme == .multiColour {
                ColorPickerSheet { hex in
                    applyColor(hex: hex)
                    showColorPickerSheet = false
                } onCancel: {
                    showColorPickerSheet = false
                }
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    private func loadInitial() {
        guard !hasLoaded else { return }
        // Respect an explicitly-empty timers list; do not substitute defaults for UI editing.
        let initial = timers
        let limit = isPro ? 9999 : freeTimersAllowed
        working = Array(initial.prefix(limit))
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
        guard canAddMore else { return }
        working.append(newTimer)
        newName = ""
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        let limit = isPro ? proTimersAllowed : freeTimersAllowed
        onSave(Array(working.prefix(limit)))
        dismiss()
    }
}

private struct GoalsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Binding var goals: [GoalItem]
    var isPro: Bool
    var onSave: ([GoalItem]) -> Void
    @State private var working: [GoalItem] = []
    @State private var newName: String = ""
    @State private var newNote: String = ""
    @State private var newDate: Date = Date()
    @State private var hasLoaded: Bool = false
    @State private var showProSubscription: Bool = false
    
    private let freeGoals = 12
    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeGoals
    }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var presets: [GoalItem] {
        let cal = Calendar.current
        let today = Date()
        let in3 = cal.date(byAdding: .day, value: 3, to: today) ?? today
        let in14 = cal.date(byAdding: .day, value: 14, to: today) ?? today
        return [
            GoalItem(title: "Stop eating fast food", note: "Focus on home-cooked meals", dueDate: in3),
            GoalItem(title: "Drop 5 kg in weight", note: "Maintain a healthy diet and exercise routine", dueDate: in14),
            GoalItem(title: "Get a job", note: "Update resume and apply to at least 5 positions", dueDate: in14),
            GoalItem(title: "Get promoted", note: "Take on additional responsibilities at work", dueDate: in14),
            GoalItem(title: "Travel to Bali", note: "Plan itinerary and book accommodations", dueDate: in14),
            GoalItem(title: "Travel around Europe", note: "Visit at least 3 new countries", dueDate: in14),
            GoalItem(title: "Gain financial freedom", note: "Create a budget and start investing", dueDate: in14),
            GoalItem(title: "Find a soulmate", note: "Join social groups and attend events", dueDate: in14)
        ]
    }



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

                    if !isPro {
                        if !isPro {
                            Button(action: { showProSubscription = true }) {
                                HStack(alignment: .center) {
                                    Image(systemName: "sparkles")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.trailing, 8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Upgrade to Pro")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("Unlock unlimited goal slots + other benefits")
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
                        if !isPro {
                            Text("You can track up to \(freeGoals) goals.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
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

    private var presets: [GroceryItem] {
        [
            GroceryItem(title: "Greek Yogurt", note: "32 oz tub"),
            GroceryItem(title: "Blueberries", note: "1 pint"),
            GroceryItem(title: "Brown Rice", note: "2 lb bag")
        ]
    }

    private var canAddCustom: Bool { !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
        } else {
            var new = preset
            new = GroceryItem(title: new.title, note: new.note, isChecked: false)
            working.append(new)
        }
    }

    private func isPresetSelected(_ preset: GroceryItem) -> Bool {
        return working.contains { $0.title == preset.title }
    }

    private func donePressed() {
        onSave(working)
        dismiss()
    }
}

private struct ExpenseCategoriesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var categories: [ExpenseCategory]
    @Binding var currencySymbol: String
    var onSave: ([ExpenseCategory], String) -> Void

    @State private var working: [ExpenseCategory] = []
    @State private var hasLoaded: Bool = false
    @State private var showColorPickerSheet: Bool = false
    @State private var colorPickerTargetId: Int?
    @State private var workingCurrencySymbol: String = ""
    @State private var customCurrencyInput: String = ""
    @FocusState private var focusedCategoryId: Int?

    // Predefined currency symbol options for the editor
    private let currencyOptions: [String] = ["$", "€", "£", "¥", "₹", "₩", "₱", "Rp"]
    private let currencyPillColumns: [GridItem] = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tracked Categories")
                        .font(.subheadline.weight(.semibold))

                    VStack(spacing: 12) {
                        ForEach($working) { $category in
                            HStack(spacing: 12) {
                                Button {
                                    colorPickerTargetId = category.id
                                    showColorPickerSheet = true
                                } label: {
                                    Circle()
                                        .fill((Color(hex: category.colorHex) ?? Color.accentColor).opacity(0.2))
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

                                    HStack(spacing: 8) {
                                        TextField("Name", text: $category.name)
                                            .font(.subheadline.weight(.semibold))
                                            .textInputAutocapitalization(.words)
                                            .focused($focusedCategoryId, equals: category.id)

                                        Spacer()
                                        
                                        Button {
                                            focusedCategoryId = category.id
                                        } label: {
                                            Image(systemName: "pencil")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Currency")
                            .font(.subheadline.weight(.semibold))

                        LazyVGrid(columns: currencyPillColumns, alignment: .leading, spacing: 12) {
                            ForEach(currencyOptions, id: \.self) { option in
                                SelectablePillComponent(
                                    label: option,
                                    isSelected: workingCurrencySymbol == option,
                                    selectedTint: Color.accentColor
                                ) {
                                    workingCurrencySymbol = option
                                    customCurrencyInput = ""
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Enter custom currency", text: $customCurrencyInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .onChange(of: customCurrencyInput) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmed.isEmpty {
                                        if !currencyOptions.contains(workingCurrencySymbol) {
                                            workingCurrencySymbol = ""
                                        }
                                        return
                                    }
                                    workingCurrencySymbol = trimmed
                                }

                            Text("You may use any currency symbol or abbreviation.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { donePressed() }
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
        // Merge existing categories with defaults so editor always shows the full set
        let defaults = ExpenseCategory.defaultCategories()
        var normalized: [ExpenseCategory] = []
        for idx in 0..<defaults.count {
            if let existing = categories.first(where: { $0.id == idx }) {
                // keep existing but fall back to default fields when empty
                let name = existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaults[idx].name : existing.name
                let color = existing.colorHex.isEmpty ? defaults[idx].colorHex : existing.colorHex
                normalized.append(ExpenseCategory(id: idx, name: name, colorHex: color))
            } else {
                normalized.append(defaults[idx])
            }
        }
        working = normalized
        workingCurrencySymbol = currencySymbol
        if !currencyOptions.contains(currencySymbol) {
            customCurrencyInput = currencySymbol
        }
        hasLoaded = true
    }

    private func applyColor(hex: String) {
        guard let targetId = colorPickerTargetId, let idx = working.firstIndex(where: { $0.id == targetId }) else { return }
        working[idx].colorHex = hex
    }

    private func donePressed() {
        // Ensure any UI state updates (e.g. quick taps on currency pills) are applied
        // before we resolve and persist the currency symbol. Dispatching to the
        // next runloop tick avoids a race where a rapid tap + Done could read
        // a stale value.
        DispatchQueue.main.async {
            let trimmed = self.workingCurrencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedCurrency = trimmed.isEmpty ? Account.deviceCurrencySymbol : trimmed
            self.onSave(self.working, resolvedCurrency)
            self.dismiss()
        }
    }
}

// MARK: - Daily task persistence
extension RoutineTabView {
    private func applyGoalsEditorChanges(_ items: [GoalItem]) {
        goals = items
        onUpdateGoals(items)
    }

    private func applyGroceryListChanges(_ items: [GroceryItem]) {
        groceryItems = Array(items.prefix(8))
        onUpdateGroceryItems(groceryItems)
    }

    private func applyExpenseCategoryChanges(_ items: [ExpenseCategory], currencySymbol: String) {
        let defaults = ExpenseCategory.defaultCategories()
        var normalized: [ExpenseCategory] = []
        let trimmedCurrency = currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCurrency = trimmedCurrency.isEmpty ? Account.deviceCurrencySymbol : trimmedCurrency

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
        expenseCurrencySymbol = resolvedCurrency
        onUpdateExpenseCategories(normalized, resolvedCurrency)
    }

    private func applyActivityTimerChanges(_ items: [ActivityTimerItem]) {
        // Persist exactly what the user provided; allow empty arrays to be saved.
        activityTimers = items
        onUpdateActivityTimers(activityTimers)
    }

    private func applyHabitsEditorChanges(_ items: [HabitItem]) {
        let limit = isPro ? 8 : 3
        habitItems = Array(items.prefix(limit))
        let defs = habitItems.map { HabitDefinition(id: $0.id, name: $0.name, colorHex: $0.colorHex) }
        account.habits = defs
        onUpdateHabits(defs)
        persistAccount()
        rebuildHabitProgress(using: currentDay)
        loadHabitWeek()
    }

    private func loadDailyTasks() {
        // Load from local cache immediately
        let localDay = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros)
        currentDay = localDay
        pruneCompletions(for: localDay)
        pruneHabitCompletions(for: localDay)
        rebuildDailyTaskItems(using: localDay)
        rebuildHabitProgress(using: localDay)

        dayService.fetchDay(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros) { day in
            DispatchQueue.main.async {
                let resolvedDay = day ?? Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros)
                currentDay = resolvedDay
                pruneCompletions(for: resolvedDay)
                pruneHabitCompletions(for: resolvedDay)
                rebuildDailyTaskItems(using: resolvedDay)
                rebuildHabitProgress(using: resolvedDay)
            }
        }
    }

    private func loadHabitWeek() {
        let dates = weekDates(for: selectedDate)
        
        // Load locally immediately
        var localDayMap: [Date: Day] = [:]
        for date in dates {
            let localDay = Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: account.trackedMacros)
            pruneHabitCompletions(for: localDay)
            localDayMap[Calendar.current.startOfDay(for: date)] = localDay
        }
        rebuildHabitProgress(using: localDayMap)

        let group = DispatchGroup()
        var remoteDayMap: [Date: Day] = [:]

        for date in dates {
            group.enter()
            dayService.fetchDay(for: date, in: modelContext, trackedMacros: account.trackedMacros) { day in
                DispatchQueue.main.async {
                    let resolvedDay = day ?? Day.fetchOrCreate(for: date, in: modelContext, trackedMacros: account.trackedMacros)
                    pruneHabitCompletions(for: resolvedDay)
                    remoteDayMap[Calendar.current.startOfDay(for: date)] = resolvedDay
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            rebuildHabitProgress(using: remoteDayMap)
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

    // Refresh habit definitions and visible items when the bound habits change.
    private func rebuildHabits(using definitions: [HabitDefinition]) {
        let resolved = definitions.isEmpty ? HabitDefinition.defaults : definitions
        account.habits = resolved
        if let day = currentDay {
            pruneHabitCompletions(for: day)
        }
        rebuildHabitProgress(using: currentDay)
        
        if habitsAlertsEnabled {
            let day = ensureCurrentDay()
            let completedHabitIds = Set(day.habitCompletions.filter { $0.isCompleted }.map { $0.habitId })
            NotificationsHelper.scheduleHabitNotifications(resolved, completedHabitIds: completedHabitIds)
        } else {
            NotificationsHelper.removeHabitNotifications()
        }
    }

    private func ensureCurrentDay() -> Day {
        if let day = currentDay {
            return day
        }
        let created = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: account.trackedMacros)
        currentDay = created
        return created
    }

    private func refreshNotifications() {
        let day = ensureCurrentDay()
        
        if dailyTasksAlertsEnabled {
            let completedIds = Set(day.dailyTaskCompletions.filter { $0.isCompleted }.map { $0.id })
            NotificationsHelper.scheduleDailyTaskNotifications(account.dailyTasks, completedTaskIds: completedIds, silenceCompleted: true)
        }
        
        if habitsAlertsEnabled {
            let completedHabitIds = Set(day.habitCompletions.filter { $0.isCompleted }.map { $0.habitId })
            NotificationsHelper.scheduleHabitNotifications(account.habits, completedHabitIds: completedHabitIds)
        }
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
        
        // Replace scheduled notifications for daily tasks with the updated set
        if dailyTasksAlertsEnabled {
            let completedIds = Set(completions.filter { $0.isCompleted }.map { $0.id })
            NotificationsHelper.scheduleDailyTaskNotifications(definitions, completedTaskIds: completedIds, silenceCompleted: true)
        } else {
            NotificationsHelper.removeDailyTaskNotifications()
        }

        rebuildDailyTaskItems(using: currentDay)
        rebuildHabitProgress(using: currentDay)
    }

    

    private func handleTaskToggle(id: String, isCompleted: Bool) {
        let day = ensureCurrentDay()
        if let idx = day.dailyTaskCompletions.firstIndex(where: { $0.id == id }) {
            day.dailyTaskCompletions[idx].isCompleted = isCompleted
        } else {
            day.dailyTaskCompletions.append(DailyTaskCompletion(id: id, isCompleted: isCompleted))
        }
        persistDay(day)
        
        // Update notifications
        if dailyTasksAlertsEnabled {
            let completedIds = Set(day.dailyTaskCompletions.filter { $0.isCompleted }.map { $0.id })
            NotificationsHelper.scheduleDailyTaskNotifications(account.dailyTasks, completedTaskIds: completedIds, silenceCompleted: true)
        }
    }

    private func handleHabitToggle(habitId: UUID, isCompleted: Bool) {
        let day = ensureCurrentDay()
        var comps = day.habitCompletions
        if let idx = comps.firstIndex(where: { $0.habitId == habitId }) {
            comps[idx].isCompleted = isCompleted
        } else {
            comps.append(HabitCompletion(habitId: habitId, isCompleted: isCompleted))
        }
        day.habitCompletions = comps
        persistDay(day)

        let weekdayIndex = weekdayIndex(for: selectedDate)
        if let habitIdx = habitItems.firstIndex(where: { $0.id == habitId }), habitItems[habitIdx].weeklyProgress.indices.contains(weekdayIndex) {
            habitItems[habitIdx].weeklyProgress[weekdayIndex] = isCompleted ? .tracked : .notTracked
        }
        
        if habitsAlertsEnabled {
            let completedHabitIds = Set(day.habitCompletions.filter { $0.isCompleted }.map { $0.habitId })
            NotificationsHelper.scheduleHabitNotifications(account.habits, completedHabitIds: completedHabitIds)
        }
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
        // If account is temporary/loading, do not prune completions yet
        if account.id == "temp" { return }
        
        let allowedIds = Set(account.dailyTasks.map { $0.id })
        day.dailyTaskCompletions.removeAll { !allowedIds.contains($0.id) }
    }

    private func pruneHabitCompletions(for day: Day) {
        if account.id == "temp" { return }
        let allowedHabitIds = Set(account.habits.map { $0.id })
        day.habitCompletions.removeAll { !allowedHabitIds.contains($0.habitId) }
    }

    private func rebuildHabitProgress(using day: Day?) {
        guard let day else { return }
        var map: [Date: Day] = [:]
        map[day.date] = day
        rebuildHabitProgress(using: map)
    }

    private func rebuildHabitProgress(using days: [Date: Day]) {
        // Respect an explicitly-empty habits list; do not substitute defaults when enumerating.
        let defs = account.habits
        let week = weekDates(for: selectedDate)

        let resolved: [HabitItem] = defs.enumerated().map { idx, def in
            var weekly = Array(repeating: HabitDayStatus.notTracked, count: 7)
            for (offset, date) in week.enumerated() {
                if let day = days[Calendar.current.startOfDay(for: date)],
                   let completion = day.habitCompletions.first(where: { $0.habitId == def.id }) {
                    weekly[offset] = completion.isCompleted ? .tracked : .notTracked
                }
            }
            let color = def.colorHex.isEmpty ? HabitDefinition.defaults[idx % HabitDefinition.defaults.count].colorHex : def.colorHex
            return HabitItem(id: def.id, name: def.name, weeklyProgress: weekly, colorHex: color)
        }

        habitItems = resolved
    }

    private func routineTaskCompletionPercent() -> Int {
        guard !dailyTaskItems.isEmpty else { return 0 }
        let completed = dailyTaskItems.filter { $0.isCompleted }.count
        return Int((Double(completed) / Double(dailyTaskItems.count)) * 100)
    }

    private func routineCompletedGoalsSnapshot() -> [GoalItem] {
        let completed = goals.filter { $0.isCompleted }
        let sorted = completed.sorted { $0.dueDate > $1.dueDate }
        return Array(sorted.prefix(5))
    }

    private func routineHabitSnapshots() -> [RoutineHabitSnapshot] {
        let dayIndex = weekdayIndex(for: selectedDate)
        let fallbackColor = accentOverride ?? .accentColor
        return habitItems.prefix(4).map { item in
            let isCompleted: Bool
            if item.weeklyProgress.indices.contains(dayIndex) {
                isCompleted = item.weeklyProgress[dayIndex] == .tracked
            } else {
                isCompleted = false
            }
            let resolvedColor = Color(hex: item.colorHex) ?? fallbackColor
            return RoutineHabitSnapshot(id: item.id, name: item.name, isCompleted: isCompleted, color: resolvedColor)
        }
    }

    private func routineExpenseBars() -> [RoutineExpenseBar] {
        let week = weekDates(for: selectedDate)
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = weekStartsOnMonday ? "EEE" : "E"

        return week.map { date in
            let total = expenseEntries.filter { cal.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.amount }
            let label = formatter.string(from: date).uppercased()
            return RoutineExpenseBar(id: date, label: label, total: total)
        }
    }

    private func weekDates(for anchor: Date) -> [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: anchor)
        let startIndex = weekStartsOnMonday ? 2 : 1 // 1=Sunday, 2=Monday
        let offset = (weekday - startIndex + 7) % 7
        guard let start = cal.date(byAdding: .day, value: -offset, to: anchor) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func weekdayIndex(for date: Date) -> Int {
        let dates = weekDates(for: date).map { Calendar.current.startOfDay(for: $0) }
        let target = Calendar.current.startOfDay(for: date)
        return dates.firstIndex(of: target) ?? 0
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
    let currentDayIndex: Int
    var onToggle: (UUID, Bool) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No habits yet", systemImage: "checklist")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add habits using the Edit button to start tracking daily routines.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }

    var body: some View {
        VStack(spacing: 12) {
            if habits.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    let palette: [Color] = [.purple, .orange, .pink, .teal, .mint, .yellow, .green]
                    ForEach(habits.indices, id: \.self) { idx in
                        let habit = habits[idx]
                        let rowColor: Color = {
                            // When app theme is not multiColour, override all habit colors with theme accent
                            if themeManager.selectedTheme != .multiColour {
                                return themeManager.selectedTheme.accent(for: colorScheme)
                            }
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
                                    .padding(2) // small visual padding to enlarge tap target
                                    .background(Color.clear)
                                    .contentShape(Rectangle()) // make the full padded area tappable
                            }
                            .buttonStyle(HabitCompactButtonStyle(background: Color(.systemBackground)))
                            .contentShape(Rectangle()) // ensure the whole button area is hit-testable
                        }
                        .padding(.top, 6)
                        .background(Color.clear)
                    }
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 16.0))
            }
        }
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
        onToggle(habitId, habits[idx].weeklyProgress[currentDayIndex] == .tracked)
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
}
