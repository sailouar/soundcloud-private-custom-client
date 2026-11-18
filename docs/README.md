# SoundCloud Personal Offline Client

Personal native iOS client architecture for SoundCloud browsing, streaming, and an authorized offline library.

## Status

All six roadmap phases are now **implemented in source** and documented: the Foundation-only core (capability states, OAuth 2.1 + PKCE contract, endpoint policy, resource models, download manager with dedup and atomic files, playlist reconciliation, offline-first playback resolver), the iOS app shell (Keychain sign-in, 5-tab SwiftUI interface, AVFoundation player with background audio and lock-screen controls, SwiftData local library), the AltStore build lane, and unit tests for the new core logic. Native compilation, simulator tests, device sign-in, and IPA packaging remain **pending on a Mac** (friend's Mac or cloud Mac — see `docs/BUILD.md`, "Second-Mac build handoff"). Nothing is claimed as compiled or device-verified yet.

The app is a single-owner personal build delivered through AltStore/AltServer with a free Apple ID (7-day refresh), not an App Store release. No SoundCloud app secret is committed or embedded in the build; the owner enters the client ID and secret on the device.

## Product principles

- Offline files are created only through an officially supported, explicitly authorized download path.
- Streaming is not treated as download permission.
- Track IDs are unique in the local library, even when referenced by multiple playlists.
- Unsupported API operations are shown as unavailable rather than simulated.

See the subsystem documents in this directory and the roadmap in [`../.planning/ROADMAP.md`](../.planning/ROADMAP.md).
