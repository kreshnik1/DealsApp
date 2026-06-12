import Foundation

enum InventoryCompletionAction: Sendable {
    case finished
    case wasted

    var inventoryState: InventoryItemState {
        switch self {
        case .finished:
            .finished
        case .wasted:
            .wasted
        }
    }

    func title(for itemName: String) -> String {
        switch self {
        case .finished:
            "\(itemName) finished"
        case .wasted:
            "\(itemName) wasted"
        }
    }
}
