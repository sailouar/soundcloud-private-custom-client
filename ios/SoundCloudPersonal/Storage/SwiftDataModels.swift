import Foundation
import SwiftData

// MARK: - SwiftData entities
//
// File ownership lives on the track entity: one row per SoundCloud track ID,
// one file on disk. Playlists reference tracks through entry rows, so
// deleting a playlist cascades its entries but never the track files, and
// deleting a track is intercepted by the store to clean up references first.

@Model
final class LocalTrackEntity {
    @Attribute(.unique) var trackID: Int64
    var originalURL: URL?
    var localPath: String?
    var title: String?
    var artistName: String?
    var artworkURL: URL?
    var duration: Int?
    var status: String
    var progress: Double
    var errorMessage: String?
    var addedAt: Date

    @Relationship(inverse: \LocalPlaylistEntry.track)
    var entries: [LocalPlaylistEntry]?

    init(
        trackID: Int64,
        originalURL: URL? = nil,
        localPath: String? = nil,
        title: String? = nil,
        artistName: String? = nil,
        artworkURL: URL? = nil,
        duration: Int? = nil,
        status: String = LocalTrackStatus.queued.rawValue,
        progress: Double = 0,
        errorMessage: String? = nil,
        addedAt: Date = Date()
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
}

@Model
final class LocalPlaylistEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var remoteURN: String?
    var isLocalOnly: Bool

    @Relationship(deleteRule: .cascade, inverse: \LocalPlaylistEntry.playlist)
    var entries: [LocalPlaylistEntry]?

    init(
        id: UUID = UUID(),
        title: String,
        remoteURN: String? = nil,
        isLocalOnly: Bool = true
    ) {
        self.id = id
        self.title = title
        self.remoteURN = remoteURN
        self.isLocalOnly = isLocalOnly
    }
}

@Model
final class LocalPlaylistEntry {
    var index: Int

    @Relationship(inverse: \LocalTrackEntity.entries)
    var track: LocalTrackEntity?

    @Relationship(inverse: \LocalPlaylistEntity.entries)
    var playlist: LocalPlaylistEntity?

    init(index: Int = 0, track: LocalTrackEntity? = nil, playlist: LocalPlaylistEntity? = nil) {
        self.index = index
        self.track = track
        self.playlist = playlist
    }
}
