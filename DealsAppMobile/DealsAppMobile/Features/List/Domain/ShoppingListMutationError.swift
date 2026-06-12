import Foundation

enum ShoppingListMutationError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Add an item name before saving it to your list."
        }
    }
}
