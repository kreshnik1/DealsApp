import Foundation

struct StoreDealsQuery: Sendable {
    var search: String?
    var category: String?
    var hydrateIfEmpty: Bool
    var limit: Int
    var offset: Int

    init(
        search: String? = nil,
        category: String? = nil,
        hydrateIfEmpty: Bool = false,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.search = search
        self.category = category
        self.hydrateIfEmpty = hydrateIfEmpty
        self.limit = limit
        self.offset = offset
    }
}
