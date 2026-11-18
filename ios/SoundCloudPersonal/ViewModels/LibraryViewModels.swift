import Foundation
import Combine
import SoundCloudCore

// MARK: - Library (account + local)

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var likedTracks: [SCTrack] = []
    @Published var remotePlaylists: [SCPlaylist] = []
    @Published var localPlaylists: [LocalPlaylistRecord] = []
    @Published var localTracks: [LocalTrackDetails] = []
    @Published var errorMessage: String?

    private let resources: SoundCloudResources
    private let library: any LocalLibraryStore

    init(resources: SoundCloudResources, library: any LocalLibraryStore) {
        self.resources = resources
        self.library = library
    }

    func load() async {
        errorMessage = nil
        do {
            async let likes = resources.likedTracks(limit: 50)
            async let playlists = resources.ownPlaylists(limit: 50)
            likedTracks = try await likes.collection ?? []
            remotePlaylists = try await playlists.collection ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        await reloadLocal()
    }

    func reloadLocal() async {
        localPlaylists = (try? await library.playlists()) ?? []
        localTracks = (try? await library.allTracks()) ?? []
    }
}

// MARK: - Downloads

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published var jobs: [DownloadJob] = []
    @Published var localTracks: [LocalTrackDetails] = []
    @Published var localPlaylists: [LocalPlaylistRecord] = []
    @Published var storageUsageBytes: Int64 = 0
    @Published var errorMessage: String?
    @Published var deletingTrackWarning: (trackID: Int64, playlists: [String])?

    private let downloads: DownloadManager
    private let library: any LocalLibraryStore
    private let libraryDirectory: URL
    private var refreshTask: Task<Void, Never>?

    init(downloads: DownloadManager, library: any LocalLibraryStore, libraryDirectory: URL) {
        self.downloads = downloads
        self.library = library
        self.libraryDirectory = libraryDirectory
    }

    func start() {
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func refresh() async {
        jobs = await downloads.snapshot()
        localTracks = (try? await library.allTracks()) ?? []
        localPlaylists = (try? await library.playlists()) ?? []
        storageUsageBytes = directorySize(libraryDirectory)
    }

    func cancel(_ id: UUID) async {
        await downloads.cancel(id)
        await refresh()
    }

    func retry(_ id: UUID) async {
        try? await downloads.retry(id)
        await refresh()
    }

    func dismiss(_ id: UUID) async {
        await downloads.dismiss(id)
        await refresh()
    }

    /// Downloads a whole remote playlist, skipping tracks already local.
    func downloadPlaylist(_ playlist: SCPlaylist) async {
        let tracks = playlist.tracks ?? []
        guard !tracks.isEmpty else {
            errorMessage = "This playlist's tracks are not embedded in the API response; open it and download tracks individually."
            return
        }
        do {
            _ = try await downloads.enqueuePlaylist(tracks)
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }

    /// Prepares deletion of a local track: warns when playlists still
    /// reference it. The caller confirms, then calls `confirmDeleteTrack`.
    func prepareDeleteTrack(_ trackID: Int64) async {
        let referencing = (try? await library.playlistTitlesReferencing(trackID: trackID)) ?? []
        deletingTrackWarning = (trackID, referencing)
    }

    func confirmDeleteTrack(_ trackID: Int64) async {
        deletingTrackWarning = nil
        try? await library.deleteTrack(trackID)
        // Remove the file from disk as well.
        if let track = localTracks.first(where: { $0.trackID == trackID }), let path = track.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        await refresh()
    }

    func deletePlaylist(_ id: UUID) async {
        // Deleting a playlist never deletes the shared track files.
        try? await library.deletePlaylist(id)
        await refresh()
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    var storageUsageText: String {
        ByteCountFormatter.string(fromByteCount: storageUsageBytes, countStyle: .file)
    }
}

// MARK: - Player view model

@MainActor
final class PlayerViewModel: ObservableObject {
    let player: PlayerService

    init(player: PlayerService) {
        self.player = player
    }
}
