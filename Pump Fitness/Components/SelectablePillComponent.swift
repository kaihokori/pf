import SwiftUI

public struct SelectablePillComponent<Label: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    private let label: () -> Label

    public init(label: String, isSelected: Bool, action: @escaping () -> Void) where Label == Text {
        self.isSelected = isSelected
        self.action = action
        self.label = {
            Text(label)
        }
    }

    public init(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(action: action) {
            label()
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .glassEffect(in: .rect(cornerRadius: 12.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
