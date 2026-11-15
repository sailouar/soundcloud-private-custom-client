import XCTest
import SoundCloudCore
@testable import SoundCloudPersonal

@MainActor
final class CapabilityAdapterIntegrationTests: XCTestCase {
    func testTransportCoreEnvironmentAndViewModelPreserveCapabilityState() throws {
        let operation = CapabilityOperation.trackMetadata
        let response = try MockAPITransport.json(
            state: .requiresUserPermission,
            reason: "The fixture requires an authenticated user."
        )
        let transport = MockAPITransport(fixtures: [
            .init(method: operation.method, path: operation.path): .success(response)
        ])
        let environment = AppEnvironment(api: SoundCloudAPI(transport: transport))

        environment.load(operation)

        XCTAssertEqual(
            environment.capabilityResponse,
            CapabilityResponse(
                operation: operation,
                state: .requiresUserPermission,
                reason: "The fixture requires an authenticated user."
            )
        )
        XCTAssertEqual(
            CapabilityStatusViewModel(response: environment.capabilityResponse),
            CapabilityStatusViewModel(
                title: "Requires user permission",
                detail: "The fixture requires an authenticated user."
            )
        )
    }
}
