import Foundation

enum InventoryItemState: String, Codable, Sendable {
    case inStock
    case finished
    case wasted
}
