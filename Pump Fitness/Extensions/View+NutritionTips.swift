import SwiftUI
import TipKit

enum NutritionTipType {
    case dateSelector
    case themeSelector
    case profile
    case logIntake
    case editCalorieGoal
    case consumedCalories
    case trackMacros
    case editMacros
    case supplements
    case editSupplements
}

extension View {
    @ViewBuilder
    func nutritionTip(_ type: NutritionTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        if #available(iOS 17.0, *) {
            self.background {
                Color.clear
                    .applyTip(type, onStepChange: onStepChange)
            }
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
extension View {
    @ViewBuilder
    func applyTip(_ type: NutritionTipType, onStepChange: ((Int) -> Void)? = nil) -> some View {
        switch type {
        case .dateSelector:
            self.popoverTip(NutritionTips.DateSelectorTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 1
                    onStepChange?(1)
                }
            }
        case .themeSelector:
            self.popoverTip(NutritionTips.ThemeSelectorTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 2
                    onStepChange?(2)
                }
            }
        case .profile:
            self.popoverTip(NutritionTips.ProfileTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 3
                    onStepChange?(3)
                }
            }
        case .logIntake:
            self.popoverTip(NutritionTips.LogIntakeTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 4
                    onStepChange?(4)
                }
            }
        case .editCalorieGoal:
            self.popoverTip(NutritionTips.EditCalorieGoalTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 4
                    onStepChange?(4)
                }
            }
        case .consumedCalories:
            self.popoverTip(NutritionTips.ConsumedCaloriesTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 5
                    onStepChange?(5)
                }
            }
        case .trackMacros:
            self.popoverTip(NutritionTips.TrackMacrosTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 6
                    onStepChange?(6)
                }
            }
        case .editMacros:
            self.popoverTip(NutritionTips.EditMacrosTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 7
                    onStepChange?(7)
                }
            }
        case .supplements:
            self.popoverTip(NutritionTips.SupplementsTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 8
                    onStepChange?(8)
                }
            }
        case .editSupplements:
            self.popoverTip(NutritionTips.EditSupplementsTip()) { action in
                if action.id == "finish" {
                    NutritionTips.currentStep = 9
                    onStepChange?(9)
                }
            }
        }
    }
}
