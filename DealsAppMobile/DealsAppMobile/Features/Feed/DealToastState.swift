import Foundation

struct DealToastState: Identifiable {
    enum Kind {
        case success
        case error
    }

    let id: UUID
    let title: String
    let message: String?
    let kind: Kind

    init(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        kind: Kind
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.kind = kind
    }
}
