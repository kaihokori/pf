import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct WorkoutTips {
    @Parameter
    static var currentStep: Int = 0

    struct DailyCheckInTip: Tip {
        var title: Text { Text("Daily Check-In") }
        var message: Text? { Text("Tap Check-In when you workout. Tap Rest when you skip a day.") }
        var image: Image? { Image(systemName: "checkmark.circle") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditScheduleTip: Tip {
        var title: Text { Text("Edit Schedule") }
        var message: Text? { Text("Tap Edit to adjust your schedule and colours") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct WorkoutSupplementsTip: Tip {
        var title: Text { Text("Workout Supplements") }
        var message: Text? { Text("Tap supplement to mark them as consumed.") }
        var image: Image? { Image(systemName: "pills.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 2 }
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
            #Rule(WorkoutTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct WeightsTrackingTip: Tip {
        var title: Text { Text("Weights Tracking") }
        var message: Text? { Text("Tap add exercises to add machine/exercises that relate the body parts you train.") }
        var image: Image? { Image(systemName: "dumbbell.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 4 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct EditTrackingTip: Tip {
        var title: Text { Text("Edit Tracking") }
        var message: Text? { Text("Tap Edit to adjust body parts to track.") }
        var image: Image? { Image(systemName: "pencil") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 5 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct WeeklyProgressTip: Tip {
        var title: Text { Text("Weekly Progress") }
        var message: Text? { Text("Tap Add to add you progress for this week. You can adjust this anytime.") }
        var image: Image? { Image(systemName: "chart.bar.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 6 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
