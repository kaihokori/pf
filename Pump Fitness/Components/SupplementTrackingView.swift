import SwiftUI

private enum NutritionLayout {
    static let supplementTileMinHeight: CGFloat = 150
}

struct SupplementTrackingView: View {
    var accentColorOverride: Color?
    var tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight

    // Supplements provided by parent view (nutrition or workout)
    var supplements: [Supplement]

    // IDs of supplements taken for the current day
    @Binding var takenSupplementIDs: Set<String>

    // Callbacks to let the parent persist changes
    var onToggle: (Supplement) -> Void
    var onRemove: (Supplement) -> Void

    init(
        accentColorOverride: Color? = nil,
        supplements: [Supplement],
        takenSupplementIDs: Binding<Set<String>>,
        tileMinHeight: CGFloat = NutritionLayout.supplementTileMinHeight,
        onToggle: @escaping (Supplement) -> Void,
        onRemove: @escaping (Supplement) -> Void
    ) {
        self.accentColorOverride = accentColorOverride
        self.supplements = supplements
        self._takenSupplementIDs = takenSupplementIDs
        self.tileMinHeight = tileMinHeight
        self.onToggle = onToggle
        self.onRemove = onRemove
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
                            case let .supplement(_, supplement):
                                SupplementRing(
                                    itemName: supplement.name,
                                    amountLabel: supplement.amountLabel,
                                    isTaken: takenSupplementIDs.contains(supplement.id),
                                    tint: supplementTint,
                                    minHeight: tileMinHeight,
                                    onToggle: { onToggle(supplement) },
                                    onRemove: { onRemove(supplement) }
                                )
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

    // Parent is responsible for persistence when toggling/removing
}

private enum SupplementSummaryItem: Identifiable {
    case supplement(index: Int, item: Supplement)

    var id: String {
        switch self {
        case let .supplement(_, item):
            return item.id
        }
    }
}

private struct SupplementRing: View {
    var itemName: String
    var amountLabel: String?
    var isTaken: Bool
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
                        .trim(from: 0, to: isTaken ? 1 : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                    Image(systemName: isTaken ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 10)
                VStack(spacing: 2) {
                    if let amountLabel {
                        Text(amountLabel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 0)
                    }
                    Text(itemName)
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

// SupplementItem view model removed; use `Supplement` from Account model

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
