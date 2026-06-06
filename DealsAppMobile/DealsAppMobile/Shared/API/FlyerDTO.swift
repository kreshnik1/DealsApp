import Foundation

struct FlyerDTO: Decodable, Identifiable, Sendable {
    let id: Int
    let storeID: Int
    let url: String
    let pdfPath: String?
    let fileSize: Int?
    let weekNumber: Int?
    let validFrom: Date?
    let validTo: Date?
    let scrapedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storeID = "store_id"
        case url
        case pdfPath = "pdf_path"
        case fileSize = "file_size"
        case weekNumber = "week_number"
        case validFrom = "valid_from"
        case validTo = "valid_to"
        case scrapedAt = "scraped_at"
    }
}
