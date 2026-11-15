import Foundation
import XCTest
@testable import SoundCloudCore

final class DownloadAuthorizationTests: XCTestCase {
    func testStreamPlaybackCapabilityProducesNoDownloadRequest() {
        let stream = CapabilityResponse(operation: .streamPlayback, state: .supported)

        XCTAssertEqual(
            DownloadAuthorization(explicitOfficialEntitlement: true)
                .decision(for: stream, trackID: "123"),
            .denied(.notDownloadCapability)
        )
    }

    func testUnknownMissingAndPermissionGatedCapabilitiesAreDenied() {
        let authorization = DownloadAuthorization(explicitOfficialEntitlement: true)
        let permissionGated = CapabilityResponse(
            operation: .downloadAuthorization,
            state: .requiresUserPermission
        )

        XCTAssertEqual(authorization.decision(for: nil, trackID: "123"), .denied(.missingCapability))
        XCTAssertEqual(
            authorization.decision(for: permissionGated, trackID: "123"),
            .denied(.capabilityNotSupported)
        )
        XCTAssertEqual(
            DownloadAuthorization().decision(
                for: CapabilityResponse(operation: .downloadAuthorization, state: .supported),
                trackID: "123"
            ),
            .denied(.noExplicitOfficialEntitlement)
        )
    }

    func testOnlyExplicitlyGrantedOfficialCapabilityCreatesARequest() {
        let permission = CapabilityResponse(operation: .downloadAuthorization, state: .supported)

        XCTAssertEqual(
            DownloadAuthorization(explicitOfficialEntitlement: true)
                .decision(for: permission, trackID: "123"),
            .authorized(DownloadRequest(trackID: "123"))
        )
    }

    func testProductionSourceContainsNoProhibitedImplementationPaths() throws {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDirectory = testDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SoundCloudCore")
        guard let enumerator = FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: nil
        ) else {
            XCTFail("Could not enumerate production source")
            return
        }
        let sourceFiles = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let production = try sourceFiles.map {
            try String(contentsOf: $0, encoding: .utf8).lowercased()
        }.joined(separator: "\n")

        let prohibitedImplementationMarkers = [
            "hidden stream url",
            "scraping",
            "drm bypass",
            "access-control bypass",
            "ad skipping",
            "unauthorized downloading"
        ]
        for marker in prohibitedImplementationMarkers {
            XCTAssertFalse(production.contains(marker), "Found prohibited marker: \(marker)")
        }
    }
}
