import SwiftUI

struct SurfaceCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var fillColor: Color
    var shadowOpacity: Double

    init(cornerRadius: CGFloat, fillColor: Color = Color(.secondarySystemBackground), shadowOpacity: Double = 0.05) {
        self.cornerRadius = cornerRadius
        self.fillColor = fillColor
        self.shadowOpacity = shadowOpacity
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
                    .shadow(color: Color.black.opacity(shadowOpacity), radius: 12, y: 6)
            )
    }
}

extension View {
    func surfaceCard(_ cornerRadius: CGFloat = 16, fill: Color = Color(.secondarySystemBackground), shadowOpacity: Double = 0.05) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius, fillColor: fill, shadowOpacity: shadowOpacity))
    }
}
