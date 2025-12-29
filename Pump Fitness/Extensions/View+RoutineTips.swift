import SwiftUI
import TipKit

enum RoutineTipType {
    case dailyTasks
    case editTasks
    case goals
    case editGoals
    case habits
    case expenseTracker
    case editCategories
}

extension View {
    @ViewBuilder
    func routineTip(_ type: RoutineTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        if #available(iOS 17.0, *) {
            self.background {
                Color.clear
                    .applyRoutineTip(type, onStepChange: onStepChange)
            }
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func applyRoutineTip(_ type: RoutineTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        switch type {
        case .dailyTasks:
            self.popoverTip(RoutineTips.DailyTasksTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 1
                    onStepChange?(1)
                }
            }
        case .editTasks:
            self.popoverTip(RoutineTips.EditTasksTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 2
                    onStepChange?(2)
                }
            }
        case .goals:
            self.popoverTip(RoutineTips.GoalsTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 3
                    onStepChange?(3)
                }
            }
        case .editGoals:
            self.popoverTip(RoutineTips.EditGoalsTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 4
                    onStepChange?(4)
                }
            }
        case .habits:
            self.popoverTip(RoutineTips.HabitsTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 5
                    onStepChange?(5)
                }
            }
        case .expenseTracker:
            self.popoverTip(RoutineTips.ExpenseTrackerTip()) { action in
                if action.id == "next" {
                    RoutineTips.currentStep = 6
                    onStepChange?(6)
                }
            }
        case .editCategories:
            self.popoverTip(RoutineTips.EditCategoriesTip()) { action in
                if action.id == "finish" {
                    RoutineTips.currentStep = 7
                    onStepChange?(7)
                }
            }
        }
    }
}
