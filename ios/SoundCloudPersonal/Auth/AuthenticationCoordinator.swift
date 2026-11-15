import AuthenticationServices
import Combine
import Foundation
import SoundCloudCore

/// Drives the personal sign-in experience: app credentials, the browser
/// authorization session, Keychain-backed session restore, and sign-out.
@MainActor
final class AuthenticationCoordinator: ObservableObject {
    enum State: Equatable {
        case needsConfiguration
        case restoring
        case signedOut
        case authorizing
        case signedIn
        case failed(String)
    }

    @Published private(set) var state: State = .needsConfiguration
    @Published var clientIDInput: String = ""
    @Published var clientSecretInput: String = ""

    private let credentialStore: AppCredentialStore
    private let tokenStore: any TokenStore
    private let transport: any OAuthTransport
    private let browser: BrowserAuthenticator

    private var configuration: OAuthConfiguration?
    private var service: AuthenticationService?
    private var validator = OAuthCallbackValidator()

    init(
        credentialStore: AppCredentialStore,
        tokenStore: any TokenStore,
        transport: any OAuthTransport
    ) {
        self.credentialStore = credentialStore
        self.tokenStore = tokenStore
        self.transport = transport
        self.browser = BrowserAuthenticator()
    }

    static func live() -> AuthenticationCoordinator {
        AuthenticationCoordinator(
            credentialStore: AppCredentialStore(),
            tokenStore: KeychainTokenStore(),
            transport: URLSessionOAuthTransport()
        )
    }

    var canSaveConfiguration: Bool {
        !clientIDInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientSecretInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Restores the Keychain-backed session on launch, refreshing it if needed.
    func start() async {
        state = .restoring
        do {
            guard let credentials = try credentialStore.load() else {
                state = .needsConfiguration
                return
            }
            clientIDInput = credentials.clientID
            try configure(with: credentials)

            let bundle = try await service?.restoreSession()
            state = bundle == nil ? .signedOut : .signedIn
        } catch let error as AuthenticationError {
            if Self.isUnrecoverableSession(error) {
                // The stored grant is expired or rejected; drop it and let the
                // owner sign in again instead of retrying the same record.
                try? await tokenStore.delete()
                state = .signedOut
            } else {
                state = .failed(Self.message(for: error))
            }
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Validates and stores the credentials from the SoundCloud developer app.
    func saveCredentials() async {
        let clientID = clientIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = clientSecretInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            state = .failed("Enter both the client ID and the client secret from your SoundCloud app.")
            return
        }

        state = .restoring
        do {
            let credentials = OAuthAppCredentials(clientID: clientID, clientSecret: clientSecret)
            try configure(with: credentials)
            try credentialStore.save(credentials)
            clientSecretInput = ""
            state = .signedOut
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Runs one authorization-code + PKCE sign-in with the system browser.
    func signIn() async {
        guard let service, let configuration else {
            state = .failed("Save your SoundCloud app credentials first.")
            return
        }
        guard let scheme = configuration.redirectURI.scheme, !scheme.isEmpty else {
            state = .failed("The registered redirect address has no scheme.")
            return
        }

        state = .authorizing
        do {
            let request = try service.beginSignIn()
            validator = OAuthCallbackValidator()
            try validator.register(request.transaction)

            let callbackURL = try await browser.authenticate(
                url: request.url,
                callbackURLScheme: scheme
            )
            let callback = try validator.consume(callbackURL)
            _ = try await service.completeSignIn(
                callback: callback,
                transaction: request.transaction
            )
            state = .signedIn
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Retries the step that failed without requiring the owner to re-enter
    /// configuration.
    func retry() async {
        if service == nil {
            await start()
        } else {
            await signIn()
        }
    }

    /// Explicit local sign-out. Application credentials are kept.
    func signOut() async {
        do {
            try await service?.signOut()
            state = .signedOut
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Removes both the session and the stored application credentials.
    func resetCredentials() async {
        do {
            try credentialStore.delete()
            try await tokenStore.delete()
            service = nil
            configuration = nil
            clientIDInput = ""
            clientSecretInput = ""
            state = .needsConfiguration
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private func configure(with credentials: OAuthAppCredentials) throws {
        let configuration = try AppOAuthConfiguration.configuration(for: credentials)
        self.configuration = configuration
        self.service = AuthenticationService(
            configuration: configuration,
            transport: transport,
            store: tokenStore,
            hashing: CryptoKitPKCEHasher()
        )
    }

    private static func isUnrecoverableSession(_ error: AuthenticationError) -> Bool {
        switch error {
        case .invalidTokenBundle, .notAuthenticated:
            return true
        case .httpStatus(let status, _):
            return status == 400 || status == 401
        case .missingClientSecret, .stateMismatch, .transport, .invalidTokenResponse:
            return false
        }
    }

    private static func message(for error: Error) -> String {
        if let webError = error as? ASWebAuthenticationSessionError,
           webError.code == .canceledLogin {
            return "Sign-in was cancelled."
        }
        if error is DecodingError {
            return "The stored SoundCloud session could not be read. Sign in again."
        }
        return error.localizedDescription
    }
}
