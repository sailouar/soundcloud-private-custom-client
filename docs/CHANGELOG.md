# Changelog

## Unreleased - 2026-11-15

- Initialized GSD project tracking from `Task.md`.
- Added project constraints, requirements, roadmap, and state.
- Added mandatory architecture and subsystem documentation.
- Explicitly gated downloads on official authorization.
- Researched existing GitHub projects and recorded reusable patterns and incompatibilities.
- Added the Foundation-only capability tracer, sanitized fixture transport, typed capability
  states, and deny-by-default download authorization regression tests. Cloud-Mac Swift
  verification remains pending.
- Added the canonical SwiftUI app/test source layout, Xcode project and shared scheme,
  protocol-only `LocalStore` boundary, candidate iOS 17/SwiftData markers, and reproducible
  Windows/cloud-Mac verification instructions. Native verification remains pending without
  a cloud Mac.
- Added the executable OAuth 2.1 + PKCE contract: official hosts, custom-scheme redirect
  validation, state and one-time-code checks, token exchange, single-use refresh replacement,
  redacted token models, and a protocol-only `TokenStore`. Cloud-Mac Swift execution remains
  pending.
- Added the documented API endpoint contract with official host and `OAuth` header
  enforcement, typed refusals for unsupported operations, stream-only disposition, and
  retryable/auth error classification. Cloud-Mac Swift execution remains pending.
- Reconciled the Phase 1 documentation with the implemented source and tests: added a
  source-to-document claim table, the explicit legal prohibitions (scraping, hidden stream
  URL extraction, DRM/access-control bypass, ad skipping, unauthorized downloading), the
  testing matrix, and the Windows-runnable documentation audit. Cloud-Mac execution of the
  Swift suites remains pending.
- Added the Phase 2 personal-build authentication adapter: on-device OAuth app credentials
  in the Keychain, `ASWebAuthenticationSession` sign-in, `URLSession` token transport, a
  sign-in/restore/sign-out coordinator with typed recoverable failures, the registered
  `soundcloudpersonal` URL scheme, and a signed-team-free AltStore IPA build script.
  Compilation, device sign-in, and the IPA build remain pending on a cloud Mac.
- Added a second-Mac (friend) build handoff to `docs/BUILD.md`: clone, optionally
  run the Swift/Xcode verification suites, run `scripts/build-altstore-ipa.sh`,
  and return the unsigned IPA — no signing identity or SoundCloud secret involved.
- Implemented roadmap Phases 3-6 in source (authored; cloud-Mac verification pending):
  - Core: resource models (`SCUser`/`SCTrack`/`SCPlaylist`/collections/transcodings),
    live `SoundCloudResources` client over `ResourceTransport` + `AccessTokenProvider`
    (search, profiles, likes, follows, playlists, stream resolution — stream-only),
    `DownloadManager` actor (per-track entitlement gate, track-ID dedup, atomic temp-to-library
    moves, progress/cancel/retry/failure states), `LocalLibraryStore` boundary with an
    in-memory implementation, `PlaylistSync` reconciliation, and the offline-first
    `PlaybackResolver` (a downloaded track plays from the local file, not the stream).
  - App: `URLSession` resource transport, `URLSessionDownloadSession`, AVFoundation
    `PlayerService` (queue, shuffle, repeat, background audio, Now Playing + remote
    commands), SwiftData entities + `SwiftDataLocalStore` (track owns the file; playlists
    reference tracks via ordered entries), view models, and the 5-tab UI
    (Home/Search/Library/Downloads/Player) with track/artist detail sheets.
  - Tests: `ResourceModelTests`, `DownloadManagerTests`, `PlaylistSyncTests`,
    `PlaybackResolverTests`. All new files registered in `project.pbxproj`;
    `UIBackgroundModes = audio` added to `Info.plist`.
  - Downloads remain deny-by-default: they start only when the uploader's documented
    `downloadable` flag is set AND the API response itself provides a download location,
    and the download capability is confirmed. Streaming is never treated as permission.
