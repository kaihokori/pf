import SwiftUI

struct MacroCalculationExplainer: View {
    private let rows = MacroCalculationExplanation.rows

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Pump Calculates Macros")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Targets start with the Mifflin-St Jeor calorie estimate, then each macro uses the rules below. Adjusting weight, focus, or calories refreshes the math automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        Text(row.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if row.id != rows.last?.id {
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

private struct MacroCalculationExplanation: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String

    static let rows: [MacroCalculationExplanation] = [
        MacroCalculationExplanation(
            id: "protein",
            title: "Protein",
            description: "Body weight × macro-focus multiplier (≈1.8–2.2 g/kg) with a safety floor of 1.4 g/kg and a 2.4 g/kg (220 g) ceiling."
        ),
        MacroCalculationExplanation(
            id: "fats",
            title: "Fats",
            description: "Body weight × macro-focus multiplier (≈0.8–1.0 g/kg) but always between 0.6 and 1.2 g/kg (35–120 g)."
        ),
        MacroCalculationExplanation(
            id: "carbs",
            title: "Carbohydrates",
            description: "Whatever calories remain after protein and fat are allocated. We divide the remainder by 4 cal/g to get grams so totals match your calorie target."
        ),
        MacroCalculationExplanation(
            id: "fibre",
            title: "Fibre",
            description: "14 g for every 1,000 calories eaten, clamped between 20 g and 40 g for practicality."
        ),
        MacroCalculationExplanation(
            id: "sodium",
            title: "Sodium",
            description: "A steady 2,300 mg per day guideline until we add personalised intake ranges."
        ),
        MacroCalculationExplanation(
            id: "water",
            title: "Water",
            description: "Body weight × 35 ml with a minimum of roughly 2 L to keep hydration goals realistic."
        )
    ]
}
