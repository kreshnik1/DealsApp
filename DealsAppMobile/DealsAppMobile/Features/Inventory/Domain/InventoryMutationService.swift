import Foundation
import SwiftData

@MainActor
struct InventoryMutationService {
    let context: ModelContext

    @discardableResult
    func upsertItem(
        from shoppingListItem: ShoppingListItem,
        acquiredAt: Date = .now,
        autosave: Bool = true
    ) throws -> InventoryItem {
        let inventoryItem: InventoryItem

        if let existingItem = try queries.item(linkedTo: shoppingListItem.id) {
            existingItem.updateName(shoppingListItem.name)
            existingItem.quantityText = shoppingListItem.quantityText
            existingItem.notes = shoppingListItem.notes
            existingItem.category = shoppingListItem.category
            existingItem.brandSnapshot = shoppingListItem.brandSnapshot
            existingItem.sizeSnapshot = shoppingListItem.sizeSnapshot
            existingItem.imageURL = shoppingListItem.imageURL
            existingItem.priceSnapshot = shoppingListItem.priceSnapshot
            existingItem.originalPriceSnapshot = shoppingListItem.originalPriceSnapshot
            existingItem.comparisonPriceSnapshot = shoppingListItem.comparisonPriceSnapshot
            existingItem.productID = shoppingListItem.productID
            existingItem.preferredStoreID = shoppingListItem.preferredStoreID
            existingItem.preferredStoreName = shoppingListItem.preferredStoreName
            existingItem.acquiredAt = acquiredAt
            existingItem.updateState(.inStock, at: acquiredAt)
            inventoryItem = existingItem
        } else {
            inventoryItem = InventoryItem(
                sourceShoppingListItemID: shoppingListItem.id,
                name: shoppingListItem.name,
                quantityText: shoppingListItem.quantityText,
                notes: shoppingListItem.notes,
                category: shoppingListItem.category,
                brandSnapshot: shoppingListItem.brandSnapshot,
                sizeSnapshot: shoppingListItem.sizeSnapshot,
                imageURL: shoppingListItem.imageURL,
                priceSnapshot: shoppingListItem.priceSnapshot,
                originalPriceSnapshot: shoppingListItem.originalPriceSnapshot,
                comparisonPriceSnapshot: shoppingListItem.comparisonPriceSnapshot,
                productID: shoppingListItem.productID,
                preferredStoreID: shoppingListItem.preferredStoreID,
                preferredStoreName: shoppingListItem.preferredStoreName,
                state: .inStock,
                stateChangedAt: acquiredAt,
                createdAt: acquiredAt,
                updatedAt: acquiredAt,
                acquiredAt: acquiredAt,
                sortOrder: try nextSortOrder()
            )
            context.insert(inventoryItem)
        }

        if autosave {
            try context.save()
        }

        return inventoryItem
    }

    func removeLinkedItem(
        for shoppingListItemID: UUID,
        autosave: Bool = true
    ) throws {
        guard let inventoryItem = try queries.item(linkedTo: shoppingListItemID) else {
            return
        }

        context.delete(inventoryItem)

        if autosave {
            try context.save()
        }
    }

    func deleteItem(_ item: InventoryItem) throws {
        context.delete(item)
        try context.save()
    }

    func markItem(
        _ item: InventoryItem,
        as state: InventoryItemState,
        at date: Date = .now,
        autosave: Bool = true
    ) throws {
        item.updateState(state, at: date)

        if autosave {
            try context.save()
        }
    }

    func restoreToStock(
        _ item: InventoryItem,
        at date: Date = .now,
        autosave: Bool = true
    ) throws {
        try markItem(item, as: .inStock, at: date, autosave: autosave)
    }

    private var queries: InventoryQueryService {
        InventoryQueryService(context: context)
    }

    private func nextSortOrder() throws -> Int {
        var descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [SortDescriptor(\InventoryItem.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        let highestSortOrder = try context.fetch(descriptor).first?.sortOrder ?? -1
        return highestSortOrder + 1
    }
}
