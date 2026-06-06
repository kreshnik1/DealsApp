import Foundation

struct FlyersQuery: Sendable {
    var storeIDs: [Int]
    var limit: Int
    var offset: Int

    init(
        storeIDs: [Int],
        limit: Int = 50,
        offset: Int = 0
    ) {
        self.storeIDs = storeIDs
        self.limit = limit
        self.offset = offset
    }
}
