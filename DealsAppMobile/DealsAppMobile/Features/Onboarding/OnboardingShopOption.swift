import Foundation

struct OnboardingShopOption: Identifiable {
    let id: String
    let name: String
    let detail: String

    init(id: String, name: String, detail: String) {
        self.id = id
        self.name = name
        self.detail = detail
    }

    init(store: StoreDTO) {
        id = String(store.id)
        name = store.name

        let parts = [store.detail?.city, store.detail?.address]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        detail = parts.isEmpty ? "Coop store" : parts.joined(separator: " · ")
    }

    static let previewSamples = [
        OnboardingShopOption(id: "1", name: "Coop Aby", detail: "Åby · Nyköpingsvägen 18-22"),
        OnboardingShopOption(id: "2", name: "Coop Alidhem", detail: "Umeå · Ekonomistråket 7"),
        OnboardingShopOption(id: "3", name: "Coop Alingsas", detail: "Alingsås · Kungegårdsgatan 1a")
    ]
}
