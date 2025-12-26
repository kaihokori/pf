import SwiftUI
import TipKit

enum WorkoutTipType {
    case dailyCheckIn
    case workoutSupplements
    case weightsTracking
    case weeklyProgress
}

extension View {
    @ViewBuilder
    func workoutTip(_ type: WorkoutTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        if #available(iOS 17.0, *) {
            self.background {
                Color.clear
                    .applyWorkoutTip(type, onStepChange: onStepChange)
            }
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func applyWorkoutTip(_ type: WorkoutTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        switch type {
        case .dailyCheckIn:
            self.popoverTip(WorkoutTips.DailyCheckInTip()) { action in
                if action.id == "next" {
                    WorkoutTips.currentStep = 1
                    onStepChange?(1)
                }
            }
        case .workoutSupplements:
            self.popoverTip(WorkoutTips.WorkoutSupplementsTip()) { action in
                if action.id == "next" {
                    WorkoutTips.currentStep = 2
                    onStepChange?(2)
                }
            }
        case .weightsTracking:
            self.popoverTip(WorkoutTips.WeightsTrackingTip()) { action in
                if action.id == "next" {
                    WorkoutTips.currentStep = 3
                    onStepChange?(3)
                }
            }
        case .weeklyProgress:
            self.popoverTip(WorkoutTips.WeeklyProgressTip()) { action in
                if action.id == "finish" {
                    WorkoutTips.currentStep = 4
                    onStepChange?(4)
                }
            }
        }
    }
}
