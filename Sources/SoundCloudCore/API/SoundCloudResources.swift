import Foundation

// MARK: - Resource client
//
// Read/write access to the documented SoundCloud resources. Every call goes
// through `APIEndpoint`, so host, scheme, header, and path-parameter
// validation are enforced in exactly one place. Stream resolution is
// disposition `streamOnly`: the resolved media URL is returned for playback
// and is never exposed as a download source.

public struct SoundCloudResources: Sendable {
    private let transport: any ResourceTransport
    private let tokens: any AccessTokenProvider
    private let decoder: JSONDecoder

    public init(transport: any ResourceTransport, tokens: any AccessTokenProvider) {
        self.transport = transport
        self.tokens = tokens
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: URN helpers

    public static func trackURN(id: Int64) -> String { "urn:soundcloud:tracks:\(id)" }
    public static func userURN(id: Int64) -> String { "urn:soundcloud:users:\(id)" }
    public static func playlistURN(id: Int64) -> String { "urn:soundcloud:playlists:\(id)" }

    // MARK: Request plumbing

    private func perform(
        _ kind: APIEndpointKind,
        parameters: [String: String] = [:],
        query: [String: String] = [:]
    ) async throws -> HTTPResponse {
        let endpoint = try APIEndpoint(kind: kind, parameters: parameters, query: query)
        let token = try await tokens.currentAccessToken()
        let request = try endpoint.urlRequest(accessToken: token)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: response.body)
            let message = payload?.message ?? payload?.errors?.first?.message
            throw APIError.httpStatus(response.statusCode, message: message)
        }
        return response
    }

    private func decode<T: Decodable>(_ type: T.Type, _ kind: APIEndpointKind, parameters: [String: String] = [:], query: [String: String] = [:]) async throws -> T {
        let response = try await perform(kind, parameters: parameters, query: query)
        do {
            return try decoder.decode(type, from: response.body)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func performWrite(
        _ kind: APIEndpointKind,
        parameters: [String: String] = [:]
    ) async throws {
        _ = try await perform(kind, parameters: parameters)
    }

    // MARK: Account

    public func me() async throws -> SCUser {
        try await decode(SCUser.self, .authenticatedProfile)
    }

    // MARK: Search and browse

    public func searchTracks(query: String, limit: Int = 20, offset: Int = 0) async throws -> SCCollection<SCTrack> {
        try await decode(
            SCCollection<SCTrack>.self,
            .searchTracks,
            query: ["q": query, "limit": "\(limit)", "offset": "\(offset)"]
        )
    }

    public func searchUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> SCCollection<SCUser> {
        try await decode(
            SCCollection<SCUser>.self,
            .searchUsers,
            query: ["q": query, "limit": "\(limit)", "offset": "\(offset)"]
        )
    }

    public func searchPlaylists(query: String, limit: Int = 20, offset: Int = 0) async throws -> SCCollection<SCPlaylist> {
        try await decode(
            SCCollection<SCPlaylist>.self,
            .searchPlaylists,
            query: ["q": query, "limit": "\(limit)", "offset": "\(offset)"]
        )
    }

    public func track(urn: String) async throws -> SCTrack {
        try await decode(SCTrack.self, .track, parameters: ["track_urn": urn])
    }

    public func user(urn: String) async throws -> SCUser {
        try await decode(SCUser.self, .user, parameters: ["user_urn": urn])
    }

    public func playlist(urn: String) async throws -> SCPlaylist {
        try await decode(SCPlaylist.self, .playlist, parameters: ["playlist_urn": urn])
    }

    public func resolve(url: String) async throws -> SCTrack {
        try await decode(SCTrack.self, .resolveURL, query: ["url": url])
    }

    // MARK: Account library

    public func likedTracks(limit: Int = 50, offset: Int = 0) async throws -> SCCollection<SCTrack> {
        try await decode(
            SCCollection<SCTrack>.self,
            .likedTracks,
            query: ["limit": "\(limit)", "offset": "\(offset)"]
        )
    }

    public func ownPlaylists(limit: Int = 50, offset: Int = 0) async throws -> SCCollection<SCPlaylist> {
        try await decode(
            SCCollection<SCPlaylist>.self,
            .ownPlaylists,
            query: ["limit": "\(limit)", "offset": "\(offset)"]
        )
    }

    // MARK: Social actions (write operations)

    public func likeTrack(urn: String) async throws {
        try await performWrite(.likeTrack, parameters: ["track_urn": urn])
    }

    public func unlikeTrack(urn: String) async throws {
        try await performWrite(.unlikeTrack, parameters: ["track_urn": urn])
    }

    public func followUser(urn: String) async throws {
        try await performWrite(.followUser, parameters: ["user_urn": urn])
    }

    public func unfollowUser(urn: String) async throws {
        try await performWrite(.unfollowUser, parameters: ["user_urn": urn])
    }

    // MARK: Streaming

    /// Resolves a playable stream URL for a track. The result is stream-only:
    /// it may be handed to a player and must never be persisted as an
    /// offline file. Returns nil when the track has no usable transcoding.
    public func streamURL(for track: SCTrack) async throws -> URL? {
        guard track.streamable == true else { return nil }
        let urn = track.urn ?? SoundCloudResources.trackURN(id: track.id)

        // Prefer the transcodings embedded in the track resource.
        if let transcoding = track.media?.preferredTranscoding, let apiURL = transcoding.url {
            return try await resolveStream(apiURL: apiURL)
        }

        // Fall back to the documented /streams endpoint, whose collection
        // entries carry transcoding API URLs.
        let response = try await perform(.trackStreams, parameters: ["track_urn": urn])
        let collection = try? decoder.decode(SCCollection<SCTranscoding>.self, from: response.body)
        guard let transcodings = collection?.collection, let preferred = SCMedia(transcodings: transcodings).preferredTranscoding, let apiURL = preferred.url else {
            return nil
        }
        return try await resolveStream(apiURL: apiURL)
    }

    private func resolveStream(apiURL: URL) async throws -> URL? {
        var request = URLRequest(url: apiURL)
        let token = try await tokens.currentAccessToken()
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: response.body)
            throw APIError.httpStatus(response.statusCode, message: payload?.message)
        }
        let resolved = try decoder.decode(SCResolvedStream.self, from: response.body)
        return resolved.url
    }
}
