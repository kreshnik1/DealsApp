import Foundation
import SwiftData

@MainActor
struct ShoppingListMutationService {
    let context: ModelContext

    private var inventoryMutations: InventoryMutationService {
        InventoryMutationService(context: context)
    }

    @discardableResult
    func createItem(
        name: String,
        quantityText: String? = nil,
        notes: String? = nil,
        category: String? = nil,
        brandSnapshot: String? = nil,
        sizeSnapshot: String? = nil,
        imageURL: String? = nil,
        priceSnapshot: String? = nil,
        originalPriceSnapshot: String? = nil,
        comparisonPriceSnapshot: String? = nil,
        productID: Int? = nil,
        preferredStoreID: Int? = nil,
        preferredStoreName: String? = nil,
        source: ShoppingListItemSource = .manual,
        now: Date = .now
    ) throws -> ShoppingListItem {
        let normalizedName = normalized(name)
        guard normalizedName.isEmpty == false else {
            throw ShoppingListMutationError.emptyName
        }

        let item = ShoppingListItem(
            name: normalizedName,
            quantityText: normalizedOptionalText(quantityText),
            notes: normalizedOptionalText(notes),
            category: normalizedOptionalText(category),
            brandSnapshot: normalizedOptionalText(brandSnapshot),
            sizeSnapshot: normalizedOptionalText(sizeSnapshot),
            imageURL: normalizedOptionalText(imageURL),
            priceSnapshot: normalizedOptionalText(priceSnapshot),
            originalPriceSnapshot: normalizedOptionalText(originalPriceSnapshot),
            comparisonPriceSnapshot: normalizedOptionalText(comparisonPriceSnapshot),
            productID: productID,
            preferredStoreID: preferredStoreID,
            preferredStoreName: normalizedOptionalText(preferredStoreName),
            source: source,
            createdAt: now,
            updatedAt: now,
            sortOrder: try nextSortOrder()
        )

        context.insert(item)
        try context.save()
        return item
    }

    func updateItem(
        _ item: ShoppingListItem,
        name: String,
        quantityText: String? = nil,
        notes: String? = nil,
        category: String? = nil,
        brandSnapshot: String? = nil,
        sizeSnapshot: String? = nil,
        imageURL: String? = nil,
        priceSnapshot: String? = nil,
        originalPriceSnapshot: String? = nil,
        comparisonPriceSnapshot: String? = nil,
        productID: Int? = nil,
        preferredStoreID: Int? = nil,
        preferredStoreName: String? = nil,
        now: Date = .now
    ) throws {
        let normalizedName = normalized(name)
        guard normalizedName.isEmpty == false else {
            throw ShoppingListMutationError.emptyName
        }

        item.updateName(normalizedName)
        item.quantityText = normalizedOptionalText(quantityText)
        item.notes = normalizedOptionalText(notes)
        item.category = normalizedOptionalText(category)
        item.brandSnapshot = normalizedOptionalText(brandSnapshot)
        item.sizeSnapshot = normalizedOptionalText(sizeSnapshot)
        item.imageURL = normalizedOptionalText(imageURL)
        item.priceSnapshot = normalizedOptionalText(priceSnapshot)
        item.originalPriceSnapshot = normalizedOptionalText(originalPriceSnapshot)
        item.comparisonPriceSnapshot = normalizedOptionalText(comparisonPriceSnapshot)
        item.productID = productID
        item.preferredStoreID = preferredStoreID
        item.preferredStoreName = normalizedOptionalText(preferredStoreName)
        item.touch(at: now)

        if item.isChecked {
            try inventoryMutations.upsertItem(
                from: item,
                acquiredAt: item.checkedAt ?? now,
                autosave: false
            )
        }

        try context.save()
    }

    func setChecked(_ item: ShoppingListItem, to isChecked: Bool, now: Date = .now) throws {
        item.isChecked = isChecked
        item.checkedAt = isChecked ? now : nil
        item.touch(at: now)

        if isChecked {
            try inventoryMutations.upsertItem(from: item, acquiredAt: now, autosave: false)
        } else {
            try inventoryMutations.removeLinkedItem(for: item.id, autosave: false)
        }

        try context.save()
    }

