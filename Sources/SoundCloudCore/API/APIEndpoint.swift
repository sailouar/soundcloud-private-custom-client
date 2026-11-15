import Foundation

public enum HTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// How an endpoint's response may be used. No documented Phase 1 endpoint grants
/// an offline file, so `allowsOfflineFile` is always false.
public enum EndpointDisposition: String, Equatable, Sendable {
    case read
    case write
    case streamOnly

    /// Streaming is playback, not download authorization. Keeping this in the
    /// endpoint type prevents a resolved stream URL from becoming a file.
    public var allowsOfflineFile: Bool { false }
}

/// The documented operations the client may request. Paths and methods match
/// the official OpenAPI document at `developers.soundcloud.com/docs/api/explorer`
/// (accessed 2026-11-15); there is no album search and no download endpoint.
public enum APIEndpointKind: String, CaseIterable, Sendable {
    case authenticatedProfile
    case searchTracks
    case searchUsers
    case searchPlaylists
    case track
    case user
    case playlist
    case likedTracks
    case ownPlaylists
    case likeTrack
    case unlikeTrack
    case followUser
    case unfollowUser
    case trackStreams
    case resolveURL
    case disconnect

    public var method: HTTPMethod {
        switch self {
        case .authenticatedProfile, .searchTracks, .searchUsers, .searchPlaylists,
             .track, .user, .playlist, .likedTracks, .ownPlaylists, .trackStreams,
             .resolveURL:
            return .get
        case .likeTrack, .disconnect:
            return .post
        case .followUser:
            return .put
        case .unlikeTrack, .unfollowUser:
            return .delete
        }
    }

    public var pathTemplate: String {
        switch self {
        case .authenticatedProfile:
            return "/me"
        case .searchTracks:
            return "/tracks"
        case .searchUsers:
            return "/users"
        case .searchPlaylists:
            return "/playlists"
        case .track:
            return "/tracks/{track_urn}"
        case .user:
            return "/users/{user_urn}"
        case .playlist:
            return "/playlists/{playlist_urn}"
        case .likedTracks:
            return "/me/likes/tracks"
        case .ownPlaylists:
            return "/me/playlists"
        case .likeTrack:
            return "/likes/tracks/{track_urn}"
        case .unlikeTrack:
            return "/likes/tracks/{track_urn}"
        case .followUser:
            return "/me/followings/{user_urn}"
        case .unfollowUser:
            return "/me/followings/{user_urn}"
        case .trackStreams:
            return "/tracks/{track_urn}/streams"
        case .resolveURL:
            return "/resolve"
        case .disconnect:
            return "/disconnect"
        }
    }

    public var disposition: EndpointDisposition {
        switch self {
        case .likeTrack, .unlikeTrack, .followUser, .unfollowUser, .disconnect:
            return .write
        case .trackStreams:
            return .streamOnly
        case .authenticatedProfile, .searchTracks, .searchUsers, .searchPlaylists,
             .track, .user, .playlist, .likedTracks, .ownPlaylists, .resolveURL:
            return .read
        }
    }

    public var pathParameters: [String] {
        switch self {
        case .track, .likeTrack, .unlikeTrack, .trackStreams:
            return ["track_urn"]
        case .user, .followUser, .unfollowUser:
            return ["user_urn"]
        case .playlist:
            return ["playlist_urn"]
        case .authenticatedProfile, .searchTracks, .searchUsers, .searchPlaylists,
             .likedTracks, .ownPlaylists, .resolveURL, .disconnect:
            return []
        }
    }
}

public enum APIEndpointError: Error, Equatable, Sendable {
    case missingPathParameter(String)
    case unexpectedPathParameter(String)
    case invalidPathParameter(String)
    case invalidQueryParameter(String)
    case missingAccessToken
    case invalidBaseURL
    case insecureBaseURL
    case unofficialHost(String)
}

/// A validated, authenticated API request target. Requests always use
/// `https://api.soundcloud.com` and `Authorization: OAuth <access token>`.
public struct APIEndpoint: Equatable, Sendable {
    public static let defaultBaseURL = URL(string: "https://api.soundcloud.com")!

    public let kind: APIEndpointKind
    public let method: HTTPMethod
    public let path: String
    public let query: [String: String]
    public let disposition: EndpointDisposition

    /// Every documented SoundCloud endpoint requires the authorization header.
    public var requiresAuthentication: Bool { true }

    public init(
        kind: APIEndpointKind,
        parameters: [String: String] = [:],
        query: [String: String] = [:]
    ) throws {
        for name in parameters.keys where !kind.pathParameters.contains(name) {
            throw APIEndpointError.unexpectedPathParameter(name)
        }

        var path = kind.pathTemplate
        for name in kind.pathParameters {
            guard let value = parameters[name] else {
                throw APIEndpointError.missingPathParameter(name)
            }
            try APIEndpoint.validatePathParameter(value, name: name)
            path = path.replacingOccurrences(of: "{\(name)}", with: value)
        }

        try APIEndpoint.validateQuery(query)

        self.kind = kind
        self.method = kind.method
        self.path = path
        self.query = query
        self.disposition = kind.disposition
    }

