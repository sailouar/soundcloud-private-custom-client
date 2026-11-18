import XCTest
@testable import SoundCloudCore

final class ResourceModelTests: XCTestCase {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func testTrackDecodesFromDocumentedShape() throws {
        let json = """
        {
          "id": 123,
          "urn": "urn:soundcloud:tracks:123",
          "title": "Fixture Track",
          "permalink_url": "https://soundcloud.com/artist/fixture-track",
          "artwork_url": "https://i1.sndcdn.com/artworks-000-large.jpg",
          "duration": 182000,
          "user": { "id": 7, "username": "artist", "avatar_url": "https://i1.sndcdn.com/avatars-000-large.jpg" },
          "likes_count": 42,
          "playback_count": 1000,
          "genre": "Electronic",
          "streamable": true,
          "downloadable": true,
          "download_url": "https://api.soundcloud.com/tracks/123/download",
          "media": { "transcodings": [
            { "url": "https://api.soundcloud.com/tracks/123/streams/hls", "format": { "protocol": "hls", "mime_type": "audio/mpeg" } },
            { "url": "https://api.soundcloud.com/tracks/123/streams/progressive", "format": { "protocol": "progressive", "mime_type": "audio/mpeg" } }
          ] }
        }
        """.data(using: .utf8)!
        let track = try decoder.decode(SCTrack.self, from: json)
        XCTAssertEqual(track.id, 123)
        XCTAssertEqual(track.title, "Fixture Track")
        XCTAssertEqual(track.user?.username, "artist")
        XCTAssertTrue(track.streamable == true)
        XCTAssertTrue(track.isDownloadPermittedByUploader)
        XCTAssertEqual(track.downloadUrl?.absoluteString, "https://api.soundcloud.com/tracks/123/download")
        XCTAssertEqual(track.durationText, "3:02")
        // Progressive transcoding is preferred over HLS for playback.
        XCTAssertEqual(
            track.media?.preferredTranscoding?.url?.absoluteString,
            "https://api.soundcloud.com/tracks/123/streams/progressive"
        )
    }

    func testTrackWithoutDownloadPermissionIsNotAuthorized() throws {
        let json = """
        { "id": 5, "title": "Stream only", "streamable": true, "downloadable": false }
        """.data(using: .utf8)!
        let track = try decoder.decode(SCTrack.self, from: json)
        let entitlement = TrackDownloadEntitlement(track: track)
        XCTAssertFalse(entitlement.isAuthorized)
        XCTAssertNotNil(entitlement.denialReason)
    }

    func testCollectionDecodesWithNextHref() throws {
        let json = """
        { "collection": [ { "id": 1, "title": "A" }, { "id": 2, "title": "B" } ],
          "next_href": "https://api.soundcloud.com/tracks?q=x&offset=20" }
        """.data(using: .utf8)!
        let collection = try decoder.decode(SCCollection<SCTrack>.self, from: json)
        XCTAssertEqual(collection.collection?.count, 2)
        XCTAssertEqual(collection.nextHref?.absoluteString, "https://api.soundcloud.com/tracks?q=x&offset=20")
    }

    func testPlaylistDecodesEmbeddedTracks() throws {
        let json = """
        { "id": 9, "title": "Mix", "track_count": 2,
          "tracks": [ { "id": 1 }, { "id": 2 } ] }
        """.data(using: .utf8)!
        let playlist = try decoder.decode(SCPlaylist.self, from: json)
        XCTAssertEqual(playlist.trackCount, 2)
        XCTAssertEqual(playlist.tracks?.count, 2)
    }

    func testArtworkSizeRewrite() throws {
        let url = URL(string: "https://i1.sndcdn.com/artworks-000-large.jpg")!
        XCTAssertEqual(
            ArtworkSize.rewrite(url, to: .xlarge)?.absoluteString,
            "https://i1.sndcdn.com/artworks-000-t500x500.jpg"
        )
        XCTAssertNil(SCUser(id: 1).avatarURL(size: .large))
    }

    func testResolvedStreamDecodes() throws {
        let json = #"{ "url": "https://cf-media.sndcdn.com/abc" }"#.data(using: .utf8)!
        let resolved = try decoder.decode(SCResolvedStream.self, from: json)
        XCTAssertEqual(resolved.url?.host, "cf-media.sndcdn.com")
    }
}
