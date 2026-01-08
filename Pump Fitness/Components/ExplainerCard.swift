import SwiftUI

struct ExplainerCard: View {
    var title: String
    var icon: String
    var description: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    var accentColor: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(accentColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
    }
}
