import Foundation

struct StoreFlyersQuery: Sendable {
    var limit: Int
    var offset: Int

    init(limit: Int = 10, offset: Int = 0) {
        self.limit = limit
        self.offset = offset
    }
}
