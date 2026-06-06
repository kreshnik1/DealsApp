import Foundation

protocol StoresServicing {
    func fetchStores(_ query: StoresQuery) async throws -> [StoreDTO]
    func fetchCompanyStores(companySlug: String, query: CompanyStoresQuery) async throws -> [StoreDTO]
    func fetchFlyers(_ query: FlyersQuery) async throws -> [FlyerDTO]
    func fetchStoreFlyers(companySlug: String, storeID: Int, query: StoreFlyersQuery) async throws -> [FlyerDTO]
}
