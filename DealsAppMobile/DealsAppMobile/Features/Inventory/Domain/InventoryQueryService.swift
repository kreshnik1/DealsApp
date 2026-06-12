import Foundation
import SwiftData

@MainActor
struct InventoryQueryService {
    let context: ModelContext

    func items() throws -> [InventoryItem] {
        var descriptor = FetchDescriptor<InventoryItem>(
            sortBy: [
                SortDescriptor(\InventoryItem.acquiredAt, order: .reverse),
                SortDescriptor(\InventoryItem.updatedAt, order: .reverse),
            ]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor).filter { $0.state == .inStock }
    }

    func item(linkedTo shoppingListItemID: UUID) throws -> InventoryItem? {
        var descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.sourceShoppingListItemID == shoppingListItemID
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor).first
    }

    func item(withID id: UUID) throws -> InventoryItem? {
        var descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor).first
    }
}
