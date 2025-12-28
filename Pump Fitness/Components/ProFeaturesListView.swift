import SwiftUI

struct ProFeaturesListView: View {
    let categories: [ProBenefitCategory]
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private let collapsedHeight: CGFloat = 260

    private var totalBenefitCount: Int {
        categories.reduce(into: 0) { partialResult, category in
            partialResult += category.benefits.count
        }
    }

    private func summaryLine(for category: ProBenefitCategory) -> String {
        let titles = category.benefits.map { $0.title }
        let prefix = titles.prefix(3).joined(separator: ", ")
        let suffix = titles.count > 3 ? " + more" : ""
        return prefix + suffix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(categories) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: category.image)
                                    .foregroundStyle(category.color)
                                    .font(.headline)
                                    .frame(width: 24, height: 24)
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(category.benefits) { benefit in
                                    HStack(alignment: .center, spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.primary)
                                            .font(.title3)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(benefit.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                            if !benefit.description.isEmpty {
                                                Text(benefit.description)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories) { category in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: category.image)
                                .foregroundStyle(category.color)
                                .font(.headline)
                                .frame(width: 22, height: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(summaryLine(for: category))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 18)
                .padding(.bottom, -12)
                .frame(height: collapsedHeight, alignment: .top)
                .clipped()
            }

            if totalBenefitCount > 3 {
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
                            Text("See all \(totalBenefitCount) features")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                }
            }
        }
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
    }
}

struct ProFeaturesListView_Previews: PreviewProvider {
    static var previews: some View {
        ProFeaturesListView(categories: [
            ProBenefitCategory(name: "Nutrition", image: "leaf.fill", color: .green, benefits: [
                ProBenefit(icon: "chart.pie.fill", title: "Macros", description: "Track unlimited macronutrients and calories."),
                ProBenefit(icon: "pills.fill", title: "Supplements", description: "Log unlimited supplements and vitamins.")
            ]),
            ProBenefitCategory(name: "Routine", image: "checklist.checked", color: .blue, benefits: [
                ProBenefit(icon: "list.bullet", title: "Daily Tasks", description: "Create unlimited daily tasks to stay organized."),
                ProBenefit(icon: "timer", title: "Activity Timers", description: "Use up to 6 activity timers for your routines.")
            ])
        ])
            .previewLayout(.sizeThatFits)
    }
}
