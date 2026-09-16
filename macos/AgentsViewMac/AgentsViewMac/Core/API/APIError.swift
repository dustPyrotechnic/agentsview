import Foundation

/// Errors that can occur during API operations
public enum APIError: Error, LocalizedError {
    case networkError(String)
    case decodingError(String)
    case serverError(Int, String)
    case invalidResponse
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}
