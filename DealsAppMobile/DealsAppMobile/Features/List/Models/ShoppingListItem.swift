import Foundation
import SwiftData

@Model
final class ShoppingListItem {
    var id: UUID
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
    var source: ShoppingListItemSource
    var isChecked: Bool
    var checkedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
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
        source: ShoppingListItemSource = .manual,
        isChecked: Bool = false,
        checkedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName ?? Self.normalizedName(from: name)
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
        self.source = source
        self.isChecked = isChecked
        self.checkedAt = checkedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }

    var hasLinkedProduct: Bool {
        productID != nil
    }

    var hasPreferredStore: Bool {
        preferredStoreID != nil || preferredStoreName != nil
    }

    func updateName(_ value: String) {
        name = value
        normalizedName = Self.normalizedName(from: value)
    }

    func touch(at date: Date = .now) {
        updatedAt = date
    }

    static func normalizedName(from value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
