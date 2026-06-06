import Foundation

struct OpeningHoursEntryDTO: Decodable, Sendable {
    let days: [String]
    let open: String?
    let close: String?
}
