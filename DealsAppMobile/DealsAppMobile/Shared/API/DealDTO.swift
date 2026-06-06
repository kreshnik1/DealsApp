import Foundation

struct DealDTO: Decodable, Identifiable, Sendable {
    let id: Int
    let chain: String
    let storeID: Int
    let externalID: String?
    let name: String
    let brand: String?
    let size: String?
    let description: String?
    let category: String?
    let imageURL: String?
    let originalPrice: Double?
    let dealPrice: Double?
    let dealText: String?
    let priceLabel: String?
    let isMembershipPrice: Bool
    let comparisonPrice: String?
    let extraInfo: String?
    let validFrom: Date?
    let validTo: Date?
    let scrapedAt: Date
    let sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case chain
        case storeID = "store_id"
        case externalID = "external_id"
        case name
        case brand
        case size
        case description
        case category
        case imageURL = "image_url"
        case originalPrice = "original_price"
        case dealPrice = "deal_price"
        case dealText = "deal_text"
        case priceLabel = "price_label"
        case isMembershipPrice = "is_membership_price"
        case comparisonPrice = "comparison_price"
        case extraInfo = "extra_info"
        case validFrom = "valid_from"
        case validTo = "valid_to"
        case scrapedAt = "scraped_at"
        case sourceURL = "source_url"
    }
}
