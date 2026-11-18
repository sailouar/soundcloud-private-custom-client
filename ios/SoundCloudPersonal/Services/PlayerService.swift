import AVFoundation
import Combine
import Foundation
import MediaPlayer
import SoundCloudCore

/// One playable source. `stream` URLs come from the stream-only API path and
/// are never persisted; `local` URLs point at files in the download library.
public enum PlayableItem: Equatable, Sendable, Identifiable {
    case stream(url: URL, track: SCTrack)
    case local(fileURL: URL, track: LocalTrackDetails)

    public var id: String {
        switch self {
        case .stream(_, let track): return "stream-\(track.id)"
        case .local(_, let track): return "local-\(track.trackID)"
        }
    }

    public var title: String {
        switch self {
        case .stream(_, let track): return track.title ?? "Unknown title"
        case .local(_, let track): return track.title ?? "Unknown title"
        }
    }

    public var artistName: String {
        switch self {
        case .stream(_, let track): return track.user?.username ?? "Unknown artist"
        case .local(_, let track): return track.artistName ?? "Unknown artist"
        }
    }

    public var artworkURL: URL? {
        switch self {
        case .stream(_, let track): return track.artworkURL(size: .large)
        case .local(_, let track): return track.artworkURL
        }
    }

    public var isOffline: Bool {
        if case .local = self { return true }
        return false
    }

    var playerURL: URL {
        switch self {
        case .stream(let url, _): return url
        case .local(let fileURL, _): return fileURL
        }
    }
}

public enum RepeatMode: String, Sendable, CaseIterable {
    case off
    case all
    case one
}

/// Native audio playback: AVPlayer for the queue, AVAudioSession for
/// background playback, MPNowPlayingInfoCenter + MPRemoteCommandCenter for
/// lock-screen controls. The UI never talks to AVPlayer directly.
@MainActor
final class PlayerService: ObservableObject {
    @Published private(set) var queue: [PlayableItem] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var shuffle = false
    @Published var repeatMode: RepeatMode = .off

    private let player = AVPlayer()
    private let library: (any LocalLibraryStore)?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var order: [Int] = [] // playback order when shuffle is on

    /// When true (default), a track that exists in the local library is played
    /// from the downloaded file instead of the stream.
    @Published var preferLocalPlayback = true

    var currentItem: PlayableItem? {
        guard !queue.isEmpty, order.indices.contains(currentIndex) else { return nil }
        return queue[order[currentIndex]]
    }

    init(library: (any LocalLibraryStore)? = nil) {
        self.library = library
        configureAudioSession()
        observePlayer()
        registerRemoteCommands()
    }

    /// Resolves a track to a playable item, preferring the local file when the
    /// track has been downloaded (offline-first playback).
    func playableItem(for track: SCTrack, streamURL: URL?) async -> PlayableItem? {
        if preferLocalPlayback, let library {
            let resolution = try? await PlaybackResolver.resolve(trackID: track.id, library: library)
            if case .localFile(let path) = resolution, let fileURL = URL(fileURLWithPath: path) {
                let details = (try? await library.track(withID: track.id)) ?? Self.details(for: track)
                return .local(fileURL: fileURL, track: details)
            }
        }
        guard let streamURL else { return nil }
        return .stream(url: streamURL, track: track)
    }

    private static func details(for track: SCTrack) -> LocalTrackDetails {
        LocalTrackDetails(
            trackID: track.id,
            originalURL: track.permalinkURL,
            title: track.title,
            artistName: track.user?.username,
            artworkURL: track.artworkURL,
            duration: track.duration,
            status: .completed,
            progress: 1,
            addedAt: Date()
        )
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    // MARK: Queue management

    func setQueue(_ items: [PlayableItem], startAt index: Int = 0) {
        queue = items
        rebuildOrder()
        currentIndex = min(max(0, index), max(0, order.count - 1))
        playCurrent()
    }

    func play(_ item: PlayableItem) {
        if let index = queue.firstIndex(where: { $0.id == item.id }) {
            currentIndex = order.firstIndex(of: index) ?? 0
            playCurrent()
        } else {
            setQueue([item])
        }
    }

    func playPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func next() {
        guard !order.isEmpty else { return }
        if repeatMode == .one {
            playCurrent()
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < order.count {
            currentIndex = nextIndex
            playCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            playCurrent()
        } else {
            player.pause()
            isPlaying = false
        }
    }

    func previous() {
        guard !order.isEmpty else { return }
        // Restart the track if more than 3s in, like the official player.
        if progress * duration > 3 {
            seek(to: 0)
            return
        }
        if currentIndex > 0 {
            currentIndex -= 1
            playCurrent()
        } else {
            seek(to: 0)
        }
    }

    func seek(to fraction: Double) {
        let clamped = min(1, max(0, fraction))
        progress = clamped
        let seconds = clamped * duration
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func setShuffle(_ enabled: Bool) {
        shuffle = enabled
        rebuildOrder()
        if let current = currentItem, let newPos = order.firstIndex(of: queue.firstIndex(where: { $0.id == current.id }) ?? 0) {
            currentIndex = newPos
        }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: Internals

    private func rebuildOrder() {
        order = Array(queue.indices)
        if shuffle {
            let current = currentIndex < order.count ? order[currentIndex] : nil
            order.shuffle()
            if let current, let pos = order.firstIndex(of: current) {
                order.remove(at: pos)
                order.insert(current, at: 0)
                currentIndex = 0
            }
        } else {
            currentIndex = min(currentIndex, max(0, order.count - 1))
        }
    }

    private func playCurrent() {
        guard let item = currentItem else { return }
        let playerItem = AVPlayerItem(url: item.playerURL)
        player.replaceCurrentItem(with: playerItem)
        updateNowPlaying(for: item)
        player.play()
        isPlaying = true
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback still works in the foreground; background audio is best-effort here.
        }
    }

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if let item = player.currentItem {
                self.duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
            }
            if self.duration > 0 {
                self.progress = min(1, max(0, seconds / self.duration))
            }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.next()
            }
            .store(in: &cancellables)

        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.isPlaying = rate > 0
            }
            .store(in: &cancellables)
    }

    private func updateNowPlaying(for item: PlayableItem) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artistName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress * duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            "isOffline": item.isOffline
        ]
        if let artworkURL = item.artworkURL {
            loadArtwork(artworkURL) { image in
                if let image {
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var image: UIImage?
            if let data { image = UIImage(data: data) }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in self?.playPause(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true { self?.playPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent, self?.duration ?? 0 > 0 {
                self?.seek(to: event.positionTime / (self?.duration ?? 1))
            }
            return .success
        }
    }
}
