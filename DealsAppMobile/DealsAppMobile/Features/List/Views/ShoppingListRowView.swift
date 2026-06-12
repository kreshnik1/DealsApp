import SwiftUI

struct ShoppingListRowView: View {
    let item: ShoppingListItem
    let onToggleChecked: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Button(action: onToggleChecked) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(item.isChecked ? AppTheme.Colors.accentStrong : AppTheme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isChecked ? "Mark as not purchased" : "Mark as purchased")

            if item.imageURL != nil {
                ShoppingListItemImageView(
                    imageURL: item.imageURL,
                    size: 56,
                    cornerRadius: AppTheme.Radii.small
                )
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text(item.name)
                    .breezeText(.bodyStrong, color: item.isChecked ? AppTheme.Colors.secondaryText : AppTheme.Colors.primaryText)
                    .strikethrough(item.isChecked, color: AppTheme.Colors.tertiaryText)
                    .multilineTextAlignment(.leading)

                if metadataText.isEmpty == false {
                    Text(metadataText)
                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
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
            .accessibilityLabel("Item actions")
        }
        .padding(18)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous))
        .onTapGesture(perform: onEdit)
        .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.large)
    }

    private var metadataText: String {
        var parts: [String] = []

        if let quantityText = item.quantityText {
            parts.append(quantityText)
        }

        if let preferredStoreName = item.preferredStoreName {
            parts.append("Target: \(preferredStoreName)")
        } else if let preferredStoreID = item.preferredStoreID {
            parts.append("Store #\(preferredStoreID)")
        }

        if let productID = item.productID {
            parts.append("Product #\(productID)")
        }

        return parts.joined(separator: " · ")
    }
}
