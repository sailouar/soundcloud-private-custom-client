import Foundation

// MARK: - Playlist synchronization
//
// Pure reconciliation logic between a remote SoundCloud playlist and the
// local library. Rules from the product spec:
//  - tracks already in the local library are skipped, never re-downloaded;
//  - both playlists and tracks reference the single shared local track file;
//  - a local collection mirrors the remote order for the tracks it has.

public struct PlaylistSyncPlan: Equatable, Sendable {
    /// Remote tracks not yet local — these need downloading.
    public let missing: [SCTrack]
    /// Remote tracks already present locally — these are only linked.
    public let alreadyLocal: [SCTrack]

    public init(missing: [SCTrack] = [], alreadyLocal: [SCTrack] = []) {
        self.missing = missing
        self.alreadyLocal = alreadyLocal
    }
}

public enum PlaylistSync {
    /// Computes what a download of `remote` would actually do given the set
    /// of track IDs already stored locally.
    public static func plan(remoteTracks: [SCTrack], localTrackIDs: Set<Int64>) -> PlaylistSyncPlan {
        var missing: [SCTrack] = []
        var alreadyLocal: [SCTrack] = []
        var seen = Set<Int64>()
        for track in remoteTracks {
            guard !seen.contains(track.id) else { continue }
            seen.insert(track.id)
            if localTrackIDs.contains(track.id) {
                alreadyLocal.append(track)
            } else {
                missing.append(track)
            }
        }
        return PlaylistSyncPlan(missing: missing, alreadyLocal: alreadyLocal)
    }

    /// Reconciles a local collection with the current remote playlist: the
    /// local entry order follows the remote order, new remote tracks are
    /// appended (and reported for download), and remote tracks that vanished
    /// are kept locally (removing them from SoundCloud never deletes files).
    public static func reconcile(
        remoteTracks: [SCTrack],
        localPlaylist: LocalPlaylistRecord
    ) -> (updated: LocalPlaylistRecord, newTrackIDs: [Int64]) {
        let remoteIDs = remoteTracks.map(\.id)
        var updated = localPlaylist
        var next: [Int64] = []
        var appended: [Int64] = []

        for id in remoteIDs where !next.contains(id) {
            next.append(id)
        }
        // Local-only additions the user made stay at the end.
        for id in localPlaylist.trackIDs where !next.contains(id) {
            next.append(id)
            appended.append(id)
        }

        updated.trackIDs = next
        let newIDs = remoteIDs.filter { !localPlaylist.trackIDs.contains($0) }
        return (updated, newIDs)
    }
}