    public func url(relativeTo baseURL: URL = APIEndpoint.defaultBaseURL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIEndpointError.invalidBaseURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw APIEndpointError.insecureBaseURL
        }
        let host = components.host?.lowercased() ?? ""
        guard host == "soundcloud.com" || host.hasSuffix(".soundcloud.com") else {
            throw APIEndpointError.unofficialHost(host)
        }

        components.path = path
        components.queryItems = query.isEmpty
            ? nil
            : query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw APIEndpointError.invalidBaseURL
        }
        return url
    }

    /// Builds the authenticated request. An empty token is rejected rather than
    /// producing a request that would silently fail with 401.
    public func urlRequest(
        accessToken: String,
        baseURL: URL = APIEndpoint.defaultBaseURL
    ) throws -> URLRequest {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIEndpointError.missingAccessToken
        }
        var request = URLRequest(url: try url(relativeTo: baseURL))
        request.httpMethod = method.rawValue
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        return request
    }

    private static let allowedPathParameterScalars = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-:._"
    )

    private static func validatePathParameter(_ value: String, name: String) throws {
        guard !value.isEmpty else {
            throw APIEndpointError.invalidPathParameter(name)
        }
        guard value.unicodeScalars.allSatisfy({ allowedPathParameterScalars.contains($0) }) else {
            throw APIEndpointError.invalidPathParameter(name)
        }
        guard !value.contains("..") else {
            throw APIEndpointError.invalidPathParameter(name)
        }
    }

    private static func validateQuery(_ query: [String: String]) throws {
        for (name, value) in query {
            guard !name.isEmpty else {
                throw APIEndpointError.invalidQueryParameter(name)
            }
            let controlCharacters = CharacterSet.controlCharacters
            let hasControlCharacter = value.unicodeScalars.contains(where: { controlCharacters.contains($0) })
                || name.unicodeScalars.contains(where: { controlCharacters.contains($0) })
            guard !hasControlCharacter else {
                throw APIEndpointError.invalidQueryParameter(name)
            }
        }
    }
}

/// Operations that the reviewed official material does not support. They are
/// modelled as typed refusals so no caller can construct a request for them.
public enum UnsupportedAPIOperation: String, CaseIterable, Sendable {
    case albumSearch
    case generalDownload
    case originalUploadFileDownload
    case adRemoval
    case undocumentedMediaURLExtraction
    case contentProtectionCircumvention
    case webPageHarvesting
    case unpermittedDownloading

    public var reason: String {
        switch self {
        case .albumSearch:
            return "The documented API searches tracks, users, and playlists, not albums."
        case .generalDownload:
            return "No general offline-download endpoint is documented."
        case .originalUploadFileDownload:
            return "The API exposes transcoded streams, not the original upload file."
        case .adRemoval:
            return "The API does not expose advertising controls."
        case .undocumentedMediaURLExtraction:
            return "Media locations must come from documented API responses only."
        case .contentProtectionCircumvention:
            return "Content protection and access controls must not be circumvented."
        case .webPageHarvesting:
            return "Data comes from the documented API, not from parsing web pages."
        case .unpermittedDownloading:
            return "Downloads require explicit official authorization per track."
        }
    }
}

public enum APIRequestTarget: Equatable, Sendable {
    case documented(APIEndpointKind)
    case unsupported(UnsupportedAPIOperation)
}

public enum APIPolicyError: Error, Equatable, Sendable {
    case unsupportedOperation(UnsupportedAPIOperation)
}

extension APIEndpoint {
    public static func resolve(
        _ target: APIRequestTarget,
        parameters: [String: String] = [:],
        query: [String: String] = [:]
    ) throws -> APIEndpoint {
        switch target {
        case .documented(let kind):
            return try APIEndpoint(kind: kind, parameters: parameters, query: query)
        case .unsupported(let operation):
            throw APIPolicyError.unsupportedOperation(operation)
        }
    }
}

extension APIError {
    public var httpStatusCode: Int? {
        if case .httpStatus(let status, _) = self {
            return status
        }
        return nil
    }

    public var isAuthenticationFailure: Bool { httpStatusCode == 401 }
    public var isPermissionFailure: Bool { httpStatusCode == 403 }

    /// 429 and transient gateway/server failures may be retried with backoff.
    public var isRetryable: Bool {
        guard let status = httpStatusCode else { return false }
        return status == 429 || status == 500 || status == 503 || status == 504
    }
}
