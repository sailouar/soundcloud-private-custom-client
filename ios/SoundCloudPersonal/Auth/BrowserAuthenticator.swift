import AuthenticationServices
import UIKit

enum BrowserAuthenticatorError: Error, Equatable {
    case couldNotStart
    case missingCallback
}

extension BrowserAuthenticatorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            return "The system browser could not start the sign-in session."
        case .missingCallback:
            return "The sign-in session ended without returning a callback."
        }
    }
}

/// Presents the official SoundCloud authorization page in
/// `ASWebAuthenticationSession`, which keeps cookies and credentials out of the
/// app process and returns only the registered custom-scheme callback.
@MainActor
final class BrowserAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: BrowserAuthenticatorError.missingCallback)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            guard session.start() else {
                continuation.resume(throwing: BrowserAuthenticatorError.couldNotStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? UIWindow(frame: .zero)
    }
}
