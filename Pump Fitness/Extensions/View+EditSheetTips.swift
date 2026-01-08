import SwiftUI
import TipKit

extension View {
    @ViewBuilder
    func editSheetChangeColorTip(hasTrackedItems: Bool, isMultiColourTheme: Bool, isActive: Bool = true) -> some View {
        if #available(iOS 17.0, *) {
            // Updating the parameters just before showing
            self.onAppear {
                if isActive {
                    EditSheetTips.ChangeColorTip.hasTrackedItems = hasTrackedItems
                    EditSheetTips.ChangeColorTip.isMultiColourTheme = isMultiColourTheme
                }
            }
            .popoverTip(isActive ? EditSheetTips.ChangeColorTip() : nil)
        } else {
            self
        }
    }
}
