import SwiftUI

struct ShoppingListRowView: View {
    let item: ShoppingListItem
    let onToggleChecked: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Button(
                item.isChecked ? "Mark as not purchased" : "Mark as purchased",
                systemImage: item.isChecked ? "checkmark.circle.fill" : "circle",
                action: onToggleChecked
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(item.isChecked ? AppTheme.Colors.accentStrong : AppTheme.Colors.secondaryText)

            Button(action: onEdit) {
                HStack(spacing: AppTheme.Spacing.medium) {
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
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Item actions")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(rowBackground)
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

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
            .fill(AppTheme.Colors.panelFill.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
                    .strokeBorder(AppTheme.Colors.border, lineWidth: 1)
            )
            .glassEffect(
                Glass.regular.tint(AppTheme.Colors.panelFillMuted.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
            )
    }
}
