import SwiftUI
import SoundCloudCore

// MARK: - Downloads

struct DownloadsView: View {
    @StateObject private var viewModel: DownloadsViewModel
    let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        let libraryDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Library", isDirectory: true)
        _viewModel = StateObject(wrappedValue: DownloadsViewModel(
            downloads: environment.downloads,
            library: environment.library,
            libraryDirectory: libraryDirectory
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Storage") {
                    HStack {
                        Text("Local library size")
                        Spacer()
                        Text(viewModel.storageUsageText)
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.jobs.isEmpty {
                    Section("Queue") {
                        ForEach(viewModel.jobs) { job in
                            JobRow(job: job,
                                   onCancel: { Task { await viewModel.cancel(job.id) } },
                                   onRetry: { Task { await viewModel.retry(job.id) } })
                        }
                    }
                }

                if !viewModel.localPlaylists.isEmpty {
                    Section("Downloaded playlists") {
                        ForEach(viewModel.localPlaylists) { playlist in
                            PlaylistRowView(
                                title: playlist.title,
                                subtitle: "\(playlist.trackIDs.count) tracks",
                                artworkURL: nil
                            ) {}
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.deletePlaylist(playlist.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Downloaded tracks") {
                    ForEach(viewModel.localTracks, id: \.trackID) { track in
                        LocalTrackRowView(track: track) {
                            if let path = track.localPath, track.status == .completed {
                                environment.player.setQueue([.local(fileURL: URL(fileURLWithPath: path), track: track)])
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.prepareDeleteTrack(track.trackID) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    if viewModel.localTracks.isEmpty {
                        Text("Nothing downloaded yet. Open a track and tap Download — only when the uploader allows it.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Downloads")
            .task { viewModel.start(); await viewModel.refresh() }
            .alert(
                "Delete track?",
                isPresented: Binding(
                    get: { viewModel.deletingTrackWarning != nil },
                    set: { if !$0 { viewModel.deletingTrackWarning = nil } }
                )
            ) {
                if let warning = viewModel.deletingTrackWarning, !warning.playlists.isEmpty {
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.confirmDeleteTrack(warning.trackID) }
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("Delete", role: .destructive) {
                        if let warning = viewModel.deletingTrackWarning {
                            Task { await viewModel.confirmDeleteTrack(warning.trackID) }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                if let warning = viewModel.deletingTrackWarning, !warning.playlists.isEmpty {
                    Text("This track is still referenced by: \(warning.playlists.joined(separator: ", ")). The playlists keep their entries but the file will be removed.")
                } else {
                    Text("The local file will be removed. SoundCloud streaming is unaffected.")
                }
            }
        }
    }
}

private struct JobRow: View {
    let job: DownloadJob
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ArtworkView(url: job.artworkURL)
                VStack(alignment: .leading) {
                    Text(job.title ?? "Unknown title")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(job.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stateView
            }
            if case .running(let progress) = job.state {
                ProgressView(value: progress)
                    .tint(.orange)
            }
        }
    }

    private var stateView: some View {
        switch job.state {
        case .queued:
            return AnyView(Text("Queued").font(.caption).foregroundStyle(.secondary))
        case .running:
            return AnyView(
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
            )
        case .completed:
            return AnyView(Image(systemName: "checkmark.circle.fill").foregroundStyle(.orange))
        case .failed(_, let retryable):
            return AnyView(
                HStack {
                    if retryable {
                        Button(action: onRetry) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.orange)
                        }
                    }
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            )
        case .cancelled:
            return AnyView(
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.orange)
                }
            )
        }
    }
}

// MARK: - Player

struct PlayerView: View {
    @ObservedObject var player: PlayerService

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let item = player.currentItem {
                    ArtworkView(url: item.artworkURL, size: 240, cornerRadius: 16)
                    VStack(spacing: 4) {
                        Text(item.title)
                            .font(.title3.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(item.artistName)
                            .foregroundStyle(.secondary)
                        if item.isOffline {
                            Label("Playing offline copy", systemImage: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Label("Streaming", systemImage: "waveform")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { player.progress },
                            set: { player.seek(to: $0) }
                        ), in: 0...1)
                        .tint(.orange)
                        HStack {
                            Text(timeText(player.progress * player.duration))
                            Spacer()
                            Text(timeText(player.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    HStack(spacing: 36) {
                        Button {
                            player.setShuffle(!player.shuffle)
                        } label: {
                            Image(systemName: "shuffle")
                                .foregroundStyle(player.shuffle ? .orange : .secondary)
                        }
                        Button(action: player.previous) {
                            Image(systemName: "backward.fill").font(.title2)
                        }
                        Button(action: player.playPause) {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.orange)
                        }
                        Button(action: player.next) {
                            Image(systemName: "forward.fill").font(.title2)
                        }
                        Button(action: player.cycleRepeatMode) {
                            Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                .foregroundStyle(player.repeatMode == .off ? .secondary : .orange)
                        }
                    }
                    if !player.queue.isEmpty {
                        List {
                            Section("Up next (\(player.queue.count))") {
                                ForEach(Array(player.queue.enumerated()), id: \.element.id) { _, item in
                                    HStack {
                                        ArtworkView(url: item.artworkURL, size: 40)
                                        VStack(alignment: .leading) {
                                            Text(item.title).font(.subheadline).lineLimit(1)
                                            Text(item.artistName).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if item.isOffline {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .foregroundStyle(.orange)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                } else {
                    EmptyStateView(message: "Pick a track from Home, Search, or Library to start playing. Downloaded tracks play offline automatically.")
                }
                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Player")
        }
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
