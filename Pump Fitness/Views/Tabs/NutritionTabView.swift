import SwiftUI
import UIKit
import SwiftData
import UserNotifications
import Combine

extension Notification.Name {
    static let dayDataDidChange = Notification.Name("DayDataDidChangeNotification")
}

struct NutritionTabView: View {
    @Binding var account: Account
    @Binding var consumedCalories: Int
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showCalendar = false
    @Binding var selectedDate: Date
    @State private var showAccountsView = false
    @State private var showLogIntakeSheet = false
    @State private var showCalorieGoalSheet = false
    @Binding var calorieGoal: Int
    @Binding var selectedMacroFocus: MacroCalculator.WeightGoalOption?
    @Binding var trackedMacros: [TrackedMacro]
    @Binding var macroConsumptions: [MacroConsumption]
    @Binding var cravings: [CravingItem]
    @Binding var mealReminders: [MealReminder]
    @Binding var checkedMeals: Set<String>
    @Binding var groceryItems: [GroceryItem]
    @Binding var selectedMacroStrategy: MacroCalculator.MacroDistributionStrategy?
    @State private var showMacroEditorSheet = false
    @State private var selectedMacroForLog: MacroMetric?
    @State private var showConsumedSheet = false
    @State private var showProtocolSheet = false
    @State private var showProSheet = false
    @State private var showSupplementEditor = false
    @State private var showCravingEditor = false
    @State private var showMealReminderSheet = false
    @State private var showShareSheet = false
    @State private var shareSheetID = UUID()
    // supplements are persisted on Account; per-day taken state is stored on Day
    @State private var dayTakenSupplementIDs: Set<String> = []
    @State private var nutritionSearchText: String = ""
    @State private var weeklyEntries: [WeeklyProgressEntry] = []
    @State private var dailyMealEntries: [MealIntakeEntry] = []

    @Binding var maintenanceCalories: Int
    var isPro: Bool

    private let accountFirestoreService = AccountFirestoreService()
    private let dayFirestoreService = DayFirestoreService()

    init(
        account: Binding<Account>,
        consumedCalories: Binding<Int>,
        selectedDate: Binding<Date>,
        calorieGoal: Binding<Int>,
        selectedMacroFocus: Binding<MacroCalculator.WeightGoalOption?>,
        trackedMacros: Binding<[TrackedMacro]>,
        macroConsumptions: Binding<[MacroConsumption]>,
        cravings: Binding<[CravingItem]>,
        mealReminders: Binding<[MealReminder]>,
        checkedMeals: Binding<Set<String>>,
        groceryItems: Binding<[GroceryItem]>,
        maintenanceCalories: Binding<Int>,
        selectedMacroStrategy: Binding<MacroCalculator.MacroDistributionStrategy?>,
        isPro: Bool
    ) {
        _account = account
        _consumedCalories = consumedCalories
        _selectedDate = selectedDate
        _calorieGoal = calorieGoal
        _selectedMacroFocus = selectedMacroFocus
        _trackedMacros = trackedMacros
        _macroConsumptions = macroConsumptions
        _cravings = cravings
        _mealReminders = mealReminders
        _checkedMeals = checkedMeals
        _groceryItems = groceryItems
        _maintenanceCalories = maintenanceCalories
        _selectedMacroStrategy = selectedMacroStrategy
        self.isPro = isPro
    }

    private let caloriesBurnedToday: Int = 620
    private let caloriesBurnGoal: Int = 800
    private let stepsTakenToday: Int = 8_500
    private let stepsGoalToday: Int = 10_000

    private var stepsProgress: Double {
        guard stepsGoalToday > 0 else { return 0 }
        return min(max(Double(stepsTakenToday) / Double(stepsGoalToday), 0), 1)
    }

