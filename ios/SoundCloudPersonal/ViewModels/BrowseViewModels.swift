import Foundation
import Combine
import SoundCloudCore

// MARK: - Home

/// Home aggregates documented endpoints: the signed-in profile, liked tracks,
/// and the user's own playlists. The official API has no dedicated
/// home-feed endpoint, so nothing here is fabricated.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var me: SCUser?
    @Published var likedTracks: [SCTrack] = []
    @Published var playlists: [SCPlaylist] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let resources: SoundCloudResources

    init(resources: SoundCloudResources) {
        self.resources = resources
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let me = resources.me()
            async let likes = resources.likedTracks(limit: 20)
            async let playlists = resources.ownPlaylists(limit: 20)
            self.me = try await me
            self.likedTracks = try await likes.collection ?? []
            self.playlists = try await playlists.collection ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Search

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var tracks: [SCTrack] = []
    @Published var users: [SCUser] = []
    @Published var playlists: [SCPlaylist] = []
    @Published var errorMessage: String?
    @Published var isSearching = false

    private let resources: SoundCloudResources
    private var searchTask: Task<Void, Never>?

    init(resources: SoundCloudResources) {
        self.resources = resources
    }

    func onQueryChanged() {
        searchTask?.cancel()
        let current = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else {
            tracks = []
            users = []
            playlists = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000) // debounce
            guard let self, !Task.isCancelled else { return }
            await self.search(current)
        }
    }

    func search(_ query: String) async {
        isSearching = true
        errorMessage = nil
        do {
            async let tracks = resources.searchTracks(query: query)
            async let users = resources.searchUsers(query: query)
            async let playlists = resources.searchPlaylists(query: query)
            self.tracks = try await tracks.collection ?? []
            self.users = try await users.collection ?? []
            self.playlists = try await playlists.collection ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}

// MARK: - Track detail

@MainActor
final class TrackDetailViewModel: ObservableObject {
    @Published var track: SCTrack
    @Published var isLiked = false
    @Published var downloadState: DownloadAvailability = .unknown
    @Published var errorMessage: String?
    @Published var isBusy = false

    private let resources: SoundCloudResources
    private let downloads: DownloadManager
    private let library: any LocalLibraryStore

    enum DownloadAvailability: Equatable {
        case unknown
        case alreadyLocal
        case permitted
        case notPermitted(reason: String)
    }

    init(track: SCTrack, resources: SoundCloudResources, downloads: DownloadManager, library: any LocalLibraryStore) {
        self.track = track
        self.resources = resources
        self.downloads = downloads
        self.library = library
    }

    func load() async {
        let entitlement = TrackDownloadEntitlement(track: track)
        if let local = try? await library.track(withID: track.id), local.status == .completed {
            downloadState = .alreadyLocal
        } else if entitlement.isAuthorized {
            downloadState = .permitted
        } else {
            downloadState = .notPermitted(reason: entitlement.denialReason ?? "Downloads are not permitted for this track.")
        }
    }

    func toggleLike() async {
        guard let urn = track.urn else { return }
        isBusy = true
        do {
            if isLiked {
                try await resources.unlikeTrack(urn: urn)
            } else {
                try await resources.likeTrack(urn: urn)
            }
            isLiked.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    /// Resolves the stream URL for this track (stream-only disposition).
    func streamURL() async throws -> URL? {
        try await resources.streamURL(for: track)
    }

    /// Downloads the track when authorized; never fakes success.
    @discardableResult
    func download() async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let id = try await downloads.enqueue(track: track)
            if id == nil { downloadState = .alreadyLocal }
            return true
        } catch {
            errorMessage = error.localizedDescription
            downloadState = .notPermitted(reason: error.localizedDescription)
            return false
        }
    }
}

// MARK: - Artist detail

@MainActor
final class ArtistViewModel: ObservableObject {
    @Published var user: SCUser
    @Published var isFollowing = false
    @Published var errorMessage: String?

    private let resources: SoundCloudResources

    init(user: SCUser, resources: SoundCloudResources) {
        self.user = user
        self.resources = resources
    }

    func toggleFollow() async {
        guard let urn = user.urn else { return }
        do {
            if isFollowing {
                try await resources.unfollowUser(urn: urn)
            } else {
                try await resources.followUser(urn: urn)
            }
            isFollowing.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
