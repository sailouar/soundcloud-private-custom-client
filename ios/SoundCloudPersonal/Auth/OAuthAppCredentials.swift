import Foundation
import SoundCloudCore

/// OAuth application credentials for this personal build. They are entered in
/// the app, stored in the device Keychain, and never committed to source
/// control or baked into a build configuration.
struct OAuthAppCredentials: Codable, Equatable, Sendable {
    let clientID: String
    let clientSecret: String
}

/// Problems that make the installed build unusable before any network call.
enum AppConfigurationError: Error, Equatable {
    case missingURLScheme
    case malformedRedirectURI
}

extension AppConfigurationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingURLScheme:
            return "This build does not declare the soundcloudpersonal URL scheme in Info.plist."
        case .malformedRedirectURI:
            return "The registered redirect address could not be built from the URL scheme."
        }
    }
}

/// Bridges stored credentials and the URL scheme declared in `Info.plist`, so
/// the redirect URI in the authorization request always matches the scheme the
/// app is registered to receive.
enum AppOAuthConfiguration {
    static let callbackHost = "oauth"
    static let callbackPath = "/callback"

    static func redirectURI(bundle: Bundle = .main) throws -> URL {
        guard
            let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
            let schemes = types.compactMap({ $0["CFBundleURLSchemes"] as? [String] }).first,
            let scheme = schemes.first(where: { !$0.isEmpty })
        else {
            throw AppConfigurationError.missingURLScheme
        }

        guard let url = URL(string: "\(scheme)://\(callbackHost)\(callbackPath)") else {
            throw AppConfigurationError.malformedRedirectURI
        }
        return url
    }

    static func configuration(
        for credentials: OAuthAppCredentials,
        bundle: Bundle = .main
    ) throws -> OAuthConfiguration {
        let redirectURI = try redirectURI(bundle: bundle)
        return try OAuthConfiguration(
            clientID: credentials.clientID,
            redirectURI: redirectURI,
            clientSecret: credentials.clientSecret
        )
    }
}
