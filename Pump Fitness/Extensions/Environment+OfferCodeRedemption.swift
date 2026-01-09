import SwiftUI
import StoreKit
import UIKit

/// Provides an offer code redemption action for SwiftUI toolbars and buttons.
struct OfferCodeRedemptionAction {
    func callAsFunction() {
        Task {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ??
                  UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                return
            }
            try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
        }
    }
}

private struct OfferCodeRedemptionKey: EnvironmentKey {
    static let defaultValue = OfferCodeRedemptionAction()
}

extension EnvironmentValues {
    var offerCodeRedemption: OfferCodeRedemptionAction {
        get { self[OfferCodeRedemptionKey.self] }
        set { self[OfferCodeRedemptionKey.self] = newValue }
    }
}
