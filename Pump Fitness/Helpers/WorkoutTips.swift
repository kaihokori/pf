import SwiftUI
import TipKit

@available(iOS 17.0, *)
struct WorkoutTips {
    @Parameter
    static var currentStep: Int = 0

    struct DailyCheckInTip: Tip {
        var title: Text { Text("Daily Check-In") }
        var message: Text? { Text("Log your daily workout status here.") }
        var image: Image? { Image(systemName: "checkmark.circle") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 0 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct WorkoutSupplementsTip: Tip {
        var title: Text { Text("Workout Supplements") }
        var message: Text? { Text("Track supplements specific to your workouts.") }
        var image: Image? { Image(systemName: "pills.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 1 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }

    struct WeightsTrackingTip: Tip {
        var title: Text { Text("Weights Tracking") }
        var message: Text? { Text("Log your weight lifting progress.") }
        var image: Image? { Image(systemName: "dumbbell.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 2 }
        }
        
        var actions: [Action] {
            Action(id: "next", title: "Next")
        }
    }
    
    struct WeeklyProgressTip: Tip {
        var title: Text { Text("Weekly Progress") }
        var message: Text? { Text("Review your weekly achievements and photos.") }
        var image: Image? { Image(systemName: "chart.bar.fill") }
        
        var rules: [Rule] {
            #Rule(WorkoutTips.$currentStep) { $0 == 3 }
        }
        
        var actions: [Action] {
            Action(id: "finish", title: "Finish")
        }
    }
}
