import Foundation

struct StoreDetailDTO: Decodable, Identifiable, Sendable {
    let id: Int
    let storeID: Int
    let aboutURL: String?
    let address: String?
    let postalCode: String?
    let city: String?
    let phone: String?
    let googleMapsURL: String?
    let latitude: Double?
    let longitude: Double?
    let openingHours: [OpeningHoursEntryDTO]?
    let specialHours: [OpeningHoursEntryDTO]?
    let scrapedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeID = "store_id"
        case aboutURL = "about_url"
        case address
        case postalCode = "postal_code"
        case city
        case phone
        case googleMapsURL = "google_maps_url"
        case latitude
        case longitude
        case openingHours = "opening_hours"
        case specialHours = "special_hours"
        case scrapedAt = "scraped_at"
        case updatedAt = "updated_at"
    }
}
