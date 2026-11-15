# SoundCloud Personal Offline Client

Personal native iOS client architecture for SoundCloud browsing, streaming, and an authorized offline library.

## Status

Project initialization is complete. There is no implemented iOS source tree yet. Phase 1 must verify the official SoundCloud API and establish the SwiftUI project structure before feature claims can be made.

## Product principles

- Offline files are created only through an officially supported, explicitly authorized download path.
- Streaming is not treated as download permission.
- Track IDs are unique in the local library, even when referenced by multiple playlists.
- Unsupported API operations are shown as unavailable rather than simulated.

See the subsystem documents in this directory and the roadmap in [`../.planning/ROADMAP.md`](../.planning/ROADMAP.md).
