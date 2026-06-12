import SwiftUI

struct InventoryRowView: View {
    let item: InventoryItem
    let onFinish: () -> Void
    let onWaste: () -> Void
    let onFinishAndAddBack: () -> Void
    let onWasteAndAddBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accentStrong)
                .frame(width: 34, height: 34)
                .breezeSurface(
                    fill: AppTheme.Colors.accentSoft2,
                    border: AppTheme.Colors.activeBorder,
                    radius: AppTheme.Radii.phone
                )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text(item.name)
                    .breezeText(.bodyStrong)
                    .multilineTextAlignment(.leading)

                if metadataText.isEmpty == false {
                    Text(metadataText)
                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button("Finish", systemImage: "checkmark", action: onFinish)
                Button("Waste", systemImage: "trash.slash", action: onWaste)
                Divider()
                Button("Finish and Add Back", systemImage: "arrow.uturn.backward.circle", action: onFinishAndAddBack)
                Button("Waste and Add Back", systemImage: "arrow.uturn.backward.circle.fill", action: onWasteAndAddBack)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(width: 34, height: 34)
                    .breezeSurface(
                        fill: AppTheme.Colors.panelFillStrong,
                        border: AppTheme.Colors.borderStrong,
                        radius: AppTheme.Radii.phone
                    )
            }
            .accessibilityLabel("Inventory item actions")
        }
        .padding(18)
        .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.large)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Finish", action: onFinish)
                .tint(.green)

            Button("Waste", role: .destructive, action: onWaste)
        }
    }

    private var metadataText: String {
        var parts: [String] = []

        if let quantityText = item.quantityText {
            parts.append(quantityText)
        }

        if let preferredStoreName = item.preferredStoreName {
            parts.append("Bought for \(preferredStoreName)")
        } else if let preferredStoreID = item.preferredStoreID {
            parts.append("Store #\(preferredStoreID)")
        }

        if let productID = item.productID {
            parts.append("Product #\(productID)")
        }

        return parts.joined(separator: " · ")
    }
}
