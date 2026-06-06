import Foundation

struct APIConfiguration {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

extension APIConfiguration {
    static let `default` = APIConfiguration(
        baseURL: URL(
            string: ProcessInfo.processInfo.environment["DEALSAPP_API_BASE_URL"] ?? "http://127.0.0.1:8000"
        )!
    )
}
