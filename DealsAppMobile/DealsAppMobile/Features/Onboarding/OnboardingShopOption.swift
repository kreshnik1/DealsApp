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

        var parts = [store.chain]

        if let distanceKM = store.distanceKM {
            let formattedDistance = distanceKM.formatted(.number.precision(.fractionLength(1)))
            parts.append("\(formattedDistance) km")
        }

        parts += [store.detail?.city, store.detail?.address]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        detail = parts.joined(separator: " · ")
    }

    static let previewSamples = [
        OnboardingShopOption(id: "1", name: "Coop Åby", detail: "STORA COOP · 1.1 km · Åby · Nyköpingsvägen 18-22"),
        OnboardingShopOption(id: "2", name: "ICA Alidhem", detail: "ICA SUPERMARKET · 2.4 km · Umeå · Ekonomistråket 7"),
        OnboardingShopOption(id: "3", name: "Lidl Alingsås", detail: "LIDL · 3.8 km · Alingsås · Kungegårdsgatan 1A")
    ]
}
