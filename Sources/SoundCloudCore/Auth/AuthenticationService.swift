import Foundation

/// Network boundary for the authorization server. `URLSession` implements this
/// in the app adapter; tests supply a recording fake.
public protocol OAuthTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

/// Authentication failures. Only documented OAuth mechanics are represented;
/// there is no password grant and no implicit fallback.
public enum AuthenticationError: Error, Equatable, Sendable {
    case missingClientSecret
    case notAuthenticated
    case invalidTokenBundle
    case stateMismatch
    case transport(String)
    case httpStatus(Int, message: String?)
    case invalidTokenResponse(String)
}

/// Orchestrates the documented authorization-code + PKCE flow:
/// begin -> browser -> validated callback -> token exchange -> stored bundle.
///
/// Refresh tokens are single-use, so every refresh loads the current record,
/// exchanges it, and saves the complete replacement record.
public struct AuthenticationService: Sendable {
    public let configuration: OAuthConfiguration

    private let transport: any OAuthTransport
    private let store: any TokenStore
    private let hashing: any PKCEHashing
    private let random: any SecureRandomSource
    private let clock: any DateProviding

    public init(
        configuration: OAuthConfiguration,
        transport: any OAuthTransport,
        store: any TokenStore,
        hashing: any PKCEHashing,
        random: any SecureRandomSource = SystemSecureRandomSource(),
        clock: any DateProviding = SystemDateProvider()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.store = store
        self.hashing = hashing
        self.random = random
        self.clock = clock
    }

    /// Creates a fresh PKCE transaction and the official authorization URL.
    public func beginSignIn(now: Date? = nil) throws -> OAuthAuthorizationRequest {
        let transaction = try configuration.makeTransaction(
            hashing: hashing,
            random: random,
            now: now ?? clock.now
        )
        return OAuthAuthorizationRequest(
            transaction: transaction,
            url: try configuration.authorizationURL(for: transaction)
        )
    }

    /// Exchanges an already validated one-time code for the first token bundle.
    public func completeSignIn(
        callback: OAuthCallback,
        transaction: OAuthTransaction,
        now: Date? = nil
    ) async throws -> TokenBundle {
        guard callback.state == transaction.state else {
            throw AuthenticationError.stateMismatch
        }

        let request = try tokenRequest(parameters: [
            ("grant_type", "authorization_code"),
            ("client_id", configuration.clientID),
            ("client_secret", try clientSecret()),
            ("redirect_uri", configuration.redirectURI.absoluteString),
            ("code_verifier", transaction.codeVerifier),
            ("code", callback.code)
        ])

        let bundle = try await tokenBundle(from: request, receivedAt: now ?? clock.now)
        try await store.save(bundle)
        return bundle
    }

    /// Loads the stored session and refreshes it when it is about to expire.
    public func restoreSession(now: Date? = nil) async throws -> TokenBundle? {
        let date = now ?? clock.now
        guard let bundle = try await store.load() else {
            return nil
        }
        guard bundle.isUsable else {
            throw AuthenticationError.invalidTokenBundle
        }
        if bundle.needsRefresh(at: date) {
            return try await refreshSession(now: date)
        }
        return bundle
    }

    /// Replaces the stored bundle using the single-use refresh token.
    public func refreshSession(now: Date? = nil) async throws -> TokenBundle {
        guard let current = try await store.load() else {
            throw AuthenticationError.notAuthenticated
        }
        guard !current.refreshToken.isEmpty else {
            throw AuthenticationError.invalidTokenBundle
        }

        let request = try tokenRequest(parameters: [
            ("grant_type", "refresh_token"),
            ("client_id", configuration.clientID),
            ("client_secret", try clientSecret()),
            ("refresh_token", current.refreshToken)
        ])

        let replacement = try await tokenBundle(from: request, receivedAt: now ?? clock.now)
        // One logical record: the consumed refresh token is not retained.
        try await store.save(replacement)
        return replacement
    }

    /// Explicit local sign-out. `POST /disconnect` remains an API operation so
    /// a failed network call cannot leave a stale session on the device.
    public func signOut() async throws {
        try await store.delete()
    }

    public func storedBundle() async throws -> TokenBundle? {
        try await store.load()
    }

    private func tokenBundle(from request: URLRequest, receivedAt: Date) async throws -> TokenBundle {
        let response = try await send(request)
        do {
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: response.body)
            return try tokenResponse.bundle(receivedAt: receivedAt)
        } catch let error as TokenError {
            throw AuthenticationError.invalidTokenResponse(String(describing: error))
        } catch {
            throw AuthenticationError.invalidTokenResponse(error.localizedDescription)
        }
    }

    private func send(_ request: URLRequest) async throws -> HTTPResponse {
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw AuthenticationError.httpStatus(
                response.statusCode,
                message: OAuthErrorEnvelope.message(from: response.body)
            )
        }
        return response
    }

    private func clientSecret() throws -> String {
        guard let secret = configuration.clientSecret, !secret.isEmpty else {
            throw AuthenticationError.missingClientSecret
        }
        return secret
    }

    private func tokenRequest(parameters: [(String, String)]) throws -> URLRequest {
        var request = URLRequest(url: OAuthConfiguration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Data(OAuthForm.encode(parameters).utf8)
        return request
    }
}

/// RFC 6749 token error body. Falls back to the API `message` field.
private struct OAuthErrorEnvelope: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
    }

    static func message(from body: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(OAuthErrorEnvelope.self, from: body) else {
            return nil
        }
        return envelope.errorDescription ?? envelope.error ?? envelope.message
    }
}

/// `application/x-www-form-urlencoded` encoding with deterministic ordering.
enum OAuthForm {
    private static let allowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func encode(_ parameters: [(String, String)]) -> String {
        parameters
            .map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
            .joined(separator: "&")
    }

    static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
