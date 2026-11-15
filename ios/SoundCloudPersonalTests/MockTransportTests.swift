import XCTest
@testable import SoundCloudCore

final class MockTransportTests: XCTestCase {
    func testFixtureLookupUsesMethodAndPath() throws {
        let expected = try MockAPITransport.json(state: .temporarilyUnavailable)
        let transport = MockAPITransport(fixtures: [
            .init(method: "get", path: "/fixture"): .success(expected)
        ])

        XCTAssertEqual(try transport.send(method: "GET", path: "/fixture"), expected)
    }

    func testMissingFixtureIsAnExplicitTransportError() {
        let transport = MockAPITransport(fixtures: [:])

        XCTAssertThrowsError(try transport.send(method: "GET", path: "/missing")) { error in
            XCTAssertEqual(
                error as? APIError,
                .transport("No fixture for GET /missing")
            )
        }
    }
}
