import SwiftUI

struct ProFeaturesListView: View {
    let benefits: [ProBenefit]
    @State private var isExpanded = false
    
    private let collapsedHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack {
                ForEach(benefits) { benefit in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: benefit.icon)
                            .foregroundStyle(.primary)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(benefit.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if !benefit.description.isEmpty {
                                Text(benefit.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding()
            .frame(height: (isExpanded || benefits.count <= 3) ? nil : collapsedHeight, alignment: .top)
            .clipped()
            
            if benefits.count > 3 {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        if isExpanded {
                            Text("See Less")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text("See all \(benefits.count) features")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.06))
                }
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
    }
}

struct ProFeaturesListView_Previews: PreviewProvider {
    static var previews: some View {
        ProFeaturesListView(benefits: [
            ProBenefit(icon: "checkmark", title: "Unlimited macro, supplement, daily task tracking + more", description: ""),
            ProBenefit(icon: "checkmark", title: "Increased limits on timers, habits + more", description: ""),
            ProBenefit(icon: "checkmark", title: "Full access to expense tracking, travel planning + more", description: "")
        ])
            .previewLayout(.sizeThatFits)
    }
}
