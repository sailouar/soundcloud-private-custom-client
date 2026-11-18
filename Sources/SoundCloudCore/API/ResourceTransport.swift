import Foundation

/// Sends a fully-built, authenticated URLRequest. Unlike the fixture-level
/// `HTTPTransport` (method + path only), this is the live resource transport:
/// it carries the OAuth header, query items, and HTTP body.
public protocol ResourceTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

/// Supplies the current access token. Implementations must refresh or fail
/// explicitly; an empty token is rejected downstream by
/// `APIEndpoint.urlRequest(accessToken:)`.
public protocol AccessTokenProvider: Sendable {
    func currentAccessToken() async throws -> String
}

/// Error payload used by the resource client when a non-2xx body carries a
/// JSON `errors`/`message` field.
public struct APIErrorPayload: Decodable, Sendable {
    public let message: String?
    public let errors: [APIErrorItem]?

    public init(message: String? = nil, errors: [APIErrorItem]? = nil) {
        self.message = message
        self.errors = errors
    }
}

public struct APIErrorItem: Decodable, Sendable {
    public let message: String?

    public init(message: String? = nil) {
        self.message = message
    }
}
