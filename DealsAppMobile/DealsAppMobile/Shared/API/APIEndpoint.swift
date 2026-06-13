import Foundation

enum APIEndpoint {
    case listDeals(DealsQuery)
    case listCompanyDeals(companySlug: String, query: CompanyDealsQuery)
    case listStoreDeals(companySlug: String, storeID: Int, query: StoreDealsQuery)
    case getDeal(id: Int)
    case listStores(StoresQuery)
    case listNearbyStores(NearbyStoresQuery)
    case listCompanyStores(companySlug: String, query: CompanyStoresQuery)
    case listFlyers(FlyersQuery)
    case listStoreFlyers(companySlug: String, storeID: Int, query: StoreFlyersQuery)

    var method: HTTPMethod {
        .get
    }

    func makeRequest(baseURL: URL) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        let items = queryItems
        if items.isEmpty == false {
            components.queryItems = items
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private var path: String {
        switch self {
        case .listDeals:
            return "deals/"
        case let .listCompanyDeals(companySlug, _):
            return "deals/\(companySlug)"
        case let .listStoreDeals(companySlug, storeID, _):
            return "deals/\(companySlug)/\(storeID)"
        case let .getDeal(id):
            return "deals/by-id/\(id)"
        case .listStores:
            return "stores/"
        case .listNearbyStores:
            return "stores/nearby"
        case let .listCompanyStores(companySlug, _):
            return "stores/\(companySlug)"
        case .listFlyers:
            return "stores/flyers"
        case let .listStoreFlyers(companySlug, storeID, _):
            return "stores/\(companySlug)/\(storeID)/flyers"
        }
    }

    private var queryItems: [URLQueryItem] {
        let items: [URLQueryItem?]

        switch self {
        case let .listDeals(query):
            items = [
                queryItem(named: "search", value: query.search),
                queryItem(named: "chain", value: query.chain),
                queryItem(named: "category", value: query.category),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ] + query.storeIDs.map { queryItem(named: "store_id", value: $0) }
        case let .listCompanyDeals(_, query):
            items = [
                queryItem(named: "search", value: query.search),
                queryItem(named: "chain", value: query.chain),
                queryItem(named: "category", value: query.category),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        case let .listStoreDeals(_, _, query):
            items = [
                queryItem(named: "search", value: query.search),
                queryItem(named: "category", value: query.category),
                queryItem(named: "hydrate_if_empty", value: query.hydrateIfEmpty),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        case .getDeal:
            items = []
        case let .listStores(query):
            items = [
                queryItem(named: "chain", value: query.chain)
            ]
        case let .listNearbyStores(query):
            items = [
                queryItem(named: "latitude", value: query.latitude),
                queryItem(named: "longitude", value: query.longitude),
                queryItem(named: "limit", value: query.limit)
            ]
        case let .listCompanyStores(_, query):
            items = [
                queryItem(named: "chain", value: query.chain),
                queryItem(named: "limit", value: query.limit)
            ]
        case let .listFlyers(query):
            items = [
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ] + query.storeIDs.map { queryItem(named: "store_id", value: $0) }
        case let .listStoreFlyers(_, _, query):
            items = [
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        }

        return items.compactMap { $0 }
    }

    private func queryItem(named name: String, value: String?) -> URLQueryItem? {
        guard let value, value.isEmpty == false else {
            return nil
        }

        return URLQueryItem(name: name, value: value)
    }

    private func queryItem(named name: String, value: Int) -> URLQueryItem? {
        URLQueryItem(name: name, value: String(value))
    }

    private func queryItem(named name: String, value: Int?) -> URLQueryItem? {
        guard let value else {
            return nil
        }

        return URLQueryItem(name: name, value: String(value))
    }

    private func queryItem(named name: String, value: Double) -> URLQueryItem? {
        URLQueryItem(name: name, value: String(value))
    }

    private func queryItem(named name: String, value: Bool) -> URLQueryItem? {
        URLQueryItem(name: name, value: value ? "true" : "false")
    }
}
