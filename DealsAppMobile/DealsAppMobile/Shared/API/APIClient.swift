import Foundation

struct APIClient {
    let configuration: APIConfiguration
    let session: URLSession

    init(
        configuration: APIConfiguration = .default,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func send<Response: Decodable>(_ endpoint: APIEndpoint, as responseType: Response.Type = Response.self) async throws -> Response {
        let request = try endpoint.makeRequest(baseURL: configuration.baseURL)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.requestFailed(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.unexpectedStatusCode(httpResponse.statusCode, detail: errorResponse?.detail)
        }

        do {
            return try Self.makeDecoder().decode(responseType, from: data)
        } catch {
            throw APIError.decodingFailed(
                underlying: error,
                responseBody: Self.responsePreview(from: data)
            )
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeDate)
        return decoder
    }

    private static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter.standard.date(from: value) {
            return date
        }

        if let date = DateFormatter.backendFractionalSecondsUTC.date(from: value) {
            return date
        }

        if let date = DateFormatter.backendStandardUTC.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date string: \(value)"
        )
    }

    private static func responsePreview(from data: Data) -> String? {
        guard data.isEmpty == false else {
            return nil
        }

        let previewData = data.prefix(500)
        guard var string = String(data: previewData, encoding: .utf8) else {
            return "Non-UTF8 response (\(data.count) bytes)"
        }

        if data.count > previewData.count {
            string += "..."
        }

        return string.replacingOccurrences(of: "\n", with: " ")
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension DateFormatter {
    static let backendFractionalSecondsUTC: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let backendStandardUTC: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
