import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class InventoryViewModel {
    @ObservationIgnored private let context: ModelContext

    private(set) var items: [InventoryItem]
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?
    private(set) var bannerState: InventoryBannerState?

    init(context: ModelContext) {
        self.context = context
        self.items = []
        self.isLoading = false
        self.errorMessage = nil
        self.bannerState = nil
    }

    var itemCount: Int {
        items.count
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try queries.items()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: InventoryItem) {
        do {
            try mutations.deleteItem(item)
            items = try queries.items()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeItem(_ item: InventoryItem, using action: InventoryCompletionAction) {
        do {
            try mutations.markItem(item, as: action.inventoryState)
            items = try queries.items()
            errorMessage = nil
            bannerState = InventoryBannerState(
                title: action.title(for: item.name),
                message: "You can add it back to your shopping list anytime.",
                primaryButtonTitle: "Add Back",
                primaryAction: .addBack,
                showsUndoButton: true,
                inventoryItemID: item.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeAndAddBack(_ item: InventoryItem, using action: InventoryCompletionAction) {
        do {
            try mutations.markItem(item, as: action.inventoryState, autosave: false)
            let createdItem = try shoppingListMutations.createItem(from: item)
            items = try queries.items()
            errorMessage = nil
            bannerState = InventoryBannerState(
                title: "\(item.name) added back to your shopping list",
                message: nil,
                primaryButtonTitle: "Undo",
                primaryAction: .undo,
                showsUndoButton: false,
                inventoryItemID: item.id,
                createdShoppingListItemID: createdItem.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleBannerPrimaryAction() {
        guard let bannerState else {
            return
        }

        switch bannerState.primaryAction {
        case .addBack:
            addBackToShoppingList(from: bannerState)
        case .undo:
            undo(from: bannerState)
        }
    }

    func undoBannerAction() {
        guard let bannerState else {
            return
        }

        undo(from: bannerState)
    }

    func dismissBanner() {
        bannerState = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private var queries: InventoryQueryService {
        InventoryQueryService(context: context)
    }

    private var mutations: InventoryMutationService {
        InventoryMutationService(context: context)
    }

    private var shoppingListMutations: ShoppingListMutationService {
        ShoppingListMutationService(context: context)
    }

    private func addBackToShoppingList(from bannerState: InventoryBannerState) {
        do {
            guard let inventoryItem = try queries.item(withID: bannerState.inventoryItemID) else {
                self.bannerState = nil
                return
            }

            let createdItem = try shoppingListMutations.createItem(from: inventoryItem)
            items = try queries.items()
            errorMessage = nil
            self.bannerState = InventoryBannerState(
                title: "\(inventoryItem.name) added back to your shopping list",
                message: nil,
                primaryButtonTitle: "Undo",
                primaryAction: .undo,
                showsUndoButton: false,
                inventoryItemID: inventoryItem.id,
                createdShoppingListItemID: createdItem.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undo(from bannerState: InventoryBannerState) {
        do {
            guard let inventoryItem = try queries.item(withID: bannerState.inventoryItemID) else {
                self.bannerState = nil
                return
            }

            try mutations.restoreToStock(inventoryItem, autosave: false)

            if let createdShoppingListItemID = bannerState.createdShoppingListItemID {
                try shoppingListMutations.deleteItem(withID: createdShoppingListItemID)
            } else {
                try context.save()
            }

            items = try queries.items()
            errorMessage = nil
            self.bannerState = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
