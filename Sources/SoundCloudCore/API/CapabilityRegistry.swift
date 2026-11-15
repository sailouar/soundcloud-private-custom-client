import Foundation

public struct CapabilityRegistry: Sendable {
    public init() {}

    public func response(
        for operation: CapabilityOperation,
        envelope: CapabilityEnvelope
    ) -> CapabilityResponse {
        CapabilityResponse(
            operation: operation,
            state: envelope.state,
            reason: envelope.reason
        )
    }
}

public struct CapabilityEnvelope: Codable, Equatable, Sendable {
    public let state: CapabilityState
    public let reason: String?

    public init(state: CapabilityState, reason: String? = nil) {
        self.state = state
        self.reason = reason
    }
}
