import Foundation
import SoundCloudCore

/// Live `ResourceTransport` backed by URLSession. Requests are pre-built by
/// `APIEndpoint.urlRequest(accessToken:)`, so the OAuth header and host
/// validation happen in the core, not here.
struct URLSessionResourceTransport: ResourceTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { partial, pair in
            partial[String(describing: pair.key).lowercased()] = String(describing: pair.value)
        }
        return HTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }
}

/// Bridges the authentication coordinator into the core's
/// `AccessTokenProvider`, refreshing the session when it is near expiry.
actor CoordinatorTokenProvider: AccessTokenProvider {
    private let coordinator: AuthenticationCoordinator

    init(coordinator: AuthenticationCoordinator) {
        self.coordinator = coordinator
    }

    func currentAccessToken() async throws -> String {
        try await coordinator.currentAccessToken()
    }
}

/// Live `DownloadSession` using URLSession's download task with a delegate so
/// progress, cancellation, and completion are all real.
final class URLSessionDownloadSession: NSObject, URLSessionDownloadDelegate, DownloadSession, @unchecked Sendable {
    private let session: URLSession
    private var delegates: [UUID: DownloadDelegate] = [:]
    private let lock = NSLock()

    override init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.personal.SoundCloudPersonal.downloads")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func download(
        id: UUID,
        source: URL,
        destination: URL,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        let delegate = DownloadDelegate(destination: destination, onProgress: onProgress)
        lock.lock()
        delegates[id] = delegate
        lock.unlock()

        let request = URLRequest(url: source)
        let task = session.downloadTask(with: request)
        task.taskDescription = id.uuidString
        task.resume()

        try await delegate.wait()
    }

    func cancel(id: UUID) async {
        lock.lock()
        let delegate = delegates[id]
        lock.unlock()
        delegate?.cancel()
    }

    // MARK: URLSessionDownloadDelegate (via per-task delegate objects)

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = UUID(uuidString: downloadTask.taskDescription ?? ""),
              let delegate = lockedDelegate(id) else { return }
        if totalBytesExpectedToWrite > 0 {
            delegate.reportProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = UUID(uuidString: downloadTask.taskDescription ?? ""),
              let delegate = lockedDelegate(id) else { return }
        delegate.complete(downloadedAt: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = UUID(uuidString: task.taskDescription ?? ""),
              let delegate = lockedDelegate(id) else { return }
        delegate.finish(error: error)
        removeDelegate(id)
    }

    private func lockedDelegate(_ id: UUID) -> DownloadDelegate? {
        lock.lock()
        defer { lock.unlock() }
        return delegates[id]
    }

    fileprivate func removeDelegate(_ id: UUID) {
        lock.lock()
        delegates[id] = nil
        lock.unlock()
    }
}

/// Per-download continuation. The delegate methods above forward into this
/// object, which owns the async continuation the manager awaits. A single
/// `Result` box makes the finish-before-wait race safe.
final class DownloadDelegate: NSObject, @unchecked Sendable {
    private let destination: URL
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?
    private var downloadedLocation: URL?
    private let lock = NSLock()

    init(destination: URL, onProgress: @Sendable @escaping (Double) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    func reportProgress(_ progress: Double) {
        onProgress(progress)
    }

    func complete(downloadedAt location: URL) {
        lock.lock()
        downloadedLocation = location
        lock.unlock()
    }

    func cancel() {
        settle(.failure(CancellationError()))
    }

    func finish(error: Error?) {
        if let error {
            settle(.failure(error))
            return
        }
        lock.lock()
        let location = downloadedLocation
        lock.unlock()
        guard let location else {
            settle(.failure(APIError.invalidResponse))
            return
        }
        // Move off the system temp location immediately.
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            settle(.success(()))
        } catch {
            settle(.failure(error))
        }
    }

    private func settle(_ outcome: Result<Void, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = outcome
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        switch outcome {
        case .success:
            continuation?.resume(returning: ())
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }
}
