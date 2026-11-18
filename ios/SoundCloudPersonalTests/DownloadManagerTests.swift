import XCTest
@testable import SoundCloudCore

// MARK: - Fakes

private actor FakeDownloadSession: DownloadSession {
    var started: [(id: UUID, source: URL, destination: URL)] = []
    var startedCount: Int { started.count }
    var cancelled: [UUID] = []
    var failNext: Bool = false
    var hangUntilCancelled: Bool = false
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func download(
        id: UUID,
        source: URL,
        destination: URL,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        started.append((id, source, destination))
        if hangUntilCancelled {
            try await withCheckedThrowingContinuation { continuation in
                waiters[id] = continuation
            }
            throw CancellationError()
        }
        if failNext {
            failNext = false
            throw APIError.httpStatus(503, message: "try later")
        }
        onProgress(0.5)
        try Data("audio".utf8).write(to: destination)
        onProgress(1.0)
    }

    func cancel(id: UUID) async {
        cancelled.append(id)
        waiters[id]?.resume(throwing: CancellationError())
        waiters[id] = nil
    }
}

// MARK: - Tests

final class DownloadManagerTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func authorizedTrack(_ id: Int64) -> SCTrack {
        SCTrack(
            id: id,
            title: "T\(id)",
            streamable: true,
            downloadable: true,
            downloadURL: URL(string: "https://api.soundcloud.com/tracks/\(id)/download")!
        )
    }

    private var supportedCapability: CapabilityResponse {
        CapabilityResponse(operation: .downloadAuthorization, state: .supported)
    }

    private func makeManager(
        session: any DownloadSession,
        library: any LocalLibraryStore
    ) -> DownloadManager {
        makeManager(session: session, library: library, capability: supportedCapability)
    }

    private func makeManager(
        session: any DownloadSession,
        library: any LocalLibraryStore,
        capability: CapabilityResponse?
    ) -> DownloadManager {
        DownloadManager(
            session: session,
            library: library,
            downloadCapability: capability,
            libraryDirectory: directory
        )
    }

    func testAuthorizedDownloadCompletesAndPersistsRecord() async throws {
        let session = FakeDownloadSession()
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library)

        let jobID = try await manager.enqueue(track: authorizedTrack(1))
        XCTAssertNotNil(jobID)

        // Wait for completion.
        try await waitForState(manager: manager, jobID: jobID!) { state in
            if case .completed = state { return true }
            return false
        }

        let record = try await library.track(withID: 1)
        XCTAssertEqual(record?.status, .completed)
        XCTAssertEqual(record?.progress, 1)
        XCTAssertNotNil(record?.localPath)
        if let path = record?.localPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, "1.mp3")
        }
    }

    func testNeverDownloadsSameTrackTwice() async throws {
        let session = FakeDownloadSession()
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library)

        let first = try await manager.enqueue(track: authorizedTrack(7))
        XCTAssertNotNil(first)
        try await waitForState(manager: manager, jobID: first!) {
            if case .completed = $0 { return true }
            return false
        }

        // Second enqueue of the same track is skipped (already local).
        let second = try await manager.enqueue(track: authorizedTrack(7))
        XCTAssertNil(second)
        let starts = await session.started
        XCTAssertEqual(starts.count, 1)
    }

    func testDeniedWithoutUploaderPermission() async throws {
        let session = FakeDownloadSession()
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library)

        let track = SCTrack(id: 3, title: "Stream only", streamable: true, downloadable: false)
        await XCTAssertThrowsErrorAsync(try await manager.enqueue(track: track)) { error in
            guard case DownloadManagerError.denied(let reason) = error else {
                return XCTFail("Expected denial, got \(error)")
            }
            XCTAssertEqual(reason, .noExplicitOfficialEntitlement)
        }
        let starts = await session.started
        XCTAssertTrue(starts.isEmpty)
    }

    func testDeniedWhenCapabilityNotConfirmed() async throws {
        let session = FakeDownloadSession()
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library, capability: nil)

        await XCTAssertThrowsErrorAsync(try await manager.enqueue(track: authorizedTrack(4))) { error in
            guard case DownloadManagerError.denied(let reason) = error else {
                return XCTFail("Expected denial, got \(error)")
            }
            XCTAssertEqual(reason, .missingCapability)
        }
    }

    func testPlaylistEnqueueSkipsAlreadyLocalTracks() async throws {
        let session = FakeDownloadSession()
        let library = InMemoryLocalStore(seedTracks: [
            LocalTrackDetails(trackID: 2, localPath: "/x/2.mp3", status: .completed, progress: 1)
        ])
        let manager = makeManager(session: session, library: library)

        let enqueued = try await manager.enqueuePlaylist([
            authorizedTrack(1), authorizedTrack(2), authorizedTrack(3)
        ])
        XCTAssertEqual(enqueued.count, 2)
        // Jobs start asynchronously; wait until both actually hit the session.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if await session.startedCount >= 2 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let starts = await session.started
        XCTAssertEqual(Set(starts.map { $0.source.absoluteString }), [
            "https://api.soundcloud.com/tracks/1/download",
            "https://api.soundcloud.com/tracks/3/download"
        ])
    }

    func testCancelMarksJobCancelled() async throws {
        let session = FakeDownloadSession()
        await session.setHangUntilCancelled(true)
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library)

        let jobID = try await manager.enqueue(track: authorizedTrack(8))!
        try await waitForState(manager: manager, jobID: jobID) {
            if case .running = $0 { return true }
            return false
        }
        await manager.cancel(jobID)
        try await waitForState(manager: manager, jobID: jobID) {
            if case .cancelled = $0 { return true }
            return false
        }
        let cancelled = await session.cancelled
        XCTAssertTrue(cancelled.contains(jobID))
    }

    func testRetryAfterFailure() async throws {
        let session = FakeDownloadSession()
        await session.setFailNext(true)
        let library = InMemoryLocalStore()
        let manager = makeManager(session: session, library: library)

        let jobID = try await manager.enqueue(track: authorizedTrack(9))!
        try await waitForState(manager: manager, jobID: jobID) {
            if case .failed = $0 { return true }
            return false
        }
        try await manager.retry(jobID)
        try await waitForState(manager: manager, jobID: jobID) {
            if case .completed = $0 { return true }
            return false
        }
        let record = try await library.track(withID: 9)
        XCTAssertEqual(record?.status, .completed)
    }

    // MARK: Helpers

    private func waitForState(
        manager: DownloadManager,
        jobID: UUID,
        timeout: TimeInterval = 5,
        _ predicate: (DownloadJobState) -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let job = await manager.job(withID: jobID), predicate(job.state) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let state = await manager.job(withID: jobID)?.state
        XCTFail("Timed out waiting for job state; current: \(String(describing: state))")
    }
}

// MARK: - XCTest async helpers

extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void
    ) async {
        do {
            _ = try await expression()
            XCTFail(message.isEmpty ? "Expected error" : message, file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}

private extension FakeDownloadSession {
    func setFailNext(_ value: Bool) async { failNext = value }
    func setHangUntilCancelled(_ value: Bool) async { hangUntilCancelled = value }
}
