import Foundation

public struct DownloadRequest: Equatable, Sendable {
    public let trackID: String

    public init(trackID: String) {
        self.trackID = trackID
    }
}

public enum DownloadDenialReason: String, Equatable, Sendable {
    case missingCapability
    case notDownloadCapability
    case capabilityNotSupported
    case noExplicitOfficialEntitlement
    case invalidTrackID
}

public enum DownloadAuthorizationDecision: Equatable, Sendable {
    case denied(DownloadDenialReason)
    case authorized(DownloadRequest)
}

public struct DownloadAuthorization: Sendable {
    private let explicitOfficialEntitlement: Bool

    /// The entitlement is supplied by a future, documented official response.
    /// It defaults to false and is never inferred from playback availability.
    public init(explicitOfficialEntitlement: Bool = false) {
        self.explicitOfficialEntitlement = explicitOfficialEntitlement
    }

    public func decision(
        for capability: CapabilityResponse?,
        trackID: String
    ) -> DownloadAuthorizationDecision {
        guard !trackID.isEmpty else {
            return .denied(.invalidTrackID)
        }
        guard let capability else {
            return .denied(.missingCapability)
        }
        guard capability.operation == .downloadAuthorization else {
            return .denied(.notDownloadCapability)
        }
        guard capability.state == .supported else {
            return .denied(.capabilityNotSupported)
        }
        guard explicitOfficialEntitlement else {
            return .denied(.noExplicitOfficialEntitlement)
        }
        return .authorized(DownloadRequest(trackID: trackID))
    }
}
