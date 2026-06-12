import SwiftUI

struct ShoppingListEditSheetView: View {
    let item: ShoppingListItem
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var quantityText: String
    @State private var notes: String

    init(
        item: ShoppingListItem,
        onSave: @escaping (String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: item.name)
        _quantityText = State(initialValue: item.quantityText ?? "")
        _notes = State(initialValue: item.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    heroSection

                    if showsPriceSection {
                        detailSection(title: "Price Snapshot") {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                if let priceSnapshot = item.priceSnapshot {
                                    Text(priceSnapshot)
                                        .breezeText(.bodyStrong)
                                }

                                if let originalPriceSnapshot = item.originalPriceSnapshot {
                                    detailLine(title: "Ord. price", value: originalPriceSnapshot)
                                }

                                if let comparisonPriceSnapshot = item.comparisonPriceSnapshot {
                                    detailLine(title: "Compare", value: comparisonPriceSnapshot)
                                }
                            }
                        }
                    }

                    if showsStoreSection {
                        detailSection(title: "Source Store") {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                if let preferredStoreName = item.preferredStoreName {
                                    Text(preferredStoreName)
                                        .breezeText(.bodyStrong)
                                }

                                if let preferredStoreID = item.preferredStoreID {
                                    detailLine(title: "Store ID", value: String(preferredStoreID))
                                }

                                if let productID = item.productID {
                                    detailLine(title: "Product ID", value: String(productID))
                                }
                            }
                        }
                    }

                    detailSection(title: "Your Item") {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                            TextField("Item name", text: $name)
                                .breezeText(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .breezeSurface(
                                    fill: AppTheme.Colors.textFieldFill,
                                    border: AppTheme.Colors.borderStrong,
                                    radius: AppTheme.Radii.medium
                                )

                            TextField("Quantity", text: $quantityText)
                                .breezeText(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .breezeSurface(
                                    fill: AppTheme.Colors.textFieldFill,
                                    border: AppTheme.Colors.borderStrong,
                                    radius: AppTheme.Radii.medium
                                )

                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...)
                                .breezeText(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .breezeSurface(
                                    fill: AppTheme.Colors.textFieldFill,
                                    border: AppTheme.Colors.borderStrong,
                                    radius: AppTheme.Radii.medium
                                )
                        }
                    }
                }
                .padding(AppTheme.Spacing.screenInset)
                .padding(.bottom, AppTheme.Spacing.xxLarge)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        onSave(name, quantityText, notes)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            if item.imageURL != nil {
                ShoppingListItemImageView(
                    imageURL: item.imageURL,
                    size: 220,
                    cornerRadius: AppTheme.Radii.large
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                if let brandSnapshot = item.brandSnapshot {
                    Text(brandSnapshot)
                        .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)
                }

                Text(item.name)
                    .breezeText(.section)
                    .fixedSize(horizontal: false, vertical: true)

                if summaryLine.isEmpty == false {
                    Text(summaryLine)
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var summaryLine: String {
        let parts: [String?] = [
            item.quantityText,
            item.sizeSnapshot,
            item.category
        ]

        return parts
        .compactMap { value -> String? in
            guard let value else {
                return nil
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        .reduce(into: [String]()) { result, value in
            guard result.contains(value) == false else {
                return
            }

            result.append(value)
        }
        .joined(separator: " · ")
    }

    private var showsPriceSection: Bool {
        item.priceSnapshot != nil || item.originalPriceSnapshot != nil || item.comparisonPriceSnapshot != nil
    }

    private var showsStoreSection: Bool {
        item.preferredStoreName != nil || item.preferredStoreID != nil || item.productID != nil
    }

    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                content()
            }
            .padding(16)
            .breezeSurface(
                fill: AppTheme.Colors.panelFillStrong,
                border: AppTheme.Colors.borderStrong,
                radius: AppTheme.Radii.medium
            )
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
            Text(title)
                .breezeText(.meta, color: AppTheme.Colors.tertiaryText)

            Spacer(minLength: 0)

            Text(value)
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
