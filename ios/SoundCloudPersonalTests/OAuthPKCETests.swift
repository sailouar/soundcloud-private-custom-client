import Foundation
import XCTest
@testable import SoundCloudCore

final class OAuthPKCETests: XCTestCase {
    private let redirectURI = URL(string: "soundcloudpersonal://oauth/callback")!

    // MARK: - PKCE

    func testRFC7636KnownVector() throws {
        #if canImport(CryptoKit)
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(
            try CryptoKitPKCEHasher().s256Challenge(for: verifier),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
        #else
        throw XCTSkip("CryptoKit is unavailable; the S256 vector runs on the cloud Mac.")
        #endif
    }

    func testGeneratedVerifierAndStateAreRFC7636Compliant() {
        let random = CountingRandomSource()
        let verifier = PKCE.makeVerifier(random: random)
        let state = PKCE.makeState(random: random)

        XCTAssertTrue(PKCE.isValidVerifier(verifier))
        XCTAssertEqual(verifier.count, 43)
        XCTAssertFalse(verifier.contains("+"))
        XCTAssertFalse(verifier.contains("/"))
        XCTAssertFalse(verifier.contains("="))
        XCTAssertNotEqual(verifier, state)
        XCTAssertEqual(state.count, 43)
    }

    func testInvalidVerifiersAreRejectedWithTypedErrors() {
        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 42)))
        XCTAssertFalse(PKCE.isValidVerifier(String(repeating: "a", count: 129)))

        XCTAssertThrowsError(try PKCE.validate(String(repeating: "a", count: 42))) { error in
            XCTAssertEqual(error as? PKCEError, .invalidVerifierLength)
        }
        XCTAssertThrowsError(try PKCE.validate(String(repeating: "a", count: 43) + "/")) { error in
            XCTAssertEqual(error as? PKCEError, .invalidVerifierCharacter("/"))
        }
    }

    // MARK: - Authorization request

    func testAuthorizationURLUsesOfficialHostAndRequiredParameters() throws {
        let configuration = try makeConfiguration()
        let transaction = try configuration.makeTransaction(
            hashing: StubPKCEHasher(),
            random: CountingRandomSource(),
            now: Date(timeIntervalSince1970: 1_000)
        )

        let url = try configuration.authorizationURL(for: transaction)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "secure.soundcloud.com")
        XCTAssertEqual(components.path, "/authorize")
        XCTAssertEqual(items["client_id"], "test-client")
        XCTAssertEqual(items["redirect_uri"], redirectURI.absoluteString)
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["code_challenge"], transaction.codeChallenge)
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["state"], transaction.state)
        XCTAssertEqual(items["display"], "popup")
        XCTAssertNil(items["password"])
    }

    func testTransactionSeparatesVerifierFromState() throws {
        let configuration = try makeConfiguration()
        let transaction = try configuration.makeTransaction(
            hashing: StubPKCEHasher(),
            random: CountingRandomSource()
        )

        XCTAssertNotEqual(transaction.state, transaction.codeVerifier)
        XCTAssertEqual(transaction.codeChallenge, "stub-challenge-43")
        XCTAssertEqual(transaction.redirectURI, configuration.redirectURI)
    }

    func testConfigurationRejectsNonCustomOrMalformedRedirects() {
        XCTAssertThrowsError(
            try OAuthConfiguration(clientID: "id", redirectURI: URL(string: "https://soundcloud.com/callback")!)
        ) { XCTAssertEqual($0 as? OAuthConfigurationError, .redirectMustUseCustomScheme) }

        XCTAssertThrowsError(
            try OAuthConfiguration(clientID: "id", redirectURI: URL(string: "soundcloudpersonal:callback")!)
        ) { XCTAssertEqual($0 as? OAuthConfigurationError, .redirectMustBeAbsolute) }

        XCTAssertThrowsError(
            try OAuthConfiguration(
                clientID: "id",
                redirectURI: URL(string: "soundcloudpersonal://user:secret@oauth/callback")!
            )
        ) { XCTAssertEqual($0 as? OAuthConfigurationError, .redirectMustNotContainUserInfo) }

        XCTAssertThrowsError(
            try OAuthConfiguration(clientID: " ", redirectURI: redirectURI)
        ) { XCTAssertEqual($0 as? OAuthConfigurationError, .emptyClientID) }
    }

    // MARK: - Token exchange

    func testTokenExchangeUsesOfficialEndpointAndDocumentedParameters() async throws {
        let transport = RecordingOAuthTransport(responses: [tokenResponse(access: "a1", refresh: "r1")])
        let store = InMemoryTokenStore()
        let service = try makeService(transport: transport, store: store)

        let authorization = try service.beginSignIn(now: Date(timeIntervalSince1970: 5_000))
        let callback = OAuthCallback(code: "code-1", state: authorization.transaction.state)
        let bundle = try await service.completeSignIn(
            callback: callback,
            transaction: authorization.transaction,
            now: Date(timeIntervalSince1970: 5_010)
        )

        XCTAssertEqual(bundle.accessToken, "a1")
        XCTAssertEqual(bundle.refreshToken, "r1")
        let savedBundle = try await store.current()
        XCTAssertEqual(savedBundle, bundle)

        let recordedRequests = await transport.recordedRequests()
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.url, OAuthConfiguration.tokenEndpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )

        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertTrue(body.contains("client_id=test-client"))
        XCTAssertTrue(body.contains("client_secret=test-secret"))
        XCTAssertTrue(body.contains("code=code-1"))
        XCTAssertTrue(body.contains("code_verifier=\(authorization.transaction.codeVerifier)"))
        XCTAssertFalse(body.contains("password"))
    }

    func testRefreshUsesSingleUseReplacementToken() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenBundle(
            accessToken: "a1",
            refreshToken: "r1",
            expiresAt: Date(timeIntervalSince1970: 10_000)
        ))
        let transport = RecordingOAuthTransport(responses: [
            tokenResponse(access: "a2", refresh: "r2"),
            tokenResponse(access: "a3", refresh: "r3")
        ])
        let service = try makeService(transport: transport, store: store)

        let first = try await service.refreshSession(now: Date(timeIntervalSince1970: 11_000))
        let second = try await service.refreshSession(now: Date(timeIntervalSince1970: 12_000))

        XCTAssertEqual(first.refreshToken, "r2")
        XCTAssertEqual(second.refreshToken, "r3")
        let persistedBundle = try await store.current()
        XCTAssertEqual(persistedBundle?.refreshToken, "r3")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        let secondBody = try XCTUnwrap(
            requests[1].httpBody.flatMap { String(data: $0, encoding: .utf8) }
        )
        XCTAssertTrue(secondBody.contains("grant_type=refresh_token"))
        XCTAssertTrue(secondBody.contains("refresh_token=r2"))
        XCTAssertFalse(secondBody.contains("refresh_token=r1"))
        XCTAssertFalse(secondBody.contains("password"))
        XCTAssertEqual(requests[1].url, OAuthConfiguration.tokenEndpoint)
    }

    func testRestoreRefreshesExpiredSessionsAndKeepsFreshOnes() async throws {
        let store = InMemoryTokenStore()
        let transport = RecordingOAuthTransport(responses: [tokenResponse(access: "new", refresh: "r-new")])
        let service = try makeService(transport: transport, store: store)
        let now = Date(timeIntervalSince1970: 20_000)

        let missingBundle = try await service.restoreSession(now: now)
        XCTAssertNil(missingBundle)

        try await store.save(TokenBundle(
            accessToken: "fresh",
            refreshToken: "r-fresh",
            expiresAt: now.addingTimeInterval(3_600)
        ))
        let freshBundle = try await service.restoreSession(now: now)
        XCTAssertEqual(freshBundle?.accessToken, "fresh")
        let freshRequests = await transport.recordedRequests()
        XCTAssertTrue(freshRequests.isEmpty)

        try await store.save(TokenBundle(
            accessToken: "stale",
            refreshToken: "r-stale",
            expiresAt: now.addingTimeInterval(30)
        ))
        let refreshedBundle = try await service.restoreSession(now: now)
        XCTAssertEqual(refreshedBundle?.accessToken, "new")
        let refreshRequests = await transport.recordedRequests()
        XCTAssertEqual(refreshRequests.count, 1)
    }

    func testMissingClientSecretFailsBeforeAnyNetworkCall() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenBundle(
            accessToken: "a1",
            refreshToken: "r1",
            expiresAt: Date(timeIntervalSince1970: 10_000)
        ))
        let transport = RecordingOAuthTransport(responses: [])
        let service = try makeService(
            configuration: try makeConfiguration(clientSecret: nil),
            transport: transport,
            store: store
        )

        do {
            _ = try await service.refreshSession()
            XCTFail("Refresh must not proceed without a client secret")
        } catch {
            XCTAssertEqual(error as? AuthenticationError, .missingClientSecret)
        }
        let recordedRequests = await transport.recordedRequests()
        XCTAssertTrue(recordedRequests.isEmpty)
    }

    func testSignOutDeletesTheStoredBundle() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenBundle(
            accessToken: "a1",
            refreshToken: "r1",
            expiresAt: Date(timeIntervalSince1970: 10_000)
        ))
        let service = try makeService(transport: RecordingOAuthTransport(responses: []), store: store)

        try await service.signOut()
        let remainingBundle = try await store.current()
        XCTAssertNil(remainingBundle)
        let storedBundle = try await service.storedBundle()
        XCTAssertNil(storedBundle)
    }

    // MARK: - Redaction

    func testDescriptionsNeverExposeSecrets() throws {
        let configuration = try makeConfiguration()
        XCTAssertTrue(String(describing: configuration).contains("<redacted>"))
        XCTAssertTrue(String(reflecting: configuration).contains("<redacted>"))
        XCTAssertFalse(String(describing: configuration).contains("test-secret"))

        let bundle = try XCTUnwrap(OAuthTokenResponse(
            accessToken: "access-value",
            refreshToken: "refresh-value",
            expiresIn: 3_600,
            scope: "non-expiring",
            tokenType: "OAuth"
        ).bundle(receivedAt: Date(timeIntervalSince1970: 1_000)))

        XCTAssertFalse(String(describing: bundle).contains("access-value"))
        XCTAssertFalse(String(describing: bundle).contains("refresh-value"))
        XCTAssertFalse(String(reflecting: bundle).contains("access-value"))
        XCTAssertTrue(String(describing: bundle).contains("<redacted>"))
    }

    func testTokenResponseRejectsIncompleteBundles() {
        XCTAssertThrowsError(
            try OAuthTokenResponse(accessToken: "", refreshToken: "r1", expiresIn: 3_600).bundle()
        ) { XCTAssertEqual($0 as? TokenError, .missingAccessToken) }

        XCTAssertThrowsError(
            try OAuthTokenResponse(accessToken: "a1", refreshToken: "", expiresIn: 3_600).bundle()
        ) { XCTAssertEqual($0 as? TokenError, .missingRefreshToken) }

        XCTAssertThrowsError(
            try OAuthTokenResponse(accessToken: "a1", refreshToken: "r1", expiresIn: 0).bundle()
        ) { XCTAssertEqual($0 as? TokenError, .nonPositiveExpiry) }
    }

    // MARK: - Helpers

    private func makeConfiguration(clientSecret: String? = "test-secret") throws -> OAuthConfiguration {
        try OAuthConfiguration(
            clientID: "test-client",
            redirectURI: redirectURI,
            clientSecret: clientSecret
        )
    }

    private func makeService(
        configuration: OAuthConfiguration? = nil,
        transport: RecordingOAuthTransport,
        store: InMemoryTokenStore
    ) throws -> AuthenticationService {
        let resolvedConfiguration: OAuthConfiguration
        if let configuration {
            resolvedConfiguration = configuration
        } else {
            resolvedConfiguration = try makeConfiguration()
        }
        return AuthenticationService(
            configuration: resolvedConfiguration,
            transport: transport,
            store: store,
            hashing: StubPKCEHasher(),
            random: CountingRandomSource(),
            clock: FixedDateProvider(now: Date(timeIntervalSince1970: 1_000))
        )
    }

    private func tokenResponse(access: String, refresh: String) -> HTTPResponse {
        let json = """
        {"access_token":"\(access)","refresh_token":"\(refresh)","expires_in":3600,"scope":"non-expiring","token_type":"OAuth"}
        """
        return HTTPResponse(statusCode: 200, body: Data(json.utf8))
    }
}

