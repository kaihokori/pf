import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct EditSheetTips {
    
    struct EditMacrosColorTip: Tip {
        var title: Text { Text("Customise Colour") }
        var message: Text? { Text("Tap the icon to change the colour.") }
        var image: Image? { Image(systemName: "paintpalette") }
    }
    
    struct EditWeeklyScheduleColorTip: Tip {
        var title: Text { Text("Customise Colour") }
        var message: Text? { Text("Tap the icon to change the colour.") }
        var image: Image? { Image(systemName: "paintpalette") }
    }
    
    struct EditMealPlanningColorTip: Tip {
        var title: Text { Text("Customise Colour") }
        var message: Text? { Text("Tap the icon to change the colour.") }
        var image: Image? { Image(systemName: "paintpalette") }
    }
}
