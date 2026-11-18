import XCTest
@testable import SoundCloudCore

final class PlaylistSyncTests: XCTestCase {
    private func track(_ id: Int64, downloadable: Bool = false) -> SCTrack {
        SCTrack(id: id, title: "T\(id)", streamable: true, downloadable: downloadable)
    }

    func testPlanSplitsMissingAndLocal() {
        let remote = [track(1), track(2), track(3), track(1)] // duplicate id collapses
        let plan = PlaylistSync.plan(remoteTracks: remote, localTrackIDs: [2])
        XCTAssertEqual(plan.missing.map(\.id), [1, 3])
        XCTAssertEqual(plan.alreadyLocal.map(\.id), [2])
    }

    func testReconcileFollowsRemoteOrderAndKeepsLocalAdditions() {
        let remote = [track(3), track(1), track(2)]
        var local = LocalPlaylistRecord(title: "Mix", trackIDs: [1, 9])
        let result = PlaylistSync.reconcile(remoteTracks: remote, localPlaylist: local)
        XCTAssertEqual(result.updated.trackIDs, [3, 1, 2, 9])
        XCTAssertEqual(result.newTrackIDs, [3, 2])
        local = result.updated
    }

    func testReconcileNeverDeletesLocalTracksWhenRemoteRemovesThem() {
        let remote = [track(1)]
        let local = LocalPlaylistRecord(title: "Mix", trackIDs: [1, 2])
        let result = PlaylistSync.reconcile(remoteTracks: remote, localPlaylist: local)
        XCTAssertTrue(result.updated.trackIDs.contains(2))
        XCTAssertEqual(result.newTrackIDs, [])
    }
}

final class PlaybackResolverTests: XCTestCase {
    func testResolvesToLocalFileOnlyWhenCompletedWithPath() async throws {
        let store = InMemoryLocalStore(seedTracks: [
            LocalTrackDetails(
                trackID: 1,
                localPath: "/tmp/1.mp3",
                status: .completed,
                progress: 1
            ),
            LocalTrackDetails(trackID: 2, status: .downloading, progress: 0.4)
        ])
        let hit = try await PlaybackResolver.resolve(trackID: 1, library: store)
        XCTAssertEqual(hit, .localFile(path: "/tmp/1.mp3"))
        let downloading = try await PlaybackResolver.resolve(trackID: 2, library: store)
        XCTAssertEqual(downloading, .notLocal)
        let missing = try await PlaybackResolver.resolve(trackID: 99, library: store)
        XCTAssertEqual(missing, .notLocal)
    }
}