// MARK: - Test doubles

struct StubPKCEHasher: PKCEHashing {
    func s256Challenge(for verifier: String) throws -> String {
        "stub-challenge-\(verifier.count)"
    }
}

final class CountingRandomSource: SecureRandomSource, @unchecked Sendable {
    private let lock = NSLock()
    private var counter: UInt8 = 0

    func bytes(count: Int) -> [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        return (0..<count).map { _ in
            counter = counter &+ 1
            return counter
        }
    }
}

struct FixedDateProvider: DateProviding {
    let now: Date
}

actor RecordingOAuthTransport: OAuthTransport {
    private var queued: [Result<HTTPResponse, APIError>]
    private var requests: [URLRequest] = []

    init(responses: [HTTPResponse]) {
        self.queued = responses.map { .success($0) }
    }

    init(results: [Result<HTTPResponse, APIError>]) {
        self.queued = results
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !queued.isEmpty else {
            throw APIError.transport("No queued OAuth response")
        }
        return try queued.removeFirst().get()
    }

    func recordedRequests() -> [URLRequest] { requests }
}

actor InMemoryTokenStore: TokenStore {
    private var bundle: TokenBundle?

    func load() async throws -> TokenBundle? { bundle }

    func save(_ bundle: TokenBundle) async throws {
        self.bundle = bundle
    }

    func delete() async throws {
        bundle = nil
    }

    func current() -> TokenBundle? { bundle }
}