    private var formattedStepsTaken: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsTakenToday)) ?? "\(stepsTakenToday)"
    }

    private var formattedStepsGoal: String {
        NumberFormatter.withComma.string(from: NSNumber(value: stepsGoalToday)) ?? "\(stepsGoalToday)"
    }

    private func persistIntermittentFasting(minutes: Int) {
        account.intermittentFastingMinutes = minutes

        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save intermittent fasting minutes locally: \(error)")
        }

        accountFirestoreService.saveAccount(account) { success in
            if success {
            } else {
                print("NutritionTabView: failed to sync intermittent fasting minutes to Firestore")
            }
        }
    }

    private func saveCravings() {
        account.cravings = cravings
        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save cravings locally: \(error)")
        }

        // Persist cravings explicitly (avoid calling saveAccount without
        // includeCravings to prevent accidental overwrites).
        account.saveCravings(service: accountFirestoreService) { success in
            if !success { print("NutritionTabView: failed to sync cravings to Firestore") }
        }
    }

    private func saveMealSchedule(_ schedule: [MealScheduleItem]) {
        account.mealSchedule = schedule
        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save meal schedule locally: \(error)")
        }
        accountFirestoreService.saveAccount(account) { success, _ in
            if !success { print("NutritionTabView: failed to sync meal schedule to Firestore") }
        }
    }

    private func saveMealCatalog(_ catalog: [CatalogMeal]) {
        account.mealCatalog = catalog
        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save meal catalog locally: \(error)")
        }
        accountFirestoreService.saveAccount(account) { success, _ in
            if !success { print("NutritionTabView: failed to sync meal catalog to Firestore") }
        }
    }

    private func addGroceryItems(_ items: [GroceryItem]) {
        account.groceryItems.append(contentsOf: items)
        groceryItems.append(contentsOf: items)
        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save grocery items locally: \(error)")
        }
        accountFirestoreService.saveAccount(account) { success, _ in
            if !success { print("NutritionTabView: failed to sync grocery items to Firestore") }
        }
    }

    private func fetchDayTakenSupplements() {
        // Optimistic load
        let localDay = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        dayTakenSupplementIDs = Set(localDay.takenSupplements)

        dayFirestoreService.fetchDay(for: selectedDate, in: modelContext, trackedMacros: trackedMacros) { day in
            DispatchQueue.main.async {
                if let day = day {
                    dayTakenSupplementIDs = Set(day.takenSupplements)
                } else {
                    dayTakenSupplementIDs = []
                }
            }
        }
    }

    /// Seed a few sensible default supplements when the list is empty.
    /// Cravings are no longer auto-seeded here to avoid overwriting server data
    /// before the app finishes hydrating from Firestore.
    private func ensureDefaultSupplements() {
        // Intentionally left blank: do not auto-seed supplements here.
        // Supplements should be preserved exactly as stored on the Account (including empty arrays).
    }

    private var cravingsEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No cravings yet", systemImage: "heart.slash")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add cravings using the Edit button to track foods you want to watch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            HeaderComponent(
                            showCalendar: $showCalendar,
                            selectedDate: $selectedDate,
                            onProfileTap: { showAccountsView = true },
                            isPro: isPro
                        )
                        .environmentObject(account)
                        
                        HStack {
                            Text("Calorie Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        CalorieSummary(
                            accentColorOverride: accentOverride,
                            caloriesMaintenance: maintenanceCalories,
                            caloriesConsumed: consumedCalories,
                            calorieGoal: calorieGoal,
                            onEditGoal: { showCalorieGoalSheet = true },
                            onAdjustConsumed: { showConsumedSheet = true }
                        )
                        .nutritionTip(.consumedCalories)
                        .padding(.top, 14)

                        Button {
                            showCalorieGoalSheet = true
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

                        Button {
                            showLogIntakeSheet = true
                        } label: {
                            Label("Log Intake", systemImage: "plus")
                              .font(.callout.weight(.semibold))
                              .padding(.vertical, 18)
                              .frame(maxWidth: .infinity, minHeight: 52)
                              .glassEffect(in: .rect(cornerRadius: 16.0))
                              .contentShape(Rectangle())
                        }
                        .nutritionTip(.logIntake)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .buttonStyle(.plain)

                        HStack {
                            Text("Macro Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showMacroEditorSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .nutritionTip(.editMacros, onStepChange: { step in
                                if step == 7 {
                                    withAnimation {
                                        proxy.scrollTo("supplements", anchor: .top)
                                    }
                                }
                            })
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)

                        MacroSummary(
                            accentColorOverride: accentOverride,
                            macros: macroMetrics,
                            onEditMacros: { showMacroEditorSheet = true },
                            onMacroTap: { metric in
                                selectedMacroForLog = metric
                            }
                        )
                        .nutritionTip(.trackMacros)

                        HStack {
                            Text("Supplement Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showSupplementEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(in: .rect(cornerRadius: 18.0))
                                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .nutritionTip(.editSupplements)
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.top, 48)
                        .id("supplements")

                        SupplementTrackingView(
                            accentColorOverride: .orange,
                            supplements: account.nutritionSupplements,
                            takenSupplementIDs: $dayTakenSupplementIDs,
                            onToggle: { supplement in
                                // Optimistically update UI state first to avoid stale reads
                                var newSet = dayTakenSupplementIDs
                                if newSet.contains(supplement.id) {
                                    newSet.remove(supplement.id)
                                } else {
                                    newSet.insert(supplement.id)
                                }
                                dayTakenSupplementIDs = newSet

                                // Persist the canonical array to the Day model and Firestore
                                let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
                                day.takenSupplements = Array(newSet)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("NutritionTabView: failed to save Day after toggling supplement: \(error)")
                                }
                                
                                dayFirestoreService.updateDayFields(["takenSupplements": day.takenSupplements], for: day) { success in
                                    if !success { print("NutritionTabView: failed to sync takenSupplements to Firestore") }
                                }
                            },
                            onRemove: { supplement in
                                // remove supplement from Account then persist
                                account.nutritionSupplements.removeAll { $0.id == supplement.id }
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("NutritionTabView: failed to save Account after removing nutrition supplement: \(error)")
                                }
                                accountFirestoreService.saveAccount(account) { success in
                                    if !success { print("NutritionTabView: failed to sync removed nutrition supplement to Firestore") }
                                }
                            }
                        )
                        .nutritionTip(.supplements)
                        .onAppear {
                            fetchDayTakenSupplements()
                        }
                        .onChange(of: selectedDate) {
                            fetchDayTakenSupplements()
                        }
                        
                        HStack {
                            Text("Meal Tracking")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showMealReminderSheet = true
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
                        
                        MealScheduleSection(
                            accentColorOverride: accentOverride,
                            checkedMeals: $checkedMeals,
                            mealReminders: mealReminders
                        )

                        DailyMealLogSection(
                            accentColorOverride: accentOverride,
                            weeklyEntries: weeklyEntries,
                            weekStartsOnMonday: true,
                            trackedMacros: trackedMacros,
                            selectedDate: selectedDate,
                            currentConsumedCalories: consumedCalories,
                            currentCalorieGoal: calorieGoal,
                            currentMacroConsumptions: macroConsumptions,
                            onDeleteMealEntry: { entry in
                                deleteMealEntry(entry)
                            }
                        )

                        WeeklyMealScheduleCard(
                            schedule: $account.mealSchedule,
                            catalog: $account.mealCatalog,
                            trackedMacros: trackedMacros,
                            groceryItems: groceryItems,
                            consumedMeals: Set(dailyMealEntries.map { $0.itemName }),
                            accentColor: accentOverride ?? .accentColor,
                            onSave: { updated in
                                saveMealSchedule(updated)
                            },
                            onSaveCatalog: { updated in
                                saveMealCatalog(updated)
                            },
                            onAddToGroceryList: { items in
                                addGroceryItems(items)
                            },
                            onConsumeMeal: { meal in
                                logCatalogMeal(meal)
                            }
                        )
                        .opacity(isPro ? 1 : 0.5)
                        .blur(radius: isPro ? 0 : 4)
                        .disabled(!isPro)
                        .overlay {
                            if !isPro {
                                ZStack {
                                    Color.black.opacity(0.001) // Capture taps
                                        .onTapGesture {
                                            // no-op capture
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

                                            Text("Upgrade to unlock Meal Planning + More")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .glassEffect(in: .rect(cornerRadius: 16.0))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // MARK: - Cravings Section
                        VStack(spacing: 0) {
                            HStack {
                                Text("Cravings")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showCravingEditor = true
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
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)

                            if cravings.isEmpty {
                                cravingsEmptyState
                                    .padding(.horizontal, 18)
                                    .padding(.top, 12)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(cravings.enumerated()), id: \.element.id) { idx, _ in
                                        let binding = $cravings[idx]
                                        let isChecked = binding.wrappedValue.isChecked

                                        Button {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                binding.isChecked.wrappedValue.toggle()
                                            }
                                            saveCravings()
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(binding.name.wrappedValue)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .strikethrough(isChecked, color: .secondary)
                                                        .foregroundStyle(isChecked ? .secondary : .primary)

                                                    Text("\(binding.calories.wrappedValue) cal")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                ZStack {
                                                    Circle()
                                                        .fill(isChecked ? (accentOverride ?? .accentColor).opacity(0.16) : Color.clear)
                                                        .frame(width: 40, height: 40)

                                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "checkmark.circle")
                                                        .font(.title3)
                                                        .foregroundStyle(isChecked ? (accentOverride ?? .accentColor) : Color(.systemGray3))
                                                        .scaleEffect(isChecked ? 1.15 : 1.0)
                                                        .rotationEffect(.degrees(isChecked ? 0 : 0))
                                                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isChecked)
                                                }
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                Group {
                                                    if isChecked {
                                                        (accentOverride ?? .accentColor).opacity(0.06)
                                                    } else {
                                                        Color.clear
                                                    }
                                                }
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(.plain)

                                        if idx != cravings.indices.last {
                                            Divider()
                                                .padding(.leading, 12)
                                        }
                                    }
                                }
                                .glassEffect(in: .rect(cornerRadius: 16.0))
                                .padding(.horizontal, 18)
                                .padding(.top, 12)
                            }
                        }
                        .opacity(isPro ? 1 : 0.5)
                        .blur(radius: isPro ? 0 : 4)
                        .disabled(!isPro)
                        .overlay {
                            if !isPro {
                                ZStack {
                                    Color.black.opacity(0.001) // Capture taps
                                        .onTapGesture {
                                            // no-op capture
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

                                            Text("Upgrade to unlock Cravings + More")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .glassEffect(in: .rect(cornerRadius: 16.0))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // MARK: - Intermittent Fasting Section
                        VStack(spacing: 0) {
                            HStack {
                                Text("Intermittent Fasting")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showProtocolSheet = true
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
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.top, 48)
                            .opacity(isPro ? 1 : 0.5)
                            .blur(radius: isPro ? 0 : 4)
                            .disabled(!isPro)

                            FastingTimerCard(
                                accentColorOverride: accentOverride,
                                showProtocolSheet: $showProtocolSheet,
                                currentFastingMinutes: account.intermittentFastingMinutes,
                                onProtocolChanged: { minutes in
                                    persistIntermittentFasting(minutes: minutes)
                                }
                            )
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .opacity(isPro ? 1 : 0.5)
                            .blur(radius: isPro ? 0 : 4)
                            .disabled(!isPro)
                            .overlay {
                                if !isPro {
                                    ZStack {
                                        Color.black.opacity(0.001) // Capture taps
                                            .onTapGesture {
                                                // no-op capture
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
                                                
                                                Text("Upgrade to unlock Fasting + More")
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
                        }

                        ShareProgressCTA(accentColor: accentOverride ?? .accentColor) {
                            // Force a new sheet instance each open to avoid empty-first-open bug
                            shareSheetID = UUID()
                            showShareSheet = true
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 24)
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
        }
        .onAppear {
            // Ensure meal schedule is populated
            if account.mealSchedule.isEmpty {
                let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                account.mealSchedule = days.map { MealScheduleItem(day: $0, sessions: []) }
                saveMealSchedule(account.mealSchedule)
            }

            // Safely hydrate cravings from Firestore if needed without
            // overwriting local changes. When the account adopts remote
            // cravings, reflect that into this view's binding.
            account.syncCravingsIfNeeded(service: accountFirestoreService) { updated in
                if updated {
                    DispatchQueue.main.async {
                        cravings = account.cravings
                    }
                }
            }
        }
        .tint(accentOverride ?? .accentColor)
        .accentColor(accentOverride ?? .accentColor)
        .sheet(isPresented: $showMacroEditorSheet) {
            MacroEditorSheet(
                macros: macroEditorBinding,
                tint: accentOverride ?? .accentColor,
                isMultiColourTheme: themeManager.selectedTheme == .multiColour,
                macroFocus: selectedMacroFocus,
                calorieGoal: calorieGoal,
                bodyWeightKg: bodyWeightKg,
                selectedMacroStrategy: $selectedMacroStrategy,
                isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty,
                onDone: { showMacroEditorSheet = false }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCalorieGoalSheet) {
                            CalorieGoalEditorSheet(
                                selectedMacroFocus: $selectedMacroFocus,
                                calorieGoal: $calorieGoal,
                                maintenanceCalories: maintenanceCalories,
                                activityLevelName: ActivityLevelOption(rawValue: account.activityLevel ?? ActivityLevelOption.moderatelyActive.rawValue)?.displayName ?? ActivityLevelOption.moderatelyActive.displayName,
                                tint: accentOverride ?? .accentColor,
                                onDone: { showCalorieGoalSheet = false }
                            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLogIntakeSheet) {
            MealIntakeSheet(
                tint: accentOverride ?? .accentColor,
                trackedMacros: trackedMacros,
                onSave: { entry in
                    handleMealIntakeSave(entry)
                    showLogIntakeSheet = false
                },
                onCancel: { showLogIntakeSheet = false }
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSupplementEditor) {
            let supplementsBinding = Binding<[Supplement]>(
                get: { account.nutritionSupplements },
                set: { newValue in
                    account.nutritionSupplements = newValue
                    do {
                        try modelContext.save()
                    } catch {
                        print("NutritionTabView: failed to save Account after editing nutrition supplements: \(error)")
                    }
                    accountFirestoreService.saveAccount(account) { success in
                        if !success { print("NutritionTabView: failed to sync nutrition supplements to Firestore") }
                    }
                }
            )

            SupplementEditorSheet(
                supplements: supplementsBinding,
                tint: accentOverride ?? .orange,
                isPro: isPro && !subscriptionManager.purchasedProductIDs.isEmpty,
                onDone: { showSupplementEditor = false }
            )
            .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $showCravingEditor) {
            CravingEditorSheet(
                cravings: $cravings,
                tint: accentOverride ?? .accentColor,
                onDone: {
                    showCravingEditor = false
                    saveCravings()
                }
            )
            .presentationDetents([.large, .medium])
        }
        .sheet(isPresented: $showMealReminderSheet) {
            MealReminderEditorSheet(
                mealReminders: $mealReminders,
                tint: accentOverride ?? .accentColor
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showConsumedSheet) {
            CalorieConsumedAdjustmentSheet(
                currentCalories: $consumedCalories,
                tint: accentOverride ?? .accentColor
            )
            .presentationDetents([.fraction(0.38)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareProgressSheet(
                caloriesConsumed: consumedCalories,
                calorieGoal: calorieGoal,
                maintenanceCalories: maintenanceCalories,
                macros: macroMetrics,
                supplements: account.nutritionSupplements,
                takenSupplements: dayTakenSupplementIDs,
                cravings: cravings,
                fastingMinutes: account.intermittentFastingMinutes,
                selectedDate: selectedDate,
                trackedMacros: trackedMacros,
                accentColor: accentOverride ?? .accentColor
            )
            .id(shareSheetID)
        }
        .sheet(item: $selectedMacroForLog) { metric in
            MacroLogEntrySheet(
                metric: metric,
                initialValue: macroConsumptions.first(where: { $0.trackedMacroId == metric.id.uuidString })?.consumed ?? 0,
                unitSuffix: inferredUnitSuffix(for: metric)
            ) { newValue in
                updateMacro(metric, with: newValue)
                selectedMacroForLog = nil
            } onCancel: {
                selectedMacroForLog = nil
            }
            .presentationDetents([.fraction(0.38)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            updateWeeklyEntries()
            refreshDailyMeals()
        }
        .onChange(of: account.weeklyProgress) { _, _ in
            updateWeeklyEntries()
        }
        .onChange(of: selectedDate) {
            refreshDailyMeals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDataDidChange)) { note in
            if let info = note.userInfo as? [String: Any], let date = info["date"] as? Date {
                let localCal = Calendar.current
                let compsA = localCal.dateComponents([.year, .month, .day], from: date)
                let compsB = localCal.dateComponents([.year, .month, .day], from: selectedDate)
                if compsA == compsB {
                    refreshDailyMeals()
                }
            } else {
                refreshDailyMeals()
            }
        }
    }
}

private enum NutritionLayout {
    static let macroTileMinHeight: CGFloat = 128
    static let supplementTileMinHeight: CGFloat = 150
}

private enum NutritionMacroLimits {
    static let freeTrackedMacros = 8
}

private extension NutritionTabView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .nutrition)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    var accentOverride: Color? {
        guard themeManager.selectedTheme != .multiColour else { return nil }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    var bodyWeightKg: Double {
        guard let w = account.weight else { return 70 }
        if account.unitSystem == "imperial" {
            return w * 0.453592
        }
        return w
    }

    private func updateWeeklyEntries() {
        weeklyEntries = account.weeklyProgress.map { record in
            WeeklyProgressEntry(
                id: UUID(uuidString: record.id) ?? UUID(),
                date: record.date,
                weight: record.weight,
                waterPercent: record.waterPercent,
                bodyFatPercent: record.bodyFatPercent,
                photoData: record.photoData
            )
        }
    }

    private var macroMetrics: [MacroMetric] {
        trackedMacros.map { macroMetric(from: $0) }
    }

    private var macroEditorBinding: Binding<[MacroMetric]> {
        Binding(
            get: { macroMetrics },
            set: { incoming in
                trackedMacros = incoming.map { trackedMacro(from: $0) }
            }
        )
    }

    private func macroMetric(from tracked: TrackedMacro) -> MacroMetric {
        let consumed = currentConsumption(for: tracked)
        let percent = tracked.target > 0 ? min(max(consumed / tracked.target, 0), 1) : 0
        let preset = MacroPreset.allCases.first { $0.displayName.lowercased() == tracked.name.lowercased() }
        let targetLabel = formattedMacroValue(tracked.target, suffix: tracked.unit)
        let currentLabel = formattedMacroValue(consumed, suffix: tracked.unit)

        return MacroMetric(
            id: UUID(uuidString: tracked.id) ?? UUID(),
            title: tracked.name,
            percent: percent,
            currentLabel: currentLabel,
            targetLabel: targetLabel,
            color: tracked.color,
            source: preset.map { .preset($0) } ?? .custom
        )
    }

    private func trackedMacro(from metric: MacroMetric) -> TrackedMacro {
        let targetValue = numericValue(from: metric.targetLabel) ?? 0
        let suffix = unitSuffix(from: metric.targetLabel).isEmpty ? unitSuffix(from: metric.currentLabel) : unitSuffix(from: metric.targetLabel)
        let colorHex = metric.color.toHex() ?? "#FF3B30"
        return TrackedMacro(
            id: metric.id.uuidString,
            name: metric.title,
            target: targetValue,
            unit: suffix.isEmpty ? "g" : suffix,
            colorHex: colorHex
        )
    }

    private func currentConsumption(for tracked: TrackedMacro) -> Double {
        macroConsumptions.first(where: { $0.trackedMacroId == tracked.id })?.consumed ?? 0
    }

    func numericValue(from label: String) -> Double? {
        let allowed = CharacterSet(charactersIn: "0123456789.")
        let filteredScalars = label.unicodeScalars.filter { allowed.contains($0) }
        guard !filteredScalars.isEmpty else { return nil }
        return Double(String(String.UnicodeScalarView(filteredScalars)))
    }

    func unitSuffix(from label: String) -> String {
        let disallowed = CharacterSet(charactersIn: "0123456789.").union(.whitespacesAndNewlines)
        let scalars = label.unicodeScalars.filter { !disallowed.contains($0) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    func inferredUnitSuffix(for metric: MacroMetric) -> String {
        let currentSuffix = unitSuffix(from: metric.currentLabel)
        if !currentSuffix.isEmpty {
            return currentSuffix
        }
        let targetSuffix = unitSuffix(from: metric.targetLabel)
        return targetSuffix
    }

    func formattedMacroValue(_ value: Double, suffix: String) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return suffix.isEmpty ? formatted : "\(formatted)\(suffix)"
    }

    func updateMacro(_ metric: MacroMetric, with newValue: Double) {
        let suffix = inferredUnitSuffix(for: metric)
        let updatedValue = max(0, newValue)
        if let idx = macroConsumptions.firstIndex(where: { $0.trackedMacroId == metric.id.uuidString }) {
            macroConsumptions[idx].consumed = updatedValue
            macroConsumptions[idx].unit = suffix.isEmpty ? macroConsumptions[idx].unit : suffix
        } else {
            macroConsumptions.append(
                MacroConsumption(
                    trackedMacroId: metric.id.uuidString,
                    name: metric.title,
                    unit: suffix.isEmpty ? unitSuffix(from: metric.targetLabel) : suffix,
                    consumed: updatedValue
                )
            )
        }
    }

    func handleMealIntakeSave(_ entry: MealIntakeEntry) {
        // Optimistically update the local day immediately.
        // We trust the local cache for immediate feedback.
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        applyMealIntake(entry, to: day)
        refreshDailyMeals()
    }

    private func refreshDailyMeals() {
        let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == selectedDate })
        do {
            if let day = try modelContext.fetch(request).first {
                self.dailyMealEntries = day.mealIntakes
            } else {
                self.dailyMealEntries = []
            }
        } catch {
            print("NutritionTabView: failed to fetch daily meals: \(error)")
        }
    }

    private func logCatalogMeal(_ meal: CatalogMeal) {
        let totalCalories = Int(meal.calories)
        
        var macroEntries: [MealMacroEntry] = []
        for macro in trackedMacros {
            let totalAmount: Double = {
                if let val = meal.macroValues[macro.id] { return val }
                let name = macro.name.lowercased()
                if name == "protein" { return meal.protein }
                if name == "carbs" { return meal.carbs }
                if name == "fats" { return meal.fats }
                return 0
            }()
            
            if totalAmount > 0 {
                macroEntries.append(MealMacroEntry(
                    trackedMacroId: macro.id,
                    name: macro.name,
                    unit: macro.unit,
                    amount: totalAmount
                ))
            }
        }
        
        let entry = MealIntakeEntry(
            mealType: meal.mealType,
            itemName: meal.name,
            quantityPerServing: "1 serving",
            calories: totalCalories,
            macros: macroEntries
        )
        
        handleMealIntakeSave(entry)
    }

    private func deleteMealEntry(_ entry: MealIntakeEntry) {
        let day = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        guard let removed = day.mealIntakes.first(where: { $0.id == entry.id }) else { return }

        // Remove only the selected meal intake
        day.mealIntakes.removeAll { $0.id == entry.id }

        // Subtract calories contributed by this item
        if removed.calories != 0 {
            day.caloriesConsumed = max(0, day.caloriesConsumed - removed.calories)
            consumedCalories = day.caloriesConsumed
        }

        // Subtract macro amounts contributed by this item
        if day.macroConsumptions.isEmpty {
            day.ensureMacroConsumptions(for: trackedMacros)
        }

        for macro in removed.macros {
            guard macro.amount != 0 else { continue }
            if let idx = day.macroConsumptions.firstIndex(where: { $0.trackedMacroId == macro.trackedMacroId }) {
                day.macroConsumptions[idx].consumed = max(0, day.macroConsumptions[idx].consumed - macro.amount)
            }
        }
        macroConsumptions = day.macroConsumptions

        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save Day after deleting meal entry: \(error)")
        }

        // Notify other UI that this day's data changed so they can refresh immediately
        NotificationCenter.default.post(name: .dayDataDidChange, object: nil, userInfo: ["date": self.selectedDate])

        dayFirestoreService.saveDay(day) { success in
            if !success {
                print("NutritionTabView: failed to sync meal entry deletion to Firestore")
            }
        }
    }

    private func applyMealIntake(_ entry: MealIntakeEntry, to day: Day) {
        // Store the detailed entry on the already-merged Day instance
        day.mealIntakes.append(entry)

        // Update calorie aggregate using existing total so we add rather than replace
        if entry.calories != 0 {
            day.caloriesConsumed = max(0, day.caloriesConsumed + entry.calories)
            consumedCalories = day.caloriesConsumed
        }

        // Update macro aggregates to keep summaries in sync
        if day.macroConsumptions.isEmpty {
            day.ensureMacroConsumptions(for: trackedMacros)
        }

        for macro in entry.macros {
            guard macro.amount != 0 else { continue }
            if let idx = day.macroConsumptions.firstIndex(where: { $0.trackedMacroId == macro.trackedMacroId }) {
                day.macroConsumptions[idx].consumed = max(0, day.macroConsumptions[idx].consumed + macro.amount)
                day.macroConsumptions[idx].unit = macro.unit
                day.macroConsumptions[idx].name = macro.name
            } else {
                day.macroConsumptions.append(
                    MacroConsumption(
                        trackedMacroId: macro.trackedMacroId,
                        name: macro.name,
                        unit: macro.unit,
                        consumed: max(0, macro.amount)
                    )
                )
            }
        }

        macroConsumptions = day.macroConsumptions

        do {
            try modelContext.save()
        } catch {
            print("NutritionTabView: failed to save Day after logging intake: \(error)")
        }

        // Notify other UI that this day's data changed so they can refresh immediately
        NotificationCenter.default.post(name: .dayDataDidChange, object: nil, userInfo: ["date": self.selectedDate])

        dayFirestoreService.saveDay(day) { success in
            if !success {
                print("NutritionTabView: failed to sync logged intake to Firestore")
            }
        }
    }
}

struct CalorieSummary: View {
    var accentColorOverride: Color?
    var caloriesMaintenance: Int = 2200
    var caloriesConsumed: Int = 3100
    var calorieGoal: Int
    var onEditGoal: () -> Void
    var onAdjustConsumed: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 2) {
                    Text("Maintenance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(caloriesMaintenance)")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Button(action: onAdjustConsumed) {
                    VStack(spacing: 2) {
                        HStack {
                          Text("Consumed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                          Image(systemName: "plus.circle.dashed")
                            .symbolVariant(.none)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .offset(x: -6)
                        }
                        Text("\(caloriesConsumed)")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(caloriesConsumed > calorieGoal ? .red : .primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    Text("\(calorieGoal)")
                        .font(.title2)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 12)
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Values are in calories (cal).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -8)
            .padding(.bottom, -8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
    }
}

struct CravingEditorSheet: View {
    @Binding var cravings: [CravingItem]
    var tint: Color
    var onDone: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var working: [CravingItem] = []
    @State private var newName: String = ""
    @State private var newCalories: String = ""
    @State private var hasLoaded = false

    private let maxTrackedCravings = 20
    private let caloriesFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        nf.maximumFractionDigits = 0
        return nf
    }()

    private var presets: [CravingItem] {
        [
            CravingItem(name: "Chocolate Chip Cookie", calories: 220),
            CravingItem(name: "Salted Pretzel", calories: 180),
            CravingItem(name: "Berry Smoothie", calories: 250),
            CravingItem(name: "Iced Latte", calories: 140),
            CravingItem(name: "Protein Bar", calories: 210),
            CravingItem(name: "Granola Yogurt", calories: 190),
            CravingItem(name: "Trail Mix", calories: 280)
        ]
    }

    private var canAddMore: Bool { working.count < maxTrackedCravings }
    private var canAddCustom: Bool {
        canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(newCalories.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Cravings")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, _ in
                                    let binding = $working[idx]
                                    VStack(spacing: 10) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(tint.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "birthday.cake")
                                                        .foregroundStyle(tint)
                                                        .editSheetChangeColorTip(
                                                            hasTrackedItems: !working.isEmpty,
                                                            isMultiColourTheme: themeManager.selectedTheme == .multiColour,
                                                            isActive: idx == 0
                                                        )
                                                )

                                            VStack(alignment: .leading) {
                                                Text(binding.wrappedValue.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(binding.wrappedValue.calories) cal")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            // VStack(alignment: .leading, spacing: 6) {
                                            //     TextField("Name", text: binding.name)
                                            //         .font(.subheadline.weight(.semibold))
                                            //     HStack(spacing: 6) {
                                            //         TextField(
                                            //             "Calories",
                                            //             value: binding.calories,
                                            //             formatter: caloriesFormatter
                                            //         )
                                            //         .keyboardType(.numberPad)
                                            //         .font(.caption)
                                            //         .foregroundStyle(.secondary)
                                            //         Text("cal")
                                            //             .font(.caption)
                                            //             .foregroundStyle(.secondary)
                                            //         Spacer()
                                            //     }
                                            // }

                                            Spacer()

                                            Button(role: .destructive) {
                                                removeCraving(binding.wrappedValue)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding()
                                    .surfaceCard(12)
                                }
                            }
                        }
                    }

                    if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(presets.filter { !isPresetSelected($0) }, id: \.id) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(tint.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "birthday.cake")
                                                    .foregroundStyle(tint)
                                            )

                                        VStack(alignment: .leading) {
                                            Text(preset.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(preset.calories) cal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(tint)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMore)
                                        .opacity(!canAddMore ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Custom Craving")
                        VStack(spacing: 12) {
                            TextField("Craving name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            HStack(spacing: 12) {
                                TextField("Calories (e.g. 180)", text: $newCalories)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomCraving) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(tint)
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
            .navigationTitle("Edit Cravings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cravings = working
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        guard !hasLoaded else { return }
        working = cravings
        hasLoaded = true
    }

    private func togglePreset(_ preset: CravingItem) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: CravingItem) -> Bool {
        working.contains { $0.name == preset.name }
    }

    private func removeCraving(_ item: CravingItem) {
        if presets.contains(where: { $0.name == item.name }) {
            working.removeAll { $0.name == item.name }
        } else {
            working.removeAll { $0.id == item.id }
        }
    }

    private func addCustomCraving() {
        guard canAddCustom else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCalories = newCalories.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let caloriesInt = Int(trimmedCalories) else { return }
        let newItem = CravingItem(name: trimmedName, calories: caloriesInt)
        working.append(newItem)
        newName = ""
        newCalories = ""
    }
}

struct SupplementEditorSheet: View {
    @Binding var supplements: [Supplement]
    var tint: Color
    var isPro: Bool
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    // local working state
    @State private var working: [Supplement] = []
    @State private var newName: String = ""
    @State private var newTarget: String = ""
    @State private var hasLoaded = false
    @State private var showProSubscription = false

    // presets available in Quick Add (some may not be selected initially)
    private var presets: [Supplement] {
        [
            Supplement(name: "Vitamin D", amountLabel: "50 μg"),
            Supplement(name: "Vitamin B Complex", amountLabel: "50 mg"),
            Supplement(name: "Magnesium", amountLabel: "200 mg"),
            Supplement(name: "Probiotics", amountLabel: "10 Billion CFU"),
            Supplement(name: "Fish Oil", amountLabel: "1000 mg"),
            Supplement(name: "Ashwagandha", amountLabel: "500 mg"),
            Supplement(name: "Melatonin", amountLabel: "3 mg"),
            Supplement(name: "Calcium", amountLabel: "500 mg"),
            Supplement(name: "Iron", amountLabel: "18 mg"),
            Supplement(name: "Zinc", amountLabel: "15 mg"),
            Supplement(name: "Vitamin C", amountLabel: "1000 mg"),
            Supplement(name: "Caffeine", amountLabel: "200 mg")
        ]
    }

    private let freeTrackedSupplements = 8

    private var canAddMore: Bool {
        if isPro { return true }
        return working.count < freeTrackedSupplements
    }
    private var canAddCustom: Bool { canAddMore && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tracked supplements
                    if !working.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Supplements")
                            VStack(spacing: 12) {
                                ForEach(Array(working.enumerated()), id: \.element.id) { idx, item in
                                    let binding = $working[idx]
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(tint.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "pills.fill")
                                                        .foregroundStyle(tint)
                                                )

                                            VStack(alignment: .leading, spacing: 6) {
                                                TextField("Name", text: binding.name)
                                                    .font(.subheadline.weight(.semibold))
                                                TextField("Amount or note (e.g. 5 g or 3 scoops)", text: Binding(
                                                    get: { binding.amountLabel.wrappedValue ?? "" },
                                                    set: { binding.amountLabel.wrappedValue = $0 }
                                                ))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(role: .destructive) {
                                                removeSupplement(item.id)
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
                    }

                    // Quick Add
                        if !presets.filter({ !isPresetSelected($0) }).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                MacroEditorSectionHeader(title: "Quick Add")
                                VStack(spacing: 12) {
                                        ForEach(presets.filter { !isPresetSelected($0) }, id: \.name) { preset in
                                        HStack(spacing: 14) {
                                            Circle()
                                                .fill(tint.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "pills.fill")
                                                        .foregroundStyle(tint)
                                                )

                                            VStack(alignment: .leading) {
                                                Text(preset.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(preset.amountLabel ?? "")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(action: { togglePreset(preset) }) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 24, weight: .semibold))
                                                    .foregroundStyle(tint)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(!canAddMore)
                                            .opacity(!canAddMore ? 0.3 : 1)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .surfaceCard(18)
                                    }
                                }
                            }
                        }
                    
                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(tint)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock more supplement slots + benefits")
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
                        MacroEditorSectionHeader(title: "Custom Supplement")
                        VStack(spacing: 12) {
                            TextField("Supplement name", text: $newName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            HStack(spacing: 12) {
                                TextField("Amount or note (e.g. 5 g or 3 scoops)", text: $newTarget)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomSupplement) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(tint)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustom)
                                .opacity(!canAddCustom ? 0.4 : 1)
                            }

                            if !isPro {
                                Text("You can track up to \(freeTrackedSupplements) supplements.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        donePressed()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadInitialState)
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    private func loadInitialState() {
        guard !hasLoaded else { return }
        working = supplements
        hasLoaded = true
    }

    private func togglePreset(_ preset: Supplement) {
        if isPresetSelected(preset) {
            working.removeAll { $0.name == preset.name }
        } else if canAddMore {
            working.append(preset)
        }
    }

    private func isPresetSelected(_ preset: Supplement) -> Bool {
        // Only consider a preset selected if any working item matches its name
        return working.contains { $0.name == preset.name }
    }

    private func removeSupplement(_ id: String) {
        // Find the supplement being removed
        guard let item = working.first(where: { $0.id == id }) else { return }
        // Always remove all with that name if it's a preset, so preset returns to Quick Add
        if presets.contains(where: { $0.name == item.name }) {
            working.removeAll { $0.name == item.name }
        } else {
            working.removeAll { $0.id == item.id }
        }
    }

    private func addCustomSupplement() {
        guard canAddCustom else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = Supplement(name: trimmed, amountLabel: newTarget.trimmingCharacters(in: .whitespacesAndNewlines))
        working.append(new)
        newName = ""
        newTarget = ""
    }

    // Persist working to the binding and save to Firestore
    private func donePressed() {
        supplements = working
        do {
            try modelContext.save()
        } catch {
            print("SupplementEditorSheet: failed to save context: \(error)")
        }
        // Attempt to sync account if available in the context
        let acctReq = FetchDescriptor<Account>()
        do {
            let accounts = try modelContext.fetch(acctReq)
            if let acct = accounts.first {
                AccountFirestoreService().saveAccount(acct) { success in
                    if !success { print("SupplementEditorSheet: failed to sync account supplements to Firestore") }
                }
            }
        } catch {
            // ignore
        }
        onDone()
    }
}

struct MacroSummary: View {
    var accentColorOverride: Color?
    var macros: [MacroMetric]
    var onEditMacros: () -> Void
    var onMacroTap: (MacroMetric) -> Void

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No macros tracked yet", systemImage: "chart.bar.doc.horizontal")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add macros using the Edit button to start tracking nutrition.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }

    var body: some View {
        if macros.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                let items: [MacroSummaryItem] = macros.map { .metric($0) }
                
                let macroRows: [[MacroSummaryItem]] = {
                    let count = items.count
                    if count <= 4 {
                        return [items]
                    } else if count == 5 {
                        return [Array(items.prefix(3)), Array(items.suffix(2))]
                    } else if count == 6 {
                        return [Array(items.prefix(3)), Array(items.suffix(3))]
                    } else if count == 7 {
                        return [Array(items.prefix(4)), Array(items.suffix(3))]
                    } else {
                        // For 8+, split into rows of 4
                        return stride(from: 0, to: count, by: 4).map { i in
                            Array(items[i..<min(i+4, count)])
                        }
                    }
                }()
                
                VStack(spacing: 16) {
                    ForEach(macroRows.indices, id: \.self) { rowIdx in
                        HStack {
                            Spacer(minLength: 0)
                            ForEach(macroRows[rowIdx]) { item in
                                switch item {
                                case let .metric(metric):
                                    Button {
                                        onMacroTap(metric)
                                    } label: {
                                        let displayColor = accentColorOverride ?? metric.color
                                        VStack(spacing: 2) {
                                            ZStack {
                                                Circle()
                                                    .stroke(displayColor.opacity(0.18), lineWidth: 6)
                                                    .frame(width: 54, height: 54)
                                                Circle()
                                                    .trim(from: 0, to: metric.percent)
                                                    .stroke(displayColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                                    .rotationEffect(.degrees(-90))
                                                    .frame(width: 54, height: 54)
                                                Text(metric.consumedLabel)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(displayColor)
                                            }
                                            .padding(.bottom, 10)
                                            Text("\(metric.allowedLabel)")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                            Text(metric.title)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.secondary)
                                                .padding(.top, 0)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: NutritionLayout.macroTileMinHeight, alignment: .top)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, -30)
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .glassEffect(in: .rect(cornerRadius: 16.0))
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }
}

private struct CalorieGoalEditorSheet: View {
    @Binding var selectedMacroFocus: MacroCalculator.WeightGoalOption?
    @Binding var calorieGoal: Int
    var maintenanceCalories: Int
    var activityLevelName: String
    var tint: Color
    var onDone: () -> Void

    @State private var goalText: String = ""
    @State private var isApplyingPreset = false
    @State private var originalGoal: Int = 0
    @State private var originalFocus: MacroCalculator.WeightGoalOption?
    @FocusState private var isGoalFieldFocused: Bool
    @State private var didInitializeGoalField: Bool = false
    @State private var showMacroExplainer = false

    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight Goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(MacroCalculator.WeightGoalOption.allCases) { option in
                                SelectablePillComponent(
                                    label: option.displayName,
                                    isSelected: selectedMacroFocus == option,
                                    selectedTint: tint
                                ) {
                                    handleMacroSelection(option)
                                }
                            }
                        }

                        Button(action: { showMacroExplainer = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                Text("Tap for Explanation")
                                Spacer()
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily calorie goal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("0", text: $goalText)
                                .keyboardType(.numberPad)
                                .focused($isGoalFieldFocused)
                                .textFieldStyle(.plain)
                            Text("cal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .surfaceCard(16)
                    }

                    // if let focus = selectedMacroFocus, focus != .custom {
                    //     let recommendation = CalorieGoalPlanner.recommendation(for: focus, maintenanceCalories: maintenanceCalories)
                    //     VStack(alignment: .leading, spacing: 6) {
                    //         Text("Recommended for \(focus.displayName)")
                    //             .font(.caption)
                    //             .foregroundStyle(.secondary)
                    //         Text("\(maintenanceCalories) cal \(recommendation.adjustmentSymbol) \(recommendation.adjustmentCaloriesText) = \(recommendation.value) cal")
                    //             .font(.body)
                    //             .fontWeight(.semibold)
                    //             .foregroundStyle(tint)
                    //         Text("Based on your maintenance of \(maintenanceCalories) cal and \(activityLevelName) activity level. Adjust manually if you need a custom target.")
                    //             .font(.footnote)
                    //             .foregroundStyle(.secondary)
                    //     }
                    // } else if selectedMacroFocus == .custom {
                    //     Text("Custom targets override the preset strategy.")
                    //         .font(.footnote)
                    //         .foregroundStyle(.secondary)
                    // }

                    if maintenanceCalories <= 0 {
                        Text("Maintenance cannot be calculated unless you select \"Male\" or \"Female\".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Maintenance uses the Mifflin-St Jeor equation and your activity level, then applies the selected macro focus offset to reach this calorie target.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Edit Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitGoal()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showMacroExplainer) {
            NavigationStack {
                WeightGoalExplainer()
                    .padding(.horizontal, 18)
                    .navigationTitle("Weight Goals")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showMacroExplainer = false
                            }
                            .foregroundStyle(.primary)
                        }
                    }
            }
        }
        .onAppear {
            // Initialize the editor fields programmatically. We set a small flag
            // so the `onChange(of: goalText)` handler can ignore this initial
            // programmatic assignment — otherwise it would treat it as a user
            // edit and mark the macro focus as `.custom`.
            didInitializeGoalField = false
            goalText = String(calorieGoal)
            originalGoal = calorieGoal
            originalFocus = selectedMacroFocus
        }
        .onChange(of: goalText) { _, newValue in
            // Ignore the first change caused by the initial assignment in
            // `.onAppear` so we don't treat it as a user edit.
            if !didInitializeGoalField {
                didInitializeGoalField = true
                return
            }

            handleGoalTextChange(newValue)
        }
    }

    private func handleMacroSelection(_ option: MacroCalculator.WeightGoalOption) {
        selectedMacroFocus = option
        guard option != .custom else { return }
        let recommended = CalorieGoalPlanner.recommendation(for: option, maintenanceCalories: maintenanceCalories).value
        isApplyingPreset = true
        goalText = String(recommended)
        calorieGoal = recommended
    }

    private func handleGoalTextChange(_ newValue: String) {
        let sanitized = newValue.filter { $0.isNumber }
        if sanitized != newValue {
            goalText = sanitized
            return
        }

        guard !isApplyingPreset else {
            isApplyingPreset = false
            return
        }

        guard let value = Int(sanitized), value > 0 else { return }
        calorieGoal = value
        if selectedMacroFocus != .custom {
            selectedMacroFocus = .custom
        }
    }

    private func commitGoal() {
        if let value = Int(goalText), value > 0 {
            calorieGoal = value
        }
    }

    private func cancelEditing() {
        calorieGoal = originalGoal
        selectedMacroFocus = originalFocus
        onDone()
    }
}

enum CalorieGoalPlanner {
    struct Recommendation {
        let value: Int
        let adjustmentCalories: Int

        var adjustmentSymbol: String {
            adjustmentCalories >= 0 ? "+" : "-"
        }

        var adjustmentCaloriesText: String {
            "\(abs(adjustmentCalories)) cal"
        }
    }

    static func recommendation(for focus: MacroCalculator.WeightGoalOption, maintenanceCalories: Int) -> Recommendation {
        guard maintenanceCalories > 0 else {
            return Recommendation(value: 0, adjustmentCalories: 0)
        }

        let baseline = Double(maintenanceCalories)
        let adjustment = Double(adjustmentCalories(for: focus))
        let adjusted = baseline + adjustment
        let clamped = min(max(adjusted, 1200), 4500)
        let rounded = Int(clamped.rounded())
        return Recommendation(value: rounded, adjustmentCalories: Int(adjustment))
    }

    static func recommendedCalories(for focus: MacroCalculator.WeightGoalOption, maintenanceCalories: Int) -> Int {
        recommendation(for: focus, maintenanceCalories: maintenanceCalories).value
    }

    private static func adjustmentCalories(for focus: MacroCalculator.WeightGoalOption) -> Int {
        switch focus {
        case .maintainWeight:
            return 0
        case .mildWeightLoss:
            return -250
        case .weightLoss:
            return -500
        case .extremeWeightLoss:
            return -1000
        case .mildWeightGain:
            return 250
        case .weightGain:
            return 500
        case .extremeWeightGain:
            return 1000
        case .custom:
            return 0
        }
    }
}

private enum MacroSummaryItem: Identifiable {
    case metric(MacroMetric)

    var id: String {
        switch self {
        case .metric(let metric):
            return metric.id.uuidString
        }
    }
}



struct MacroMetric: Identifiable {
    enum Source: Equatable {
        case preset(MacroPreset)
        case custom
    }

    let id: UUID
    var title: String
    var percent: Double
    var currentLabel: String
    var targetLabel: String
    var color: Color
    var source: Source

    init(
        id: UUID = UUID(),
        title: String,
        percent: Double,
        currentLabel: String,
        targetLabel: String,
        color: Color,
        source: Source
    ) {
        self.id = id
        self.title = title
        self.percent = percent
        self.currentLabel = currentLabel
        self.targetLabel = targetLabel
        self.color = color
        self.source = source
    }

    var isCustom: Bool {
        if case .custom = source { return true }
        return false
    }

    var consumedLabel: String { currentLabel }
    var allowedLabel: String { targetLabel }
}

enum MacroPreset: String, CaseIterable, Identifiable {
    case protein
    case carbs
    case fats
    case fibre
    case water
    case sodium
    case potassium
    case sugar
    case cholesterol

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fats"
        case .fibre: return "Fibre"
        case .water: return "Water"
        case .sodium: return "Sodium"
        case .potassium: return "Potassium"
        case .sugar: return "Sugar"
        case .cholesterol: return "Cholesterol"
        }
    }

    var consumedLabel: String {
        switch self {
        case .protein: return "72g"
        case .carbs: return "110g"
        case .fats: return "38g"
        case .fibre: return "22g"
        case .water: return "2000mL"
        case .sodium: return "1.8g"
        case .potassium: return "3.1g"
        case .sugar: return "35g"
        case .cholesterol: return "180mg"
        }
    }

    var allowedLabel: String {
        switch self {
        case .protein: return "100 g"
        case .carbs: return "200 g"
        case .fats: return "70 g"
        case .fibre: return "30 g"
        case .water: return "2500 mL"
        case .sodium: return "2.3 g"
        case .potassium: return "4.7 g"
        case .sugar: return "50 g"
        case .cholesterol: return "300 mg"
        }
    }

    var percent: Double {
        switch self {
        case .protein: return 0.72
        case .carbs: return 0.55
        case .fats: return 0.43
        case .fibre: return 0.6
        case .water: return 0.8
        case .sodium: return 0.78
        case .potassium: return 0.66
        case .sugar: return 0.7
        case .cholesterol: return 0.6
        }
    }

    var color: Color {
        switch self {
            case .protein: return Color(hex: "#D84A4A") ?? .red
            case .carbs: return Color(hex: "#E6C84F") ?? .yellow
            case .fats: return Color(hex: "#E39A3B") ?? .orange
            case .fibre: return Color(hex: "#4CAF6A") ?? .green
            case .water: return Color(hex: "#4A7BD0") ?? .blue
            case .sodium: return Color(hex: "#4FB6C6") ?? .cyan
            case .potassium: return Color(hex: "#7A5FD1") ?? .purple
            case .sugar: return Color(hex: "#C85FA8") ?? .pink
            case .cholesterol: return Color(hex: "#2a65edff") ?? .indigo
        }
    }
}

private extension MacroPreset {
    static var defaultActiveMetrics: [MacroMetric] {
        [.preset(.protein), .preset(.carbs), .preset(.fats), .preset(.water)]
    }
}

private extension MacroMetric {
    static func preset(_ preset: MacroPreset) -> MacroMetric {
        MacroMetric(
            title: preset.displayName,
            percent: preset.percent,
            currentLabel: preset.consumedLabel,
            targetLabel: preset.allowedLabel,
            color: preset.color,
            source: .preset(preset)
        )
    }

    static func custom(name: String, targetLabel: String, tint: Color) -> MacroMetric {
        MacroMetric(
            title: name,
            percent: 0.4,
            currentLabel: "–",
            targetLabel: targetLabel,
            color: tint.opacity(0.9),
            source: .custom
        )
    }
}



struct MacroEditorSheet: View {
    @Binding var macros: [MacroMetric]
    var tint: Color
    var isMultiColourTheme: Bool
    var macroFocus: MacroCalculator.WeightGoalOption?
    var calorieGoal: Int
    var bodyWeightKg: Double
    @Binding var selectedMacroStrategy: MacroCalculator.MacroDistributionStrategy?
    var isPro: Bool
    var onDone: () -> Void

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var workingMacros: [MacroMetric] = []
    @State private var newCustomName: String = ""
    @State private var newCustomTarget: String = ""
    @State private var hasLoadedState = false
    @State private var showProSubscription = false
    @State private var selectedStrategy: MacroCalculator.MacroDistributionStrategy = .custom
    @State private var showMacroExplainer = false

    private var canAddMoreMacros: Bool {
        if isPro { return true }
        return workingMacros.count < NutritionMacroLimits.freeTrackedMacros
    }

    private var canAddCustomMacro: Bool {
        canAddMoreMacros && !newCustomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !newCustomTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Macro Split Strategy
                    VStack(alignment: .leading, spacing: 12) {
                        MacroEditorSectionHeader(title: "Macro Split")
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
                            ForEach(MacroCalculator.MacroDistributionStrategy.allCases) { strategy in
                                SelectablePillComponent(
                                    label: strategy.displayName,
                                    isSelected: selectedStrategy == strategy,
                                    selectedTint: tint
                                ) {
                                    selectedStrategy = strategy
                                }
                            }
                        }
                        
                        Button(action: { showMacroExplainer = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                Text("Tap for Explanation")
                                Spacer()
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                            
                        Button(action: autoCalculateMacros) {
                            Text("Auto Calculate Macros")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                                        .fill(selectedStrategy == .custom ? Color.gray.opacity(0.5) : tint)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedStrategy == .custom)
                    }

                    // Tracked macros
                    if !workingMacros.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Tracked Macros")
                            VStack(spacing: 12) {
                                ForEach(Array(workingMacros.enumerated()), id: \.element.id) { idx, item in
                                    let binding = $workingMacros[idx]
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(displayColor(for: item).opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Image(systemName: "chart.bar.fill")
                                                        .foregroundStyle(displayColor(for: item))
                                                        .editSheetChangeColorTip(
                                                            hasTrackedItems: !workingMacros.isEmpty,
                                                            isMultiColourTheme: isMultiColourTheme,
                                                            isActive: idx == 0
                                                        )
                                                )

                                            VStack(alignment: .leading, spacing: 6) {
                                                TextField("Name", text: binding.title)
                                                    .font(.subheadline.weight(.semibold))
                                                TextField("Target (e.g. 100 g or 2.0L)", text: binding.targetLabel)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button(role: .destructive) {
                                                removeMetric(item.id)
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
                    }

                    // Quick Add
                    if !MacroPreset.allCases.filter({ !isPresetSelected($0) }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            MacroEditorSectionHeader(title: "Quick Add")
                            VStack(spacing: 12) {
                                ForEach(MacroPreset.allCases.filter { !isPresetSelected($0) }, id: \.self) { preset in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(displayColor(for: preset).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "chart.bar.fill")
                                                    .foregroundStyle(displayColor(for: preset))
                                            )

                                        VStack(alignment: .leading) {
                                            Text(preset.displayName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(preset.allowedLabel)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: { togglePreset(preset) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundStyle(tint)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!canAddMoreMacros)
                                        .opacity(!canAddMoreMacros ? 0.3 : 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .surfaceCard(18)
                                }
                            }
                        }
                    }

                    if !isPro {
                        Button(action: { showProSubscription = true }) {
                            HStack(alignment: .center) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundStyle(tint)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Unlock more macro slots + benefits")
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
                        MacroEditorSectionHeader(title: "Custom Macros")
                        VStack(spacing: 12) {
                            TextField("Macro name", text: $newCustomName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            HStack(spacing: 12) {
                                TextField("Target (e.g. 100 g or 2.0L)", text: $newCustomTarget)
                                    .padding()
                                    .surfaceCard(16)

                                Button(action: addCustomMetric) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(tint)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddCustomMacro)
                                .opacity(!canAddCustomMacro ? 0.4 : 1)
                            }

                            if !isPro {
                                Text("You can track up to \(NutritionMacroLimits.freeTrackedMacros) macros.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        macros = workingMacros
                        selectedMacroStrategy = selectedStrategy
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showMacroExplainer) {
                NavigationStack {
                    MacroStrategyExplainer()
                        .padding(.horizontal, 18)
                        .navigationTitle("Macro Strategies")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showMacroExplainer = false
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                }
            }
        }
        .onAppear(perform: loadInitialState)
        .sheet(isPresented: $showProSubscription) {
            ProSubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    private func loadInitialState() {
        guard !hasLoadedState else { return }
        workingMacros = macros
        selectedStrategy = selectedMacroStrategy ?? .custom
        hasLoadedState = true
    }

    private func displayColor(for metric: MacroMetric) -> Color {
        isMultiColourTheme ? metric.color : tint
    }

    private func displayColor(for preset: MacroPreset) -> Color {
        isMultiColourTheme ? preset.color : tint
    }

    private func togglePreset(_ preset: MacroPreset) {
        if isPresetSelected(preset) {
            workingMacros.removeAll { metric in
                if case .preset(preset) = metric.source { return true }
                return false
            }
        } else if canAddMoreMacros {
            workingMacros.append(.preset(preset))
        }
    }

    private func isPresetSelected(_ preset: MacroPreset) -> Bool {
        workingMacros.contains { metric in
            if case .preset(preset) = metric.source { return true }
            return false
        }
    }

    private func removeMetric(_ id: UUID) {
        workingMacros.removeAll { $0.id == id }
    }

    private func addCustomMetric() {
        guard canAddCustomMacro else { return }
        let trimmedName = newCustomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = newCustomTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTarget.isEmpty else { return }

        let newMetric = MacroMetric.custom(name: trimmedName, targetLabel: trimmedTarget, tint: tint)
        workingMacros.append(newMetric)
        newCustomName = ""
        newCustomTarget = ""
    }

    private func autoCalculateMacros() {
        guard selectedStrategy != .custom else { return }
        
        let calories = Double(calorieGoal)
        var proteinG: Double = 0
        var fatG: Double = 0
        var carbsG: Double = 0
        
        switch selectedStrategy {
        case .highProtein:
            // Protein = 2.5 x BW (or 30% of calories, whichever is higher)
            // Fat = 20%
            // Carbs = remaining calories
            let proteinByWeight = 2.5 * bodyWeightKg
            let proteinByCal = (calories * 0.30) / 4.0
            proteinG = max(proteinByWeight, proteinByCal)
            
            let proteinCal = proteinG * 4.0
            let fatCal = calories * 0.20
            fatG = fatCal / 9.0
            let remainingCal = calories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .balanced:
            // Protein = 25%
            // Fat = 25%
            // Carbs = remaining calories
            let proteinCal = calories * 0.25
            proteinG = proteinCal / 4.0
            let fatCal = calories * 0.25
            fatG = fatCal / 9.0
            let remainingCal = calories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .lowFat:
            // Protein = 1.6 x BW
            // Fat = 15%
            // Carbs = remaining calories
            proteinG = 1.6 * bodyWeightKg
            let proteinCal = proteinG * 4.0
            let fatCal = calories * 0.15
            fatG = fatCal / 9.0
            let remainingCal = calories - proteinCal - fatCal
            carbsG = max(0, remainingCal / 4.0)
            
        case .lowCarb:
            // Protein = 2.0 x BW
            // Carbs = 10%
            // Fat = remaining calories
            proteinG = 2.0 * bodyWeightKg
            let proteinCal = proteinG * 4.0
            let carbCal = calories * 0.10
            carbsG = carbCal / 4.0
            let remainingCal = calories - proteinCal - carbCal
            fatG = max(0, remainingCal / 9.0)
            
        case .custom:
            return
        }
        
        updateOrAddMacro(.protein, value: proteinG)
        updateOrAddMacro(.carbs, value: carbsG)
        updateOrAddMacro(.fats, value: fatG)
    }
    
    private func updateOrAddMacro(_ preset: MacroPreset, value: Double) {
        let rounded = value.rounded()
        let targetLabel = String(format: "%.0f g", rounded)
        
        if let idx = workingMacros.firstIndex(where: { 
            if case .preset(let p) = $0.source { return p == preset }
            return false 
        }) {
            workingMacros[idx].targetLabel = targetLabel
        } else {
            // Add it if not present
            var newMetric = MacroMetric.preset(preset)
            newMetric.targetLabel = targetLabel
            workingMacros.append(newMetric)
        }
    }
}

private struct MacroEditorSectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
}

private struct MacroPresetRow: View {
    var preset: MacroPreset
    var isSelected: Bool
    var canAddMore: Bool
    var tint: Color
    var color: Color
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "chart.bar.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color)
                )

            Text(preset.displayName)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isSelected ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.red : tint)
            }
            .buttonStyle(.plain)
            .disabled(!isSelected && !canAddMore)
            .opacity(!isSelected && !canAddMore ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .surfaceCard(18)
    }
}

private struct MacroTargetEditorRow: View {
    @Binding var metric: MacroMetric
    var tint: Color
    var displayColor: Color
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(displayColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(displayColor.opacity(0.6), lineWidth: 1)
                    )

                if metric.isCustom {
                    TextField("Custom macro", text: $metric.title)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.plain)
                } else {
                    Text(metric.title)
                        .font(.headline)
                }

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Target / Max")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("e.g. 100g", text: $metric.targetLabel)
                        .textFieldStyle(.plain)
                }
                .padding()
                .surfaceCard(16)
            }
        }
        .padding(16)
        .surfaceCard(20)
    }
}

private struct CustomMacroComposer: View {
    @Binding var name: String
    @Binding var target: String
    var tint: Color
    var isDisabled: Bool
    var canAddMore: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Macro name", text: $name)
                .textInputAutocapitalization(.words)
                .padding()
                .surfaceCard(16)

            HStack(spacing: 12) {
                TextField("Target (e.g. 30g)", text: $target)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding()
                    .surfaceCard(16)

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(isDisabled ? Color.gray.opacity(0.4) : tint)
                        )
                }
                .buttonStyle(.plain)
            }

            if !canAddMore {
                Text("You've reached the maximum number of macros.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct CalorieConsumedAdjustmentSheet: View {
    @Binding var currentCalories: Int
    var tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var inputValue: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust Consumed Calories")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter the amount to add or remove from today's total.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("0", text: $inputValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    Text("cal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .surfaceCard(16)

                HStack(spacing: 16) {
                    Button(action: { handleAction(isAddition: false) }) {
                        Label("Remove", systemImage: "minus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: { handleAction(isAddition: true) }) {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Consumed Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func handleAction(isAddition: Bool) {
        guard let delta = Int(inputValue), delta > 0 else { return }
        let signedDelta = isAddition ? delta : -delta
        currentCalories = max(0, currentCalories + signedDelta)
        dismiss()
    }
}

private struct MealIntakeSheet: View {
    var tint: Color
    var trackedMacros: [TrackedMacro]
    var onSave: (MealIntakeEntry) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMealType: MealType = .breakfast
    @State private var itemName: String = ""
    @State private var portionSizeGrams: String = "100"
    @State private var caloriesText: String = ""
    @State private var macroInputs: [String: String]
    @State private var isLookupPresented: Bool = false
    @State private var lookupShouldAutoSearch: Bool = false
    @State private var lookupShouldOpenScanner: Bool = false

    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    init(
        tint: Color,
        trackedMacros: [TrackedMacro],
        onSave: @escaping (MealIntakeEntry) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.tint = tint
        self.trackedMacros = trackedMacros
        self.onSave = onSave
        self.onCancel = onCancel
        _macroInputs = State(initialValue: Dictionary(uniqueKeysWithValues: trackedMacros.map { ($0.id, "") }))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal type")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(MealType.allCases) { type in
                                SelectablePillComponent(
                                    label: type.displayName,
                                    isSelected: selectedMealType == type,
                                    selectedTint: tint
                                ) {
                                    selectedMealType = type
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item details")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            TextField("Item name", text: $itemName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)

                            HStack {
                                TextField("0", text: $portionSizeGrams)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                Text("g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(width: 100)
                            .surfaceCard(16)
                            .onChange(of: portionSizeGrams) { _, newValue in
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                if filtered != newValue {
                                    portionSizeGrams = filtered
                                }
                                // Don't force a "0" while the user is actively editing —
                                // allow an empty string so they can clear and type a new value.
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button(action: {
                            lookupShouldOpenScanner = false
                            lookupShouldAutoSearch = true
                            isLookupPresented = true
                        }) {
                            Label("Search", systemImage: "magnifyingglass")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 8)
                                .surfaceCard(16)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            lookupShouldOpenScanner = true
                            lookupShouldAutoSearch = false
                            isLookupPresented = true
                        }) {
                            Image(systemName: "barcode")
                                .font(.title2.weight(.semibold))
                                .frame(minWidth: 64, minHeight: 44)
                                .padding(.vertical, 8)
                                .surfaceCard(16)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Calories")
                              .font(.footnote)
                              .foregroundStyle(.secondary)

                            Spacer()
                        }
                        
                        HStack(spacing: 8) {
                            TextField("Calories", text: $caloriesText)
                                .keyboardType(.numberPad)

                            Text("cal")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .surfaceCard(16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macros")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        VStack(spacing: 12) {
                            ForEach(trackedMacros, id: \.id) { macro in
                                HStack {
                                    Text(macro.name)
                                      .font(.footnote)
                                      .foregroundStyle(.secondary)

                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    TextField("0", text: Binding(
                                          get: { macroInputs[macro.id, default: ""] },
                                          set: { macroInputs[macro.id] = $0 }
                                      ))
                                      .keyboardType(.decimalPad)

                                    Text(macro.unit)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .surfaceCard(16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Log Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { handleSave() }
                        .fontWeight(.semibold)
                        .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $isLookupPresented) {
                LookupComponent(
                    accentColor: tint,
                    itemName: $itemName,
                    portionSizeGrams: $portionSizeGrams,
                    onAdd: { selected, portion, detail in
                        applyLookupSelection(selected, portion: portion, detail: detail)
                        isLookupPresented = false
                    },
                    shouldOpenScanner: $lookupShouldOpenScanner,
                    shouldAutoSearch: $lookupShouldAutoSearch
                )
            }
        }
    }

    private func handleSave() {
        let cleanedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let portion = portionSizeGrams.trimmingCharacters(in: .whitespacesAndNewlines)
        let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let macros = trackedMacros.map { macro in
            let value = macroInputs[macro.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let amount = Double(value) ?? 0
            return MealMacroEntry(
                trackedMacroId: macro.id,
                name: macro.name,
                unit: macro.unit,
                amount: amount
            )
        }

        let entry = MealIntakeEntry(
            mealType: selectedMealType,
            itemName: cleanedName,
            quantityPerServing: portion.isEmpty ? "0" : portion,
            calories: calories,
            macros: macros
        )
        onSave(entry)
        dismiss()
    }

    private func applyLookupSelection(_ item: LookupResultItem, portion: Int, detail: FatSecretFoodDetail?) {
        let grams = max(portion, 1)
        let scaledDetail = detail

        itemName = item.name
        portionSizeGrams = String(grams)

        let caloriesValue = scaledDetail?.calories ?? Double(item.calories)
        caloriesText = String(Int(round(caloriesValue)))

        for macro in trackedMacros {
            guard let amount = lookupAmount(for: macro, item: item, detail: scaledDetail) else { continue }
            macroInputs[macro.id] = formattedMacroAmount(amount)
        }
    }

    private func lookupAmount(for tracked: TrackedMacro, item: LookupResultItem, detail: FatSecretFoodDetail?) -> Double? {
        let name = tracked.name.lowercased()
        let unit = tracked.unit.lowercased()

        switch name {
        case "protein":
            return detail?.protein ?? Double(item.protein)
        case "carb", "carbs", "carbohydrate", "carbohydrates":
            return detail?.carbs ?? Double(item.carbs)
        case "fat", "fats":
            return detail?.fat ?? Double(item.fat)
        case "fiber", "fibre":
            return detail?.fiber
        case "sugar", "sugars":
            return detail?.sugar ?? Double(item.sugar)
        case "sodium":
            return convertMineral(detail?.sodium ?? Double(item.sodium), targetUnit: unit)
        case "potassium":
            return convertMineral(detail?.potassium ?? Double(item.potassium), targetUnit: unit)
        default:
            return nil
        }
    }

    private func convertMineral(_ valueMg: Double, targetUnit: String) -> Double {
        if targetUnit.contains("mg") { return valueMg }
        if targetUnit.contains("g") { return valueMg / 1000.0 }
        return valueMg
    }

    private func formattedMacroAmount(_ amount: Double) -> String {
        let rounded = (amount * 10).rounded() / 10
        let isWhole = rounded.truncatingRemainder(dividingBy: 1) == 0
        return isWhole ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}

private struct MacroLogEntrySheet: View {
    var metric: MacroMetric
    var initialValue: Double
    var unitSuffix: String
    var onSave: (Double) -> Void
    var onCancel: () -> Void

    @State private var inputValue: String = ""

    init(metric: MacroMetric, initialValue: Double, unitSuffix: String, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        self.metric = metric
        self.initialValue = max(0, initialValue)
        self.unitSuffix = unitSuffix
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log \(metric.title)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter the amount to add or remove")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("0", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .padding()
                    .surfaceCard(16)

                HStack(spacing: 16) {
                    Button(action: { handleAction(isAddition: false) }) {
                        Label("Remove", systemImage: "minus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: { handleAction(isAddition: true) }) {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func formattedValue(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        let formatted = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return unitSuffix.isEmpty ? formatted : "\(formatted)\(unitSuffix)"
    }

    private func handleAction(isAddition: Bool) {
        guard let delta = Double(inputValue), delta > 0 else { return }
        let signedDelta = isAddition ? delta : -delta
        let updatedValue = max(0, initialValue + signedDelta)
        onSave(updatedValue)
    }
}

struct DailyMealLogSection: View {
    var accentColorOverride: Color?
    var weeklyEntries: [WeeklyProgressEntry] = []
    var weekStartsOnMonday: Bool = true
    var trackedMacros: [TrackedMacro] = []
    var selectedDate: Date
    var currentConsumedCalories: Int
    var currentCalorieGoal: Int
    var currentMacroConsumptions: [MacroConsumption]
    var onDeleteMealEntry: (MealIntakeEntry) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var showWeeklyMacros = false
    @State private var isLoadingMeals = false
    @State private var mealEntries: [MealIntakeEntry] = []
    private let dayFirestoreService = DayFirestoreService()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let tint = accentColorOverride ?? .accentColor
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Label("What You've Eaten", systemImage: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoadingMeals && mealGroups.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().tint(tint)
                            Text("Syncing meals for this day...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if mealGroups.isEmpty {
                        Text("No meals logged yet. Tap \"Log Intake\" to add what you ate.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        // Use a non-scrolling List so swipe actions are available on iOS 16+.
                        // Increase estimated row height to prevent cut-off content for multi-line items.
                        let rowHeight: CGFloat = 85
                        let headerHeight: CGFloat = 32
                        let totalRows = mealGroups.reduce(0) { $0 + $1.entries.count }
                        // Add a buffer to the total height to account for list padding and potential text wrapping
                        let listHeight = CGFloat(totalRows) * rowHeight + CGFloat(mealGroups.count) * headerHeight + 40

                        List {
                            ForEach(mealGroups) { group in
                                Section {
                                    ForEach(group.entries) { entry in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(alignment: .firstTextBaseline) {
                                                Text(itemTitle(for: entry))
                                                    .font(.subheadline.weight(.semibold))
                                                Spacer()
                                                if !entry.quantityPerServing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    Text(entry.quantityPerServing)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }

                                                if entry.calories > 0 {
                                                    Text("\(entry.calories) cal")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Text(itemDetail(for: entry))
                                                .font(.footnote)
                                                .foregroundStyle(Color.primary.opacity(0.85))
                                        }
                                        .padding(.vertical, 4)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                mealEntries.removeAll { $0.id == entry.id }
                                                onDeleteMealEntry(entry)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 8) {
                                        Image(systemName: iconName(for: group.mealType))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(tint)
                                        Text(group.mealType.displayName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.leading, 4)
                                }
                                .textCase(nil)
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: max(listHeight, rowHeight))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)

        VStack(alignment: .leading, spacing: 16) {
            // New collapsible Weekly Macros section (separate from meals)
            HStack {
                Spacer()
                Label("Weekly Intake", systemImage: "chart.bar.xaxis")
                    .font(.callout.weight(.semibold))
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showWeeklyMacros.toggle()
                }
            }

            if showWeeklyMacros {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Determine theme-aware tint: if the selected theme is multiColour, prefer the provided accent (or system accent),
                            // otherwise use the theme's accent color and disable per-tracked-macro colours.
                            let themeTint: Color = themeManager.selectedTheme == .multiColour ? (accentColorOverride ?? .accentColor) : themeManager.selectedTheme.accent(for: colorScheme)
                            let useTrackedColors = themeManager.selectedTheme == .multiColour

                            ForEach(weeklyMacroSummaries(weekStartsOnMonday: weekStartsOnMonday, trackedMacros: trackedMacros, selectedDate: selectedDate, currentConsumedCalories: currentConsumedCalories, currentCalorieGoal: currentCalorieGoal, currentMacroConsumptions: currentMacroConsumptions)) { summary in
                                DynamicMacroDayColumn(summary: summary, tint: themeTint, trackedMacros: trackedMacros, useTrackedColors: useTrackedColors)
                            }
                        }
                        .padding(.vertical, 4)
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
        .onAppear {
            refreshMeals()
        }
        .onChange(of: selectedDate) {
            refreshMeals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDataDidChange)) { note in
            if let info = note.userInfo as? [String: Any], let date = info["date"] as? Date {
                let localCal = Calendar.current
                let compsA = localCal.dateComponents([.year, .month, .day], from: date)
                let compsB = localCal.dateComponents([.year, .month, .day], from: selectedDate)
                if compsA == compsB {
                    refreshMeals()
                }
            } else {
                // If notification doesn't include date, just refresh conservatively
                refreshMeals()
            }
        }
    }

    private var mealGroups: [MealGroup] {
        let grouped = Dictionary(grouping: mealEntries) { $0.mealType }
        return orderedMealTypes.compactMap { mealType in
            guard let entries = grouped[mealType], !entries.isEmpty else { return nil }

            let sorted = entries.sorted { lhs, rhs in
                let lhsName = lhs.itemName.trimmingCharacters(in: .whitespacesAndNewlines)
                let rhsName = rhs.itemName.trimmingCharacters(in: .whitespacesAndNewlines)

                if lhsName == rhsName { return lhs.id < rhs.id }
                if lhsName.isEmpty { return false }
                if rhsName.isEmpty { return true }
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }

            return MealGroup(mealType: mealType, entries: sorted)
        }
    }

    private var orderedMealTypes: [MealType] {
        [.breakfast, .lunch, .dinner, .snack]
    }

    private func refreshMeals() {
        let localDay = Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
        mealEntries = localDay.mealIntakes
        isLoadingMeals = true
        dayFirestoreService.fetchDay(for: selectedDate, in: modelContext, trackedMacros: trackedMacros) { fetchedDay in
            DispatchQueue.main.async {
                let refreshed = fetchedDay ?? Day.fetchOrCreate(for: selectedDate, in: modelContext, trackedMacros: trackedMacros)
                mealEntries = refreshed.mealIntakes
                isLoadingMeals = false
            }
        }
    }

    private func itemTitle(for entry: MealIntakeEntry) -> String {
        let trimmed = entry.itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? entry.mealType.displayName : trimmed
    }

    private func itemDetail(for entry: MealIntakeEntry) -> String {
        var parts: [String] = []
        let macroText = macroSummary(for: entry)
        if !macroText.isEmpty {
            parts.append(macroText)
        }
        if parts.isEmpty {
            return ""
        }
        return parts.joined(separator: " • ")
    }

    private func macroSummary(for entry: MealIntakeEntry) -> String {
        entry.macros.compactMap { macro in
            guard macro.amount > 0 else { return nil }
            let unit = macro.unit.isEmpty ? "g" : macro.unit
            let isWhole = macro.amount.truncatingRemainder(dividingBy: 1) == 0
            let formatted = isWhole ? String(format: "%.0f", macro.amount) : String(format: "%.1f", macro.amount)
            return "\(macro.name) \(formatted)\(unit)"
        }
        .joined(separator: " · ")
    }

    private func iconName(for mealType: MealType) -> String {
        switch mealType {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "fork.knife"
            case .dinner: return "moon.stars.fill"
            case .snack: return "cup.and.saucer.fill"
        }
    }

    private func weeklyMacroSummaries(weekStartsOnMonday: Bool, trackedMacros: [TrackedMacro], selectedDate: Date, currentConsumedCalories: Int, currentCalorieGoal: Int, currentMacroConsumptions: [MacroConsumption]) -> [WeeklyMacroSummary] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // Use local calendar to extract YMD from selectedDate, then construct UTC date.
        let localCal = Calendar.current
        let components = localCal.dateComponents([.year, .month, .day], from: selectedDate)

        // Use the selectedDate as the reference for which week to show
        let referenceDay = cal.date(from: components) ?? cal.startOfDay(for: selectedDate)
        let weekday = cal.component(.weekday, from: referenceDay) // 1 = Sunday
        // Allow weeks to start on Monday or Sunday based on the flag
        let startIndex = weekStartsOnMonday ? 2 : 1
        let offsetToStart = (weekday - startIndex + 7) % 7
        let startOfWeek = cal.date(byAdding: .day, value: -offsetToStart, to: referenceDay) ?? referenceDay

        let weekDates: [Date] = (0..<7).compactMap { i in
            cal.date(byAdding: .day, value: i, to: startOfWeek)
        }
        // Normalize selectedDate to UTC start-of-day for comparison
        let selDayStart = referenceDay

        // Normalize "today" to UTC start-of-day using local calendar
        let todayComponents = localCal.dateComponents([.year, .month, .day], from: Date())
        let todayUTC = cal.date(from: todayComponents) ?? cal.startOfDay(for: Date())

        return weekDates.map { date in
            let dayStart = cal.startOfDay(for: date)
            // Mark a day as future relative to the actual current day
            let isFuture = dayStart > todayUTC

            // If this is the currently-selected date, prefer the in-memory
            // binding values so the UI updates immediately while the save
            // to the ModelContext/Firestore completes asynchronously.
            if dayStart == selDayStart {
                let calories = currentConsumedCalories
                
                // Align with trackedMacros to ensure consistency
                let macros: [MacroConsumption] = trackedMacros.map { tracked in
                    // 1. Try matching by ID
                    if let match = currentMacroConsumptions.first(where: { $0.trackedMacroId == tracked.id }) {
                        return match
                    }
                    // 2. Try matching by name (case-insensitive) to handle legacy data or ID mismatches
                    if let match = currentMacroConsumptions.first(where: { $0.name.localizedCaseInsensitiveCompare(tracked.name) == .orderedSame }) {
                        return MacroConsumption(trackedMacroId: tracked.id, name: tracked.name, unit: tracked.unit, consumed: match.consumed)
                    }
                    // 3. Default to 0
                    return MacroConsumption(trackedMacroId: tracked.id, name: tracked.name, unit: tracked.unit, consumed: 0)
                }

                return WeeklyMacroSummary(
                    date: dayStart,
                    calories: calories,
                    calorieGoal: currentCalorieGoal,
                    macros: macros,
                    isFuture: isFuture
                )
            }

            let request = FetchDescriptor<Day>(predicate: #Predicate { $0.date == dayStart })
            let day: Day? = (try? modelContext.fetch(request))?.first

            let calories = day?.caloriesConsumed ?? 0
            let calorieGoal = day?.calorieGoal ?? 0
            let dayConsumptions = day?.macroConsumptions ?? []
            
            // Align with trackedMacros to ensure consistency
            let macros: [MacroConsumption] = trackedMacros.map { tracked in
                // 1. Try matching by ID
                if let match = dayConsumptions.first(where: { $0.trackedMacroId == tracked.id }) {
                    return match
                }
                // 2. Try matching by name (case-insensitive)
                if let match = dayConsumptions.first(where: { $0.name.localizedCaseInsensitiveCompare(tracked.name) == .orderedSame }) {
                    return MacroConsumption(trackedMacroId: tracked.id, name: tracked.name, unit: tracked.unit, consumed: match.consumed)
                }
                // 3. Default to 0
                return MacroConsumption(trackedMacroId: tracked.id, name: tracked.name, unit: tracked.unit, consumed: 0)
            }

            return WeeklyMacroSummary(
                date: dayStart,
                calories: calories,
                calorieGoal: calorieGoal,
                macros: macros,
                isFuture: isFuture
            )
        }
    }
}

private struct MealReminderEditorSheet: View {
    @Binding var mealReminders: [MealReminder]
    var tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var workingReminders: [MealReminder]

    init(mealReminders: Binding<[MealReminder]>, tint: Color) {
        _mealReminders = mealReminders
        self.tint = tint
        _workingReminders = State(initialValue: MealReminderEditorSheet.normalizedReminders(mealReminders.wrappedValue))
    }

    private static func sortedReminders(_ reminders: [MealReminder]) -> [MealReminder] {
        let order: [MealType: Int] = [.breakfast: 0, .lunch: 1, .dinner: 2, .snack: 3]
        return reminders.sorted { lhs, rhs in
            order[lhs.mealType, default: 0] < order[rhs.mealType, default: 0]
        }
    }

    private static func normalizedReminders(_ reminders: [MealReminder]) -> [MealReminder] {
        var map = [MealType: MealReminder]()
        for reminder in reminders {
            map[reminder.mealType] = reminder
        }
        for defaultReminder in MealReminder.defaults where map[defaultReminder.mealType] == nil {
            map[defaultReminder.mealType] = defaultReminder
        }
        return sortedReminders(Array(map.values))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($workingReminders) { $reminder in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.mealType.displayName)
                                .font(.body.weight(.semibold))
                            Text("Reminder time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        DatePicker(
                            "",
                            selection: Binding<Date>(
                                get: { reminder.dateForToday },
                                set: { newValue in
                                    let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                    reminder.hour = comps.hour ?? reminder.hour
                                    reminder.minute = comps.minute ?? reminder.minute
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .tint(tint)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Meal Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        mealReminders = MealReminderEditorSheet.normalizedReminders(workingReminders)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// New 2x2 Meal Schedule grid section
private struct MealScheduleSection: View {
    var accentColorOverride: Color?
    @Binding var checkedMeals: Set<String>
    var mealReminders: [MealReminder]

    private struct MealCell: Identifiable {
        let id = UUID()
        let mealType: MealType
        let icon: String
        let defaultTime: String
    }

    private let cells: [MealCell] = [
        MealCell(mealType: .breakfast, icon: "sunrise.fill", defaultTime: "7:30 AM"),
        MealCell(mealType: .lunch, icon: "fork.knife", defaultTime: "12:30 PM"),
        MealCell(mealType: .dinner, icon: "moon.stars.fill", defaultTime: "7:00 PM"),
        MealCell(mealType: .snack, icon: "cup.and.saucer.fill", defaultTime: "3:30 PM")
    ]

    var body: some View {
        let tint = accentColorOverride ?? .accentColor
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cells) { cell in
                Button(action: {
                    let key = cell.mealType.rawValue
                    withAnimation(.easeInOut) {
                        if checkedMeals.contains(key) {
                            checkedMeals.remove(key)
                        } else {
                            checkedMeals.insert(key)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((checkedMeals.contains(cell.mealType.rawValue) ? tint.opacity(0.18) : Color(.systemGray6)))
                                .frame(width: 44, height: 44)
                            if checkedMeals.contains(cell.mealType.rawValue) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(tint)
                            } else {
                                Image(systemName: cell.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(cell.mealType.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(checkedMeals.contains(cell.mealType.rawValue) ? tint : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(timeText(for: cell.mealType, fallback: cell.defaultTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(checkedMeals.contains(cell.mealType.rawValue) ? tint.opacity(0.08) : Color.clear)
                    )
                    .glassEffect(in: .rect(cornerRadius: 12.0))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timeText(for mealType: MealType, fallback: String) -> String {
        if let reminder = mealReminders.first(where: { $0.mealType == mealType }) {
            return reminder.displayTime
        }
        return fallback
    }
}

private struct WeeklyMacroSummary: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
    let calorieGoal: Int
    let macros: [MacroConsumption]
    let isFuture: Bool
}

private struct DynamicMacroDayColumn: View {
    var summary: WeeklyMacroSummary
    var tint: Color
    var trackedMacros: [TrackedMacro] = []
    var useTrackedColors: Bool = true

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "E, d MMM"
        return f.string(from: summary.date)
    }

    private var macroMaxValue: Double {
        let targetMax = summary.macros.compactMap { macro in
            trackedMacros.first(where: { $0.id == macro.trackedMacroId })?.target
        }.max() ?? 0
        let consumedMax = summary.macros.map { $0.consumed }.max() ?? 0
        let fallback = max(consumedMax, 1)
        return targetMax > 0 ? targetMax : fallback
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(dayLabel)
                .font(.caption)
                .fontWeight(.semibold)

            VStack(spacing: 10) {
                let calorieMax = summary.calorieGoal > 0 ? Double(summary.calorieGoal) : 4000
                MacroIndicatorRow(label: "Calories", color: tint, value: Double(summary.calories), maxValue: calorieMax, unit: "cal")

                if summary.macros.isEmpty {
                    Text("No macros logged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(summary.macros, id: \.id) { macro in
                        let macroColor: Color = {
                            if useTrackedColors, let tracked = trackedMacros.first(where: { $0.id == macro.trackedMacroId }) {
                                return tracked.color
                            }
                            return tint
                        }()

                        let macroTarget = trackedMacros.first(where: { $0.id == macro.trackedMacroId })?.target ?? 0
                        let maxValue = macroTarget > 0 ? macroTarget : macroMaxValue

                        MacroIndicatorRow(
                            label: macro.name,
                            color: macroColor,
                            value: macro.consumed,
                            maxValue: maxValue,
                            unit: macro.unit
                        )
                    }
                }
            }
            Spacer(minLength: 4)
        }
        .padding(EdgeInsets(top: 28, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 160)
        .frame(minHeight: 240)
        .liquidGlass(cornerRadius: 14)
    }
}

private struct MacroIndicatorRow: View {
    var label: String
    var color: Color
    var value: Double
    var maxValue: Double
    var unit: String = "g"

    private var displayText: String {
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedUnit = trimmedUnit.lowercased()

        switch lowercasedUnit {
        case "l":
            return String(format: "%.1fL", value)
        case "ml":
            return "\(Int(value.rounded()))mL"
        case "cal":
            return "\(Int(value.rounded()))cal"
        default:
            let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
            let formatted = isWhole ? String(format: "%.0f", value) : String(format: "%.1f", value)
            let suffix = trimmedUnit.isEmpty ? "g" : trimmedUnit
            return "\(formatted)\(suffix)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ProgressView(value: min(maxValue > 0 ? value / maxValue : 0, 1.0))
                .tint(color)
                .frame(height: 6)
        }
    }
}

private struct MacroDayColumn: View {
    var date: Date
    var tint: Color
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var waterMilliliters: Double
    var isFuture: Bool = false

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "E, d MMM"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(dayLabel)
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
                VStack(spacing: 10) {
                    MacroIndicatorRow(label: "Calories", color: .primary, value: Double(calories), maxValue: 4000, unit: "cal")
                    MacroIndicatorRow(label: "Protein", color: .red, value: Double(protein), maxValue: 200)
                    MacroIndicatorRow(label: "Carbs", color: Color(.systemTeal), value: Double(carbs), maxValue: 400)
                    MacroIndicatorRow(label: "Fats", color: .orange, value: Double(fats), maxValue: 150)
                    MacroIndicatorRow(label: "Water", color: .cyan, value: waterMilliliters, maxValue: 4000, unit: "mL")
                }
                Spacer()
            }
        }
        .padding(EdgeInsets(top: 28, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 140, height: 220)
        .liquidGlass(cornerRadius: 14)
    }
}

private struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 6)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

private struct MealGroup: Identifiable {
    let mealType: MealType
    let entries: [MealIntakeEntry]

    var id: String { mealType.rawValue }
}

struct FastingTimerCard: View {
    var accentColorOverride: Color?
    @Binding var showProtocolSheet: Bool
    var onProtocolChanged: (Int) -> Void

    @AppStorage("fasting.startTimestamp") private var storedFastingStartTimestamp: Double = 0
    @AppStorage("fasting.durationMinutes") private var storedFastingDurationMinutes: Int = 0
    @AppStorage("alerts.fastingEnabled") private var fastingAlertsEnabled: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedProtocol: FastingProtocolOption
    @State private var customHours: String
    @State private var customMinutes: String
    @State private var fastingMinutes: Int
    @State private var fastingStartDate: Date? = nil
    @State private var now: Date = Date()
    @State private var hasScheduledNotification = false
    @State private var hasFiredOverNotification = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        accentColorOverride: Color?,
        showProtocolSheet: Binding<Bool>,
        currentFastingMinutes: Int,
        onProtocolChanged: @escaping (Int) -> Void
    ) {
        self.accentColorOverride = accentColorOverride
        _showProtocolSheet = showProtocolSheet
        self.onProtocolChanged = onProtocolChanged

        // Prefer persisted duration if available so the timer resumes without flicker on app relaunch
        let restoredMinutes = UserDefaults.standard.integer(forKey: "fasting.durationMinutes")
        let resolvedMinutes = restoredMinutes > 0 ? restoredMinutes : max(currentFastingMinutes, 0)
        _fastingMinutes = State(initialValue: resolvedMinutes)
        _selectedProtocol = State(initialValue: FastingProtocolOption.from(minutes: resolvedMinutes))
        let hoursComponent = resolvedMinutes / 60
        let minutesComponent = resolvedMinutes % 60
        _customHours = State(initialValue: String(hoursComponent))
        _customMinutes = State(initialValue: String(format: "%02d", minutesComponent))

        // If a persisted start exists, seed the state so the UI shows the running timer immediately
        let persistedStart = UserDefaults.standard.double(forKey: "fasting.startTimestamp")
        if persistedStart > 0 {
            _fastingStartDate = State(initialValue: Date(timeIntervalSince1970: persistedStart))
        }
    }

    private var tint: Color {
        accentColorOverride ?? .green
    }

    private var effectiveTint: Color {
        // When overtime, force a red tint to highlight the breach
        isOverTime ? .red : tint
    }

    private var fastingDuration: TimeInterval {
        TimeInterval(fastingMinutes * 60)
    }

    private var fastingEndDate: Date? {
        fastingStartDate?.addingTimeInterval(fastingDuration)
    }

    private var remainingSeconds: TimeInterval {
        guard let start = fastingStartDate else { return fastingDuration }
        return start.addingTimeInterval(fastingDuration).timeIntervalSince(now)
    }

    private var isActive: Bool {
        fastingStartDate != nil
    }

    private var isOverTime: Bool {
        isActive && remainingSeconds <= 0
    }

    private var progress: Double {
        guard isActive, fastingDuration > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(fastingStartDate ?? now)
        return min(max(elapsed / fastingDuration, 0), 1)
    }

    private var displayTime: String {
        if isOverTime {
            return formattedDuration(seconds: abs(remainingSeconds))
        }
        return formattedDuration(seconds: max(remainingSeconds, 0))
    }

    private var nextMealText: String {
        guard let end = fastingEndDate else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if isOverTime {
            return "Time gone over since \(formatter.string(from: end))"
        }
        return "Starts at \(formatter.string(from: end))"
    }

    private var protocolDisplayText: String {
        switch selectedProtocol {
        case .twelveTwelve:
            return "12:12"
        case .fourteenTen:
            return "14:10"
        case .sixteenEight:
            return "16:8"
        case .custom:
            let hoursText = customHours.isEmpty ? "0" : customHours
            let minutesText = customMinutes.isEmpty ? "00" : customMinutes
            return "Custom \(hoursText):\(minutesText)"
        }
    }

    private func formattedDuration(seconds: TimeInterval) -> String {
        let clamped = max(seconds, 0)
        let totalMinutes = Int(clamped / 60)
        let hoursComponent = totalMinutes / 60
        let minutesComponent = totalMinutes % 60
        return String(format: "%02dh %02dm", hoursComponent, minutesComponent)
    }

    private func resolvedMinutes() -> Int {
        switch selectedProtocol {
        case .twelveTwelve:
            return FastingProtocolOption.twelveTwelve.minutes
        case .fourteenTen:
            return FastingProtocolOption.fourteenTen.minutes
        case .sixteenEight:
            return FastingProtocolOption.sixteenEight.minutes
        case .custom:
            let hoursValue = max(Int(customHours) ?? 0, 0)
            let minutesValue = min(max(Int(customMinutes) ?? 0, 0), 59)
            return max(hoursValue, 0) * 60 + minutesValue
        }
    }

    private func syncCustomFields(from minutes: Int) {
        let hoursComponent = minutes / 60
        let minutesComponent = minutes % 60
        customHours = String(hoursComponent)
        customMinutes = String(format: "%02d", minutesComponent)
    }

    private func applyProtocolChange() {
        let minutes = resolvedMinutes()
        fastingMinutes = minutes
        syncCustomFields(from: minutes)
        onProtocolChanged(minutes)

        if isActive {
            storedFastingDurationMinutes = minutes
        }

        if isActive {
            hasScheduledNotification = false
            hasFiredOverNotification = false
            scheduleNotificationIfNeeded()
        }
    }

    private func startFast() {
        let start = Date()
        fastingStartDate = start
        storedFastingStartTimestamp = start.timeIntervalSince1970
        storedFastingDurationMinutes = fastingMinutes
        hasScheduledNotification = false
        hasFiredOverNotification = false
        scheduleNotificationIfNeeded()
    }

    private func endFast() {
        fastingStartDate = nil
        storedFastingStartTimestamp = 0
        storedFastingDurationMinutes = 0
        hasScheduledNotification = false
        hasFiredOverNotification = false
        cancelFastingNotification()
    }

    private func restoreFastingStateIfNeeded() {
        guard storedFastingStartTimestamp > 0 else { return }
        let restoredStart = Date(timeIntervalSince1970: storedFastingStartTimestamp)
        fastingStartDate = restoredStart

        let restoredDuration = storedFastingDurationMinutes > 0 ? storedFastingDurationMinutes : fastingMinutes
        fastingMinutes = restoredDuration
        let protocolFromDuration = FastingProtocolOption.from(minutes: restoredDuration)
        selectedProtocol = protocolFromDuration
        syncCustomFields(from: restoredDuration)

        hasScheduledNotification = false
        hasFiredOverNotification = false
        scheduleNotificationIfNeeded()
    }

    private func scheduleNotificationIfNeeded() {
        guard fastingAlertsEnabled else { return }
        guard let end = fastingEndDate else { return }
        if hasScheduledNotification { return }
        let center = UNUserNotificationCenter.current()
        let identifier = "fasting.end"

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("FastingTimerCard: notification permission error: \(error)")
            }
            guard granted else {
                print("FastingTimerCard: notification permission not granted")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Fast Complete"
            content.body = "Your fasting window finished. Time to refuel."
            content.sound = .default

            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            let interval = max(end.timeIntervalSinceNow, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("FastingTimerCard: failed to schedule notification: \(error)")
                }
            }
            hasScheduledNotification = true
        }
    }

    private func sendCompletionNotificationIfNeeded() {
        // Only send an immediate notification while the app is active —
        // background delivery is handled by the scheduled `fasting.end` request.
        guard fastingAlertsEnabled, isOverTime, !hasFiredOverNotification, scenePhase == .active else { return }

        hasFiredOverNotification = true
        let center = UNUserNotificationCenter.current()

        // Remove any pending fasting notifications to avoid duplicates.
        center.removePendingNotificationRequests(withIdentifiers: ["fasting.end", "fasting.end.immediate"])
        hasScheduledNotification = false

        let content = UNMutableNotificationContent()
        content.title = "Fast Complete"
        content.body = "Your fasting window finished. Time to refuel."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "fasting.end.immediate", content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                print("FastingTimerCard: failed to deliver completion notification: \(error)")
            }
        }
    }

    private func cancelFastingNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["fasting.end", "fasting.end.immediate"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(protocolDisplayText)
                .font(.title)
                .fontWeight(.semibold)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(effectiveTint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(isOverTime ? "Over Time" : "Time Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(displayTime)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOverTime ? .red : .primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 6) {
                if isActive {
                    Text("Next Meal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nextMealText)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .frame(height: 40)

            Button {
                if isActive {
                    endFast()
                } else {
                    startFast()
                }
            } label: {
                Text(isActive ? "End Fast" : "Start Fast")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .glassEffect(
                        // Use a red tint when overtime to make the end button prominent
                        accentColorOverride == nil ? .regular.tint(isOverTime ? .red : tint) : .regular,
                        in: .rect(cornerRadius: 16.0)
                    )
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .onReceive(timer) { date in
            now = date
            if isOverTime {
                sendCompletionNotificationIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                restoreFastingStateIfNeeded()
            }
        }
        .onAppear {
            restoreFastingStateIfNeeded()
        }
        .onChange(of: selectedProtocol) { _, _ in
            applyProtocolChange()
        }
        .onChange(of: customHours) { _, _ in
            if selectedProtocol != .custom {
                selectedProtocol = .custom
            }
            applyProtocolChange()
        }
        .onChange(of: customMinutes) { _, _ in
            if selectedProtocol != .custom {
                selectedProtocol = .custom
            }
            applyProtocolChange()
        }
        .sheet(isPresented: $showProtocolSheet) {
            FastingProtocolSheet(
                selectedProtocol: $selectedProtocol,
                customHours: $customHours,
                customMinutes: $customMinutes,
                tint: tint,
                onDone: { showProtocolSheet = false }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

private struct FastingProtocolSheet: View {
    @Binding var selectedProtocol: FastingProtocolOption
    @Binding var customHours: String
    @Binding var customMinutes: String
    var tint: Color
    var onDone: () -> Void
    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fasting Window")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                            ForEach(FastingProtocolOption.allCases, id: \.self) { option in
                                SelectablePillComponent(
                                    label: option.displayName,
                                    isSelected: selectedProtocol == option,
                                    selectedTint: tint
                                ) {
                                    selectedProtocol = option
                                }
                            }
                        }
                    }

                    // Always-visible custom inputs so user can immediately edit hours/minutes.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Duration")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            HStack {
                                TextField("Hours", text: $customHours)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .onChange(of: customHours) { _, _ in
                                        if selectedProtocol != .custom {
                                            selectedProtocol = .custom
                                        }
                                    }
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
                                    .onChange(of: customMinutes) { _, _ in
                                        if selectedProtocol != .custom {
                                            selectedProtocol = .custom
                                        }
                                    }
                                Text("min")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .surfaceCard(16)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("Choose a fasting window that fits your routine. The custom option lets you specify an exact duration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Fasting Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private enum FastingProtocolOption: CaseIterable {
    case twelveTwelve
    case fourteenTen
    case sixteenEight
    case custom

    var displayName: String {
        switch self {
        case .twelveTwelve:
            return "12:12"
        case .fourteenTen:
            return "14:10"
        case .sixteenEight:
            return "16:8"
        case .custom:
            return "Custom"
        }
    }

    var minutes: Int {
        switch self {
        case .twelveTwelve:
            return 12 * 60
        case .fourteenTen:
            return 14 * 60
        case .sixteenEight:
            return 16 * 60
        case .custom:
            return 0
        }
    }

    static func from(minutes: Int) -> FastingProtocolOption {
        switch minutes {
        case 12 * 60:
            return .twelveTwelve
        case 14 * 60:
            return .fourteenTen
        case 16 * 60:
            return .sixteenEight
        default:
            return .custom
        }
    }
}

struct WeeklyProgressEntry: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var weight: Double
    var waterPercent: Double?
    var bodyFatPercent: Double?
    var photoData: Data?

    var imagesCount: Int { photoData == nil ? 0 : 1 }
    var isEmpty: Bool { weight <= 0 && waterPercent == nil && bodyFatPercent == nil && photoData == nil }

    init(id: UUID = UUID(), date: Date, weight: Double, waterPercent: Double? = nil, bodyFatPercent: Double? = nil, photoData: Data? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.waterPercent = waterPercent
        self.bodyFatPercent = bodyFatPercent
        self.photoData = photoData
    }
}

public extension NumberFormatter {
    static let withComma: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
