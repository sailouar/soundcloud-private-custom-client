import Foundation

public struct LocalTrackRecord: Codable, Equatable, Sendable {
    public let trackID: Int64
    public let originalURL: URL?
    public let localPath: String?

    public init(trackID: Int64, originalURL: URL? = nil, localPath: String? = nil) {
        self.trackID = trackID
        self.originalURL = originalURL
        self.localPath = localPath
    }
}

public protocol LocalStore: Sendable {
    func track(withID trackID: Int64) async throws -> LocalTrackRecord?
    func save(_ track: LocalTrackRecord) async throws
}
