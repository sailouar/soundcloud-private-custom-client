import Foundation

/// Secure session storage boundary. The Phase 2 adapter is Keychain-backed; the
/// core never touches plaintext files, `UserDefaults`, or the Security framework.
///
/// `save` replaces the single stored record so a consumed single-use refresh
/// token is not retained alongside its replacement.
public protocol TokenStore: Sendable {
    func load() async throws -> TokenBundle?
    func save(_ bundle: TokenBundle) async throws
    func delete() async throws
}
