import Foundation

struct CompanyStoresQuery: Sendable {
    var chain: String?
    var limit: Int?

    init(chain: String? = nil, limit: Int? = nil) {
        self.chain = chain
        self.limit = limit
    }
}
