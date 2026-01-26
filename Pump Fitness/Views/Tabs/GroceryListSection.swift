import SwiftUI

struct GroceryListSection: View {
    var accentColorOverride: Color?
    @Binding var items: [GroceryItem]

    private var tint: Color {
        accentColorOverride ?? .accentColor
    }

    private let itemCardWidth: CGFloat = 200

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No grocery items yet", systemImage: "cart")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Add items using the Edit button to build your grocery list.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                emptyState
            } else {
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

                                                if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .adaptiveGlassEffect(in: .rect(cornerRadius: 16.0))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }
}

#if DEBUG
struct GroceryListSection_Previews: PreviewProvider {
    @State static var items = GroceryItem.sampleItems()

    static var previews: some View {
        GroceryListSection(accentColorOverride: .accentColor, items: $items)
            .previewLayout(.sizeThatFits)
    }
}
#endif
