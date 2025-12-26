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
        var title: Text { Text("Customize Theme") }
        var message: Text? { Text("Tap here to change the app's color theme.") }
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
        var title: Text { Text("Log Intake") }
        var message: Text? { Text("Tap here to log your meals and track your calories.") }
        var image: Image? { Image(systemName: "plus.circle") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct MacroTip: Tip {
        var title: Text { Text("Track Macros") }
        var message: Text? { Text("Monitor your macronutrient intake here.") }
        var image: Image? { Image(systemName: "chart.pie") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 4 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct SupplementTip: Tip {
        var title: Text { Text("Supplements") }
        var message: Text? { Text("Keep track of your daily supplements here.") }
        var image: Image? { Image(systemName: "pills") }
        
        var rules: [Rule] {
            #Rule(NutritionTips.$currentStep) { $0 == 5 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
