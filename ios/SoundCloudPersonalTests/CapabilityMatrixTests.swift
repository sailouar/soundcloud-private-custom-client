import XCTest
@testable import SoundCloudCore

final class CapabilityMatrixTests: XCTestCase {
    func testFixtureTravelsFromTransportThroughAPIIntoTypedRegistryState() throws {
        let operation = CapabilityOperation.trackMetadata
        let response = try MockAPITransport.json(
            state: .supported,
            reason: "Documented metadata operation"
        )
        let transport = MockAPITransport(fixtures: [
            .init(method: operation.method, path: operation.path): .success(response)
        ])

        let result = try SoundCloudAPI(transport: transport).capability(for: operation)

        XCTAssertEqual(result, CapabilityResponse(
            operation: operation,
            state: .supported,
            reason: "Documented metadata operation"
        ))
    }

    func testAllStableStatesDecodeWithoutOptimisticFallback() throws {
        for state in CapabilityState.allCases {
            let operation = CapabilityOperation.streamPlayback
            let response = try MockAPITransport.json(state: state)
            let transport = MockAPITransport(fixtures: [
                .init(method: operation.method, path: operation.path): .success(response)
            ])

            XCTAssertEqual(
                try SoundCloudAPI(transport: transport).capability(for: operation).state,
                state
            )
        }
    }

    func testHTTPErrorAndMessageArePreserved() throws {
        let operation = CapabilityOperation.trackMetadata
        let body = try JSONEncoder().encode(["message": "rate limited"])
        let transport = MockAPITransport(fixtures: [
            .init(method: operation.method, path: operation.path): .success(
                HTTPResponse(statusCode: 429, body: body)
            )
        ])

        XCTAssertEqual(
            try XCTUnwrapResult { try SoundCloudAPI(transport: transport).capability(for: operation) },
            .failure(.httpStatus(429, message: "rate limited"))
        )
    }
}

private func XCTUnwrapResult<T>(_ operation: () throws -> T) -> Result<T, APIError> {
    do {
        return .success(try operation())
    } catch let error as APIError {
        return .failure(error)
    } catch {
        return .failure(.transport(error.localizedDescription))
    }
}
