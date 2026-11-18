import Foundation

// MARK: - Resource models
//
// These mirror the documented SoundCloud OpenAPI resource shapes
// (developers.soundcloud.com/docs/api/explorer). All fields beyond the
// identity are optional so a partial API response still decodes; nothing is
// invented. The resources decoder uses `.convertFromSnakeCase`, so the
// camelCase property names below map to the API's snake_case keys.

/// A SoundCloud user (artist or listener).
public struct SCUser: Codable, Equatable, Sendable, Identifiable {
    public let id: Int64
    public let urn: String?
    public let username: String?
    public let fullName: String?
    public let permalinkURL: URL?
    public let avatarURL: URL?
    public let city: String?
    public let country: String?
    public let description: String?
    public let followersCount: Int?
    public let followingsCount: Int?
    public let trackCount: Int?
    public var playlistCount: Int?

    public init(
        id: Int64,
        urn: String? = nil,
        username: String? = nil,
        fullName: String? = nil,
        permalinkURL: URL? = nil,
        avatarURL: URL? = nil,
        city: String? = nil,
        country: String? = nil,
        description: String? = nil,
        followersCount: Int? = nil,
        followingsCount: Int? = nil,
        trackCount: Int? = nil,
        playlistCount: Int? = nil
    ) {
        self.id = id
        self.urn = urn
        self.username = username
        self.fullName = fullName
        self.permalinkURL = permalinkURL
        self.avatarURL = avatarURL
        self.city = city
        self.country = country
        self.description = description
        self.followersCount = followersCount
        self.followingsCount = followingsCount
        self.trackCount = trackCount
        self.playlistCount = playlistCount
    }

    /// SoundCloud serves several artwork sizes through the same URL by
    /// swapping the `-large` suffix. This never fabricates a URL for a user
    /// without artwork.
    public func avatarURL(size: ArtworkSize) -> URL? {
        guard let avatarURL else { return nil }
        return ArtworkSize.rewrite(avatarURL, to: size)
    }
}

/// A track. `downloadable` is the uploader's own documented permission flag;
/// it is the only signal the client trusts for offline-file authorization.
public struct SCTrack: Codable, Equatable, Sendable, Identifiable {
    public let id: Int64
    public let urn: String?
    public let title: String?
    public let permalinkURL: URL?
    public let artworkURL: URL?
    /// Milliseconds.
    public let duration: Int?
    public let user: SCUser?
    public let likesCount: Int?
    public let playbackCount: Int?
    public let genre: String?
    public let description: String?
    public let streamable: Bool?
    public let downloadable: Bool?
    /// Present in an official API response only when SoundCloud itself exposes
    /// a download location for this track. Never constructed or scraped.
    public let downloadURL: URL?
    public let media: SCMedia?

    public init(
        id: Int64,
        urn: String? = nil,
        title: String? = nil,
        permalinkURL: URL? = nil,
        artworkURL: URL? = nil,
        duration: Int? = nil,
        user: SCUser? = nil,
        likesCount: Int? = nil,
        playbackCount: Int? = nil,
        genre: String? = nil,
        description: String? = nil,
        streamable: Bool? = nil,
        downloadable: Bool? = nil,
        downloadURL: URL? = nil,
        media: SCMedia? = nil
    ) {
        self.id = id
        self.urn = urn
        self.title = title
        self.permalinkURL = permalinkURL
        self.artworkURL = artworkURL
        self.duration = duration
        self.user = user
        self.likesCount = likesCount
        self.playbackCount = playbackCount
        self.genre = genre
        self.description = description
        self.streamable = streamable
        self.downloadable = downloadable
        self.downloadURL = downloadURL
        self.media = media
    }

    /// The uploader explicitly enabled downloads on this track. This is a
    /// documented boolean on the track resource; playback availability is
    /// never treated as permission.
    public var isDownloadPermittedByUploader: Bool { downloadable == true }

    public func artworkURL(size: ArtworkSize) -> URL? {
        guard let artworkURL else { return nil }
        return ArtworkSize.rewrite(artworkURL, to: size)
    }

