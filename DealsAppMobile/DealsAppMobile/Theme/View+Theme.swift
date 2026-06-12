import SwiftUI

enum BreezeGlassStyle {
    case panel
    case feature
    case interactive

    var glass: Glass {
        switch self {
        case .panel:
            AppTheme.Materials.panel
        case .feature:
            AppTheme.Materials.feature
        case .interactive:
            AppTheme.Materials.interactive
        }
    }
}

private struct BreezeGlassPanelModifier: ViewModifier {
    let style: BreezeGlassStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(
                style.glass,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(
                color: AppTheme.Shadows.ambient.color,
                radius: AppTheme.Shadows.ambient.radius,
                x: AppTheme.Shadows.ambient.x,
                y: AppTheme.Shadows.ambient.y
            )
    }
}

private struct BreezeScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppThemeBackground())
            .foregroundStyle(AppTheme.Colors.primaryText)
    }
}

private struct BreezeSurfaceModifier: ViewModifier {
    let fill: Color
    let border: Color
    let radius: CGFloat
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(border, lineWidth: lineWidth)
                )
        )
    }
}

extension View {
    func breezeScreen() -> some View {
        modifier(BreezeScreenModifier())
    }

    func breezeText(_ style: AppTextStyle, color: Color = AppTheme.Colors.primaryText) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
    }

    func breezeGlassPanel(
        _ style: BreezeGlassStyle = .panel,
        cornerRadius: CGFloat = AppTheme.Radii.medium
    ) -> some View {
        modifier(BreezeGlassPanelModifier(style: style, cornerRadius: cornerRadius))
    }

    func breezeSurface(
        fill: Color,
        border: Color = AppTheme.Colors.border,
        radius: CGFloat = AppTheme.Radii.large,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(BreezeSurfaceModifier(fill: fill, border: border, radius: radius, lineWidth: lineWidth))
    }
}
