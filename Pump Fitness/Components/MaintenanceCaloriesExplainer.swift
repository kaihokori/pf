import SwiftUI

struct MaintenanceCaloriesExplainer: View {
    private let macroPresets = ExplainerMacroPreset.presets

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    formulas
                    workedExample
                    macroBasics
                    macroExample
                    macroPresetsView
                }
                .padding(.horizontal, 18)
                .padding(.vertical)
            }
            .navigationTitle("Maintenance Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How Maintenance Is Calculated")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("We start with the Mifflin–St Jeor resting metabolic rate (RMR), then multiply by an activity factor to get TDEE (your maintenance calories).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var formulas: some View {
        SectionCard(title: "Mifflin–St Jeor Formulas") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("Men: RMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) + 5")
                bullet("Women: RMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) − 161")
            }
        }
    }

    private var workedExample: some View {
        SectionCard(title: "Example (male, 80 kg, 180 cm, 30 years)") {
            VStack(alignment: .leading, spacing: 6) {
                bullet("10 × 80 = 800")
                bullet("6.25 × 180 = 1125")
                bullet("−5 × 30 = −150")
                Text("Sum: 800 + 1125 − 150 + 5 = 1780 kcal/day (RMR)")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Text("To get TDEE, multiply RMR by an activity factor:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                bullet("Sedentary ~1.2 → 1780 × 1.2 = 2136 kcal/day")
                bullet("Light ~1.375 → 1780 × 1.375 = 2447.5 kcal/day")
                Text("Choose the factor that fits the person.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var macroBasics: some View {
        SectionCard(title: "Choose Macro Style") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("Protein 2.1–2.5 × body weight (kg)")
                bullet("Protein = 4 calories per gram")
                bullet("Carbs = 4 calories per gram")
                bullet("Fat = 9 calories per gram")
                Text("Grams = (Total calories × % macro) ÷ calories per gram")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var macroExample: some View {
        SectionCard(title: "Macro Example (TDEE 2200, goal 40/30/30)") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Example Calculation")
                    .font(.subheadline.weight(.semibold))
                Text("Assume body weight 67 kg and goal = high protein fat loss (40% protein / 30% carbs / 30% fats).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                bullet("Protein = 2.5 × 67 kg = 167 g → Minimum intake")
                bullet("Carbs = 2200 × 0.30 ÷ 4 = 165 g → Maximum intake")
                bullet("Fats = 2200 × 0.20 ÷ 9 = 48 g → Maximum intake")
            }
        }
    }

    private var macroPresetsView: some View {
        SectionCard(title: "Common Macro Setups") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(macroPresets) { preset in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(preset.number)) \(preset.title)")
                            .font(.subheadline.weight(.semibold))
                        Text(preset.details)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if preset.id != macroPresets.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content
        }
        .padding(18)
        .surfaceCard(18)
    }
}

private struct ExplainerMacroPreset: Identifiable, Equatable {
    let id: String
    let number: Int
    let title: String
    let details: String

    static let presets: [ExplainerMacroPreset] = [
        ExplainerMacroPreset(
            id: "lean-cut", number: 1, title: "Lean Cutting (High Protein + Fat Loss)",
            details: "Calories: TDEE − 500 | Protein: 2.5 × body weight | Carbs: 30% | Fats: 20%"
        ),
        ExplainerMacroPreset(
            id: "low-carb", number: 2, title: "Low Carb Diet",
            details: "Calories: TDEE − 500 | Protein: 2.1 × body weight | Carbs: 10% | Fats: 30%"
        ),
        ExplainerMacroPreset(
            id: "balanced", number: 3, title: "Balanced",
            details: "Calories: TDEE | Protein: 2.3 × body weight | Carbs: 40% | Fats: 30%"
        ),
        ExplainerMacroPreset(
            id: "lean-bulk", number: 4, title: "Lean Bulking (High Protein + High Carbs)",
            details: "Calories: TDEE + 350 | Protein: 2.5 × body weight | Carbs: 50% | Fats: 20%"
        ),
        ExplainerMacroPreset(
            id: "custom", number: 5, title: "Custom",
            details: "Choose your own calorie target and macro percentages."
        )
    ]
}
