import Foundation

struct StoreDealsQuery: Sendable {
    var search: String?
    var category: String?
    var limit: Int
    var offset: Int

    init(
        search: String? = nil,
        category: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.search = search
        self.category = category
        self.limit = limit
        self.offset = offset
    }
}
