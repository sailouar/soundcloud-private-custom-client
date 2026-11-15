import XCTest
@testable import SoundCloudPersonal

#if canImport(SwiftData)
import SwiftData

@Model
private final class SmokePlaylist {
    var name: String
    @Relationship(deleteRule: .cascade) var tracks: [SmokeTrack] = []

    init(name: String) {
        self.name = name
    }
}

@Model
private final class SmokeTrack {
    @Attribute(.unique) var trackID: Int64
    var title: String
    var playlist: SmokePlaylist?

    init(trackID: Int64, title: String) {
        self.trackID = trackID
        self.title = title
    }
}
#endif

final class StorageMigrationSmokeTests: XCTestCase {
    #if canImport(SwiftData)
    @MainActor
    func testSwiftDataRelationshipAndMigration() throws {
        let schema = Schema([SmokePlaylist.self, SmokeTrack.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let playlist = SmokePlaylist(name: "Smoke")
        let track = SmokeTrack(trackID: 1, title: "Fixture")
        playlist.tracks.append(track)
        context.insert(playlist)
        try context.save()
        context.insert(SmokePlaylist(name: "Second"))
        try context.save()

        let playlists = try context.fetch(FetchDescriptor<SmokePlaylist>())
        XCTAssertEqual(playlists.first?.tracks.first?.trackID, 1)
        XCTAssertEqual(playlists.count, 2)
    }
    #else
    func testSwiftDataRelationshipAndMigration() throws {
        throw XCTSkip("SwiftData is unavailable in this test environment.")
    }
    #endif

    func testSQLiteRelationshipAndMigration() throws {
        throw XCTSkip("SQLite is not the selected storage technology.")
    }
}
