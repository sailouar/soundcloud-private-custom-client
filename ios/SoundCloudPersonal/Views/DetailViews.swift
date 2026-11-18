import SwiftUI
import SoundCloudCore

// MARK: - Track detail

struct TrackDetailView: View {
    @StateObject var viewModel: TrackDetailViewModel
    let player: PlayerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ArtworkView(url: viewModel.track.artworkURL(size: .xlarge), size: 220, cornerRadius: 16)
                    VStack(spacing: 4) {
                        Text(viewModel.track.title ?? "Unknown title")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        if let username = viewModel.track.user?.username {
                            Text(username)
                                .foregroundStyle(.secondary)
                        }
                        Text(viewModel.track.durationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 24) {
                        Button {
                            Task { await viewModel.toggleLike() }
                        } label: {
                            VStack {
                                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(viewModel.isLiked ? .orange : .primary)
                                Text("Like").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            Task {
                                if await viewModel.download() {
                                    await viewModel.load()
                                }
                            }
                        } label: {
                            VStack {
                                switch viewModel.downloadState {
                                case .unknown:
                                    Image(systemName: "arrow.down.circle")
                                case .alreadyLocal:
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.orange)
                                case .permitted:
                                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(.orange)
                                case .notPermitted:
                                    Image(systemName: "arrow.down.circle slash")
                                }
                                Text(downloadLabel).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            Task {
                                // Offline-first: the local file wins when present.
                                let stream = try? await viewModel.streamURL()
                                if let item = await player.playableItem(for: viewModel.track, streamURL: stream) {
                                    player.play(item)
                                }
                            }
                        } label: {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                Text("Play").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if case .notPermitted(let reason) = viewModel.downloadState {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                    if let description = viewModel.track.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
        }
    }

    private var downloadLabel: String {
        switch viewModel.downloadState {
        case .alreadyLocal: return "Saved"
        case .permitted: return "Download"
        case .notPermitted: return "No download"
        case .unknown: return "…"
        }
    }
}

// MARK: - Artist detail

struct ArtistView: View {
    @StateObject var viewModel: ArtistViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ArtworkView(url: viewModel.user.avatarURL(size: .xlarge), size: 120, cornerRadius: 60)
                Text(viewModel.user.username ?? "Unknown artist")
                    .font(.title2.bold())
                HStack(spacing: 24) {
                    stat("Followers", viewModel.user.followersCount)
                    stat("Following", viewModel.user.followingsCount)
                    stat("Tracks", viewModel.user.trackCount)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Button {
                    Task { await viewModel.toggleFollow() }
                } label: {
                    Text(viewModel.isFollowing ? "Following" : "Follow")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.isFollowing ? .primary : .black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(viewModel.isFollowing ? Color.secondary.opacity(0.3) : Color.orange)
                        .clipShape(Capsule())
                }
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if let description = viewModel.user.description, !description.isEmpty {
                    Text(description).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Artist")
    }

    private func stat(_ label: String, _ value: Int?) -> some View {
        VStack {
            Text("\(value ?? 0)").font(.subheadline.weight(.semibold))
            Text(label)
        }
    }
}

