import SwiftUI
import TipKit

enum NutritionTipType {
    case dateSelector
    case themeSelector
    case profile
    case logIntake
    case macroTracking
    case supplementTracking
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
        case .macroTracking:
            self.popoverTip(NutritionTips.MacroTip()) { action in
                if action.id == "next" {
                    NutritionTips.currentStep = 5
                    onStepChange?(5)
                }
            }
        case .supplementTracking:
            self.popoverTip(NutritionTips.SupplementTip()) { action in
                if action.id == "finish" {
                    NutritionTips.currentStep = 6
                    onStepChange?(6)
                }
            }
        }
    }
}
