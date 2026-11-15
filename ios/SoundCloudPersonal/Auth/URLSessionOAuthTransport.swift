import Foundation
import SoundCloudCore

/// `URLSession` implementation of the OAuth network boundary. The core only
/// calls the documented token endpoint through this type.
struct URLSessionOAuthTransport: OAuthTransport {
    let session: URLSession
    let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.session = session
        self.timeout = timeout
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        var request = request
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AuthenticationError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthenticationError.transport("The response was not an HTTP response.")
        }

        var headers: [String: String] = [:]
        for (name, value) in http.allHeaderFields {
            if let name = name as? String, let value = value as? String {
                headers[name] = value
            }
        }
        return HTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }
}
