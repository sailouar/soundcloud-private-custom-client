import Foundation

// MARK: - Download entitlement
//
// An offline file is created only when BOTH signals come from official,
// documented API data:
//   1. the uploader set `downloadable` on the track, and
//   2. the API response itself carried a download location for the track.
// Streaming availability is never an entitlement.

public struct TrackDownloadEntitlement: Equatable, Sendable {
    public let trackID: Int64
    public let permittedByUploader: Bool
    public let officialFileURL: URL?

    public init(trackID: Int64, permittedByUploader: Bool, officialFileURL: URL? = nil) {
        self.trackID = trackID
        self.permittedByUploader = permittedByUploader
        self.officialFileURL = officialFileURL
    }

    /// Builds the entitlement from a documented track resource. `downloadURL`
    /// is used only if the API response included it; the client never
    /// constructs or scrapes a file URL.
    public init(track: SCTrack) {
        self.trackID = track.id
        self.permittedByUploader = track.isDownloadPermittedByUploader
        self.officialFileURL = track.downloadUrl
    }

    public var isAuthorized: Bool {
        permittedByUploader && officialFileURL != nil
    }

    public var denialReason: String? {
        if !permittedByUploader {
            return "The uploader has not enabled downloads for this track."
        }
        if officialFileURL == nil {
            return "The official API did not provide a download location for this track."
        }
        return nil
    }
}

// MARK: - Job model

public enum DownloadJobState: Equatable, Sendable {
    case queued
    case running(progress: Double)
    case completed
    case failed(message: String, retryable: Bool)
    case cancelled
}

public struct DownloadJob: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let trackID: Int64
    public let title: String?
    public let artistName: String?
    public let artworkURL: URL?
    public let sourceURL: URL
    public private(set) var state: DownloadJobState

    public init(
        id: UUID = UUID(),
        trackID: Int64,
        title: String? = nil,
        artistName: String? = nil,
        artworkURL: URL? = nil,
        sourceURL: URL,
        state: DownloadJobState = .queued
    ) {
        self.id = id
        self.trackID = trackID
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.sourceURL = sourceURL
        self.state = state
    }

    mutating func updating(_ state: DownloadJobState) {
        self.state = state
    }
}

public enum DownloadManagerError: Error, Equatable, Sendable {
    case denied(DownloadDenialReason)
    case alreadyLocal(trackID: Int64)
    case jobNotFound(UUID)
    case notRetryable(UUID)
    case missingSource
}

extension DownloadManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .denied(let reason):
            switch reason {
            case .missingCapability:
                return "Download capability is not confirmed yet."
            case .notDownloadCapability:
                return "The confirmed capability is not the download capability."
            case .capabilityNotSupported:
                return "The official API does not support downloads for this track."
            case .noExplicitOfficialEntitlement:
                return "No explicit official download entitlement exists for this track. Streaming is not download permission."
            case .invalidTrackID:
                return "The track ID is invalid."
            }
        case .alreadyLocal(let trackID):
            return "Track \(trackID) is already in the local library; it will not be downloaded twice."
        case .jobNotFound:
            return "The download job no longer exists."
        case .notRetryable:
            return "This download cannot be retried in its current state."
        case .missingSource:
            return "No official download source is available for this track."
        }
    }
}

// MARK: - Download session abstraction
//
// The app target implements this with URLSession + download delegate; tests
// implement it with a fake. The manager owns the state machine, dedup, and
// authorization; the session only moves bytes.

public protocol DownloadSession: Sendable {
    /// Downloads `source` to `destination`, reporting progress 0...1.
    /// Throws on failure; the manager classifies retryability.
    func download(
        id: UUID,
        source: URL,
        destination: URL,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws

    func cancel(id: UUID) async
}
