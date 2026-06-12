import SwiftUI

struct InventoryEmptyStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)

            VStack(spacing: AppTheme.Spacing.small) {
                Text("Nothing in inventory yet")
                    .breezeText(.section)
                    .multilineTextAlignment(.center)

                Text("Complete something from your shopping list and it will appear here automatically.")
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 280)
    }
}
