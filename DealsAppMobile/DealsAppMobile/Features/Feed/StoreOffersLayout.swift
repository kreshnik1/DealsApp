import Foundation

enum StoreOffersLayout: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .list:
            "list.bullet"
        case .grid:
            "square.grid.2x2"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .list:
            "List layout"
        case .grid:
            "Grid layout"
        }
    }
}
