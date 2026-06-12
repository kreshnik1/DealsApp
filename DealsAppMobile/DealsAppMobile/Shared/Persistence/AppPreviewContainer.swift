import Foundation
import SwiftData

@MainActor
enum AppPreviewContainer {
    static var shoppingList: ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: InventoryItem.self,
            ShoppingListItem.self,
            configurations: configuration
        )

        let context = container.mainContext
        let bananas = ShoppingListItem(
            name: "Bananas",
            quantityText: "6 pcs",
            preferredStoreID: 14,
            preferredStoreName: "Coop Malmborgs"
        )
        let yogurt = ShoppingListItem(
            name: "Greek yogurt",
            quantityText: "1 tub",
            brandSnapshot: "Arla",
            imageURL: "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=400&q=80",
            priceSnapshot: "2 för 35 kr",
            originalPriceSnapshot: "24,95 kr",
            comparisonPriceSnapshot: "70,00 kr/kg",
            productID: 3021,
            preferredStoreID: 28,
            preferredStoreName: "ICA Maxi",
            sortOrder: 1
        )
        let pasta = ShoppingListItem(
            name: "Pasta",
            quantityText: "2 packs",
            isChecked: true,
            checkedAt: .now.addingTimeInterval(-1800),
            sortOrder: 2
        )
        context.insert(bananas)
        context.insert(yogurt)
        context.insert(pasta)
        context.insert(
            InventoryItem(
                sourceShoppingListItemID: pasta.id,
                name: pasta.name,
                quantityText: pasta.quantityText,
                imageURL: pasta.imageURL,
                productID: pasta.productID,
                preferredStoreID: pasta.preferredStoreID,
                preferredStoreName: pasta.preferredStoreName,
                createdAt: pasta.checkedAt ?? .now,
                updatedAt: pasta.checkedAt ?? .now,
                acquiredAt: pasta.checkedAt ?? .now
            )
        )

        return container
    }
}
