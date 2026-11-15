import Foundation

/// Configuration failures for the documented SoundCloud authorization-code flow.
public enum OAuthConfigurationError: Error, Equatable, Sendable {
    case emptyClientID
    case redirectMustBeAbsolute
    case redirectMustUseCustomScheme
    case redirectMustNotContainUserInfo
    case redirectMustNotContainFragment
    case redirectMismatch
    case invalidAuthorizationRequest
}

/// The official OAuth 2.1 + PKCE contract.
///
/// Hosts and parameter names follow the SoundCloud API Guide and OpenAPI
/// document (accessed 2026-11-15):
/// - authorization: `https://secure.soundcloud.com/authorize`
/// - token/refresh: `https://secure.soundcloud.com/oauth/token`
/// - API base: `https://api.soundcloud.com`
///
/// Mobile clients must register a custom protocol redirect URI. The client
/// secret is supplied from build configuration and is never committed or
/// logged; `description` redacts it.
public struct OAuthConfiguration: Equatable, Sendable {
    public static let authorizationEndpoint = URL(string: "https://secure.soundcloud.com/authorize")!
    public static let tokenEndpoint = URL(string: "https://secure.soundcloud.com/oauth/token")!
    public static let apiBaseURL = URL(string: "https://api.soundcloud.com")!

    public let clientID: String
    public let clientSecret: String?
    public let redirectURI: URL
    public let scopes: [String]

    /// Creates a validated configuration. `clientSecret` must come from
    /// deployment configuration; an empty value is treated as absent.
    public init(
        clientID: String,
        redirectURI: URL,
        clientSecret: String? = nil,
        scopes: [String] = []
    ) throws {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedClientID.isEmpty else {
            throw OAuthConfigurationError.emptyClientID
        }

        guard let scheme = redirectURI.scheme?.lowercased(), !scheme.isEmpty else {
            throw OAuthConfigurationError.redirectMustBeAbsolute
        }
        guard scheme != "https", scheme != "http" else {
            throw OAuthConfigurationError.redirectMustUseCustomScheme
        }
        guard redirectURI.host?.isEmpty == false else {
            throw OAuthConfigurationError.redirectMustBeAbsolute
        }
        guard redirectURI.user == nil, redirectURI.password == nil else {
            throw OAuthConfigurationError.redirectMustNotContainUserInfo
        }
        guard redirectURI.fragment == nil else {
            throw OAuthConfigurationError.redirectMustNotContainFragment
        }

        let trimmedSecret = clientSecret?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientID = trimmedClientID
        self.clientSecret = (trimmedSecret?.isEmpty ?? true) ? nil : trimmedSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
    }

    /// Creates a one-time OAuth transaction bound to this configuration's
    /// registered redirect URI.
    public func makeTransaction(
        hashing: any PKCEHashing,
        random: any SecureRandomSource = SystemSecureRandomSource(),
        now: Date = Date()
    ) throws -> OAuthTransaction {
        let verifier = PKCE.makeVerifier(random: random)
        let state = PKCE.makeState(random: random)
        let challenge = try PKCE.challenge(for: verifier, hashing: hashing)
        return OAuthTransaction(
            state: state,
            codeVerifier: verifier,
            codeChallenge: challenge,
            redirectURI: redirectURI,
            createdAt: now
        )
    }

    /// Builds the documented authorization URL, including the S256 challenge,
    /// the exact registered redirect URI, and the mobile `display=popup` hint.
    public func authorizationURL(for transaction: OAuthTransaction) throws -> URL {
        guard transaction.redirectURI == redirectURI else {
            throw OAuthConfigurationError.redirectMismatch
        }
        guard PKCE.isValidVerifier(transaction.codeVerifier) else {
            throw OAuthConfigurationError.invalidAuthorizationRequest
        }

        var components = URLComponents(
            url: OAuthConfiguration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: transaction.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: transaction.state),
            URLQueryItem(name: "display", value: "popup")
        ]

        guard let url = components?.url else {
            throw OAuthConfigurationError.invalidAuthorizationRequest
        }
        return url
    }
}

extension OAuthConfiguration: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "OAuthConfiguration(clientID: \(clientID), clientSecret: <redacted>, redirectURI: \(redirectURI.absoluteString))"
    }

    public var debugDescription: String { description }
}

/// One authorization attempt. It is retained only long enough to validate the
/// callback and exchange the one-time code.
public struct OAuthTransaction: Equatable, Sendable {
    public let state: String
    public let codeVerifier: String
    public let codeChallenge: String
    public let redirectURI: URL
    public let createdAt: Date

    public init(
        state: String,
        codeVerifier: String,
        codeChallenge: String,
        redirectURI: URL,
        createdAt: Date
    ) {
        self.state = state
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
        self.redirectURI = redirectURI
        self.createdAt = createdAt
    }
}

/// The URL to open in the system browser plus the transaction it belongs to.
public struct OAuthAuthorizationRequest: Equatable, Sendable {
    public let transaction: OAuthTransaction
    public let url: URL

    public init(transaction: OAuthTransaction, url: URL) {
        self.transaction = transaction
        self.url = url
    }
}
