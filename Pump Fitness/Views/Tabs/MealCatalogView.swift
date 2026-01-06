import SwiftUI
import Combine

struct MealCatalogView: View {
    @Binding var catalog: [CatalogMeal]
    @Binding var schedule: [MealScheduleItem]
    var trackedMacros: [TrackedMacro]
    var groceryItems: [GroceryItem]
    var consumedMeals: Set<String>
    var onSave: ([CatalogMeal]) -> Void
    var onSaveSchedule: ([MealScheduleItem]) -> Void
    var onConsumeMeal: (CatalogMeal) -> Void
    var onAddToGroceryList: ([GroceryItem]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editingMeal: CatalogMeal?
    @State private var showCatalogRecipeLookup = false
    @State private var selectedMealForDetail: CatalogMeal?
    @State private var showColorPickerSheet = false
    @State private var colorPickerTargetId: UUID?
    
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    private let daySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    private var effectiveAccent: Color {
        themeManager.selectedTheme.accent(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if catalog.isEmpty {
                        Text("No meals in catalog. Tap + to add one.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 20) {
                            ForEach(MealType.allCases) { type in
                                let mealsForType = catalog.filter { $0.mealType == type }
                                if !mealsForType.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(type.displayName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 4)

                                        VStack(spacing: 14) {
                                            ForEach(mealsForType) { meal in
                                                HStack(spacing: 12) {
                                                    // Color Picker Button
                                                    Button {
                                                        guard themeManager.selectedTheme == .multiColour else { return }
                                                        colorPickerTargetId = meal.id
                                                        showColorPickerSheet = true
                                                    } label: {
                                                        let mealColor: Color = themeManager.selectedTheme == .multiColour ? (Color(hex: meal.colorHex) ?? effectiveAccent) : effectiveAccent
                                                        
                                                        Circle()
                                                            .fill(mealColor.opacity(0.18))
                                                            .frame(width: 40, height: 40)
                                                            .overlay(
                                                                Image(systemName: "fork.knife")
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                    .foregroundStyle(mealColor)
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                    .disabled(themeManager.selectedTheme != .multiColour)
                                                    
                                                    // Meal Details
                                                    Menu {
                                                        let isConsumed = consumedMeals.contains(meal.name)
                                                        Button {
                                                            onConsumeMeal(meal)
                                                        } label: {
                                                            Label(isConsumed ? "Log in Intake (Again)" : "Log in Intake", systemImage: isConsumed ? "checkmark.circle.fill" : "checkmark.circle")
                                                        }

                                                        if !meal.ingredients.isEmpty {
                                                            let inGrocery = isMealInGroceryList(meal)
                                                            Button {
                                                                addMealToGroceryList(meal)
                                                            } label: {
                                                                Label(inGrocery ? "Add to Groceries (Again)" : "Add to Groceries", systemImage: inGrocery ? "cart.fill" : "cart.badge.plus")
                                                            }
                                                        }
                                                        
                                                        Button {
                                                            selectedMealForDetail = meal
                                                        } label: {
                                                            Label("View Details", systemImage: "info.circle")
                                                        }
                                                    } label: {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(meal.name)
                                                                .font(.subheadline.weight(.semibold))
                                                                .foregroundStyle(.primary)
                                                            
                                                            if !meal.ingredients.isEmpty {
                                                                Text("\(meal.ingredients.count) ingredients")
                                                                    .font(.caption)
                                                                    .foregroundStyle(.secondary)
                                                            }
                                                        }
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    Spacer()
                                                    
                                                    // Edit Button
                                                    Button {
                                                        editingMeal = meal
                                                    } label: {
                                                        Image(systemName: "pencil")
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundStyle(.secondary)
                                                            .padding(8)
                                                            .background(Color.primary.opacity(0.05), in: Circle())
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    // Add to Schedule Button
                                                    Menu {
                                                        ForEach(Array(daySymbols.enumerated()), id: \.0) { dayIdx, label in
                                                            Button(label) {
                                                                addToSchedule(meal, dayIndex: dayIdx)
                                                            }
                                                        }
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.system(size: 28, weight: .semibold))
                                                            .foregroundStyle(effectiveAccent)
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
            .navigationTitle("Food Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCatalogRecipeLookup = true
                        } label: {
                            Label("Recipe Lookup", systemImage: "magnifyingglass")
                        }

                        Button {
                            editingMeal = CatalogMeal(name: "")
                        } label: {
                            Label("Manual", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onSave(catalog)
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingMeal) { meal in
                let isNew = !catalog.contains(where: { $0.id == meal.id })
                MealEditorView(meal: meal, isNew: isNew, initialMealType: isNew ? nil : meal.mealType, trackedMacros: trackedMacros) { updatedMeal in
                    if let index = catalog.firstIndex(where: { $0.id == updatedMeal.id }) {
                        catalog[index] = updatedMeal
                    } else {
                        catalog.append(updatedMeal)
                    }
                    editingMeal = nil
                } onDelete: {
                     if let index = catalog.firstIndex(where: { $0.id == meal.id }) {
                        let removed = catalog.remove(at: index)

                        // Remove any scheduled sessions that reference this meal
                        for dIdx in schedule.indices {
                            schedule[dIdx].sessions.removeAll { $0.name == removed.name }
                        }
                        onSaveSchedule(schedule)
                    }
                    editingMeal = nil
                }
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
            .sheet(isPresented: $showCatalogRecipeLookup) {
                RecipeLookupComponent(accentColor: effectiveAccent) { recipe in
                    let newMeal = CatalogMeal(
                        name: recipe.title,
                        mealType: .snack,
                        colorHex: "#4A7BD0",
                        ingredients: recipe.ingredients.map { ing in
                            CatalogIngredient(name: ing.name, quantity: ing.quantity)
                        },
                        calories: recipe.calories,
                        protein: recipe.protein,
                        carbs: recipe.carbs,
                        fats: recipe.fats,
                        macroValues: [
                            "protein": recipe.protein,
                            "carbs": recipe.carbs,
                            "fats": recipe.fats
                        ],
                        methodSteps: recipe.steps.enumerated().map { idx, text in
                            MethodStep(id: UUID(), text: text, durationMinutes: 0)
                        },
                        method: recipe.steps.enumerated().map { idx, text in "\(idx + 1). \(text)" }.joined(separator: "\n"),
                        notes: "",
                        url: recipe.sourceURL?.absoluteString
                    )
                    editingMeal = newMeal
                    showCatalogRecipeLookup = false
                }
            }
            .sheet(isPresented: $showColorPickerSheet) {
                ColorPickerSheet { hex in
                    if let id = colorPickerTargetId,
                       let index = catalog.firstIndex(where: { $0.id == id }) {
                        let mealName = catalog[index].name
                        catalog[index].colorHex = hex
                        
                        // Update schedule for consistency
                        for dIdx in schedule.indices {
                            for sIdx in schedule[dIdx].sessions.indices {
                                if schedule[dIdx].sessions[sIdx].name == mealName {
                                    schedule[dIdx].sessions[sIdx].colorHex = hex
                                }
                            }
                        }
                        onSaveSchedule(schedule)
                    }
                    showColorPickerSheet = false
                } onCancel: {
                    showColorPickerSheet = false
                }
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func addToSchedule(_ meal: CatalogMeal, dayIndex: Int) {
        guard schedule.indices.contains(dayIndex) else { return }
        
        let newSession = MealSession(
            name: meal.name,
            colorHex: meal.colorHex,
            hour: 0,
            minute: 0
        )
        
        schedule[dayIndex].sessions.append(newSession)
        onSaveSchedule(schedule)
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

struct MealEditorView: View {
    @State var meal: CatalogMeal
    var isNew: Bool
    var initialMealType: MealType?
    var trackedMacros: [TrackedMacro]
    var onSave: (CatalogMeal) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showLookupSheet = false
    @State private var lookupItemName = ""
    @State private var lookupPortionSize = "100"
    @State private var lookupShouldOpenScanner = false
    @State private var lookupShouldAutoSearch = false
    @FocusState private var isMultilineFocused: Bool
    @FocusState private var isNutritionFocused: Bool
    @FocusState private var focusedMacroField: String?

    @State private var selectedMealType: MealType? = nil

    private let pillColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var effectiveTint: Color {
        themeManager.selectedTheme.accent(for: colorScheme)
    }

    private var isAnyKeyboardVisible: Bool {
        isMultilineFocused || isNutritionFocused || focusedMacroField != nil
    }

    // Disable adding new ingredients while there is an existing "blank" ingredient
    private var hasBlankIngredient: Bool {
        meal.ingredients.contains { ing in
            let nameEmpty = ing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let qtyEmpty = ing.quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return nameEmpty && qtyEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Meal Type Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal Type")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            LazyVGrid(columns: pillColumns, alignment: .leading, spacing: 12) {
                                ForEach(MealType.allCases) { type in
                                    SelectablePillComponent(
                                        label: type.displayName,
                                        isSelected: selectedMealType == type,
                                        selectedTint: effectiveTint
                                    ) {
                                        selectedMealType = type
                                    }
                                }
                            }
                    }

                    // Details Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 12) {
                            TextField("Chicken Salad", text: $meal.name)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .surfaceCard(16)
                            
                            // Ingredients Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ingredients")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if !meal.ingredients.isEmpty {
                                    ForEach($meal.ingredients) { $ingredient in
                                        HStack(spacing: 12) {
                                            TextField("200g", text: $ingredient.quantity)
                                                .frame(width: 100)
                                                .padding()
                                                .surfaceCard(16)
                                            TextField("Chicken Breast", text: $ingredient.name)
                                                .textInputAutocapitalization(.words)
                                                .padding()
                                                .surfaceCard(16)
                                            Button(role: .destructive) {
                                                if let idx = meal.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                                                    meal.ingredients.remove(at: idx)
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Button(action: {
                                    meal.ingredients.append(CatalogIngredient(name: "", quantity: ""))
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Add Ingredient")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(hasBlankIngredient)
                                .opacity(hasBlankIngredient ? 0.5 : 1.0)
                            }

                            HStack {
                                Text("Method Steps")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                if !meal.methodSteps.isEmpty {
                                    ForEach(Array($meal.methodSteps.enumerated()), id: \.element.id) { index, $step in
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Text("Step \(index + 1)")
                                                    .font(.headline)
                                                Spacer()
                                                HStack(spacing: 12) {
                                                    RepeatButton(action: {
                                                        step.durationMinutes = max(0, step.durationMinutes - 1)
                                                    }) {
                                                        Image(systemName: "minus")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundStyle(.primary)
                                                            .frame(width: 32, height: 32)
                                                            .background(Color.primary.opacity(0.08), in: Circle())
                                                    }

                                                    Text("\(step.durationMinutes) min")
                                                        .font(.footnote.weight(.semibold))

                                                    RepeatButton(action: {
                                                        step.durationMinutes += 1
                                                    }) {
                                                        Image(systemName: "plus")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundStyle(.primary)
                                                            .frame(width: 32, height: 32)
                                                            .background(Color.primary.opacity(0.08), in: Circle())
                                                    }
                                                }
                                                Spacer()
                                                .frame(maxWidth: 40)
                                                Button(role: .destructive) {
                                                    meal.methodSteps.removeAll { $0.id == step.id }
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            TextField("Describe the step...", text: $step.text, axis: .vertical)
                                                .lineLimit(2...4)
                                                .focused($isMultilineFocused)
                                                .padding(10)
                                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                                        }
                                        .padding()
                                        .surfaceCard(16)
                                    }
                                }

                                Button(action: {
                                    meal.methodSteps.append(MethodStep())
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Add Step")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(
                                    meal.methodSteps.last.map { last in
                                        last.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && last.durationMinutes == 0
                                    } ?? false
                                )
                            }

                            HStack {
                                Text("Notes")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            
                            TextField("Add any additional notes here...", text: $meal.notes, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($isMultilineFocused)
                                .padding()
                                .surfaceCard(16)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nutrition")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Calories (cal)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        TextField("0", value: $meal.calories, format: .number)
                                            .keyboardType(.decimalPad)
                                            .padding()
                                            .surfaceCard(16)
                                            .focused($isNutritionFocused)
                                    }

                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                        ForEach(trackedMacros) { macro in
                                            MacroInput(
                                                label: macro.name,
                                                unit: macro.unit,
                                                value: Binding(
                                                    get: {
                                                        if let val = meal.macroValues[macro.id] {
                                                            return val
                                                        }
                                                        let name = macro.name.lowercased()
                                                        if name == "protein" { return meal.protein }
                                                        if name == "carbs" { return meal.carbs }
                                                        if name == "fats" { return meal.fats }
                                                        return 0
                                                    },
                                                    set: { val in
                                                        meal.macroValues[macro.id] = val
                                                        let name = macro.name.lowercased()
                                                        if name == "protein" { meal.protein = val }
                                                        if name == "carbs" { meal.carbs = val }
                                                        if name == "fats" { meal.fats = val }
                                                    }
                                                ),
                                                focusId: macro.id,
                                                focusedField: $focusedMacroField
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !isNew {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Text("Delete Meal")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .surfaceCard(16)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .sheet(isPresented: $showLookupSheet) {
                LookupComponent(
                    accentColor: effectiveTint,
                    itemName: $lookupItemName,
                    portionSizeGrams: $lookupPortionSize,
                    onAdd: { item, portion, detail in
                        let newIngredient = CatalogIngredient(
                            name: item.name,
                            quantity: "\(portion)g"
                        )

                        meal.ingredients.append(newIngredient)
                        showLookupSheet = false
                    },
                    shouldOpenScanner: $lookupShouldOpenScanner,
                    shouldAutoSearch: $lookupShouldAutoSearch
                )
            }
            .navigationTitle(isNew ? "New Meal" : "Edit Meal")
            .onAppear {
                if let initial = initialMealType, !isNew {
                    selectedMealType = initial
                } else {
                    selectedMealType = nil
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        // Create a sanitized copy of the meal without any blank ingredients
                        var sanitizedMeal = meal
                        sanitizedMeal.ingredients = meal.ingredients.filter { ing in
                            let nameEmpty = ing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            let qtyEmpty = ing.quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            return !(nameEmpty && qtyEmpty)
                        }

                        // Remove blank method steps and update the legacy method string for compatibility
                        sanitizedMeal.methodSteps = meal.methodSteps.filter { step in
                            let textEmpty = step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            let durationZero = step.durationMinutes <= 0
                            return !(textEmpty && durationZero)
                        }

                        if sanitizedMeal.methodSteps.isEmpty {
                            sanitizedMeal.method = meal.method
                        } else {
                            sanitizedMeal.method = sanitizedMeal.methodSteps.enumerated().map { idx, step in
                                let durationSuffix = step.durationMinutes > 0 ? " (\(step.durationMinutes) min)" : ""
                                return "\(idx + 1). \(step.text)\(durationSuffix)"
                            }.joined(separator: "\n")
                        }

                        // Ensure mealType is set from the UI selection; default to .snack if none chosen
                        sanitizedMeal.mealType = selectedMealType ?? (isNew ? .snack : meal.mealType)
                        onSave(sanitizedMeal)
                    }
                    .disabled(meal.name.isEmpty || (isNew && selectedMealType == nil))
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            KeyboardDismissBar(isVisible: isAnyKeyboardVisible) {
                isMultilineFocused = false
                isNutritionFocused = false
                focusedMacroField = nil
            }
        }
    }
}

private struct KeyboardDismissBar: View {
    var isVisible: Bool
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
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isVisible)
            } else {
                EmptyView()
                    .frame(height: 0)
            }
        }
    }
}

private struct MacroInput: View {
    var label: String
    var unit: String = ""
    @Binding var value: Double
    var focusId: String? = nil
    var focusedField: FocusState<String?>.Binding? = nil

    @ViewBuilder
    private var inputField: some View {
        let field = TextField("0", value: $value, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .surfaceCard(16)

        if let focusId, let focusedField {
            field.focused(focusedField, equals: focusId)
        } else {
            field
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label) (\(unit))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            inputField
        }
    }
}

// A button that performs `action` once on tap, and repeatedly while held.
private struct RepeatButton<Label: View>: View {
    var action: () -> Void
    var repeatInterval: TimeInterval = 0.12
    var initialDelay: TimeInterval = 0.35
    @ViewBuilder var label: () -> Label

    @State private var timer: Timer?
    @State private var startWorkItem: DispatchWorkItem?

    private func startRepeating() {
        // Cancel any existing scheduled start
        startWorkItem?.cancel()

        let work = DispatchWorkItem {
            // Fire once immediately when repeating begins
            action()
            // Then start a timer for continuous repeats
            timer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { _ in
                action()
            }
        }
        startWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay, execute: work)
    }

    private func stopRepeating() {
        startWorkItem?.cancel()
        startWorkItem = nil
        timer?.invalidate()
        timer = nil
    }

    var body: some View {
        label()
            .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
                if pressing {
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }, perform: {})
            .simultaneousGesture(TapGesture().onEnded {
                // Single tap performs action once
                action()
            })
    }
}

struct MealDetailView: View {
    let meal: CatalogMeal
    let trackedMacros: [TrackedMacro]
    var groceryItems: [GroceryItem] = []
    var consumedMeals: Set<String> = []
    var onAddToGroceryList: (([GroceryItem]) -> Void)? = nil
    var onConsumeMeal: ((CatalogMeal) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSafari = false
    @State private var safariURL: URL?

    private var effectiveAccent: Color {
        if themeManager.selectedTheme == .multiColour {
            return Color(hex: meal.colorHex) ?? themeManager.selectedTheme.accent(for: colorScheme)
        }
        return themeManager.selectedTheme.accent(for: colorScheme)
    }
    
    private var areIngredientsInGroceryList: Bool {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(spacing: 16) {
                        Circle()
                            .fill(effectiveAccent.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(effectiveAccent)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.name)
                                .font(.title2.weight(.bold))
                            Text(meal.mealType.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Macros Summary
                    let totalCalories = Int(meal.calories)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition Summary")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("\(Int(totalCalories))")
                                        .font(.title3.weight(.bold))
                                    Text("Calories")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Divider().frame(height: 30)
                                
                                ForEach(trackedMacros) { macro in
                                    let total: Double = {
                                        if let val = meal.macroValues[macro.id] { return val }
                                        let name = macro.name.lowercased()
                                        if name == "protein" { return meal.protein }
                                        if name == "carbs" { return meal.carbs }
                                        if name == "fats" { return meal.fats }
                                        return 0
                                    }()
                                    
                                    if total > 0 {
                                        VStack(alignment: .leading) {
                                            Text("\(Int(total))\(macro.unit)")
                                                .font(.title3.weight(.bold))
                                            Text(macro.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)

                    Button {
                        onConsumeMeal?(meal)
                    } label: {
                        let isConsumed = consumedMeals.contains(meal.name)
                        HStack {
                            Image(systemName: isConsumed ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(isConsumed ? "Log in Intake (Again)" : "Log in Intake")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(effectiveAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(effectiveAccent)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Ingredients
                    if !meal.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.headline)
                            
                            VStack(spacing: 10) {
                                ForEach(meal.ingredients) { ingredient in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ingredient.name)
                                                .font(.subheadline.weight(.medium))
                                            Text(ingredient.quantity)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Button {
                            let items = meal.ingredients.map { GroceryItem(title: $0.name, note: $0.quantity) }
                            onAddToGroceryList?(items)
                        } label: {
                            HStack {
                                Image(systemName: areIngredientsInGroceryList ? "cart.fill" : "cart.badge.plus")
                                Text(areIngredientsInGroceryList ? "Add to Groceries (Again)" : "Add to Groceries")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(effectiveAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(effectiveAccent)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // Method
                    if !meal.methodSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preparation")
                                .font(.headline)

                            VStack(spacing: 10) {
                                ForEach(Array(meal.methodSteps.enumerated()), id: \.element.id) { index, step in
                                    MethodStepRow(index: index, step: step, accentColor: effectiveAccent)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else if !meal.method.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preparation")
                                .font(.headline)
                            Text(meal.method)
                                .font(.subheadline)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal)
                    }

                    // Notes
                    if !meal.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
                            Text(meal.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // if let urlString = meal.url, let url = URL(string: urlString) {
                    //     Button {
                    //         safariURL = url
                    //         showSafari = true
                    //     } label: {
                    //         HStack(spacing: 8) {
                    //             Image(systemName: "link")
                    //             Text("View Source")
                    //         }
                    //         .frame(maxWidth: .infinity, minHeight: 44)
                    //     }
                    //     .buttonStyle(.borderedProminent)
                    //     .tint(effectiveAccent)
                    //     .padding(.top, 6)
                    //     .padding(.horizontal)
                    // }
                }
                .padding(.vertical)
            }
            .navigationTitle("Meal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }
}

struct MethodStepRow: View {
    let index: Int
    let step: MethodStep
    let accentColor: Color
    
    @State private var timeRemaining: TimeInterval
    @State private var isRunning = false
    
    init(index: Int, step: MethodStep, accentColor: Color) {
        self.index = index
        self.step = step
        self.accentColor = accentColor
        _timeRemaining = State(initialValue: TimeInterval(step.durationMinutes * 60))
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1).")
                .font(.callout.weight(.semibold))
                .padding(6)
                .background(accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(step.text)
                    .font(.subheadline)
                    .lineSpacing(3)
                
                if step.durationMinutes > 0 {
                    HStack(spacing: 12) {
                        // Timer Badge
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.callout)
                            Text(formatTime(timeRemaining))
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                        
                        // Controls
                        Button {
                            isRunning.toggle()
                        } label: {
                            Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                        
                        if timeRemaining != TimeInterval(step.durationMinutes * 60) {
                            Button {
                                isRunning = false
                                timeRemaining = TimeInterval(step.durationMinutes * 60)
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                isRunning = false
            }
        }
    }
    
    private func formatTime(_ totalSeconds: TimeInterval) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
