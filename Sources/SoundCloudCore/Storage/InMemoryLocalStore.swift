import Foundation

/// In-memory `LocalLibraryStore` for previews, tests, and as a fallback when
/// the persistent store cannot be created.
public actor InMemoryLocalStore: LocalLibraryStore {
    private var tracks: [Int64: LocalTrackDetails] = [:]
    private var playlistsByID: [UUID: LocalPlaylistRecord] = [:]

    public init() {}

    public init(seedTracks: [LocalTrackDetails] = [], seedPlaylists: [LocalPlaylistRecord] = []) {
        for track in seedTracks { tracks[track.trackID] = track }
        for playlist in seedPlaylists { playlistsByID[playlist.id] = playlist }
    }

    public func track(withID trackID: Int64) async throws -> LocalTrackDetails? {
        tracks[trackID]
    }

    public func allTracks() async throws -> [LocalTrackDetails] {
        tracks.values.sorted { $0.addedAt > $1.addedAt }
    }

    public func trackIDs() async throws -> Set<Int64> {
        Set(tracks.keys)
    }

    public func saveTrack(_ track: LocalTrackDetails) async throws {
        tracks[track.trackID] = track
    }

    public func deleteTrack(_ trackID: Int64) async throws {
        tracks[trackID] = nil
        for id in playlistsByID.keys {
            playlistsByID[id]?.trackIDs.removeAll { $0 == trackID }
        }
    }

    public func playlistTitlesReferencing(trackID: Int64) async throws -> [String] {
        playlistsByID.values
            .filter { $0.trackIDs.contains(trackID) }
            .map(\.title)
            .sorted()
    }

    public func playlists() async throws -> [LocalPlaylistRecord] {
        playlistsByID.values.sorted { $0.title < $1.title }
    }

    public func playlist(withID id: UUID) async throws -> LocalPlaylistRecord? {
        playlistsByID[id]
    }

    public func savePlaylist(_ playlist: LocalPlaylistRecord) async throws {
        playlistsByID[playlist.id] = playlist
    }

    public func deletePlaylist(_ id: UUID) async throws {
        playlistsByID[id] = nil
    }

    public func moveEntry(in playlistID: UUID, from source: Int, to destination: Int) async throws {
        guard var playlist = playlistsByID[playlistID],
              playlist.trackIDs.indices.contains(source),
              playlist.trackIDs.indices.contains(destination) else { return }
        let moved = playlist.trackIDs.remove(at: source)
        playlist.trackIDs.insert(moved, at: destination)
        playlistsByID[playlistID] = playlist
    }
}
