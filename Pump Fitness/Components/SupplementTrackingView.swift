import SwiftUI

private enum NutritionLayout {
    static let supplementTileMinHeight: CGFloat = 150
}

struct SupplementTrackingView: View {
    var accentColorOverride: Color?
    var tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight

    @Binding var supplements: [SupplementItem]

    init(accentColorOverride: Color? = nil, supplements: Binding<[SupplementItem]>, tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight) {
        self.accentColorOverride = accentColorOverride
        self._supplements = supplements
        self.tileMinHeight = tileMinHeight
    }

    var body: some View {
        let supplementTint = accentColorOverride ?? .orange
        let displayItems: [SupplementSummaryItem] =
            Array(supplements.enumerated()).map { .supplement(index: $0.offset, item: $0.element) }

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
        let label: String
        switch unit {
        case .gram:
            label = "1 g"
        case .milligram:
            label = "50 mg"
        case .microgram:
            label = "100 μg"
        case .scoop:
            label = "1 scoop"
        }
        let newSupplement = SupplementItem(
            name: "Supplement #\(supplements.count + 1)",
            amountLabel: label
        )
        supplements.append(newSupplement)
    }
}

private enum SupplementSummaryItem: Identifiable {
    case supplement(index: Int, item: SupplementItem)

    var id: String {
        switch self {
        case let .supplement(_, item):
            return item.id.uuidString
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

// Edit/Add button removed — supplements are display-only in this view

struct SupplementItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    // Freeform amount/label like "50 mg" or "3 scoops"
    var amountLabel: String
    var isTaken: Bool
    // Optional override label (user-entered), e.g. "5 g or 3 scoops"
    var customLabel: String?

    init(id: UUID = UUID(), name: String, amountLabel: String, isTaken: Bool = false, customLabel: String? = nil) {
        self.id = id
        self.name = name
        self.amountLabel = amountLabel
        self.isTaken = isTaken
        self.customLabel = customLabel
    }

    var measurementDescription: String {
        if let label = customLabel, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        return amountLabel
    }

    static let defaultSupplements: [SupplementItem] = [
        SupplementItem(name: "Vitamin C", amountLabel: "1000 mg"),
        SupplementItem(name: "Vitamin D", amountLabel: "50 μg"),
        SupplementItem(name: "Zinc", amountLabel: "30 mg"),
        SupplementItem(name: "Iron", amountLabel: "18 mg"),
        SupplementItem(name: "Magnesium", amountLabel: "400 mg"),
        SupplementItem(name: "Magnesium Glycinate", amountLabel: "2.5 g"),
        SupplementItem(name: "Melatonin", amountLabel: "5 mg")
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
