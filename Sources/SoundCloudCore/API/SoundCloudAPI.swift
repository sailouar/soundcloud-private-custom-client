import Foundation

public struct SoundCloudAPI: Sendable {
    private let transport: any HTTPTransport
    private let registry: CapabilityRegistry
    private let decoder: JSONDecoder

    public init(
        transport: any HTTPTransport,
        registry: CapabilityRegistry = CapabilityRegistry()
    ) {
        self.transport = transport
        self.registry = registry
        self.decoder = JSONDecoder()
    }

    public func capability(for operation: CapabilityOperation) throws -> CapabilityResponse {
        let response: HTTPResponse
        do {
            response = try transport.send(method: operation.method, path: operation.path)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            let message = try? decoder.decode(APIMessage.self, from: response.body).message
            throw APIError.httpStatus(response.statusCode, message: message)
        }

        do {
            let envelope = try decoder.decode(CapabilityEnvelope.self, from: response.body)
            return registry.response(for: operation, envelope: envelope)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

private struct APIMessage: Decodable {
    let message: String?
}
