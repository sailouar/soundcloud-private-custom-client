import Foundation

/// Token contract failures. Nothing in this file accepts a SoundCloud password.
public enum TokenError: Error, Equatable, Sendable {
    case missingAccessToken
    case missingRefreshToken
    case nonPositiveExpiry
}

/// One user session. The access token and the single-use refresh token are one
/// logical record so a refresh replaces both atomically.
public struct TokenBundle: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let scope: String?
    public let expiresAt: Date

    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "OAuth",
        scope: String? = nil,
        expiresAt: Date
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.scope = scope
        self.expiresAt = expiresAt
    }

    public var isUsable: Bool {
        !accessToken.isEmpty && !refreshToken.isEmpty
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        date >= expiresAt
    }

    /// Access tokens expire after approximately one hour, so refresh shortly
    /// before expiry instead of waiting for a 401.
    public func needsRefresh(at date: Date = Date(), leeway: TimeInterval = 60) -> Bool {
        date.addingTimeInterval(leeway) >= expiresAt
    }
}

extension TokenBundle: CustomStringConvertible, CustomDebugStringConvertible {
    /// Token material must never reach logs or fixture text.
    public var description: String {
        "TokenBundle(accessToken: <redacted>, refreshToken: <redacted>, tokenType: \(tokenType), scope: \(scope ?? "none"), expiresAt: \(expiresAt.timeIntervalSince1970))"
    }

    public var debugDescription: String { description }
}

/// Decoded token endpoint payload. Field names follow the official token
/// response: `access_token`, `refresh_token`, `expires_in`, `scope`.
public struct OAuthTokenResponse: Decodable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let scope: String?
    public let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }

    public init(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        scope: String? = nil,
        tokenType: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.scope = scope
        self.tokenType = tokenType
    }

    /// Converts a response into the persisted record. The previous refresh token
    /// is never carried over: SoundCloud refresh tokens are single-use.
    public func bundle(receivedAt: Date = Date()) throws -> TokenBundle {
        guard !accessToken.isEmpty else { throw TokenError.missingAccessToken }
        guard !refreshToken.isEmpty else { throw TokenError.missingRefreshToken }
        guard expiresIn > 0 else { throw TokenError.nonPositiveExpiry }
        return TokenBundle(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType ?? "OAuth",
            scope: scope,
            expiresAt: receivedAt.addingTimeInterval(TimeInterval(expiresIn))
        )
    }
}

/// Time boundary so expiry and transaction-age tests are deterministic.
public protocol DateProviding: Sendable {
    var now: Date { get }
}

public struct SystemDateProvider: DateProviding {
    public init() {}
    public var now: Date { Date() }
}
