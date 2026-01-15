import SwiftUI

struct ActivityLevelExplainer: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Activity Factors")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("Your activity level determines your Total Daily Energy Expenditure (TDEE). Choose the option that best matches your lifestyle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 10) {
                        ForEach(ActivityLevelOption.allCases) { option in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(option.explanation)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "x%.3g", option.tdeeMultiplier))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            if option != ActivityLevelOption.allCases.last {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 20.0))
                    attribution
                }
                .padding(.horizontal, 18)
                .padding(.vertical)
            }
            .navigationTitle("Activity Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ActivityLevelExplainer()
}

private extension ActivityLevelExplainer {
    var attribution: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Source")
                    .font(.subheadline.weight(.bold))
                Text("Eat for Health (Australian Government)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Link(destination: URL(string: "https://www.eatforhealth.gov.au/nutrient-reference-values/nutrients/dietary-energy")!) {
                Text("View")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
