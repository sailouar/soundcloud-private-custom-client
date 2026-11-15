import Foundation
import Security
import SoundCloudCore

struct KeychainError: Error, Equatable {
    let status: OSStatus
}

extension KeychainError: LocalizedError {
    var errorDescription: String? {
        "The Keychain returned status \(status)."
    }
}

/// Single generic-password record helpers. Every call targets one service and
/// account pair; no session material is written to files or `UserDefaults`.
enum KeychainRecord {
    static func load(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError(status: errSecDecode)
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    static func save(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Update first so a stored record is replaced in one item, not
        // duplicated. A missing record falls through to an insertion.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var insertion = query
        attributes.forEach { insertion[$0.key] = $0.value }
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

/// Keychain-backed `TokenStore`. The record is one JSON value so the access
/// token and its single-use refresh token are replaced together.
struct KeychainTokenStore: TokenStore {
    let service: String
    let account: String

    init(
        service: String = "com.personal.SoundCloudPersonal",
        account: String = "oauth-session"
    ) {
        self.service = service
        self.account = account
    }

    func load() async throws -> TokenBundle? {
        guard let data = try KeychainRecord.load(service: service, account: account) else {
            return nil
        }
        return try JSONDecoder().decode(SessionRecord.self, from: data).bundle
    }

    func save(_ bundle: TokenBundle) async throws {
        let data = try JSONEncoder().encode(SessionRecord(bundle))
        try KeychainRecord.save(data, service: service, account: account)
    }

    func delete() async throws {
        try KeychainRecord.delete(service: service, account: account)
    }

    private struct SessionRecord: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let scope: String?
        let expiresAt: Date

        init(_ bundle: TokenBundle) {
            accessToken = bundle.accessToken
            refreshToken = bundle.refreshToken
            tokenType = bundle.tokenType
            scope = bundle.scope
            expiresAt = bundle.expiresAt
        }

        var bundle: TokenBundle {
            TokenBundle(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: tokenType,
                scope: scope,
                expiresAt: expiresAt
            )
        }
    }
}

/// Keychain-backed storage for the personal OAuth application credentials.
/// Signing out removes the session but keeps these so re-authenticating does
/// not require retyping the secret.
struct AppCredentialStore {
    let service: String
    let account: String

    init(
        service: String = "com.personal.SoundCloudPersonal",
        account: String = "oauth-app-credentials"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> OAuthAppCredentials? {
        guard let data = try KeychainRecord.load(service: service, account: account) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthAppCredentials.self, from: data)
    }

    func save(_ credentials: OAuthAppCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try KeychainRecord.save(data, service: service, account: account)
    }

    func delete() throws {
        try KeychainRecord.delete(service: service, account: account)
    }
}
