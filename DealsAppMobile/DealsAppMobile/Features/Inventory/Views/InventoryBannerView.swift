import SwiftUI

struct InventoryBannerView: View {
    let state: InventoryBannerState
    let onPrimaryAction: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .breezeText(.bodyStrong)

                if let message = state.message {
                    Text(message)
                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                }
            }

            Spacer(minLength: 0)

            if state.showsUndoButton {
                Button("Undo", action: onUndo)
                    .buttonStyle(.plain)
                    .breezeText(.bodyStrong, color: AppTheme.Colors.secondaryText)
            }

            Button(state.primaryButtonTitle, action: onPrimaryAction)
                .buttonStyle(.plain)
                .breezeText(.bodyStrong, color: AppTheme.Colors.accentStrong)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                .fill(AppTheme.Colors.panelFillStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                        .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
                )
        )
        .shadow(
            color: AppTheme.Shadows.ambient.color,
            radius: AppTheme.Shadows.ambient.radius * 0.55,
            x: AppTheme.Shadows.ambient.x,
            y: AppTheme.Shadows.ambient.y * 0.65
        )
    }
}
