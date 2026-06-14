import Foundation

struct OnboardingShopOption: Identifiable {
    let id: String
    let name: String
    let chain: String
    let distanceKM: Double?
    let city: String?
    let address: String?

    var brand: StoreBrand { StoreBrand(chain: chain) }

    /// Distance to the store formatted for display, e.g. "1.1 km" or "450 m".
    var distanceText: String? {
        guard let distanceKM else { return nil }

        if distanceKM < 1 {
            let meters = max(Int((distanceKM * 1000 / 10).rounded()) * 10, 10)
            return "\(meters) m"
        }

        return "\(distanceKM.formatted(.number.precision(.fractionLength(1)))) km"
    }

    /// Secondary line shown under the store name. Street first so it stays the
    /// most legible part when the line is truncated, e.g. "Nyköpingsvägen 18-22, Åby".
    var addressLine: String {
        [address, city]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    init(
        id: String,
        name: String,
        chain: String,
        distanceKM: Double?,
        city: String?,
        address: String?
    ) {
        self.id = id
        self.name = name
        self.chain = chain
        self.distanceKM = distanceKM
        self.city = city
        self.address = address
    }

    init(store: StoreDTO) {
        id = String(store.id)
        name = store.name
        chain = store.chain
        distanceKM = store.distanceKM
        city = store.detail?.city
        address = store.detail?.address
    }

    static let previewSamples = [
        OnboardingShopOption(id: "1", name: "Stora Coop Åby", chain: "STORA COOP", distanceKM: 1.1, city: "Åby", address: "Nyköpingsvägen 18-22"),
        OnboardingShopOption(id: "2", name: "Coop Nyköping", chain: "COOP", distanceKM: 3.2, city: "Nyköping", address: "Brunnsgatan 2"),
        OnboardingShopOption(id: "3", name: "ICA Supermarket Alidhem", chain: "ICA SUPERMARKET", distanceKM: 2.4, city: "Umeå", address: "Ekonomistråket 7"),
        OnboardingShopOption(id: "4", name: "ICA Maxi", chain: "ICA MAXI", distanceKM: 0.45, city: "Umeå", address: "Söderslättsvägen 1"),
        OnboardingShopOption(id: "5", name: "Lidl Alingsås", chain: "LIDL", distanceKM: 3.8, city: "Alingsås", address: "Kungegårdsgatan 1A"),
        OnboardingShopOption(id: "6", name: "Willys Hemma", chain: "WILLYS", distanceKM: 4.6, city: "Alingsås", address: "Bolltorpsvägen 1")
    ]
}
