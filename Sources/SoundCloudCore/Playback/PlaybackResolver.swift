import Foundation

// MARK: - Offline-first playback resolution
//
// When a track is played, the local library is checked first: if the track
// was downloaded (completed, with a file on disk), the local file is played
// instead of the stream. Streaming is only used when no local copy exists.

public enum LocalPlaybackResolution: Equatable, Sendable {
    case localFile(path: String)
    case notLocal
}

public enum PlaybackResolver {
    public static func resolve(
        trackID: Int64,
        library: any LocalLibraryStore
    ) async throws -> LocalPlaybackResolution {
        guard let track = try await library.track(withID: trackID),
              track.isPlayableOffline,
              let path = track.localPath else {
            return .notLocal
        }
        return .localFile(path: path)
    }
}
