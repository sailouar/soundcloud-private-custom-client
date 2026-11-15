import Foundation
import XCTest
@testable import SoundCloudCore

final class OAuthCallbackTests: XCTestCase {
    private let redirectURI = URL(string: "soundcloudpersonal://oauth/callback")!
    private let createdAt = Date(timeIntervalSince1970: 1_000)

    func testMatchingCallbackProducesAOneTimeCode() throws {
        var validator = try makeValidator()
        let callback = try validator.consume(
            callbackURL("code=code-1&state=state-1"),
            at: createdAt.addingTimeInterval(5)
        )

        XCTAssertEqual(callback, OAuthCallback(code: "code-1", state: "state-1"))
    }

    func testStateMismatchIsRejected() throws {
        var validator = try makeValidator()

        XCTAssertThrowsError(
            try validator.consume(callbackURL("code=code-1&state=attacker"), at: createdAt)
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .stateMismatch) }
    }

    func testMissingStateAndMissingCodeAreRejected() throws {
        var validator = try makeValidator()

        XCTAssertThrowsError(try validator.consume(callbackURL("code=code-1"), at: createdAt)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .missingState)
        }
        XCTAssertThrowsError(
            try validator.consume(callbackURL("state=state-1"), at: createdAt)
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .missingCode) }
    }

    func testRedirectMustMatchTheRegisteredURIExactly() throws {
        var validator = try makeValidator()

        XCTAssertThrowsError(
            try validator.consume(
                URL(string: "https://oauth/callback?code=c&state=state-1")!,
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .unexpectedScheme("https")) }

        XCTAssertThrowsError(
            try validator.consume(
                URL(string: "soundcloudpersonal://attacker/callback?code=c&state=state-1")!,
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .unexpectedHost("attacker")) }

        XCTAssertThrowsError(
            try validator.consume(
                URL(string: "soundcloudpersonal://oauth/other?code=c&state=state-1")!,
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .unexpectedPath("/other")) }

        XCTAssertThrowsError(
            try validator.consume(
                URL(string: "soundcloudpersonal://oauth:8443/callback?code=c&state=state-1")!,
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .unexpectedPort(8443)) }
    }

    func testAuthorizationErrorIsSurfacedAsATypedDenial() throws {
        var validator = try makeValidator()

        XCTAssertThrowsError(
            try validator.consume(
                callbackURL("error=access_denied&error_description=user%20denied&state=state-1"),
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .authorizationDenied("user denied")) }
    }

    func testReplayedCallbackIsRejected() throws {
        var validator = try makeValidator()
        let url = callbackURL("code=code-1&state=state-1")

        _ = try validator.consume(url, at: createdAt)
        XCTAssertThrowsError(try validator.consume(url, at: createdAt.addingTimeInterval(1))) {
            XCTAssertEqual($0 as? OAuthCallbackError, .replayedCallback)
        }
    }

    func testExpiredTransactionIsRejected() throws {
        var validator = try makeValidator(maximumAge: 600)

        XCTAssertThrowsError(
            try validator.consume(
                callbackURL("code=code-1&state=state-1"),
                at: createdAt.addingTimeInterval(601)
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .expiredTransaction) }
    }

    func testDuplicateRegistrationIsRejected() throws {
        var validator = try makeValidator()
        let transaction = makeTransaction()

        XCTAssertThrowsError(try validator.register(transaction)) {
            XCTAssertEqual($0 as? OAuthCallbackError, .duplicateState)
        }
    }

    func testStaticValidationAcceptsOneCallbackAndRejectsNoState() throws {
        let transaction = makeTransaction()

        XCTAssertEqual(
            try OAuthCallbackValidator.validate(
                callbackURL("code=code-1&state=state-1"),
                against: transaction,
                at: createdAt
            ),
            OAuthCallback(code: "code-1", state: "state-1")
        )

        XCTAssertThrowsError(
            try OAuthCallbackValidator.validate(
                callbackURL("code=code-1"),
                against: transaction,
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .missingState) }
    }

    func testErrorCallbackStillRequiresMatchingState() throws {
        var validator = try makeValidator()

        XCTAssertThrowsError(
            try validator.consume(
                callbackURL("error=access_denied&state=attacker"),
                at: createdAt
            )
        ) { XCTAssertEqual($0 as? OAuthCallbackError, .stateMismatch) }
    }

    // MARK: - Helpers

    private func makeTransaction(
        state: String = "state-1",
        createdAt: Date? = nil
    ) -> OAuthTransaction {
        OAuthTransaction(
            state: state,
            codeVerifier: String(repeating: "a", count: 43),
            codeChallenge: "challenge",
            redirectURI: redirectURI,
            createdAt: createdAt ?? self.createdAt
        )
    }

    private func makeValidator(maximumAge: TimeInterval = 600) throws -> OAuthCallbackValidator {
        var validator = OAuthCallbackValidator(maximumTransactionAge: maximumAge)
        try validator.register(makeTransaction())
        return validator
    }

    private func callbackURL(_ query: String) -> URL {
        callbackURL(query, path: "callback")
    }

    private func callbackURL(_ query: String, path: String) -> URL {
        URL(string: "soundcloudpersonal://oauth/\(path)?\(query)")!
    }
}
