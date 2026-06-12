import SwiftUI

struct ShoppingListEmptyStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Image(systemName: "basket.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)

            VStack(spacing: AppTheme.Spacing.small) {
                Text("No items on your list yet")
                    .breezeText(.section)
                    .multilineTextAlignment(.center)

                Text("Add groceries from the composer below. Product and store links can stay empty until the catalog layer lands.")
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 280)
    }
}
