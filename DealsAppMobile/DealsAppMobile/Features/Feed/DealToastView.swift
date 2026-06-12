import SwiftUI

struct DealToastView: View {
    let state: DealToastState

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .breezeText(.bodyStrong)

                if let message = state.message {
                    Text(message)
                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                .fill(AppTheme.Colors.panelFillStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        )
        .shadow(
            color: AppTheme.Shadows.ambient.color,
            radius: AppTheme.Shadows.ambient.radius * 0.55,
            x: AppTheme.Shadows.ambient.x,
            y: AppTheme.Shadows.ambient.y * 0.65
        )
    }

    private var iconName: String {
        switch state.kind {
        case .success:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state.kind {
        case .success:
            AppTheme.Colors.accentStrong
        case .error:
            .red
        }
    }

    private var borderColor: Color {
        switch state.kind {
        case .success:
            AppTheme.Colors.activeBorder
        case .error:
            Color.red.opacity(0.25)
        }
    }
}
