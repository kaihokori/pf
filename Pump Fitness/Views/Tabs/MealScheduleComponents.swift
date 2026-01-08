import SwiftUI
import SwiftData
import TipKit

struct WeeklyMealScheduleCard: View {
    @Binding var schedule: [MealScheduleItem]
    @Binding var catalog: [CatalogMeal]
    var trackedMacros: [TrackedMacro]
    var groceryItems: [GroceryItem]
    var consumedMeals: Set<String>
    let accentColor: Color
    var onSave: ([MealScheduleItem]) -> Void
    var onSaveCatalog: ([CatalogMeal]) -> Void
    var onAddToGroceryList: ([GroceryItem]) -> Void
    var onConsumeMeal: (CatalogMeal) -> Void

    @State private var showEditSheet = false
    @State private var showCatalogSheet = false
    @State private var selectedMealForDetail: CatalogMeal?
    @State private var showActionAlert = false
    @State private var actionAlertMessage = ""
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Meal Planning")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showEditSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(in: .rect(cornerRadius: 18.0))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, -8)
            .padding(.bottom, -4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(schedule) { day in
                        VStack(spacing: 10) {
                            Text(day.day)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .padding(.top, 2)
                            
                            VStack(spacing: 8) {
                                ForEach(day.sessions) { session in
                                    Menu {
                                        Button {
                                            selectedMealForDetail = catalog.first(where: { $0.name == session.name })
                                        } label: {
                                            Label("View Details", systemImage: "info.circle")
                                        }
                                        
                                        if let meal = catalog.first(where: { $0.name == session.name }) {
                                            let isConsumed = consumedMeals.contains(meal.name)
                                            Button {
                                                onConsumeMeal(meal)
                                                actionAlertMessage = "Logged '\(meal.name)'"
                                                showActionAlert = true
                                            } label: {
                                                Label("Log Intake", systemImage: isConsumed ? "plus.circle.fill" : "plus.circle")
                                            }

                                            if !meal.ingredients.isEmpty {
                                                let inGrocery = isMealInGroceryList(meal)
                                                Button {
                                                    addMealToGroceryList(meal)
                                                    actionAlertMessage = "Added '\(meal.name)' to groceries"
                                                    showActionAlert = true
                                                } label: {
                                                    Label("Add to Groceries", systemImage: inGrocery ? "cart.fill" : "cart.badge.plus")
                                                }
                                            }
                                        }
                                    } label: {
                                        let mealColorHex = catalog.first(where: { $0.name == session.name })?.colorHex ?? session.colorHex
                                        WeeklyMealSessionCard(
                                            session: session,
                                            accentColor: effectiveAccent,
                                            overrideColorHex: mealColorHex
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        .frame(width: 110)
                        .background(Color.clear)
                    }
                }
                .padding()
            }
            .frame(minHeight: 200)
            .glassEffect(in: .rect(cornerRadius: 12.0))
            .overlay(
                RoundedRectangle(cornerRadius: 12.0)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 4)

            Button {
                showCatalogSheet = true
            } label: {
                Label("Food Menu", systemImage: "book")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Tap each meal to view options")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -8)
            .padding(.bottom, -8)
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .sheet(isPresented: $showEditSheet) {
            MealScheduleEditorSheet(
                schedule: $schedule,
                catalog: $catalog,
                accentColor: effectiveAccent,
                onSave: { updated in
                    schedule = updated
                    onSave(updated)
                    showEditSheet = false
                },
                onOpenCatalog: {
                    showEditSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showCatalogSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showCatalogSheet) {
            MealCatalogView(
                catalog: $catalog,
                schedule: $schedule,
                trackedMacros: trackedMacros,
                groceryItems: groceryItems,
                consumedMeals: consumedMeals,
                onSave: { updatedCatalog in
                    catalog = updatedCatalog
                    onSaveCatalog(updatedCatalog)
                },
                onSaveSchedule: { updatedSchedule in
                    schedule = updatedSchedule
                    onSave(updatedSchedule)
                },
                onConsumeMeal: onConsumeMeal,
                onAddToGroceryList: onAddToGroceryList
            )
        }
        .sheet(item: $selectedMealForDetail) { meal in
            MealDetailView(
                meal: meal,
                trackedMacros: trackedMacros,
                groceryItems: groceryItems,
                consumedMeals: consumedMeals,
                onAddToGroceryList: onAddToGroceryList,
                onConsumeMeal: onConsumeMeal
            )
        }
            .alert(actionAlertMessage, isPresented: $showActionAlert) {
                Button("OK", role: .cancel) { }
            }
    }

    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour { return accentColor }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private func addMealToGroceryList(_ meal: CatalogMeal) {
        var newItems: [GroceryItem] = []
        for ingredient in meal.ingredients {
            newItems.append(GroceryItem(title: ingredient.name, note: ingredient.quantity))
        }
        if !newItems.isEmpty {
            onAddToGroceryList(newItems)
        }
    }

    private func isMealInGroceryList(_ meal: CatalogMeal) -> Bool {
        guard !meal.ingredients.isEmpty else { return false }
        let set = Set(groceryItems.map { "\($0.title)|\($0.note)" })
        for ingredient in meal.ingredients {
            let key = "\(ingredient.name)|\(ingredient.quantity)"
            if !set.contains(key) {
                return false
            }
        }
        return true
    }
}

struct WeeklyMealSessionCard: View {
    let session: MealSession
    let accentColor: Color
    var overrideColorHex: String? = nil

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedColor: Color {
        if themeManager.selectedTheme == .multiColour {
            let hex = overrideColorHex ?? session.colorHex
            return Color(hex: hex) ?? accentColor
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(session.name)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 110, alignment: .center)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(resolvedColor), in: .rect(cornerRadius: 12.0))
    }
}

struct MealScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var schedule: [MealScheduleItem]
    @Binding var catalog: [CatalogMeal]
    var accentColor: Color
    var onSave: ([MealScheduleItem]) -> Void
    var onOpenCatalog: () -> Void

    @State private var working: [MealScheduleItem] = []

    @State private var showColorPickerSheet = false
    @State private var colorPickerTarget: (dayIndex: Int, sessionId: UUID)? = nil
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Explainer Section
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Build Your Schedule", systemImage: "calendar.badge.plus")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add meals your meal plan through the Catalog.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            onOpenCatalog()
                        } label: {
                            Text("Go to Catalog")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(accentColor.opacity(0.1), in: Capsule())
                                .foregroundStyle(accentColor)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))

                    // Current schedule by day
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 14) {
                            ForEach(Array(working.enumerated()), id: \.element.id) { dayIndex, day in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(day.day)
                                            .font(.callout.weight(.semibold))
                                            .textCase(.uppercase)
                                        Spacer()
                                        if !day.sessions.isEmpty {
                                            Text("\(day.sessions.count)" + (day.sessions.count == 1 ? " meal" : " meals"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if day.sessions.isEmpty {
                                        Text("No meals added yet.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(Array(day.sessions.enumerated()), id: \.element.id) { sessionIndex, _ in
                                                let binding = $working[dayIndex].sessions[sessionIndex]
                                                let sessionId = working[dayIndex].sessions[sessionIndex].id
                                                let isFirst = sessionIndex == 0
                                                let isLast = sessionIndex == day.sessions.count - 1
                                                HStack(spacing: 12) {
                                                    Button {
                                                        guard themeManager.selectedTheme == .multiColour else { return }
                                                        colorPickerTarget = (dayIndex, sessionId)
                                                        showColorPickerSheet = true
                                                    } label: {
                                                        let mealColorHex = catalog.first(where: { $0.name == binding.name.wrappedValue })?.colorHex ?? binding.colorHex.wrappedValue
                                                        let sessionColor: Color = themeManager.selectedTheme == .multiColour ? (Color(hex: mealColorHex) ?? accentColor) : themeManager.selectedTheme.accent(for: colorScheme)

                                                        Circle()
                                                            .fill(sessionColor.opacity(0.18))
                                                            .frame(width: 40, height: 40)
                                                            .overlay(
                                                                Image(systemName: "fork.knife")
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                    .foregroundStyle(sessionColor)
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                    .disabled(themeManager.selectedTheme != .multiColour)
                                                    .editSheetTip(.editMealPlanningColor)

                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text("\(binding.name.wrappedValue)")
                                                            .font(.subheadline.weight(.semibold))
                                                            .foregroundStyle(.primary)

                                                        HStack(spacing: 8) {
                                                            Menu {
                                                                if !isFirst {
                                                                    Button("Move to Top") {
                                                                        moveSessionWithinDay(dayIndex: dayIndex, from: sessionIndex, to: 0)
                                                                    }
                                                                    Button("Move Up") {
                                                                        moveSessionWithinDay(dayIndex: dayIndex, from: sessionIndex, to: sessionIndex - 1)
                                                                    }
                                                                }
                                                                if !isLast {
                                                                    Button("Move Down") {
                                                                        moveSessionWithinDay(dayIndex: dayIndex, from: sessionIndex, to: sessionIndex + 1)
                                                                    }
                                                                    Button("Move to Bottom") {
                                                                        moveSessionWithinDay(dayIndex: dayIndex, from: sessionIndex, to: day.sessions.count - 1)
                                                                    }
                                                                }
                                                                
                                                                Menu("Move to Day") {
                                                                    ForEach(Array(working.enumerated()), id: \.element.id) { targetDayIndex, targetDay in
                                                                        if targetDayIndex != dayIndex {
                                                                            Button(targetDay.day) {
                                                                                moveSessionToDay(fromDayIndex: dayIndex, sessionIndex: sessionIndex, toDayIndex: targetDayIndex)
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            } label: {
                                                                HStack(spacing: 6) {
                                                                    Image(systemName: "arrow.up.arrow.down")
                                                                        .font(.system(size: 14, weight: .semibold))
                                                                    Text("Reorder")
                                                                        .font(.caption)
                                                                }
                                                                .foregroundStyle(.secondary)
                                                            }
                                                            .buttonStyle(.plain)

                                                            Spacer()
                                                        }
                                                    }

                                                    Spacer()

                                                    Button(role: .destructive) {
                                                        removeSession(dayIndex: dayIndex, sessionId: sessionId)
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Edit Meal Planning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveChanges() }
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

    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour { return accentColor }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }

    private func loadInitial() {
        working = schedule.isEmpty ? MealScheduleItem.defaults : schedule
    }

    private func removeSession(dayIndex: Int, sessionId: UUID) {
        guard working.indices.contains(dayIndex) else { return }
        working[dayIndex].sessions.removeAll { $0.id == sessionId }
    }

    private func moveSessionWithinDay(dayIndex: Int, from sourceIndex: Int, to targetIndex: Int) {
        guard working.indices.contains(dayIndex),
              working[dayIndex].sessions.indices.contains(sourceIndex),
              targetIndex >= 0 else { return }

        let session = working[dayIndex].sessions.remove(at: sourceIndex)
        let newCount = working[dayIndex].sessions.count
        let safeIndex = min(targetIndex, newCount)
        working[dayIndex].sessions.insert(session, at: safeIndex)
    }

    private func moveSessionToDay(fromDayIndex: Int, sessionIndex: Int, toDayIndex: Int) {
        guard working.indices.contains(fromDayIndex),
              working.indices.contains(toDayIndex),
              working[fromDayIndex].sessions.indices.contains(sessionIndex) else { return }

        let session = working[fromDayIndex].sessions.remove(at: sessionIndex)
        working[toDayIndex].sessions.append(session)
    }

    private func saveChanges() {
        schedule = working
        onSave(working)
        dismiss()
    }

    private func applyColor(hex: String) {
        guard let target = colorPickerTarget,
              working.indices.contains(target.dayIndex),
              let sessionIndex = working[target.dayIndex].sessions.firstIndex(where: { $0.id == target.sessionId })
        else { return }
        
        let sessionName = working[target.dayIndex].sessions[sessionIndex].name
        
        // Update ALL sessions in the working schedule with this name
        for dIdx in working.indices {
            for sIdx in working[dIdx].sessions.indices {
                if working[dIdx].sessions[sIdx].name == sessionName {
                    working[dIdx].sessions[sIdx].colorHex = hex
                }
            }
        }
        
        // Also update catalog if a meal with this name exists
        if let catalogIndex = catalog.firstIndex(where: { $0.name == sessionName }) {
            catalog[catalogIndex].colorHex = hex
        }
    }
}
