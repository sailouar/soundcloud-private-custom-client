# Database

The local store must have one track record per SoundCloud track ID. A track record includes the original URL, metadata, artwork reference, local path, download status, error information, and timestamps.

Playlist records reference tracks through ordered join records. This permits the same track file to appear in many playlists and ensures deleting a playlist does not delete the file. Track deletion must update or remove join records and warn when references remain.

Phase 1 records SwiftData as the candidate technology at iOS 17.0, with
`LocalStore` keeping the core independent of the persistence framework. The
cloud-Mac `testSwiftDataRelationshipAndMigration` smoke test remains required
to confirm deployment support, relationship queries, and save/reload behavior.
No persistence implementation or database files are claimed in this phase.

## Implementation (Phase 5, authored)

SwiftData entities live in `ios/SoundCloudPersonal/Storage/SwiftDataModels.swift`:

- `LocalTrackEntity` — one row per SoundCloud track ID (`@Attribute(.unique)`), owns the
  local file path, status, progress, metadata, artwork URL, timestamps.
- `LocalPlaylistEntity` — collection with ordered entries; cascade delete removes entries
  only, never track files.
- `LocalPlaylistEntry` — ordered join record (`index`, `track`, `playlist`).

`SwiftDataLocalStore` (`Storage/SwiftDataLocalStore.swift`) implements the core
`LocalLibraryStore` protocol on a single actor; `InMemoryLocalStore` serves previews and
tests. Deleting a track removes its entries first and warns via
`playlistTitlesReferencing`. The cloud-Mac/CI smoke test
(`StorageMigrationSmokeTests`) still has to confirm relationship and save/reload behavior.
