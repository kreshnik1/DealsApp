import Foundation

struct StoresQuery: Sendable {
    var chain: String?

    init(chain: String? = nil) {
        self.chain = chain
    }
}
