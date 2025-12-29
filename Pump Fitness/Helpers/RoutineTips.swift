import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct RoutineTips {
    @Parameter
    static var currentStep: Int = 0

    struct DailyTasksTip: Tip {
        var title: Text { Text("Daily Tasks") }
        var message: Text? { Text("Tap each task to check them off.") }
        var image: Image? { Image(systemName: "checklist") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditTasksTip: Tip {
        var title: Text { Text("Edit Tasks") }
        var message: Text? { Text("Tap Edit to add or remove tasks and adjust colours") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct GoalsTip: Tip {
        var title: Text { Text("Goals") }
        var message: Text? { Text("Tap a goal to mark them as completed. Overdue goals are given their own group.") }
        var image: Image? { Image(systemName: "target") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 2 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditGoalsTip: Tip {
        var title: Text { Text("Edit Goals") }
        var message: Text? { Text("Tap Edit to set your goals.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct HabitsTip: Tip {
        var title: Text { Text("Habits") }
        var message: Text? { Text("Easily check off the habits you've completed") }
        var image: Image? { Image(systemName: "arrow.triangle.2.circlepath") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 4 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct ExpenseTrackerTip: Tip {
        var title: Text { Text("Expense Tracker") }
        var message: Text? { Text("Tap + below to add your expenses.") }
        var image: Image? { Image(systemName: "banknote") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 5 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditCategoriesTip: Tip {
        var title: Text { Text("Edit Categories") }
        var message: Text? { Text("Tap Edit to change category titles and tracked currency.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(RoutineTips.$currentStep) { $0 == 6 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
