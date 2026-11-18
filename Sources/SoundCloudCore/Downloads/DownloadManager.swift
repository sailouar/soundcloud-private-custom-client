import Foundation

// MARK: - Download manager
//
// Central, deduplicating download pipeline. Guarantees:
//  - a track ID is downloaded at most once (checked against the library
//    before enqueueing and again before starting);
//  - downloads start only with an explicit official entitlement (uploader
//    permission + an API-provided download location), confirmed through the
//    `DownloadAuthorization` gate;
//  - files land atomically: bytes go to a temp file first and are moved into
//    the library directory only after a complete transfer;
//  - progress, cancellation, retry, and failure states are all explicit.

public actor DownloadManager {
    private var jobs: [UUID: DownloadJob] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]

    private let session: any DownloadSession
    private let library: any LocalLibraryStore
    private var downloadCapability: CapabilityResponse?
    private let libraryDirectory: URL
    private let fileManager: FileManager

    public init(
        session: any DownloadSession,
        library: any LocalLibraryStore,
        downloadCapability: CapabilityResponse? = nil,
        libraryDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.session = session
        self.library = library
        self.downloadCapability = downloadCapability
        self.libraryDirectory = libraryDirectory
        self.fileManager = fileManager
    }

    /// Updates the download-capability state (e.g. after a live capability
    /// check). Downloads stay denied until the capability is confirmed.
    public func updateDownloadCapability(_ capability: CapabilityResponse?) {
        downloadCapability = capability
    }

    // MARK: Public API

    public func snapshot() -> [DownloadJob] {
        jobs.values.sorted { lhs, rhs in
            if case .completed = lhs.state, case .completed = rhs.state { return lhs.trackID < rhs.trackID }
            return lhs.trackID < rhs.trackID
        }
    }

    public func job(withID id: UUID) -> DownloadJob? { jobs[id] }

    /// Enqueues a single track download. Returns nil when the track is
    /// already local (never downloaded twice). Throws when authorization is
    /// denied.
    @discardableResult
    public func enqueue(track: SCTrack) async throws -> UUID? {
        let trackID = track.id

        // Dedup: never download the same track twice.
        if let existing = try await library.track(withID: trackID),
           existing.status == .completed || existing.status == .downloading || existing.status == .queued {
            return nil
        }

        let entitlement = TrackDownloadEntitlement(track: track)
        // The gate is evaluated per track: the explicit official entitlement
        // comes from the documented track fields, never from playback state.
        let gate = DownloadAuthorization(explicitOfficialEntitlement: entitlement.isAuthorized)
        let decision = gate.decision(
            for: downloadCapability,
            trackID: String(trackID)
        )
        switch decision {
        case .authorized:
            break
        case .denied(let reason):
            throw DownloadManagerError.denied(reason)
        }

        guard let sourceURL = entitlement.officialFileURL else {
            throw DownloadManagerError.missingSource
        }

        // Re-check dedup inside the actor to avoid a race between two
        // concurrent enqueues of the same track.
        for job in jobs.values where job.trackID == trackID {
            switch job.state {
            case .queued, .running:
                return job.id
            default:
                break
            }
        }

        let job = DownloadJob(
            trackID: trackID,
            title: track.title,
            artistName: track.user?.username,
            artworkURL: track.artworkURL,
            sourceURL: sourceURL
        )
        jobs[job.id] = job
        try await library.saveTrack(record(for: track, jobID: job.id, status: .queued, progress: 0, localPath: nil))
        start(job: job)
        return job.id
    }

    /// Enqueues a playlist download, skipping tracks that are already local.
    /// Returns the IDs of newly enqueued jobs.
    @discardableResult
    public func enqueuePlaylist(_ tracks: [SCTrack]) async throws -> [UUID] {
        let local = try await library.trackIDs()
        var enqueued: [UUID] = []
        for track in tracks where !local.contains(track.id) {
            if let id = try await enqueue(track: track) {
                enqueued.append(id)
            }
        }
        return enqueued
    }

    public func cancel(_ id: UUID) async {
        tasks[id]?.cancel()
        await session.cancel(id: id)
        if var job = jobs[id] {
            job.updating(.cancelled)
            jobs[id] = job
            if let track = try? await library.track(withID: job.trackID) {
                var record = track
                record = LocalTrackDetails(
                    trackID: record.trackID,
                    originalURL: record.originalURL,
                    localPath: record.localPath,
                    title: record.title,
                    artistName: record.artistName,
                    artworkURL: record.artworkURL,
                    duration: record.duration,
                    status: .cancelled,
                    progress: record.progress,
                    errorMessage: nil,
                    addedAt: record.addedAt
                )
                try? await library.saveTrack(record)
            }
        }
    }

    public func retry(_ id: UUID) async throws {
        guard var job = jobs[id] else { throw DownloadManagerError.jobNotFound(id) }
        switch job.state {
        case .failed, .cancelled:
            break
        default:
            throw DownloadManagerError.notRetryable(id)
        }
        job.updating(.queued)
        jobs[id] = job
        try? await library.saveTrack(record(for: job, status: .queued, progress: 0, localPath: nil))
        start(job: job)
    }

    /// Removes a finished job from the visible queue. The downloaded file and
    /// library record are untouched.
    public func dismiss(_ id: UUID) async {
        if case .completed = jobs[id]?.state {
            jobs[id] = nil
            tasks[id] = nil
        }
    }

    // MARK: Internals

    private func start(job: DownloadJob) {
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.run(job: job)
        }
        tasks[job.id] = task
    }

    private func run(job: DownloadJob) async {
        var job = job
        job.updating(.running(progress: 0))
        jobs[job.id] = job
        try? await library.saveTrack(record(for: job, status: .downloading, progress: 0, localPath: nil))

        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            let tempURL = tempDirectory.appendingPathComponent("\(job.id.uuidString).download")

            try await session.download(id: job.id, source: job.sourceURL, destination: tempURL) { [weak self] progress in
                Task { [weak self] in
                    await self?.updateProgress(jobID: job.id, progress: progress)
                }
            }

            guard !Task.isCancelled else {
                try? fileManager.removeItem(at: tempURL)
                await markCancelled(job)
                return
            }

            // Atomic move into the library directory.
            let finalURL = finalURL(for: job)
            try fileManager.createDirectory(at: finalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: tempURL, to: finalURL)

            job.updating(.completed)
            jobs[job.id] = job
            try? await library.saveTrack(record(for: job, status: .completed, progress: 1, localPath: finalURL.path))
        } catch {
            if Task.isCancelled {
                try? fileManager.removeItem(at: tempDirectory.appendingPathComponent("\(job.id.uuidString).download"))
                await markCancelled(job)
                return
            }
            let retryable = (error as? APIError)?.isRetryable ?? true
            let message = error.localizedDescription
            job.updating(.failed(message: message, retryable: retryable))
            jobs[job.id] = job
            try? await library.saveTrack(record(for: job, status: .failed, progress: job.stateProgress, localPath: nil, errorMessage: message))
        }
    }

    private func markCancelled(_ job: DownloadJob) async {
        var job = job
        job.updating(.cancelled)
        jobs[job.id] = job
        try? await library.saveTrack(record(for: job, status: .cancelled, progress: job.stateProgress, localPath: nil))
    }

    private func updateProgress(jobID: UUID, progress: Double) async {
        guard var job = jobs[jobID] else { return }
        job.updating(.running(progress: min(1, max(0, progress))))
        jobs[jobID] = job
        if let track = try? await library.track(withID: job.trackID) {
            try? await library.saveTrack(record(for: track, status: .downloading, progress: progress, localPath: nil))
        }
    }

    private var tempDirectory: URL {
        libraryDirectory.appendingPathComponent(".tmp", isDirectory: true)
    }

    private func finalURL(for job: DownloadJob) -> URL {
        let ext = job.sourceURL.pathExtension.isEmpty ? "mp3" : job.sourceURL.pathExtension
        return libraryDirectory
            .appendingPathComponent("Tracks", isDirectory: true)
            .appendingPathComponent("\(job.trackID).\(ext)")
    }

    private func record(for track: SCTrack, jobID: UUID, status: LocalTrackStatus, progress: Double, localPath: String?) -> LocalTrackDetails {
        LocalTrackDetails(
            trackID: track.id,
            originalURL: track.permalinkURL,
            localPath: localPath,
            title: track.title,
            artistName: track.user?.username,
            artworkURL: track.artworkURL,
            duration: track.duration,
            status: status,
            progress: progress
        )
    }

    private func record(for job: DownloadJob, status: LocalTrackStatus, progress: Double, localPath: String?, errorMessage: String? = nil) -> LocalTrackDetails {
        LocalTrackDetails(
            trackID: job.trackID,
            originalURL: nil,
            localPath: localPath,
            title: job.title,
            artistName: job.artistName,
            artworkURL: job.artworkURL,
            status: status,
            progress: progress,
            errorMessage: errorMessage
        )
    }

    private func record(for track: LocalTrackDetails, status: LocalTrackStatus, progress: Double, localPath: String?, errorMessage: String? = nil) -> LocalTrackDetails {
        LocalTrackDetails(
            trackID: track.trackID,
            originalURL: track.originalURL,
            localPath: localPath ?? track.localPath,
            title: track.title,
            artistName: track.artistName,
            artworkURL: track.artworkURL,
            duration: track.duration,
            status: status,
            progress: progress,
            errorMessage: errorMessage,
            addedAt: track.addedAt
        )
    }
}

private extension DownloadJob {
    var stateProgress: Double {
        if case .running(let progress) = state { return progress }
        if case .completed = state { return 1 }
        return 0
    }
}
