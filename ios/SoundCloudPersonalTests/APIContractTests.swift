import Foundation
import XCTest
@testable import SoundCloudCore

final class APIContractTests: XCTestCase {
    func testEveryDocumentedEndpointUsesOfficialHostAndOAuthHeader() throws {
        XCTAssertEqual(APIEndpoint.defaultBaseURL, OAuthConfiguration.apiBaseURL)

        for kind in APIEndpointKind.allCases {
            let endpoint = try APIEndpoint(kind: kind, parameters: pathParameters(for: kind))
            let request = try endpoint.urlRequest(accessToken: "access-token")

            XCTAssertEqual(request.url?.scheme, "https", "\(kind) must use https")
            XCTAssertEqual(request.url?.host, "api.soundcloud.com", "\(kind) must use the official host")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "OAuth access-token",
                "\(kind) must use the documented OAuth header"
            )
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Accept"),
                "application/json; charset=utf-8"
            )
            XCTAssertTrue(endpoint.requiresAuthentication)
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Password"))
        }
    }

    func testDocumentedSearchPathsMatchTheOpenAPIResources() throws {
        XCTAssertEqual(try APIEndpoint(kind: .searchTracks).path, "/tracks")
        XCTAssertEqual(try APIEndpoint(kind: .searchUsers).path, "/users")
        XCTAssertEqual(try APIEndpoint(kind: .searchPlaylists).path, "/playlists")
        XCTAssertEqual(try APIEndpoint(kind: .authenticatedProfile).path, "/me")
        XCTAssertEqual(
            try APIEndpoint(kind: .track, parameters: ["track_urn": "urn:soundcloud:tracks:1"]).path,
            "/tracks/urn:soundcloud:tracks:1"
        )
        XCTAssertEqual(
            try APIEndpoint(kind: .likeTrack, parameters: ["track_urn": "1"]).method,
            .post
        )
        XCTAssertEqual(
            try APIEndpoint(kind: .followUser, parameters: ["user_urn": "9"]).method,
            .put
        )
    }

    func testStreamResponsesAreNeverOfflineFiles() throws {
        let streams = try APIEndpoint(kind: .trackStreams, parameters: ["track_urn": "1"])
        XCTAssertEqual(streams.disposition, .streamOnly)
        XCTAssertFalse(streams.disposition.allowsOfflineFile)

        for kind in APIEndpointKind.allCases {
            XCTAssertFalse(
                kind.disposition.allowsOfflineFile,
                "\(kind) must not claim an offline file in Phase 1"
            )
        }
    }

    func testPathParameterInjectionIsRejected() {
        let unsafeValues = [
            "../me",
            "1/streams",
            "1?client_id=other",
            "1#fragment",
            "urn:soundcloud:tracks:1/../../me",
            "1 2",
            ""
        ]

        for value in unsafeValues {
            XCTAssertThrowsError(
                try APIEndpoint(kind: .track, parameters: ["track_urn": value]),
                "Expected rejection for \(value)"
            )
        }
    }

    func testMissingUnexpectedAndInvalidParametersAreTyped() {
        XCTAssertThrowsError(try APIEndpoint(kind: .track)) {
            XCTAssertEqual($0 as? APIEndpointError, .missingPathParameter("track_urn"))
        }
        XCTAssertThrowsError(
            try APIEndpoint(kind: .authenticatedProfile, parameters: ["track_urn": "1"])
        ) { XCTAssertEqual($0 as? APIEndpointError, .unexpectedPathParameter("track_urn")) }
        XCTAssertThrowsError(
            try APIEndpoint(kind: .searchTracks, query: ["": "value"])
        ) { XCTAssertEqual($0 as? APIEndpointError, .invalidQueryParameter("")) }
    }

    func testEmptyAccessTokenIsRejected() {
        XCTAssertThrowsError(
            try APIEndpoint(kind: .authenticatedProfile).urlRequest(accessToken: "  ")
        ) { XCTAssertEqual($0 as? APIEndpointError, .missingAccessToken) }
    }

    func testUnofficialOrInsecureBaseURLsAreRejected() throws {
        let endpoint = try APIEndpoint(kind: .authenticatedProfile)

        XCTAssertThrowsError(
            try endpoint.url(relativeTo: URL(string: "http://api.soundcloud.com")!)
        ) { XCTAssertEqual($0 as? APIEndpointError, .insecureBaseURL) }

        XCTAssertThrowsError(
            try endpoint.url(relativeTo: URL(string: "https://api.example.com")!)
        ) { XCTAssertEqual($0 as? APIEndpointError, .unofficialHost("api.example.com")) }

        XCTAssertThrowsError(
            try endpoint.url(relativeTo: URL(string: "https://evilsoundcloud.com")!)
        ) { XCTAssertEqual($0 as? APIEndpointError, .unofficialHost("evilsoundcloud.com")) }
    }

    func testQueryParametersAreSortedAndEncoded() throws {
        let endpoint = try APIEndpoint(
            kind: .searchTracks,
            query: ["q": "hello world", "limit": "25"]
        )
        let components = try XCTUnwrap(
            URLComponents(url: try endpoint.url(), resolvingAgainstBaseURL: false)
        )

        XCTAssertEqual(components.percentEncodedQuery, "limit=25&q=hello%20world")
    }

    func testUndocumentedOperationsReturnTypedPolicyErrors() {
        for operation in UnsupportedAPIOperation.allCases {
            XCTAssertFalse(operation.reason.isEmpty)
            XCTAssertThrowsError(try APIEndpoint.resolve(.unsupported(operation))) { error in
                XCTAssertEqual(error as? APIPolicyError, .unsupportedOperation(operation))
            }
        }
    }

    func testNoDownloadOrAlbumEndpointIsRepresentedAsSupported() {
        for kind in APIEndpointKind.allCases {
            let path = kind.pathTemplate.lowercased()
            XCTAssertFalse(path.contains("download"), "\(kind) exposes an undocumented download path")
            XCTAssertFalse(path.contains("album"), "\(kind) exposes an unsupported album path")
            XCTAssertFalse(path.contains("/search"), "\(kind) uses an undocumented search alias")
        }

        let kindNames = Set(APIEndpointKind.allCases.map(\.rawValue))
        XCTAssertFalse(kindNames.contains("albumSearch"))
        XCTAssertFalse(kindNames.contains("download"))
    }

    func testStatusCodesClassifyAuthenticationPermissionAndRetry() {
        XCTAssertTrue(APIError.httpStatus(401, message: nil).isAuthenticationFailure)
        XCTAssertTrue(APIError.httpStatus(403, message: nil).isPermissionFailure)
        XCTAssertEqual(APIError.httpStatus(404, message: "nope").httpStatusCode, 404)

        for status in [429, 500, 503, 504] {
            XCTAssertTrue(
                APIError.httpStatus(status, message: nil).isRetryable,
                "\(status) should be retryable"
            )
        }
        for status in [400, 401, 403, 404, 406, 422] {
            XCTAssertFalse(
                APIError.httpStatus(status, message: nil).isRetryable,
                "\(status) should not be retryable"
            )
        }
        XCTAssertFalse(APIError.transport("offline").isRetryable)
        XCTAssertFalse(APIError.decoding("bad").isAuthenticationFailure)
    }

    func testDocumentedSourceContainsNoPasswordTransport() throws {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDirectory = testDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SoundCloudCore")

        let files = ["Auth/AuthenticationService.swift", "API/APIEndpoint.swift"]
        for file in files {
            let contents = try String(
                contentsOf: sourceDirectory.appendingPathComponent(file),
                encoding: .utf8
            ).lowercased()
            XCTAssertFalse(contents.contains("password="), "\(file) must not send passwords")
            XCTAssertFalse(contents.contains("grant_type=password"), "\(file) must not use a password grant")
        }
    }

    private func pathParameters(for kind: APIEndpointKind) -> [String: String] {
        Dictionary(uniqueKeysWithValues: kind.pathParameters.map { ($0, "1") })
    }
}
