# SoundCloud Personal Offline Client

## What This Is

A personal native iOS client for browsing and playing a user's SoundCloud content, with a centralized offline library for tracks that SoundCloud and the uploader explicitly permit the app to download. It is designed for one owner first, uses SwiftUI and native audio services, and clearly separates streamed tracks from locally available files.

## Core Value

The owner can reliably find and play their SoundCloud music offline without duplicate local files or misleading download behavior.

## Requirements

### Validated

(None yet - greenfield project.)

### Active

- [ ] Establish the currently supported SoundCloud authentication and API capability matrix.
- [ ] Provide authenticated discovery, search, track details, likes, follows, and playlists where officially supported.
- [ ] Provide native streaming and background playback with lock-screen controls.
- [ ] Download only explicitly authorized audio and persist metadata safely.
- [ ] Deduplicate local tracks by SoundCloud track ID across individual downloads and playlists.
- [ ] Manage local playlists independently from file ownership and support offline playback.
- [ ] Document a reproducible Windows-first workflow and the cloud Mac build/signing boundary.

### Out of Scope

- Unauthorized downloading, hidden stream URL extraction, DRM circumvention, or access-control bypassing - prohibited by the product constraints.
- A public multi-user backend or account system - this is a personal client.
- Reproducing SoundCloud proprietary branding or assets - the UI may be inspired by visual language only.
- Claiming unsupported SoundCloud write/download operations work - unsupported API behavior must be surfaced as a limitation.

## Context

- The initial workspace contained only `Task.md`; no source tree or existing iOS project is present.
- Development occurs on Windows 11 with VS Code and no local Mac, so local iOS compilation and signing cannot be assumed.
- The first release is offline-first for personal use, but API capability validation is a hard prerequisite for download work.
- The requested local library must use the SoundCloud track ID as its unique identity and must not remove shared files when a playlist is deleted.

## Constraints

- **Platform**: Swift and SwiftUI with AVFoundation, URLSession, Keychain, FileManager, and SwiftData or SQLite - required native architecture.
- **Authorization**: Download only through an official, explicitly permitted path - personal use does not change authorization requirements.
- **Privacy**: Never store SoundCloud passwords; keep tokens in the iOS Keychain.
- **Build environment**: Windows-compatible scripts and documentation; cloud Mac workflow required for actual iOS build/signing.
- **Reliability**: Download operations need cancellation, retry, progress, failure states, and atomic file handling.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Offline-first personal MVP | The main differentiator is reliable local playback and deduplicated storage. | - Pending |
| Track ID is the local identity | The same track can arrive from multiple playlists or direct download. | - Pending |
| Official capability gate before downloads | Streaming availability does not imply download permission. | - Pending |
| SwiftUI plus modular services | Keeps UI testable and allows API/storage/player boundaries to evolve. | - Pending |
| SwiftData or SQLite after capability research | Persistence choice should fit iOS deployment and relationship/query needs. | - Pending |

## Evolution

After each phase, update this document: move shipped requirements to Validated, record new constraints and decisions, and remove stale assumptions.

---
*Last updated: 2026-11-15 after project initialization from Task.md*
