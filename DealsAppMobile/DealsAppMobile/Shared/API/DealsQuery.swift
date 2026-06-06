import Foundation

struct DealsQuery: Sendable {
    var search: String?
    var chain: String?
    var category: String?
    var storeIDs: [Int]
    var limit: Int
    var offset: Int

    init(
        search: String? = nil,
        chain: String? = nil,
        category: String? = nil,
        storeIDs: [Int] = [],
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.search = search
        self.chain = chain
        self.category = category
        self.storeIDs = storeIDs
        self.limit = limit
        self.offset = offset
    }
}
