import SwiftUI
import UIKit

// Reusable keyboard toolbar with a Dismiss button for numeric keyboards.
extension View {
    func keyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Dismiss") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .offset(x: 0, y: 1)
            }
        }
    }
}
