import Foundation

struct StoreDTO: Decodable, Identifiable, Sendable {
    let id: Int
    let companyID: Int
    let name: String
    let chain: String
    let externalID: String?
    let storeURL: String?
    let weeklyDealsURL: String?
    let distanceKM: Double? = nil
    let detail: StoreDetailDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case companyID = "company_id"
        case name
        case chain
        case externalID = "external_id"
        case storeURL = "store_url"
        case weeklyDealsURL = "weekly_deals_url"
        case distanceKM = "distance_km"
        case detail
    }
}
