import Foundation

/// A validated authorization-code callback. Constructed only by
/// `OAuthCallbackValidator`, after the redirect, state, and one-time rules pass.
public struct OAuthCallback: Equatable, Sendable {
    public let code: String
    public let state: String

    public init(code: String, state: String) {
        self.code = code
        self.state = state
    }
}

/// Callback rejection reasons. Every case is a denial; there is no optimistic
/// fallback that accepts an unverified authorization code.
public enum OAuthCallbackError: Error, Equatable, Sendable {
    case invalidRedirectURI
    case missingState
    case stateMismatch
    case replayedCallback
    case expiredTransaction
    case duplicateState
    case unexpectedScheme(String)
    case unexpectedHost(String)
    case unexpectedPath(String)
    case unexpectedPort(Int?)
    case authorizationDenied(String?)
    case missingCode
    case duplicateCode
}

/// Validates the untrusted browser callback against a pending transaction.
///
/// Rules enforced before any token exchange:
/// - the state nonce must match a pending transaction,
/// - the callback scheme, host, port, and path must equal the registered
///   redirect URI exactly,
/// - the transaction must be recent (default ten minutes),
/// - authorization errors are surfaced as typed denials,
/// - both the state and the authorization code are single-use.
public struct OAuthCallbackValidator: Sendable {
    private var pending: [String: OAuthTransaction] = [:]
    private var consumedStates: Set<String> = []
    private var consumedCodes: Set<String> = []

    public let maximumTransactionAge: TimeInterval

    public init(maximumTransactionAge: TimeInterval = 600) {
        self.maximumTransactionAge = maximumTransactionAge
    }

    /// Registers a transaction so its state can be matched exactly once.
    public mutating func register(_ transaction: OAuthTransaction) throws {
        guard pending[transaction.state] == nil,
              !consumedStates.contains(transaction.state) else {
            throw OAuthCallbackError.duplicateState
        }
        pending[transaction.state] = transaction
    }

    /// Consumes a callback URL. On success the transaction and its code are
    /// retired, so a repeated callback is rejected.
    public mutating func consume(
        _ callbackURL: URL,
        at now: Date = Date()
    ) throws -> OAuthCallback {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw OAuthCallbackError.invalidRedirectURI
        }
        let items = components.queryItems ?? []
        func parameter(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard let state = parameter("state"), !state.isEmpty else {
            throw OAuthCallbackError.missingState
        }
        if consumedStates.contains(state) {
            throw OAuthCallbackError.replayedCallback
        }
        guard let transaction = pending[state] else {
            throw OAuthCallbackError.stateMismatch
        }

        try OAuthCallbackValidator.validateRedirect(callbackURL, matches: transaction.redirectURI)

        let age = now.timeIntervalSince(transaction.createdAt)
        guard age <= maximumTransactionAge, age >= 0 else {
            throw OAuthCallbackError.expiredTransaction
        }

        if let error = parameter("error") {
            throw OAuthCallbackError.authorizationDenied(parameter("error_description") ?? error)
        }

        guard let code = parameter("code"), !code.isEmpty else {
            throw OAuthCallbackError.missingCode
        }
        guard !consumedCodes.contains(code) else {
            throw OAuthCallbackError.duplicateCode
        }

        pending.removeValue(forKey: state)
        consumedStates.insert(state)
        consumedCodes.insert(code)
        return OAuthCallback(code: code, state: state)
    }

    /// Single-transaction convenience used when the caller already holds the
    /// pending transaction. It is not a replay cache; use `consume` for that.
    public static func validate(
        _ callbackURL: URL,
        against transaction: OAuthTransaction,
        at now: Date = Date(),
        maximumAge: TimeInterval = 600
    ) throws -> OAuthCallback {
        var validator = OAuthCallbackValidator(maximumTransactionAge: maximumAge)
        try validator.register(transaction)
        return try validator.consume(callbackURL, at: now)
    }

    private static func validateRedirect(_ callbackURL: URL, matches expected: URL) throws {
        guard let expectedScheme = expected.scheme?.lowercased(), !expectedScheme.isEmpty else {
            throw OAuthCallbackError.invalidRedirectURI
        }
        let receivedScheme = callbackURL.scheme?.lowercased() ?? ""
        guard receivedScheme == expectedScheme else {
            throw OAuthCallbackError.unexpectedScheme(receivedScheme)
        }

        let expectedHost = expected.host?.lowercased() ?? ""
        let receivedHost = callbackURL.host?.lowercased() ?? ""
        guard receivedHost == expectedHost else {
            throw OAuthCallbackError.unexpectedHost(receivedHost)
        }

        guard callbackURL.port == expected.port else {
            throw OAuthCallbackError.unexpectedPort(callbackURL.port)
        }

        guard callbackURL.path == expected.path else {
            throw OAuthCallbackError.unexpectedPath(callbackURL.path)
        }
    }
}
