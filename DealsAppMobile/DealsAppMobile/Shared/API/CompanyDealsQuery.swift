import Foundation

struct CompanyDealsQuery: Sendable {
    var search: String?
    var chain: String?
    var category: String?
    var limit: Int
    var offset: Int

    init(
        search: String? = nil,
        chain: String? = nil,
        category: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.search = search
        self.chain = chain
        self.category = category
        self.limit = limit
        self.offset = offset
    }
}
