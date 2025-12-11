import SwiftUI

struct ActivityLevelSelector: View {
    @Binding var selection: ActivityLevelOption
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity level")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(ActivityLevelOption.allCases) { option in
                    SelectablePillComponent(
                        label: option.displayName,
                        isSelected: selection == option
                    ) {
                        selection = option
                    }
                }
            }
        }
    }
}

struct ActivityLevelSelector_Previews: PreviewProvider {
    static var previews: some View {
        ActivityLevelSelector(selection: .constant(.moderatelyActive))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
