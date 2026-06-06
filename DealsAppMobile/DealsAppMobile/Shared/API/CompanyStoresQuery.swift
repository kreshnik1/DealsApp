import Foundation

struct CompanyStoresQuery: Sendable {
    var chain: String?

    init(chain: String? = nil) {
        self.chain = chain
    }
}
