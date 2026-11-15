import Foundation

// User-facing descriptions for the typed core failures. These messages never
// include token values, client secrets, or response bodies.

extension AuthenticationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingClientSecret:
            return "The SoundCloud app client secret is missing. Add it in the app configuration."
        case .notAuthenticated:
            return "No SoundCloud session is stored. Sign in again."
        case .invalidTokenBundle:
            return "The stored SoundCloud session is incomplete. Sign in again."
        case .stateMismatch:
            return "The authorization response did not belong to this sign-in attempt."
        case .transport(let message):
            return "The SoundCloud request failed: \(message)"
        case .httpStatus(let status, let message):
            return message.map { "SoundCloud rejected the request (HTTP \(status)): \($0)" }
                ?? "SoundCloud rejected the request (HTTP \(status))."
        case .invalidTokenResponse(let message):
            return "The token response was not usable: \(message)"
        }
    }
}

extension OAuthCallbackError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRedirectURI:
            return "The sign-in callback address was invalid."
        case .missingState:
            return "The sign-in callback did not include a state value."
        case .stateMismatch:
            return "The sign-in callback state did not match the pending request."
        case .replayedCallback:
            return "This sign-in callback was already used. Start sign-in again."
        case .expiredTransaction:
            return "The sign-in attempt expired. Start sign-in again."
        case .duplicateState:
            return "A sign-in attempt with this state already exists."
        case .unexpectedScheme, .unexpectedHost, .unexpectedPath, .unexpectedPort:
            return "The sign-in callback did not use the registered redirect address."
        case .authorizationDenied(let reason):
            return reason.map { "SoundCloud declined the authorization: \($0)" }
                ?? "SoundCloud declined the authorization."
        case .missingCode:
            return "The sign-in callback did not include an authorization code."
        case .duplicateCode:
            return "This authorization code was already used. Start sign-in again."
        }
    }
}

extension OAuthConfigurationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyClientID:
            return "The SoundCloud client ID is empty."
        case .redirectMustBeAbsolute:
            return "The redirect address must be an absolute custom-scheme URL."
        case .redirectMustUseCustomScheme:
            return "The redirect address must use a custom scheme such as soundcloudpersonal, not http or https."
        case .redirectMustNotContainUserInfo:
            return "The redirect address must not contain a user name or password."
        case .redirectMustNotContainFragment:
            return "The redirect address must not contain a fragment."
        case .redirectMismatch:
            return "The redirect address does not match the configured one."
        case .invalidAuthorizationRequest:
            return "The authorization request could not be built."
        }
    }
}

extension APIEndpointError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingPathParameter(let name):
            return "The API request is missing the path parameter \(name)."
        case .unexpectedPathParameter(let name):
            return "The API request has an unexpected path parameter \(name)."
        case .invalidPathParameter(let name):
            return "The API request has an invalid path parameter \(name)."
        case .invalidQueryParameter(let name):
            return "The API request has an invalid query parameter \(name)."
        case .missingAccessToken:
            return "An access token is required for this API request."
        case .invalidBaseURL:
            return "The API base address is invalid."
        case .insecureBaseURL:
            return "The API base address must use https."
        case .unofficialHost(let host):
            return "\(host.isEmpty ? "The API host" : host) is not an official SoundCloud host."
        }
    }
}

extension TokenError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "The token response did not include an access token."
        case .missingRefreshToken:
            return "The token response did not include a refresh token."
        case .nonPositiveExpiry:
            return "The token response reported an invalid lifetime."
        }
    }
}

extension APIPolicyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let operation):
            return operation.reason
        }
    }
}

extension PKCEError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidVerifierLength:
            return "The PKCE verifier has an invalid length."
        case .invalidVerifierCharacter:
            return "The PKCE verifier contains an unsupported character."
        case .hashingUnavailable(let message):
            return "PKCE hashing is unavailable: \(message)"
        }
    }
}
