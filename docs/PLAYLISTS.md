# Playlists

Remote SoundCloud playlists and local downloaded collections are separate concepts connected by stable track IDs. Local playlist entries preserve order and may reference a shared local track.

Remote writes and synchronization are implemented only where officially supported. A remote playlist deletion or local playlist deletion removes references, not shared audio files.

## Implementation (Phase 6, authored)

- `PlaylistSync.plan(remoteTracks:localTrackIDs:)` splits a remote playlist into tracks to
  download vs. already-local (dedup by track ID, order preserved).
- `PlaylistSync.reconcile(remoteTracks:localPlaylist:)` re-orders a local collection to
  follow the remote playlist, appends new remote tracks (reported for download), and never
  deletes local tracks that disappeared remotely.
- `DownloadManager.enqueuePlaylist` downloads only the missing tracks.
- `LocalPlaylistRecord`/`LocalPlaylistEntity` store ordered track-ID references; entries
  are join records, so deleting a playlist never deletes shared track files
  (`SwiftDataLocalStore.deletePlaylist` cascades entries only).
- `LocalLibraryStore.playlistTitlesReferencing` powers the delete-track warning;
  `deleteTrack` removes the file and cleans the references.
- Remote playlist create/edit/delete/reorder are only wired where the documented API
  supports them; everything else is surfaced as unavailable rather than simulated.
