import SwiftUI

struct MaintenanceCaloriesExplainer: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    formulas
                    workedExample
                    stepFlow
                    attribution
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
        SectionCard(title: "Formulas (RMR → TDEE)") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("Men: RMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) + 5")
                bullet("Women: RMR = 10 × weight (kg) + 6.25 × height (cm) − 5 × age (years) − 161")
                bullet("TDEE (maintenance) = RMR × activity factor")
                Text("Activity factors: sedentary 1.2, light 1.375, moderate 1.55, high 1.725, athlete 1.9.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workedExample: some View {
        SectionCard(title: "Example (male, 78 kg, 180 cm, 30 years)") {
            VStack(alignment: .leading, spacing: 6) {
                bullet("RMR pieces: 10 × 78 = 780; 6.25 × 180 = 1125; −5 × 30 = −150; +5")
                Text("RMR ≈ 780 + 1125 − 150 + 5 = 1760 kcal/day")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                Text("Apply activity factor to get maintenance (TDEE):")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                bullet("Sedentary 1.2 → 1760 × 1.2 ≈ 2112 kcal/day")
                bullet("Light 1.375 → 1760 × 1.375 ≈ 2420 kcal/day")
                bullet("Moderate 1.55 → 1760 × 1.55 ≈ 2728 kcal/day")
                bullet("High 1.725 → 1760 × 1.725 ≈ 3036 kcal/day")
                bullet("Athlete 1.9 → 1760 × 1.9 ≈ 3344 kcal/day")
                Text("Pick the factor that matches lifestyle; that product is the maintenance calorie target.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var stepFlow: some View {
        SectionCard(title: "Steps to Get Maintenance") {
            VStack(alignment: .leading, spacing: 8) {
                bullet("1) Gather age, height (cm), and weight (kg).")
                bullet("2) Calculate RMR with the gender-specific Mifflin–St Jeor formula.")
                bullet("3) Choose the activity factor that best fits daily movement (sedentary 1.2 → athlete 1.9).")
                bullet("4) Multiply: TDEE = RMR × activity factor. That is maintenance calories.")
            }
        }
    }

    private var attribution: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Source")
                    .font(.subheadline.weight(.bold))
                Text("NCBI Metabolic research")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Link(destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC8017325/")!) {
                Text("View")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
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
