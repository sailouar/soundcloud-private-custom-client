import Foundation

public enum APIError: Error, Equatable, Sendable {
    case transport(String)
    case httpStatus(Int, message: String?)
    case invalidResponse
    case decoding(String)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .transport(let message):
            return message
        case .httpStatus(let status, let message):
            return message.map { "HTTP \(status): \($0)" } ?? "HTTP \(status)"
        case .invalidResponse:
            return "The API response was invalid."
        case .decoding(let message):
            return "The API response could not be decoded: \(message)"
        }
    }
}
