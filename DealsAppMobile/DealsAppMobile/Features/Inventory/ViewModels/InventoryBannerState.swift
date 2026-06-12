import Foundation

struct InventoryBannerState: Identifiable {
    enum PrimaryAction {
        case addBack
        case undo
    }

    let id: UUID
    let title: String
    let message: String?
    let primaryButtonTitle: String
    let primaryAction: PrimaryAction
    let showsUndoButton: Bool
    let inventoryItemID: UUID
    var createdShoppingListItemID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        primaryButtonTitle: String,
        primaryAction: PrimaryAction,
        showsUndoButton: Bool,
        inventoryItemID: UUID,
        createdShoppingListItemID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.showsUndoButton = showsUndoButton
        self.inventoryItemID = inventoryItemID
        self.createdShoppingListItemID = createdShoppingListItemID
    }
}
