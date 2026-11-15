import SwiftUI
import SoundCloudCore

@main
struct SoundCloudPersonalApp: App {
    @StateObject private var environment: AppEnvironment

    init() {
        let operation = CapabilityOperation.trackMetadata
        let response = try! MockAPITransport.json(
            state: .supported,
            reason: "Sanitized fixture: documented metadata operation."
        )
        let transport = MockAPITransport(fixtures: [
            .init(method: operation.method, path: operation.path): .success(response)
        ])
        _environment = StateObject(
            wrappedValue: AppEnvironment(api: SoundCloudAPI(transport: transport))
        )
    }

    var body: some Scene {
        WindowGroup {
            CapabilityStatusView(response: environment.capabilityResponse)
                .task {
                    environment.load()
                }
        }
    }
}
