import Foundation

enum APIEndpoint {
    case listDeals(DealsQuery)
    case listCompanyDeals(companySlug: String, query: CompanyDealsQuery)
    case listStoreDeals(companySlug: String, storeID: Int, query: StoreDealsQuery)
    case getDeal(id: Int)
    case listStores(StoresQuery)
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
        case let .listCompanyStores(companySlug, _):
            return "stores/\(companySlug)"
        case .listFlyers:
            return "stores/flyers"
        case let .listStoreFlyers(companySlug, storeID, _):
            return "stores/\(companySlug)/\(storeID)/flyers"
        }
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case let .listDeals(query):
            return [
                queryItem(named: "search", value: query.search),
                queryItem(named: "chain", value: query.chain),
                queryItem(named: "category", value: query.category),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ] + query.storeIDs.map { queryItem(named: "store_id", value: $0) }
        case let .listCompanyDeals(_, query):
            return [
                queryItem(named: "search", value: query.search),
                queryItem(named: "chain", value: query.chain),
                queryItem(named: "category", value: query.category),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        case let .listStoreDeals(_, _, query):
            return [
                queryItem(named: "search", value: query.search),
                queryItem(named: "category", value: query.category),
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        case .getDeal:
            return []
        case let .listStores(query):
            return [
                queryItem(named: "chain", value: query.chain)
            ]
        case let .listCompanyStores(_, query):
            return [
                queryItem(named: "chain", value: query.chain)
            ]
        case let .listFlyers(query):
            return [
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ] + query.storeIDs.map { queryItem(named: "store_id", value: $0) }
        case let .listStoreFlyers(_, _, query):
            return [
                queryItem(named: "limit", value: query.limit),
                queryItem(named: "offset", value: query.offset)
            ]
        }
        .compactMap { $0 }
    }

    private func queryItem(named name: String, value: String?) -> URLQueryItem? {
        guard let value, value.isEmpty == false else {
            return nil
        }

        return URLQueryItem(name: name, value: value)
    }

    private func queryItem(named name: String, value: Int) -> URLQueryItem {
        URLQueryItem(name: name, value: String(value))
    }
}
