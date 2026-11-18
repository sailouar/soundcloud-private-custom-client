import Foundation
import Combine
import SoundCloudCore

/// Central wiring for the app: capability tracer, authentication, resource
/// client, local library, download manager, and player. Everything the views
/// need is reachable from here.
@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var capabilityResponse: CapabilityResponse

    let authentication: AuthenticationCoordinator
    let resources: SoundCloudResources
    let library: any LocalLibraryStore
    let downloads: DownloadManager
    let player: PlayerService

    private let api: SoundCloudAPI

    init(
        api: SoundCloudAPI,
        authentication: AuthenticationCoordinator,
        resources: SoundCloudResources,
        library: any LocalLibraryStore,
        downloads: DownloadManager,
        player: PlayerService
    ) {
        self.api = api
        self.authentication = authentication
        self.resources = resources
        self.library = library
        self.downloads = downloads
        self.player = player
        self.capabilityResponse = CapabilityResponse(
            operation: .trackMetadata,
            state: .temporarilyUnavailable,
            reason: "Capability check has not run."
        )
    }

    /// Mock-backed environment for previews and UI development.
    convenience init(api: SoundCloudAPI) {
        let authentication = AuthenticationCoordinator.live()
        let library = InMemoryLocalStore()
        let tokens = CoordinatorTokenProvider(coordinator: authentication)
        let resources = SoundCloudResources(
            transport: URLSessionResourceTransport(),
            tokens: tokens
        )
        let libraryDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library", isDirectory: true)
        self.init(
            api: api,
            authentication: authentication,
            resources: resources,
            library: library,
            downloads: DownloadManager(
                session: URLSessionDownloadSession(),
                library: library,
                libraryDirectory: libraryDirectory
            ),
            player: PlayerService(library: library)
        )
    }

    /// Production wiring: Keychain session, live API transport, SwiftData
    /// library, URLSession download session, AVFoundation player.
    static func live() -> AppEnvironment {
        let authentication = AuthenticationCoordinator.live()
        let library: any LocalLibraryStore = (try? SwiftDataLocalStore()) ?? InMemoryLocalStore()
        let tokens = CoordinatorTokenProvider(coordinator: authentication)
        let resources = SoundCloudResources(
            transport: URLSessionResourceTransport(),
            tokens: tokens
        )
        let libraryDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library", isDirectory: true)
        let operation = CapabilityOperation.trackMetadata
        let transport = MockAPITransport(fixtures: [
            .init(method: operation.method, path: operation.path): .success(
                (try? MockAPITransport.json(state: .supported, reason: "fixture")) ?? HTTPResponse(statusCode: 200, body: Data())
            )
        ])
        return AppEnvironment(
            api: SoundCloudAPI(transport: transport),
            authentication: authentication,
            resources: resources,
            library: library,
            downloads: DownloadManager(
                session: URLSessionDownloadSession(),
                library: library,
                libraryDirectory: libraryDirectory
            ),
            player: PlayerService(library: library)
        )
    }

    /// Runs the startup work: the capability check and Keychain session restore.
    func start() async {
        load()
        await authentication.start()
        await loadDownloadCapability()
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

    /// Feeds the download-capability state into the download manager. Until
    /// an official download path is confirmed, downloads stay denied.
    func loadDownloadCapability() async {
        if case .supported = capability(for: .downloadAuthorization)?.state {
            await downloads.updateDownloadCapability(capability(for: .downloadAuthorization))
        } else {
            await downloads.updateDownloadCapability(nil)
        }
    }

    private func capability(for operation: CapabilityOperation) -> CapabilityResponse? {
        try? api.capability(for: operation)
    }
}
