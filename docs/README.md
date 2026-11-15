# SoundCloud Personal Offline Client

Personal native iOS client architecture for SoundCloud browsing, streaming, and an authorized offline library.

## Status

The Foundation-only core contracts and the iOS app shell are implemented and documented: capability states, the OAuth 2.1 + PKCE contract, the documented API endpoint policy, the Keychain-backed personal sign-in path, and the AltStore build lane. Native compilation, simulator tests, device sign-in, and IPA packaging remain pending on a cloud Mac.

The app is a single-owner personal build delivered through AltStore/AltServer with a free Apple ID (7-day refresh), not an App Store release. No SoundCloud app secret is committed or embedded in the build; the owner enters the client ID and secret on the device.

## Product principles

- Offline files are created only through an officially supported, explicitly authorized download path.
- Streaming is not treated as download permission.
- Track IDs are unique in the local library, even when referenced by multiple playlists.
- Unsupported API operations are shown as unavailable rather than simulated.

See the subsystem documents in this directory and the roadmap in [`../.planning/ROADMAP.md`](../.planning/ROADMAP.md).
