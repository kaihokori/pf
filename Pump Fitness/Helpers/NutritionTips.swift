import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct NutritionTips {
    @Parameter
    static var currentStep: Int = 0

    struct DateSelectorTip: Tip {
        var title: Text { Text("Change Date") }
        var message: Text? { Text("Tap here to select a different date or view your history.") }
        var image: Image? { Image(systemName: "calendar") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct ThemeSelectorTip: Tip {
        var title: Text { Text("Customise Theme") }
        var message: Text? { Text("Tap here to change the app's colour theme.") }
        var image: Image? { Image(systemName: "paintpalette") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct ProfileTip: Tip {
        var title: Text { Text("Your Profile") }
        var message: Text? { Text("Access your account settings and profile here.") }
        var image: Image? { Image(systemName: "person.circle") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 2 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct LogIntakeTip: Tip {
        var title: Text { Text("Log Your Intake") }
        var message: Text? { Text("Track meals with barcode scanning and food lookup") }
        var image: Image? { Image(systemName: "plus.circle") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct EditCalorieGoalTip: Tip {
        var title: Text { Text("Edit Calorie Goal") }
        var message: Text? { Text("Tap Edit to change Goal.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct ConsumedCaloriesTip: Tip {
        var title: Text { Text("Consumed Calories") }
        var message: Text? { Text("Tap your consumed calories to adjust manually.") }
        var image: Image? { Image(systemName: "flame") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 4 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct TrackMacrosTip: Tip {
        var title: Text { Text("Track Macros") }
        var message: Text? { Text("Tap each macro to manually adjust your intake.") }
        var image: Image? { Image(systemName: "chart.pie") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 5 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditMacrosTip: Tip {
        var title: Text { Text("Edit Macros") }
        var message: Text? { Text("Tap Edit to add or remove macros and adjust colours") }
        var image: Image? { Image(systemName: "slider.horizontal.3") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 6 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct SupplementsTip: Tip {
        var title: Text { Text("Supplements") }
        var message: Text? { Text("Tap each circle to checklist of your supplements.") }
        var image: Image? { Image(systemName: "pills") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 7 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditSupplementsTip: Tip {
        var title: Text { Text("Edit Supplements") }
        var message: Text? { Text("Tap Edit to add or remove supplements.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 8 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
