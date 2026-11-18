import SwiftUI
import SoundCloudCore

@main
struct SoundCloudPersonalApp: App {
    @StateObject private var environment: AppEnvironment

    init() {
        _environment = StateObject(wrappedValue: AppEnvironment.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .preferredColorScheme(.dark)
                .accentColor(.orange)
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
            HomeView(environment: environment)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            SearchView(environment: environment)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            LibraryView(environment: environment)
                .tabItem {
                    Label("Library", systemImage: "square.stack.fill")
                }
            DownloadsView(environment: environment)
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
            PlayerView(player: environment.player)
                .tabItem {
                    Label("Player", systemImage: "play.circle.fill")
                }
        }
        .sheet(isPresented: Binding(
            get: { environment.authentication.state != .signedIn && environment.authentication.state != .restoring },
            set: { _ in }
        )) {
            AuthenticationView(coordinator: environment.authentication)
        }
    }
}
