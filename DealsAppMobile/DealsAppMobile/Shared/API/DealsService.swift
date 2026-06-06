import Foundation

struct DealsService: DealsServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchDeals(_ query: DealsQuery = DealsQuery()) async throws -> [DealDTO] {
        try await client.send(.listDeals(query))
    }

    func fetchCompanyDeals(
        companySlug: String,
        query: CompanyDealsQuery = CompanyDealsQuery()
    ) async throws -> [DealDTO] {
        try await client.send(.listCompanyDeals(companySlug: companySlug, query: query))
    }

    func fetchStoreDeals(
        companySlug: String,
        storeID: Int,
        query: StoreDealsQuery = StoreDealsQuery()
    ) async throws -> [DealDTO] {
        try await client.send(.listStoreDeals(companySlug: companySlug, storeID: storeID, query: query))
    }

    func fetchDeal(id: Int) async throws -> DealDTO {
        try await client.send(.getDeal(id: id))
    }
}
