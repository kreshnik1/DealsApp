import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(underlying: Error)
    case unexpectedStatusCode(Int, detail: String?)
    case decodingFailed(underlying: Error, responseBody: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .requestFailed(underlying):
            return Self.describeRequestFailure(underlying)
        case let .unexpectedStatusCode(statusCode, detail):
            return detail ?? "The server returned status code \(statusCode)."
        case let .decodingFailed(underlying, responseBody):
            return Self.describeDecodingFailure(underlying, responseBody: responseBody)
        }
    }
}

private extension APIError {
    static func describeRequestFailure(_ underlying: Error) -> String {
        let nsError = underlying as NSError
        var parts = [nsError.localizedDescription]

        if let reason = nsError.localizedFailureReason, reason.isEmpty == false, reason != nsError.localizedDescription {
            parts.append(reason)
        }

        if let networkPath = nsError.userInfo["_NSURLErrorNWPathKey"] as? String, networkPath.isEmpty == false {
            parts.append(networkPath)
        }

        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            parts.append("URL: \(failingURL.absoluteString)")
        }

        return parts.joined(separator: "\n")
    }

    static func describeDecodingFailure(_ underlying: Error, responseBody: String?) -> String {
        let message: String

        switch underlying {
        case let DecodingError.keyNotFound(key, context):
            let path = codingPathString(context.codingPath)
            message = "Missing key '\(key.stringValue)' at \(path). \(context.debugDescription)"
        case let DecodingError.typeMismatch(type, context):
            let path = codingPathString(context.codingPath)
            message = "Type mismatch for \(type) at \(path). \(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            let path = codingPathString(context.codingPath)
            message = "Missing value for \(type) at \(path). \(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            let path = codingPathString(context.codingPath)
            message = "Data corrupted at \(path). \(context.debugDescription)"
        default:
            message = underlying.localizedDescription
        }

        guard let responseBody, responseBody.isEmpty == false else {
            return "Failed to decode server response.\n\(message)"
        }

        return "Failed to decode server response.\n\(message)\nResponse preview: \(responseBody)"
    }

    static func codingPathString(_ codingPath: [CodingKey]) -> String {
        guard codingPath.isEmpty == false else {
            return "root"
        }

        return codingPath.map(\.stringValue).joined(separator: ".")
    }
}
