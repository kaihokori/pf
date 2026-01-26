import SwiftUI

struct GlassEffectStyle {
    var tintColor: Color?

    static var regular: GlassEffectStyle {
        GlassEffectStyle(tintColor: nil)
    }

    func tint(_ color: Color) -> GlassEffectStyle {
        var copy = self
        copy.tintColor = color
        return copy
    }
}

extension View {
    
    // 1. Syntax helper for .regular.tint(...) pattern
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(_ style: GlassEffectStyle, in shape: S) -> some View {
        if #available(iOS 26, *) {
            if let color = style.tintColor {
                self.glassEffect(.regular.tint(color), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            // Fallback: Tinted background or Black opacity
            self.background(style.tintColor?.opacity(0.12) ?? Color.black.opacity(0.2), in: shape)
        }
    }

    // 2. Generic ShapeStyle support
    // Since we can't reliably map arbitrary ShapeStyle to the 'Glass' type expected by iOS 26 glassEffect,
    // we default to .regular glass.
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(_ style: some ShapeStyle, in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(Color.black.opacity(0.2), in: shape) // Fallback for basic shape styles
        }
    }
    
    // 3. Default Convenience
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(in shape: S) -> some View {
        adaptiveGlassEffect(GlassEffectStyle.regular, in: shape)
    }
}
