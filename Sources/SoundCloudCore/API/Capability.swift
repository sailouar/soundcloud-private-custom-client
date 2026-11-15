import Foundation

public enum CapabilityState: String, Codable, CaseIterable, Equatable, Sendable {
    case supported
    case unsupported
    case requiresUserPermission
    case temporarilyUnavailable
}

public enum CapabilityOperation: String, CaseIterable, Codable, Sendable {
    case trackMetadata
    case streamPlayback
    case downloadAuthorization

    public var method: String { "GET" }

    public var path: String {
        switch self {
        case .trackMetadata:
            return "/tracks/urn:soundcloud:tracks:fixture"
        case .streamPlayback:
            return "/tracks/urn:soundcloud:tracks:fixture/streams"
        case .downloadAuthorization:
            return "/tracks/urn:soundcloud:tracks:fixture/download-permission"
        }
    }
}

public struct CapabilityResponse: Codable, Equatable, Sendable {
    public let operation: CapabilityOperation
    public let state: CapabilityState
    public let reason: String?

    public init(operation: CapabilityOperation, state: CapabilityState, reason: String? = nil) {
        self.operation = operation
        self.state = state
        self.reason = reason
    }
}
