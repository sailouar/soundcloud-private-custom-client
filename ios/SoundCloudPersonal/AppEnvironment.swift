import Foundation
import Combine
import SoundCloudCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var capabilityResponse: CapabilityResponse

    private let api: SoundCloudAPI

    init(api: SoundCloudAPI) {
        self.api = api
        self.capabilityResponse = CapabilityResponse(
            operation: .trackMetadata,
            state: .temporarilyUnavailable,
            reason: "Capability check has not run."
        )
    }

    func load(_ operation: CapabilityOperation = .trackMetadata) {
        do {
            capabilityResponse = try api.capability(for: operation)
        } catch {
            capabilityResponse = CapabilityResponse(
                operation: operation,
                state: .temporarilyUnavailable,
                reason: error.localizedDescription
            )
        }
    }
}
