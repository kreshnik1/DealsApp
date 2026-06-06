import Foundation

struct AppServices {
    let apiClient: APIClient
    let deals: DealsService
    let stores: StoresService

    init(
        configuration: APIConfiguration = .default,
        session: URLSession = .shared
    ) {
        let client = APIClient(configuration: configuration, session: session)
        self.apiClient = client
        self.deals = DealsService(client: client)
        self.stores = StoresService(client: client)
    }
}

extension AppServices {
    static let live = AppServices()
}
