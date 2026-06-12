import Foundation
import SwiftData

@MainActor
struct ShoppingListQueryService {
    let context: ModelContext

    func activeItems() throws -> [ShoppingListItem] {
        var descriptor = FetchDescriptor<ShoppingListItem>(
            predicate: #Predicate<ShoppingListItem> { item in
                item.isChecked == false
            },
            sortBy: [
                SortDescriptor(\ShoppingListItem.sortOrder),
                SortDescriptor(\ShoppingListItem.createdAt),
            ]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func checkedItems() throws -> [ShoppingListItem] {
        var descriptor = FetchDescriptor<ShoppingListItem>(
            predicate: #Predicate<ShoppingListItem> { item in
                item.isChecked == true
            },
            sortBy: [
                SortDescriptor(\ShoppingListItem.checkedAt, order: .reverse),
                SortDescriptor(\ShoppingListItem.updatedAt, order: .reverse),
            ]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func allItems() throws -> [ShoppingListItem] {
        var descriptor = FetchDescriptor<ShoppingListItem>(
            sortBy: [
                SortDescriptor(\ShoppingListItem.sortOrder),
                SortDescriptor(\ShoppingListItem.createdAt),
            ]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }
}
