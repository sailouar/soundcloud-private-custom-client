# Downloads

Downloads are permission-gated. Only an official API response or explicit uploader/SoundCloud download control that is permitted for this app can create a local audio file. Streaming endpoints, hidden URLs, scraping, access-control bypasses, and DRM circumvention are not download mechanisms.

## Authorization gate (deny by default)

A download starts only when **all** of these hold:

1. The track's documented `downloadable` flag is `true` (the uploader's explicit choice).
2. The official API response itself carried a download location for the track
   (`SCTrack.downloadURL`). The client never constructs or scrapes a file URL.
3. The download capability check (`CapabilityOperation.downloadAuthorization`) is
   confirmed `.supported`.

These are evaluated per track in `DownloadManager.enqueue(track:)` through
`TrackDownloadEntitlement` + `DownloadAuthorization`. Streaming availability is never
an entitlement. When any check fails, the UI shows the honest reason
("The uploader has not enabled downloads for this track." etc.) instead of a fake success.

## Pipeline (`Sources/SoundCloudCore/Downloads/DownloadManager.swift`)

- **Dedup:** the SoundCloud track ID is the unique key. `enqueue` returns `nil` when the
  track is already local, and re-checks inside the actor to close the race — a track is
  never downloaded twice, even when it appears in several playlists.
- **Queue states:** `queued`, `running(progress)`, `completed`, `failed(message, retryable)`,
  `cancelled` — all explicit and rendered in the Downloads tab.
- **Progress / cancel / retry:** the `DownloadSession` abstraction reports progress; the
  app implements it with `URLSessionDownloadSession` (background configuration, download
  delegate, per-job continuation). Cancellation cancels the task and marks the job.
- **Atomic files:** bytes land in `Library/.tmp/<job>.download` and are moved into
  `Library/Tracks/<trackID>.<ext>` only after a complete transfer.
- **Persistence:** every state change is written to the `LocalLibraryStore` record
  (status, progress, local path, metadata, error), so the library survives relaunches.
- **Playlist batches:** `enqueuePlaylist` uses `PlaylistSync.plan` to skip tracks that are
  already local and download only the missing ones.

## Deletion rules

Deleting a playlist removes its entry records only — shared track files are never deleted
with it. Deleting a track removes its file and cleans playlist references, and the UI warns
first, listing the playlists that still reference the track
(`LocalLibraryStore.playlistTitlesReferencing`).

## Offline playback

`PlaybackResolver` checks the local library before playback: when a track is completed
locally, `PlayerService.playableItem(for:streamURL:)` returns the `.local` file instead of
the stream (toggle: `PlayerService.preferLocalPlayback`, default on). The player UI badges
offline playback ("Playing offline copy") separately from streaming.