    func deleteItem(_ item: ShoppingListItem) throws {
        try inventoryMutations.removeLinkedItem(for: item.id, autosave: false)
        context.delete(item)
        try context.save()
    }

    @discardableResult
    func createItem(
        from inventoryItem: InventoryItem,
        now: Date = .now
    ) throws -> ShoppingListItem {
        try createItem(
            name: inventoryItem.name,
            quantityText: inventoryItem.quantityText,
            notes: inventoryItem.notes,
            category: inventoryItem.category,
            brandSnapshot: inventoryItem.brandSnapshot,
            sizeSnapshot: inventoryItem.sizeSnapshot,
            imageURL: inventoryItem.imageURL,
            priceSnapshot: inventoryItem.priceSnapshot,
            originalPriceSnapshot: inventoryItem.originalPriceSnapshot,
            comparisonPriceSnapshot: inventoryItem.comparisonPriceSnapshot,
            productID: inventoryItem.productID,
            preferredStoreID: inventoryItem.preferredStoreID,
            preferredStoreName: inventoryItem.preferredStoreName,
            source: .inventorySuggestion,
            now: now
        )
    }

    @discardableResult
    func createItem(
        from deal: DealDTO,
        store: StoreDTO,
        now: Date = .now
    ) throws -> ShoppingListItem {
        try createItem(
            name: deal.name,
            quantityText: deal.size,
            notes: noteText(for: deal),
            category: deal.category,
            brandSnapshot: deal.brand,
            sizeSnapshot: deal.size,
            imageURL: deal.imageURL,
            priceSnapshot: priceSnapshot(for: deal),
            originalPriceSnapshot: originalPriceSnapshot(for: deal),
            comparisonPriceSnapshot: normalizedOptionalText(deal.comparisonPrice),
            preferredStoreID: deal.storeID,
            preferredStoreName: preferredStoreName(for: store),
            source: .deal,
            now: now
        )
    }

    func deleteItem(withID id: UUID) throws {
        var descriptor = FetchDescriptor<ShoppingListItem>(
            predicate: #Predicate<ShoppingListItem> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true

        guard let item = try context.fetch(descriptor).first else {
            return
        }

        try deleteItem(item)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func preferredStoreName(for store: StoreDTO) -> String? {
        normalizedOptionalText(store.name) ?? normalizedOptionalText(store.chain)
    }

    private func noteText(for deal: DealDTO) -> String? {
        let parts = [
            normalizedOptionalText(deal.dealText),
            normalizedOptionalText(deal.description),
            normalizedOptionalText(deal.comparisonPrice)
        ]

        let uniqueParts = parts.reduce(into: [String]()) { result, part in
            guard let part, result.contains(part) == false else {
                return
            }

            result.append(part)
        }

        guard uniqueParts.isEmpty == false else {
            return nil
        }

        return uniqueParts.joined(separator: " | ")
    }

    private func priceSnapshot(for deal: DealDTO) -> String? {
        if let priceLabel = normalizedOptionalText(deal.priceLabel) {
            return priceLabel
        }

        guard let dealPrice = deal.dealPrice else {
            return nil
        }

        return Self.priceFormatter.string(from: NSNumber(value: dealPrice))
    }

    private func originalPriceSnapshot(for deal: DealDTO) -> String? {
        guard let originalPrice = deal.originalPrice else {
            return nil
        }

        return Self.priceFormatter.string(from: NSNumber(value: originalPrice))
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SEK"
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private func nextSortOrder() throws -> Int {
        var descriptor = FetchDescriptor<ShoppingListItem>(
            sortBy: [SortDescriptor(\ShoppingListItem.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        let highestSortOrder = try context.fetch(descriptor).first?.sortOrder ?? -1
        return highestSortOrder + 1
    }
}
