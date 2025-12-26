import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct RoutineTips {
    @Parameter
    static var currentStep: Int = 0

    struct DailyTasksTip: Tip {
        var title: Text { Text("Daily Tasks") }
        var message: Text? { Text("Manage your daily to-do list here.") }
        var image: Image? { Image(systemName: "checklist") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct GoalsTip: Tip {
        var title: Text { Text("Goals") }
        var message: Text? { Text("Set and track your personal goals.") }
        var image: Image? { Image(systemName: "target") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct HabitsTip: Tip {
        var title: Text { Text("Habits") }
        var message: Text? { Text("Build and maintain healthy habits.") }
        var image: Image? { Image(systemName: "arrow.triangle.2.circlepath") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 2 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct ExpenseTrackerTip: Tip {
        var title: Text { Text("Expense Tracker") }
        var message: Text? { Text("Track your spending and budget.") }
        var image: Image? { Image(systemName: "banknote") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
