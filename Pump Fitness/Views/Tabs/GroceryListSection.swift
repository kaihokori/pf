import SwiftUI

struct GroceryListSection: View {
    var accentColorOverride: Color?

    @State private var items: [GroceryItem] = [
        GroceryItem(title: "Apples", quantity: 6),
        GroceryItem(title: "Bananas", quantity: 6),
        GroceryItem(title: "Chicken Breast", quantity: 2),
        GroceryItem(title: "Spinach", quantity: 1),
        GroceryItem(title: "Oats", quantity: 1),
        GroceryItem(title: "Almond Milk", quantity: 2)
    ]

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private let itemCardWidth: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Horizontal scroll of columns, each column contains up to 4 items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    let perColumn = 5
                    let columnCount = (items.count + (perColumn - 1)) / perColumn
                    ForEach(0..<max(1, columnCount), id: \.self) { colIdx in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<min(perColumn, max(0, items.count - colIdx * perColumn)), id: \.self) { rowIdx in
                                let absIndex = colIdx * perColumn + rowIdx
                                let item = items[absIndex]
                                let isChecked = item.isChecked

                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        items[absIndex].isChecked.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        // Checklist on the left
                                        ZStack {
                                            Circle()
                                                .stroke(tint.opacity(0.12), lineWidth: 2)
                                                .frame(width: 36, height: 36)
                                            if isChecked {
                                                Circle()
                                                    .fill(tint)
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(.white)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.subheadline.weight(.semibold))
                                                .strikethrough(isChecked, color: .secondary)
                                                .foregroundStyle(isChecked ? .secondary : .primary)

                                            if let qty = item.quantity {
                                                Text("Qty \(qty)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            } else if !item.note.isEmpty {
                                                Text(item.note)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(12)
                                    .frame(width: itemCardWidth)
                                    .background(
                                        Group {
                                            if isChecked {
                                                tint.opacity(0.06)
                                            } else {
                                                Color.clear
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                if rowIdx != min(perColumn, max(0, items.count - colIdx * perColumn)) - 1 {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

struct GroceryItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var note: String
    var quantity: Int?
    var isChecked: Bool

    init(id: UUID = UUID(), title: String, note: String = "", quantity: Int? = nil, isChecked: Bool = false) {
        self.id = id
        self.title = title
        self.note = note
        self.quantity = quantity
        self.isChecked = isChecked
    }
}

#if DEBUG
struct GroceryListSection_Previews: PreviewProvider {
    static var previews: some View {
        GroceryListSection(accentColorOverride: .accentColor)
            .previewLayout(.sizeThatFits)
    }
}
#endif
