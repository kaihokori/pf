import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct EditSheetTips {
    static let colorPickerOpened = Tips.Event(id: "colorPickerOpened")

    struct ChangeColorTip: Tip {
        var title: Text { Text("Customise Colour") }
        var message: Text? { Text("Tap the icon to change the colour.") }
        var image: Image? { Image(systemName: "paintpalette") }
        
        @Parameter
        static var hasTrackedItems: Bool = false
        
        @Parameter
        static var isMultiColourTheme: Bool = false

        var rules: [Rule] {
            #Rule(Self.$hasTrackedItems) { $0 == true }
            #Rule(Self.$isMultiColourTheme) { $0 == true }
            #Rule(EditSheetTips.colorPickerOpened) { $0.donations.count == 0 }
        }
    }
}
