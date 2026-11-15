import Foundation
import Combine
import SoundCloudCore

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var capabilityResponse: CapabilityResponse

    let authentication: AuthenticationCoordinator

    private let api: SoundCloudAPI

    init(api: SoundCloudAPI, authentication: AuthenticationCoordinator) {
        self.api = api
        self.authentication = authentication
        self.capabilityResponse = CapabilityResponse(
            operation: .trackMetadata,
            state: .temporarilyUnavailable,
            reason: "Capability check has not run."
        )
    }

    convenience init(api: SoundCloudAPI) {
        self.init(api: api, authentication: AuthenticationCoordinator.live())
    }

    /// Runs the startup work: the capability check and Keychain session restore.
    func start() async {
        load()
        await authentication.start()
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
