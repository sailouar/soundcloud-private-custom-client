import Foundation
import SoundCloudCore
import SwiftData

/// SwiftData-backed implementation of the core `LocalLibraryStore` boundary.
/// All mutations run on this actor so the ModelContext is never touched from
/// multiple threads.
actor SwiftDataLocalStore: LocalLibraryStore {
    private let context: ModelContext

    init() throws {
        let schema = Schema([
            LocalTrackEntity.self,
            LocalPlaylistEntity.self,
            LocalPlaylistEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    init(inMemory: Bool) throws {
        let schema = Schema([
            LocalTrackEntity.self,
            LocalPlaylistEntity.self,
            LocalPlaylistEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    // MARK: Tracks

    func track(withID trackID: Int64) async throws -> LocalTrackDetails? {
        var descriptor = FetchDescriptor<LocalTrackEntity>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(details(from:))
    }

    func allTracks() async throws -> [LocalTrackDetails] {
        let descriptor = FetchDescriptor<LocalTrackEntity>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(details(from:))
    }

    func trackIDs() async throws -> Set<Int64> {
        let descriptor = FetchDescriptor<LocalTrackEntity>()
        return Set(try context.fetch(descriptor).map(\.trackID))
    }

    func saveTrack(_ track: LocalTrackDetails) async throws {
        let entity: LocalTrackEntity
        var descriptor = FetchDescriptor<LocalTrackEntity>(
            predicate: #Predicate { $0.trackID == track.trackID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            entity = existing
        } else {
            entity = LocalTrackEntity(trackID: track.trackID)
            context.insert(entity)
        }
        entity.originalURL = track.originalURL
        entity.localPath = track.localPath
        entity.title = track.title
        entity.artistName = track.artistName
        entity.artworkURL = track.artworkURL
        entity.duration = track.duration
        entity.status = track.status.rawValue
        entity.progress = track.progress
        entity.errorMessage = track.errorMessage
        if entity.addedAt == Date(timeIntervalSince1970: 0) {
            entity.addedAt = track.addedAt == Date(timeIntervalSince1970: 0) ? Date() : track.addedAt
        }
        try context.save()
    }

    func deleteTrack(_ trackID: Int64) async throws {
        var descriptor = FetchDescriptor<LocalTrackEntity>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }

        // Remove playlist references first; the file itself is deleted by the
        // download layer, not by the store.
        let entries = entity.entries
        for entry in entries {
            context.delete(entry)
        }
        context.delete(entity)
        try context.save()
    }

    // MARK: References

    func playlistTitlesReferencing(trackID: Int64) async throws -> [String] {
        var descriptor = FetchDescriptor<LocalTrackEntity>(
            predicate: #Predicate { $0.trackID == trackID }
        )
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return [] }
        return entity.entries
            .compactMap { $0.playlist?.title }
            .sorted()
    }

    // MARK: Playlists

    func playlists() async throws -> [LocalPlaylistRecord] {
        let descriptor = FetchDescriptor<LocalPlaylistEntity>(sortBy: [SortDescriptor(\.title)])
        return try context.fetch(descriptor).map(record(from:))
    }

    func playlist(withID id: UUID) async throws -> LocalPlaylistRecord? {
        var descriptor = FetchDescriptor<LocalPlaylistEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(record(from:))
    }

    func savePlaylist(_ playlist: LocalPlaylistRecord) async throws {
        let entity: LocalPlaylistEntity
        var descriptor = FetchDescriptor<LocalPlaylistEntity>(
            predicate: #Predicate { $0.id == playlist.id }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            entity = existing
        } else {
            entity = LocalPlaylistEntity(id: playlist.id, title: playlist.title)
            context.insert(entity)
        }
        entity.title = playlist.title
        entity.remoteURN = playlist.remoteURN
        entity.isLocalOnly = playlist.isLocalOnly

        // Reconcile entries with the ordered track IDs.
        let existingEntries = entity.entries.sorted { $0.index < $1.index }
        for entry in existingEntries {
            context.delete(entry)
        }
        entity.entries = []
        for (offset, trackID) in playlist.trackIDs.enumerated() {
            var trackDescriptor = FetchDescriptor<LocalTrackEntity>(
                predicate: #Predicate { $0.trackID == trackID }
            )
            trackDescriptor.fetchLimit = 1
            guard let trackEntity = try context.fetch(trackDescriptor).first else { continue }
            let entry = LocalPlaylistEntry(index: offset, track: trackEntity, playlist: entity)
            context.insert(entry)
            entity.entries.append(entry)
        }
        try context.save()
    }

    func deletePlaylist(_ id: UUID) async throws {
        var descriptor = FetchDescriptor<LocalPlaylistEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        // Cascade delete removes the entries; track files are untouched.
        context.delete(entity)
        try context.save()
    }

    func moveEntry(in playlistID: UUID, from source: Int, to destination: Int) async throws {
        guard let playlist = try await playlist(withID: playlistID) else { return }
        var ids = playlist.trackIDs
        guard ids.indices.contains(source), ids.indices.contains(destination) else { return }
        let moved = ids.remove(at: source)
        ids.insert(moved, at: destination)
        var updated = playlist
        updated.trackIDs = ids
        try await savePlaylist(updated)
    }

    // MARK: Mapping

    private func details(from entity: LocalTrackEntity) -> LocalTrackDetails {
        LocalTrackDetails(
            trackID: entity.trackID,
            originalURL: entity.originalURL,
            localPath: entity.localPath,
            title: entity.title,
            artistName: entity.artistName,
            artworkURL: entity.artworkURL,
            duration: entity.duration,
            status: LocalTrackStatus(rawValue: entity.status) ?? .queued,
            progress: entity.progress,
            errorMessage: entity.errorMessage,
            addedAt: entity.addedAt
        )
    }

    private func record(from entity: LocalPlaylistEntity) -> LocalPlaylistRecord {
        let ordered = entity.entries
            .sorted { $0.index < $1.index }
            .compactMap { $0.track?.trackID }
        return LocalPlaylistRecord(
            id: entity.id,
            title: entity.title,
            remoteURN: entity.remoteURN,
            isLocalOnly: entity.isLocalOnly,
            trackIDs: ordered
        )
    }
}
