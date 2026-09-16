import Foundation

/// Protocol for API client to allow testing with mock implementations
protocol APIClientProtocol: Sendable {
    /// Fetch usage summary for a date range
    ///
    /// - Parameters:
    ///   - from: Start date in ISO 8601 format (YYYY-MM-DD)
    ///   - to: End date in ISO 8601 format (YYYY-MM-DD)
    ///   - timezone: IANA timezone identifier (e.g., "America/New_York")
    /// - Returns: Usage summary response
    /// - Throws: APIError if the request fails
    func fetchUsageSummary(from: String, to: String, timezone: String) async throws -> UsageSummaryResponse
}

/// Production API client that communicates with the Go sidecar
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    
    public init(baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    public func fetchUsageSummary(from: String, to: String, timezone: String) async throws -> UsageSummaryResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/usage/summary"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "timezone", value: timezone)
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, message)
            }
            
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(UsageSummaryResponse.self, from: data)
            } catch {
                throw APIError.decodingError(error.localizedDescription)
            }
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}
