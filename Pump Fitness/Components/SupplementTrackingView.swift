import SwiftUI

private enum NutritionLayout {
    static let supplementTileMinHeight: CGFloat = 150
}

struct SupplementTrackingView: View {
    var accentColorOverride: Color?
    var initialSupplements: [SupplementItem] = SupplementItem.defaultSupplements
    var tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight

    @State private var supplements: [SupplementItem]

    init(accentColorOverride: Color? = nil, initialSupplements: [SupplementItem] = SupplementItem.defaultSupplements, tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight) {
        self.accentColorOverride = accentColorOverride
        self.initialSupplements = initialSupplements
        self.tileMinHeight = tileMinHeight
        _supplements = State(initialValue: initialSupplements)
    }

    var body: some View {
        let supplementTint = accentColorOverride ?? .orange
        let displayItems: [SupplementSummaryItem] =
            Array(supplements.enumerated()).map { .supplement(index: $0.offset, item: $0.element) } + [.add]

        let rows: [[SupplementSummaryItem]] = {
            let count = displayItems.count
            if count <= 4 {
                return [displayItems]
            } else if count == 5 {
                return [Array(displayItems.prefix(3)), Array(displayItems.suffix(2))]
            } else if count == 6 {
                return [Array(displayItems.prefix(3)), Array(displayItems.suffix(3))]
            } else if count == 7 {
                return [Array(displayItems.prefix(4)), Array(displayItems.suffix(3))]
            } else {
                return stride(from: 0, to: count, by: 4).map { index in
                    Array(displayItems[index..<min(index + 4, count)])
                }
            }
        }()

        VStack(spacing: 16) {
            VStack(spacing: 16) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack {
                        Spacer(minLength: 0)
                        ForEach(rows[rowIdx]) { item in
                            switch item {
                            case let .supplement(index, supplement):
                                SupplementRing(
                                    item: supplement,
                                    tint: supplementTint,
                                    minHeight: tileMinHeight
                                ) {
                                    toggleSupplement(at: index)
                                } onRemove: {
                                    removeSupplement(supplement)
                                }
                            case .add:
                                SupplementAddButton(
                                    tint: Color(.systemGray3),
                                    minHeight: tileMinHeight
                                ) {
                                    addSupplement()
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.bottom, -10)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, -30)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func toggleSupplement(at index: Int) {
        guard supplements.indices.contains(index) else { return }
        supplements[index].isTaken.toggle()
    }

    private func removeSupplement(_ supplement: SupplementItem) {
        supplements.removeAll { $0.id == supplement.id }
    }

    private func addSupplement() {
        let unit = SupplementMeasurementUnit.allCases[supplements.count % SupplementMeasurementUnit.allCases.count]
        let defaultAmount: Double
        switch unit {
        case .gram:
            defaultAmount = 1.0
        case .milligram:
            defaultAmount = 50
        case .microgram:
            defaultAmount = 100
        case .scoop:
            defaultAmount = 1.0
        }
        let newSupplement = SupplementItem(
            name: "Supplement #\(supplements.count + 1)",
            amount: defaultAmount,
            unit: unit
        )
        supplements.append(newSupplement)
    }
}

private enum SupplementSummaryItem: Identifiable {
    case supplement(index: Int, item: SupplementItem)
    case add

    var id: String {
        switch self {
        case let .supplement(_, item):
            return item.id.uuidString
        case .add:
            return "supplement-add"
        }
    }
}

private struct SupplementRing: View {
    var item: SupplementItem
    var tint: Color
    var minHeight: CGFloat
    var onToggle: () -> Void
    var onRemove: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: item.isTaken ? 1 : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                    Image(systemName: item.isTaken ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                VStack(spacing: 2) {
                    Text(item.measurementDescription)
                          .font(.caption)
                          .foregroundStyle(.tertiary)
                          .padding(.top, 0)
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 32, alignment: .top)
                }
                .frame(minHeight: 60, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeightForRing, alignment: .top)
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var minHeightForRing: CGFloat { minHeight }
}

private struct SupplementAddButton: View {
    var tint: Color
    var minHeight: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 6, dash: [4]))
                        .foregroundStyle(tint.opacity(0.35))
                        .frame(width: 54, height: 54)
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                Text("Edit Supplement")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        .buttonStyle(.plain)
    }
}

struct SupplementItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Double
    let unit: SupplementMeasurementUnit
    var isTaken: Bool

    init(id: UUID = UUID(), name: String, amount: Double, unit: SupplementMeasurementUnit, isTaken: Bool = false) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.isTaken = isTaken
    }

    var measurementDescription: String {
        let whole = amount.rounded(.towardZero)
        let isWhole = amount.truncatingRemainder(dividingBy: 1) == 0
        let formattedAmount = isWhole ? String(Int(whole)) : String(format: "%.1f", amount)
        return "\(formattedAmount) \(unit.symbol)"
    }

    static let defaultSupplements: [SupplementItem] = [
        SupplementItem(name: "Vitamin C", amount: 1000, unit: .milligram),
        SupplementItem(name: "Vitamin D", amount: 50, unit: .microgram),
        SupplementItem(name: "Zinc", amount: 30, unit: .milligram),
        SupplementItem(name: "Iron", amount: 18, unit: .milligram),
        SupplementItem(name: "Magnesium", amount: 400, unit: .milligram),
        SupplementItem(name: "Magnesium Glycinate", amount: 2.5, unit: .gram),
        SupplementItem(name: "Melatonin", amount: 5, unit: .milligram)
    ]
}

enum SupplementMeasurementUnit: CaseIterable {
    case gram
    case milligram
    case microgram
    case scoop

    var symbol: String {
        switch self {
        case .gram:
            return "g"
        case .milligram:
            return "mg"
        case .microgram:
            return "μg"
        case .scoop:
            return "scoop"
        }
    }
}
