import Foundation

// MARK: - Local library records
//
// The local library is keyed by the SoundCloud track ID. A track file exists
// at most once on disk, no matter how many playlists reference it. Deleting a
// playlist never deletes track files; deleting a track updates (and warns
// about) the playlists that referenced it.

public enum LocalTrackStatus: String, Codable, Equatable, Sendable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
}

/// Extended persisted record for a locally stored track. The original
/// `LocalTrackRecord` fields (trackID, originalURL, localPath) are kept as the
/// minimal contract; this richer record carries status and metadata.
public struct LocalTrackDetails: Codable, Equatable, Sendable {
    public let trackID: Int64
    public let originalURL: URL?
    public let localPath: String?
    public let title: String?
    public let artistName: String?
    public let artworkURL: URL?
    public let duration: Int?
    public let status: LocalTrackStatus
    public let progress: Double
    public let errorMessage: String?
    public let addedAt: Date

    public init(
        trackID: Int64,
        originalURL: URL? = nil,
        localPath: String? = nil,
        title: String? = nil,
        artistName: String? = nil,
        artworkURL: URL? = nil,
        duration: Int? = nil,
        status: LocalTrackStatus = .queued,
        progress: Double = 0,
        errorMessage: String? = nil,
        addedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.trackID = trackID
        self.originalURL = originalURL
        self.localPath = localPath
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.duration = duration
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
        self.addedAt = addedAt
    }

    public var isPlayableOffline: Bool {
        status == .completed && localPath != nil
    }
}

/// An ordered local collection. `trackIDs` are references into the shared
/// track store — never file copies.
public struct LocalPlaylistRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var remoteURN: String?
    public var isLocalOnly: Bool
    public var trackIDs: [Int64]

    public init(
        id: UUID = UUID(),
        title: String,
        remoteURN: String? = nil,
        isLocalOnly: Bool = true,
        trackIDs: [Int64] = []
    ) {
        self.id = id
        self.title = title
        self.remoteURN = remoteURN
        self.isLocalOnly = isLocalOnly
        self.trackIDs = trackIDs
    }
}

/// The full local-library persistence boundary. The SwiftData adapter in the
/// app target implements this; tests use an in-memory fake.
public protocol LocalLibraryStore: Sendable {
    // Tracks
    func track(withID trackID: Int64) async throws -> LocalTrackDetails?
    func allTracks() async throws -> [LocalTrackDetails]
    func trackIDs() async throws -> Set<Int64>
    func saveTrack(_ track: LocalTrackDetails) async throws
    func deleteTrack(_ trackID: Int64) async throws

    // Playlist references (for the delete warning)
    func playlistTitlesReferencing(trackID: Int64) async throws -> [String]

    // Playlists
    func playlists() async throws -> [LocalPlaylistRecord]
    func playlist(withID id: UUID) async throws -> LocalPlaylistRecord?
    func savePlaylist(_ playlist: LocalPlaylistRecord) async throws
    func deletePlaylist(_ id: UUID) async throws
    func moveEntry(in playlistID: UUID, from source: Int, to destination: Int) async throws
}
