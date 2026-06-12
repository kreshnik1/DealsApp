import Foundation
import SwiftData

@Model
final class InventoryItem {
    var id: UUID
    var sourceShoppingListItemID: UUID?
    var name: String
    var normalizedName: String
    var quantityText: String?
    var notes: String?
    var category: String?
    var brandSnapshot: String?
    var sizeSnapshot: String?
    var imageURL: String?
    var priceSnapshot: String?
    var originalPriceSnapshot: String?
    var comparisonPriceSnapshot: String?
    var productID: Int?
    var preferredStoreID: Int?
    var preferredStoreName: String?
    var state: InventoryItemState
    var stateChangedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var acquiredAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        sourceShoppingListItemID: UUID? = nil,
        name: String,
        normalizedName: String? = nil,
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
        state: InventoryItemState = .inStock,
        stateChangedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        acquiredAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.sourceShoppingListItemID = sourceShoppingListItemID
        self.name = name
        self.normalizedName = normalizedName ?? ShoppingListItem.normalizedName(from: name)
        self.quantityText = quantityText
        self.notes = notes
        self.category = category
        self.brandSnapshot = brandSnapshot
        self.sizeSnapshot = sizeSnapshot
        self.imageURL = imageURL
        self.priceSnapshot = priceSnapshot
        self.originalPriceSnapshot = originalPriceSnapshot
        self.comparisonPriceSnapshot = comparisonPriceSnapshot
        self.productID = productID
        self.preferredStoreID = preferredStoreID
        self.preferredStoreName = preferredStoreName
        self.state = state
        self.stateChangedAt = stateChangedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.acquiredAt = acquiredAt
        self.sortOrder = sortOrder
    }

    func updateName(_ value: String) {
        name = value
        normalizedName = ShoppingListItem.normalizedName(from: value)
    }

    func touch(at date: Date = .now) {
        updatedAt = date
    }

    func updateState(_ newState: InventoryItemState, at date: Date = .now) {
        state = newState
        stateChangedAt = date
        touch(at: date)
    }
}
