import Foundation

protocol DealsServicing {
    func fetchDeals(_ query: DealsQuery) async throws -> [DealDTO]
    func fetchCompanyDeals(companySlug: String, query: CompanyDealsQuery) async throws -> [DealDTO]
    func fetchStoreDeals(companySlug: String, storeID: Int, query: StoreDealsQuery) async throws -> [DealDTO]
    func fetchDeal(id: Int) async throws -> DealDTO
}