    /// Display duration, e.g. "3:42".
    public var durationText: String {
        guard let duration, duration > 0 else { return "--:--" }
        let total = Int(duration) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A playlist (set). `tracks` may be a partial embed depending on the API
/// response; `trackCount` is the authoritative total.
public struct SCPlaylist: Codable, Equatable, Sendable, Identifiable {
    public let id: Int64
    public let urn: String?
    public let title: String?
    public let permalinkURL: URL?
    public let artworkURL: URL?
    public let user: SCUser?
    public let trackCount: Int?
    public let tracks: [SCTrack]?
    public let description: String?

    public init(
        id: Int64,
        urn: String? = nil,
        title: String? = nil,
        permalinkURL: URL? = nil,
        artworkURL: URL? = nil,
        user: SCUser? = nil,
        trackCount: Int? = nil,
        tracks: [SCTrack]? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.urn = urn
        self.title = title
        self.permalinkURL = permalinkURL
        self.artworkURL = artworkURL
        self.user = user
        self.trackCount = trackCount
        self.tracks = tracks
        self.description = description
    }

    public func artworkURL(size: ArtworkSize) -> URL? {
        guard let artworkURL else { return nil }
        return ArtworkSize.rewrite(artworkURL, to: size)
    }
}

/// Track media: transcoded stream locations. Every transcoding URL is an API
/// URL that must be resolved with an authorized GET; the resolved media URL
/// is stream-only and must never be written to disk as an offline file
/// unless the track is explicitly download-authorized through the separate
/// download path.
public struct SCMedia: Codable, Equatable, Sendable {
    public let transcodings: [SCTranscoding]?

    public init(transcodings: [SCTranscoding]? = nil) {
        self.transcodings = transcodings
    }

    /// The preferred transcoding for playback: progressive protocol first,
    /// then any mp3, then anything else.
    public var preferredTranscoding: SCTranscoding? {
        guard let transcodings, !transcodings.isEmpty else { return nil }
        return transcodings.first { $0.format?.protocol == "progressive" }
            ?? transcodings.first { $0.format?.mimeType == "audio/mpeg" }
            ?? transcodings.first
    }
}

public struct SCTranscoding: Codable, Equatable, Sendable, Identifiable {
    public let url: URL?
    public let preset: String?
    public let duration: Int?
    public let snipped: Bool?
    public let format: SCTranscodingFormat?

    public var id: URL? { url }

    public init(url: URL? = nil, preset: String? = nil, duration: Int? = nil, snipped: Bool? = nil, format: SCTranscodingFormat? = nil) {
        self.url = url
        self.preset = preset
        self.duration = duration
        self.snipped = snipped
        self.format = format
    }
}

public struct SCTranscodingFormat: Codable, Equatable, Sendable {
    public let protocol: String?
    public let mimeType: String?

    public init(protocol: String? = nil, mimeType: String? = nil) {
        self.protocol = `protocol`
        self.mimeType = mimeType
    }
}

/// Response of resolving a transcoding URL: the actual media location.
/// Disposition is stream-only.
public struct SCResolvedStream: Codable, Equatable, Sendable {
    public let url: URL?

    public init(url: URL? = nil) {
        self.url = url
    }
}

/// Paginated collection envelope used by search and list endpoints.
public struct SCCollection<T: Codable & Sendable>: Codable, Sendable {
    public let collection: [T]?
    public let nextHref: URL?

    public init(collection: [T]? = nil, nextHref: URL? = nil) {
        self.collection = collection
        self.nextHref = nextHref
    }
}

// MARK: - Artwork sizes

public enum ArtworkSize: String, Sendable, CaseIterable {
    case small = "-t67x67"
    case medium = "-large"
    case large = "-t300x300"
    case xlarge = "-t500x500"

    /// Rewrites a SoundCloud artwork URL to the requested size by replacing
    /// the trailing `-t...x...` / `-large` marker. Returns nil-safe: callers
    /// guard the base URL first.
    static func rewrite(_ url: URL, to size: ArtworkSize) -> URL? {
        var text = url.absoluteString
        for marker in ["-t500x500", "-t300x300", "-large", "-t67x67", "-crop", "-t120x120"] where text.contains(marker) {
            text = text.replacingOccurrences(of: marker, with: size.rawValue)
            return URL(string: text)
        }
        // No known marker: append nothing; keep the original URL.
        return url
    }
}
