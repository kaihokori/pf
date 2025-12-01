import SwiftUI

struct AddNutritionView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMealSlot: MealSlot = .breakfast
    @State private var nutritionSearchTerm = ""
    @State private var brandName = ""
    @State private var eatenAmount = ""
    @State private var servingUnit: ServingUnit = .grams
    @State private var gramsPerServing = ""
    @State private var macroValues: [MacroType: String] = [:]

    var body: some View {
        ZStack {
            backgroundView
            VStack(alignment: .leading, spacing: 20) {
                Text("Log Nutrition")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 4)
                MealSlotGrid(selectedMeal: $selectedMealSlot)
                
                LabeledTextField(
                    label: "Item name",
                    text: $nutritionSearchTerm,
                    prompt: "e.g. Chicken bowl"
                )
                
                LabeledTextField(
                    label: "Brand or source",
                    text: $brandName,
                    prompt: "Optional brand"
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Serving unit")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(ServingUnit.allCases) { unit in
                            SelectablePillComponent(
                                label: unit.displayName,
                                isSelected: servingUnit == unit
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    servingUnit = unit
                                }
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    LabeledNumericField(
                        label: "Amount eaten",
                        value: $eatenAmount,
                        unitLabel: servingUnit.symbol
                    )
                    
                    if servingUnit == .servings {
                        LabeledNumericField(
                            label: "Grams per serving",
                            value: $gramsPerServing,
                            unitLabel: "g"
                        )
                    }
                }
                
                VStack(spacing: 16) {
                    ForEach(MacroType.allCases) { macro in
                        LabeledNumericField(
                            label: macro.displayName,
                            value: Binding(
                                get: { macroValues[macro] ?? "" },
                                set: { macroValues[macro] = $0 }
                            ),
                            unitLabel: macro.unitLabel
                        )
                    }
                }
            }
        }
    }
}

private extension AddNutritionView {
    @ViewBuilder
    var backgroundView: some View {
        if themeManager.selectedTheme == .multiColour {
            GradientBackground(theme: .add)
        } else {
            themeManager.selectedTheme.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }
}

private struct MealSlotGrid: View {
    @Binding var selectedMeal: MealSlot

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(MealSlot.allCases) { slot in
                let isSelected = selectedMeal == slot
                SelectablePillComponent(
                    isSelected: isSelected,
                    action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMeal = slot
                        }
                    }
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: slot.systemImage)
                            .font(.title3)
                            .frame(width: 30, alignment: .center)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private struct LabeledTextField: View {
    var label: String
    @Binding var text: String
    var prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("", text: $text, prompt: Text(prompt))
                .textInputAutocapitalization(.words)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 12.0))
        }
    }
}

private enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }
}

private enum MacroType: String, CaseIterable, Identifiable {
    case calories, protein, fats, carbs, fibre, sodium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calories: return "Calories (per 100 g)"
        case .protein: return "Protein (per 100 g)"
        case .fats: return "Fats (per 100 g)"
        case .carbs: return "Carbs (per 100 g)"
        case .fibre: return "Fibre (per 100 g)"
        case .sodium: return "Sodium (per 100 g)"
        }
    }

    var unitLabel: String {
        switch self {
        case .calories: return "kcal/100g"
        case .protein: return "g/100g"
        case .fats: return "g/100g"
        case .carbs: return "g/100g"
        case .fibre: return "g/100g"
        case .sodium: return "mg/100g"
        }
    }

    func formattedValue(from value: Double) -> String {
        let decimals: Int
        switch self {
        case .calories, .sodium:
            decimals = 0
        default:
            decimals = value < 10 ? 1 : 0
        }
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }
}

private enum ServingUnit: String, CaseIterable, Identifiable {
    case grams
    case servings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grams: return "Grams (g)"
        case .servings: return "Servings (x)"
        }
    }

    var symbol: String {
        switch self {
        case .grams: return "g"
        case .servings: return "serv"
        }
    }
}
