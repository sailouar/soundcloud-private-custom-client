import SwiftUI
import SoundCloudCore

// MARK: - Shared components (dark theme, orange accent)

struct ArtworkView: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    init(url: URL?, size: CGFloat = 56, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.orange.opacity(0.25))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.orange)
            }
    }
}

struct TrackRowView: View {
    let track: SCTrack
    let isOffline: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(url: track.artworkURL(size: .small))
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title ?? "Unknown title")
                        .foregroundStyle(.primary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(track.user?.username ?? "Unknown artist")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
                if isOffline {
                    Label("Offline", systemImage: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LocalTrackRowView: View {
    let track: LocalTrackDetails
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(url: track.artworkURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title ?? "Unknown title")
                        .foregroundStyle(.primary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(track.artistName ?? "Unknown artist")
                        if track.status == .completed {
                            Text("·")
                            Label("Offline", systemImage: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                        } else {
                            Text("· \(track.status.rawValue)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PlaylistRowView: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(url: artworkURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if let action {
                Button(action: action) {
                    Text("See all")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
    }
}
