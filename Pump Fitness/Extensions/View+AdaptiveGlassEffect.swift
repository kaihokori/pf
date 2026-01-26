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

// Helper modifier to handle color scheme adaptation
private struct AdaptiveGlassModifier<S: Shape>: ViewModifier {
    let style: GlassEffectStyle
    let shape: S
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let color = style.tintColor {
                content.glassEffect(.regular.tint(color), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            // Fallback
            content.background {
                ZStack {
                    // Base material
                    Rectangle()
                        .fill(.regularMaterial)
                    
                    // Tinting for Dark Mode or Custom Color
                    if let color = style.tintColor {
                        color.opacity(0.12)
                    } else if colorScheme == .dark {
                        // Darkens the material in dark mode so it's not "too light"
                        Color.black.opacity(0.4)
                    }
                }
                .clipShape(shape)
            }
        }
    }
}

extension View {
    
    // 1. Syntax helper for .regular.tint(...) pattern
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(_ style: GlassEffectStyle, in shape: S) -> some View {
        self.modifier(AdaptiveGlassModifier(style: style, shape: shape))
    }

    // 2. Generic ShapeStyle support
    // Since we can't reliably map arbitrary ShapeStyle to the 'Glass' type expected by iOS 26 glassEffect,
    // we default to .regular glass.
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(_ style: some ShapeStyle, in shape: S) -> some View {
        self.modifier(AdaptiveGlassModifier(style: .regular, shape: shape))
    }
    
    // 3. Default Convenience
    @ViewBuilder
    func adaptiveGlassEffect<S: Shape>(in shape: S) -> some View {
        adaptiveGlassEffect(GlassEffectStyle.regular, in: shape)
    }
}
