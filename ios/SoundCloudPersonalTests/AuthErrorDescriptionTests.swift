import XCTest
import SoundCloudCore

final class AuthErrorDescriptionTests: XCTestCase {
    func testAuthenticationErrorsHaveReadableDescriptionsWithoutSecrets() {
        let errors: [AuthenticationError] = [
            .missingClientSecret,
            .notAuthenticated,
            .invalidTokenBundle,
            .stateMismatch,
            .transport("The network is offline."),
            .httpStatus(401, message: "unauthorized"),
            .invalidTokenResponse("missing refresh token")
        ]

        for error in errors {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "\(error) must have a user-facing description")
            XCTAssertFalse(description.contains("client_secret="))
            XCTAssertFalse(description.contains("access_token"))
        }
    }

    func testConfigurationCallbackAndTokenErrorsHaveReadableDescriptions() {
        let errors: [Error] = [
            OAuthConfigurationError.redirectMustUseCustomScheme,
            OAuthCallbackError.stateMismatch,
            OAuthCallbackError.authorizationDenied("access_denied"),
            TokenError.missingRefreshToken,
            PKCEError.invalidVerifierLength,
            APIEndpointError.missingAccessToken,
            APIPolicyError.unsupportedOperation(.generalDownload)
        ]

        for error in errors {
            let description = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "\(error) must have a user-facing description")
        }
    }
}
