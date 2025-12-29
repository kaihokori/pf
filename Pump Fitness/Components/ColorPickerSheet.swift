import SwiftUI

public struct ColorPickerSheet: View {
    public var onSelect: (String) -> Void
    public var onCancel: (() -> Void)? = nil

    // Use the shared palette so the app stays consistent when picking colours
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)


    public init(onSelect: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ColorPalette.defaultColors, id: \.self) { hex in
                        let resolved = Color(hex: hex) ?? .accentColor
                        Button {
                            onSelect(hex)
                        } label: {
                            Circle()
                                .fill(resolved)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(color: resolved.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .navigationTitle("Choose a Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel?()
                    }
                    .font(.callout.weight(.semibold))
                }
            }
        }
    }
}
