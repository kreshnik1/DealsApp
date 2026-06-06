import Foundation

struct StoresService: StoresServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchStores(_ query: StoresQuery = StoresQuery()) async throws -> [StoreDTO] {
        try await client.send(.listStores(query))
    }

    func fetchCompanyStores(
        companySlug: String,
        query: CompanyStoresQuery = CompanyStoresQuery()
    ) async throws -> [StoreDTO] {
        try await client.send(.listCompanyStores(companySlug: companySlug, query: query))
    }

    func fetchFlyers(_ query: FlyersQuery) async throws -> [FlyerDTO] {
        try await client.send(.listFlyers(query))
    }

    func fetchStoreFlyers(
        companySlug: String,
        storeID: Int,
        query: StoreFlyersQuery = StoreFlyersQuery()
    ) async throws -> [FlyerDTO] {
        try await client.send(.listStoreFlyers(companySlug: companySlug, storeID: storeID, query: query))
    }
}
