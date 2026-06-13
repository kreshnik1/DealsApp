import Foundation

struct NearbyStoresQuery: Sendable {
    let latitude: Double
    let longitude: Double
    var limit: Int?

    init(latitude: Double, longitude: Double, limit: Int? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.limit = limit
    }
}
