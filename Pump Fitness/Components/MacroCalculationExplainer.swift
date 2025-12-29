import SwiftUI

struct MacroCalculationExplainer: View {
    private let goalRows = MacroGoalExplanation.rows
    private let macroRows = MacroCalculationExplanation.rows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How This Works")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Targets start with the Mifflin-St Jeor calorie estimate, then each macro focus applies its own calorie and macro split. Adjusting weight, focus, or calories refreshes the math automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Macro Goals")
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

                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Guidelines")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(macroRows) { row in
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
                        if row.id != macroRows.last?.id {
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

private struct MacroGoalExplanation: Identifiable, Equatable {
    let id: String
    let title: String
    let formula: String
    let example: String

    static let rows: [MacroGoalExplanation] = [
        MacroGoalExplanation(
            id: "leanCutting",
            title: "Lean Cutting",
            formula: "Calories = TDEE − 500; Protein = 2.5 g/kg BW; Fat = 20% of calories; Carbs = remaining calories ÷ 4",
            example: "With TDEE 2,400 kcal and 75 kg: Calories ≈ 1,900 kcal, Protein ≈ 188 g, Fat ≈ 42 g, Carbs ≈ 193 g"
        ),
        MacroGoalExplanation(
            id: "lowCarb",
            title: "Low Carb",
            formula: "Calories = TDEE − 500; Protein = 2.1 g/kg BW; Carbs = 10% of calories; Fat = remaining calories ÷ 9",
            example: "With TDEE 2,400 kcal and 75 kg: Calories ≈ 1,900 kcal, Protein ≈ 158 g, Carbs ≈ 48 g, Fat ≈ 120 g"
        ),
        MacroGoalExplanation(
            id: "balanced",
            title: "Balanced",
            formula: "Calories = TDEE; Protein = 2.3 g/kg BW; Fat = 30% of calories; Carbs = remaining calories ÷ 4",
            example: "With TDEE 2,400 kcal and 75 kg: Calories ≈ 2,400 kcal, Protein ≈ 173 g, Fat ≈ 80 g, Carbs ≈ 248 g"
        ),
        MacroGoalExplanation(
            id: "leanBulking",
            title: "Lean Bulking",
            formula: "Calories = TDEE + 350; Protein = 2.5 g/kg BW; Fat = 20% of calories; Carbs = remaining calories ÷ 4",
            example: "With TDEE 2,400 kcal and 75 kg: Calories ≈ 2,750 kcal, Protein ≈ 188 g, Fat ≈ 61 g, Carbs ≈ 362 g"
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
