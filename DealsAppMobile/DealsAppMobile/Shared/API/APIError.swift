import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(underlying: Error)
    case unexpectedStatusCode(Int, detail: String?)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .requestFailed(underlying):
            return underlying.localizedDescription
        case let .unexpectedStatusCode(statusCode, detail):
            return detail ?? "The server returned status code \(statusCode)."
        case let .decodingFailed(underlying):
            return "Failed to decode server response: \(underlying.localizedDescription)"
        }
    }
}
