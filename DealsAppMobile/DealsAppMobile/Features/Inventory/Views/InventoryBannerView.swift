import SwiftUI

struct InventoryBannerView: View {
    let state: InventoryBannerState
    let onPrimaryAction: () -> Void
    let onUndo: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 20) {
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
                        .buttonStyle(.glass)
                }

                Button(state.primaryButtonTitle, action: onPrimaryAction)
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .breezeGlassPanel(.feature, cornerRadius: AppTheme.Radii.large)
    }
}
