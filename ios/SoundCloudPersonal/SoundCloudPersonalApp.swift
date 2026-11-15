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
            RootView(environment: environment)
                .task {
                    await environment.start()
                }
        }
    }
}

private struct RootView: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        TabView {
            AuthenticationView(coordinator: environment.authentication)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
            CapabilityStatusView(response: environment.capabilityResponse)
                .tabItem {
                    Label("Capability", systemImage: "waveform")
                }
        }
    }
}
