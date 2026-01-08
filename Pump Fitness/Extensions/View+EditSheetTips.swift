import SwiftUI
import TipKit

enum EditSheetTipType {
    case editMacrosColor
    case editWeeklyScheduleColor
    case editMealPlanningColor
}

extension View {
    @ViewBuilder
    func editSheetTip(_ type: EditSheetTipType) -> some View {
        if #available(iOS 17.0, *) {
            switch type {
            case .editMacrosColor:
                self.popoverTip(EditSheetTips.EditMacrosColorTip())
            case .editWeeklyScheduleColor:
                self.popoverTip(EditSheetTips.EditWeeklyScheduleColorTip())
            case .editMealPlanningColor:
                self.popoverTip(EditSheetTips.EditMealPlanningColorTip())
            }
        } else {
            self
        }
    }
}
