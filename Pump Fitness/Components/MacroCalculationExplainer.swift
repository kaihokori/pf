import SwiftUI

struct WeightGoalExplainer: View {
    private let goalRows = MacroGoalExplanation.rows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How This Works")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Targets start with the Mifflin-St Jeor calorie estimate. Adjusting your weight goal applies a calorie deficit or surplus to your maintenance level.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Weight Goals")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(goalRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                            Text("Formula: \(row.formula)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Example: \(row.example)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if row.id != goalRows.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(18)
                .surfaceCard(18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top)
        }
    }
}

struct MacroStrategyExplainer: View {
    private let strategyRows = MacroStrategyExplanation.rows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How This Works")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Your macro strategy determines how your daily calories are split between Protein, Fats, and Carbohydrates.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Macro Strategies")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(strategyRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                            Text("Split: \(row.split)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if row.id != strategyRows.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(18)
                .surfaceCard(18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top)
        }
    }
}

// Kept for backward compatibility if needed, or can be removed if we update all call sites.
struct MacroCalculationExplainer: View {
    var body: some View {
        WeightGoalExplainer()
    }
}

private struct MacroGoalExplanation: Identifiable, Equatable {
    let id: String
    let title: String
    let formula: String
    let example: String

    static let rows: [MacroGoalExplanation] = [
        MacroGoalExplanation(
            id: "extremeWeightLoss",
            title: "Extreme Weight Loss (−1 kg/week)",
            formula: "Calories = TDEE − 1000",
            example: "With TDEE 2,400 kcal: Target ≈ 1,400 kcal"
        ),
        MacroGoalExplanation(
            id: "weightLoss",
            title: "Weight Loss (−0.5 kg/week)",
            formula: "Calories = TDEE − 500",
            example: "With TDEE 2,400 kcal: Target ≈ 1,900 kcal"
        ),
        MacroGoalExplanation(
            id: "mildWeightLoss",
            title: "Mild Weight Loss (−0.25 kg/week)",
            formula: "Calories = TDEE − 250",
            example: "With TDEE 2,400 kcal: Target ≈ 2,150 kcal"
        ),
        MacroGoalExplanation(
            id: "maintainWeight",
            title: "Maintain Weight",
            formula: "Calories = TDEE",
            example: "With TDEE 2,400 kcal: Target ≈ 2,400 kcal"
        ),
        MacroGoalExplanation(
            id: "mildWeightGain",
            title: "Mild Weight Gain (+0.25 kg/week)",
            formula: "Calories = TDEE + 250",
            example: "With TDEE 2,400 kcal: Target ≈ 2,650 kcal"
        ),
        MacroGoalExplanation(
            id: "weightGain",
            title: "Weight Gain (+0.5 kg/week)",
            formula: "Calories = TDEE + 500",
            example: "With TDEE 2,400 kcal: Target ≈ 2,900 kcal"
        ),
        MacroGoalExplanation(
            id: "extremeWeightGain",
            title: "Extreme Weight Gain (+1 kg/week)",
            formula: "Calories = TDEE + 1000",
            example: "With TDEE 2,400 kcal: Target ≈ 3,400 kcal"
        )
    ]
}

private struct MacroStrategyExplanation: Identifiable, Equatable {
    let id: String
    let title: String
    let split: String

    static let rows: [MacroStrategyExplanation] = [
        MacroStrategyExplanation(
            id: "highProtein",
            title: "High Protein",
            split: "Protein 2.5g/kg (min 30%) • Fat 20% • Carbs Remainder"
        ),
        MacroStrategyExplanation(
            id: "balanced",
            title: "Balanced",
            split: "Protein 25% • Fat 25% • Carbs Remainder"
        ),
        MacroStrategyExplanation(
            id: "lowFat",
            title: "Low Fat",
            split: "Protein 1.6g/kg • Fat 15% • Carbs Remainder"
        ),
        MacroStrategyExplanation(
            id: "lowCarb",
            title: "Low Carb",
            split: "Protein 2.0g/kg • Carbs 10% • Fat Remainder"
        )
    ]
}

private struct MacroCalculationExplanation: Identifiable, Equatable {
    let id: String
    let title: String
    let formula: String
    let example: String

    static let rows: [MacroCalculationExplanation] = [
        MacroCalculationExplanation(
            id: "fibre",
            title: "Fibre",
            formula: "14 g per 1,000 kcal, clamped 20–40 g",
            example: "At 1,900–2,750 kcal plans this lands around 27–39 g, within the 20–40 g clamp"
        ),
        MacroCalculationExplanation(
            id: "sodium",
            title: "Sodium",
            formula: "Fixed 2,300 mg guideline",
            example: "Applies to every goal until personalised ranges are added"
        ),
        MacroCalculationExplanation(
            id: "water",
            title: "Water",
            formula: "Body weight × 35 ml with a 2,000 ml floor",
            example: "At 75 kg → ≈ 2,625 ml/day"
        )
    ]
}
