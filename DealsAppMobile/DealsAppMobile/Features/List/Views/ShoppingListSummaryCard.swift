import SwiftUI

struct ShoppingListSummaryCard: View {
    let viewModel: ShoppingListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Plan your run")
                    .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

                Text("A local list that is already shaped for product and store linking.")
                    .breezeText(.section)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AppTheme.Spacing.medium) {
                metric(
                    value: "\(viewModel.activeItemCount)",
                    label: "To buy"
                )
                metric(
                    value: "\(viewModel.linkedItemCount)",
                    label: "Linked products"
                )
                metric(
                    value: "\(viewModel.preferredStoreCount)",
                    label: "Target stores"
                )
            }
        }
        .padding(22)
        .breezeGlassPanel(.feature, cornerRadius: AppTheme.Radii.xLarge)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
            Text(value)
                .breezeText(.section)

            Text(label)
                .breezeText(.meta, color: AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .breezeSurface(
            fill: AppTheme.Colors.panelFillStrong,
            border: AppTheme.Colors.borderStrong,
            radius: AppTheme.Radii.medium
        )
    }
}
