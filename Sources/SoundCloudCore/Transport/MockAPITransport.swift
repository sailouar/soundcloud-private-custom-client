import Foundation

public struct MockAPITransport: HTTPTransport, Sendable {
    public struct FixtureKey: Hashable, Sendable {
        public let method: String
        public let path: String

        public init(method: String, path: String) {
            self.method = method.uppercased()
            self.path = path
        }
    }

    private let fixtures: [FixtureKey: Result<HTTPResponse, APIError>]

    public init(fixtures: [FixtureKey: Result<HTTPResponse, APIError>]) {
        self.fixtures = fixtures
    }

    public func send(method: String, path: String) throws -> HTTPResponse {
        let key = FixtureKey(method: method, path: path)
        guard let result = fixtures[key] else {
            throw APIError.transport("No fixture for \(key.method) \(key.path)")
        }
        return try result.get()
    }

    public static func json(
        statusCode: Int = 200,
        state: CapabilityState,
        reason: String? = nil
    ) throws -> HTTPResponse {
        let envelope = CapabilityEnvelope(state: state, reason: reason)
        do {
            return HTTPResponse(
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"],
                body: try JSONEncoder().encode(envelope)
            )
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
