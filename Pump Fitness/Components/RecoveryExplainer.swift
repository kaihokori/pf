import SwiftUI

struct RecoveryMetabolicExplainer: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How This Works")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("The following information on weekly minimums for metabolic health may be beneficial for recovery and overall well-being.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Protocol Minimums")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Cold Exposure")
                            .font(.subheadline.weight(.semibold))
                        Text("11 minutes total")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Split into 2–4 sessions of 1–5 minutes each")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Heat Exposure")
                            .font(.subheadline.weight(.semibold))
                        Text("57 minutes total")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Split into 2–3 sessions")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Factor")
                            .font(.subheadline.weight(.semibold))
                        Text("Always end with cold. Forcing your body to reheat naturally (non-shivering thermogenesis) is what activates the brown fat and metabolic benefits.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .surfaceCard(18)
                
                attribution
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var attribution: some View {
        RecoverySourceAttribution(
            label: "Dr. Susanna Søberg Study",
            urlString: "https://www.cell.com/cell-reports-medicine/fulltext/S2666-3791(21)00315-X"
        )
    }
}

struct RecoveryCardioExplainer: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How This Works")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("For long-term cardiovascular benefits (reducing the risk of heart attack and stroke), following information may be beneficial.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Protocol Targets")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimal Frequency")
                            .font(.subheadline.weight(.semibold))
                        Text("4–7 times per week")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimal Duration")
                            .font(.subheadline.weight(.semibold))
                        Text("19 minutes or longer per session")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimal Temperature")
                            .font(.subheadline.weight(.semibold))
                        Text("~174°F (79°C)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Finding")
                            .font(.subheadline.weight(.semibold))
                        Text("Men who followed this frequency had a 63% lower risk of sudden cardiac death compared to those who went only once a week.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .surfaceCard(18)
                
                attribution
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var attribution: some View {
        RecoverySourceAttribution(
            label: "JAMA Internal Medicine",
            urlString: "https://jamanetwork.com/journals/jamainternalmedicine/fullarticle/2130724"
        )
    }
}

fileprivate struct RecoverySourceAttribution: View {
    let label: String
    let urlString: String

    var body: some View {
        HStack(spacing: 4) {
            Text("Source:")
            .font(.footnote)
            Link(label, destination: URL(string: urlString)!)
                .foregroundColor(.blue)
                .font(.footnote)
            Spacer()
        }
    }
}
