import SwiftUI
import SoundCloudCore

// MARK: - Home

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    let environment: AppEnvironment
    @State private var selectedTrack: SCTrack?

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: HomeViewModel(resources: environment.resources))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                    if let me = viewModel.me {
                        Text("Welcome back, \(me.username ?? "listener")")
                            .font(.title2.bold())
                            .padding(.horizontal)
                    }
                    if !viewModel.likedTracks.isEmpty {
                        SectionHeader(title: "Liked tracks")
                        VStack(spacing: 4) {
                            ForEach(viewModel.likedTracks) { track in
                                TrackRowView(track: track, isOffline: false) {
                                    selectedTrack = track
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    if !viewModel.playlists.isEmpty {
                        SectionHeader(title: "Your playlists")
                        VStack(spacing: 4) {
                            ForEach(viewModel.playlists) { playlist in
                                PlaylistRowView(
                                    title: playlist.title ?? "Untitled",
                                    subtitle: "\(playlist.trackCount ?? playlist.tracks?.count ?? 0) tracks",
                                    artworkURL: playlist.artworkURL(size: .small)
                                ) {}
                                .padding(.horizontal)
                            }
                        }
                    }
                    if viewModel.isLoading {
                        ProgressView().padding()
                    }
                    if !viewModel.isLoading && viewModel.likedTracks.isEmpty && viewModel.playlists.isEmpty {
                        EmptyStateView(message: "Sign in and like tracks or create playlists — they show up here.")
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .task { await viewModel.load() }
            .sheet(item: $selectedTrack) { track in
                TrackDetailView(
                    viewModel: TrackDetailViewModel(
                        track: track,
                        resources: environment.resources,
                        downloads: environment.downloads,
                        library: environment.library
                    ),
                    player: environment.player
                )
            }
        }
    }
}

// MARK: - Search

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    let environment: AppEnvironment
    @State private var selectedTrack: SCTrack?

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: SearchViewModel(resources: environment.resources))
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if !viewModel.tracks.isEmpty {
                    Section("Tracks") {
                        ForEach(viewModel.tracks) { track in
                            TrackRowView(track: track, isOffline: false) {
                                selectedTrack = track
                            }
                        }
                    }
                }
                if !viewModel.users.isEmpty {
                    Section("Artists") {
                        ForEach(viewModel.users) { user in
                            NavigationLink {
                                ArtistView(
                                    viewModel: ArtistViewModel(user: user, resources: environment.resources)
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(url: user.avatarURL(size: .small), cornerRadius: 28)
                                    Text(user.username ?? "Unknown")
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
                if !viewModel.playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(viewModel.playlists) { playlist in
                            PlaylistRowView(
                                title: playlist.title ?? "Untitled",
                                subtitle: "\(playlist.trackCount ?? 0) tracks",
                                artworkURL: playlist.artworkURL(size: .small)
                            ) {}
                        }
                    }
                }
                if viewModel.isSearching {
                    ProgressView()
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Tracks, artists, playlists")
            .onChange(of: viewModel.query) { _, _ in viewModel.onQueryChanged() }
            .sheet(item: $selectedTrack) { track in
                TrackDetailView(
                    viewModel: TrackDetailViewModel(
                        track: track,
                        resources: environment.resources,
                        downloads: environment.downloads,
                        library: environment.library
                    ),
                    player: environment.player
                )
            }
        }
    }
}

// MARK: - Library

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    let environment: AppEnvironment
    @State private var selectedTrack: SCTrack?

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: LibraryViewModel(
            resources: environment.resources,
            library: environment.library
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink {
                        AuthenticationView(coordinator: environment.authentication)
                    } label: {
                        Label("Sign-in & session", systemImage: "person.crop.circle")
                    }
                }

                if !viewModel.localTracks.isEmpty {
                    Section("Downloaded (\(viewModel.localTracks.count))") {
                        ForEach(viewModel.localTracks, id: \.trackID) { track in
                            LocalTrackRowView(track: track) {
                                if let path = track.localPath, track.status == .completed {
                                    environment.player.setQueue([.local(fileURL: URL(fileURLWithPath: path), track: track)])
                                }
                            }
                        }
                    }
                }

                if !viewModel.localPlaylists.isEmpty {
                    Section("Local playlists") {
                        ForEach(viewModel.localPlaylists) { playlist in
                            PlaylistRowView(
                                title: playlist.title,
                                subtitle: "\(playlist.trackIDs.count) tracks · local",
                                artworkURL: nil
                            ) {}
                        }
                    }
                }

                if !viewModel.likedTracks.isEmpty {
                    Section("Liked on SoundCloud") {
                        ForEach(viewModel.likedTracks) { track in
                            TrackRowView(track: track, isOffline: false) {
                                selectedTrack = track
                            }
                        }
                    }
                }

                if !viewModel.remotePlaylists.isEmpty {
                    Section("SoundCloud playlists") {
                        ForEach(viewModel.remotePlaylists) { playlist in
                            PlaylistRowView(
                                title: playlist.title ?? "Untitled",
                                subtitle: "\(playlist.trackCount ?? 0) tracks",
                                artworkURL: playlist.artworkURL(size: .small)
                            ) {}
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
            .navigationTitle("Library")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(item: $selectedTrack) { track in
                TrackDetailView(
                    viewModel: TrackDetailViewModel(
                        track: track,
                        resources: environment.resources,
                        downloads: environment.downloads,
                        library: environment.library
                    ),
                    player: environment.player
                )
            }
        }
    }
}
