# Project Research Summary

**Date:** 2026-11-15
**Scope:** Existing GitHub implementations, official SoundCloud API constraints, and scraping/download feasibility.

## Key Findings

### Closest architectural reference

[leonwwest/cloudscrobble-ios](https://github.com/leonwwest/cloudscrobble-ios) is a native SwiftUI client with a testable Swift core, OAuth with PKCE and state validation, Keychain-backed sessions, a token-broker boundary, queue/playback flows, and CI. It explicitly does not implement offline download/storage, so it is a reference for authentication, service boundaries, testing, and cloud Mac builds rather than a complete solution.

### Useful but non-compliant reference

[Vlad175cm/vlswmplayer-ios](https://github.com/Vlad175cm/vlswmplayer-ios) is a small SwiftUI/AVPlayer app with local caching, metadata, background-style player UX, and a GitHub Actions macOS build. Its README says it uses the public `api-v2` endpoint, extracts a client ID from JavaScript, resolves HLS URLs, and caches playback. It also says those endpoints are not official. Those techniques must not be copied into this project.

### Downloader reference

[cranci1/Osmium](https://github.com/cranci1/Osmium) is an archived iOS client for the Cobalt API and lists SoundCloud audio support. It is not a SoundCloud official API client, and its downloader behavior cannot establish authorization for this app. It is useful only as a UX reference for progress, metadata, and iOS file handling.

### Official constraints

The official [API Guide](https://developers.soundcloud.com/docs/api/) documents OAuth 2.1 with PKCE, mobile custom-scheme redirects, approximately one-hour access tokens, and single-use refresh tokens. The [API Terms of Use](https://developers.soundcloud.com/docs/api/terms-of-use) prohibit using the API to rip, capture, or copy user content or circumvent uploader content restrictions.

## Implications for Roadmap

1. Reuse the CloudScrobble-style separation between SwiftUI views, a testable core, API protocols, and secure auth/token boundaries.
2. Do not copy undocumented endpoint scraping or direct HLS caching from vlswmplayer.
3. Treat download authorization as a hard Phase 1 decision. If the official API provides no permitted path for a track, the product must show streaming-only behavior for that track.
4. Build the download manager behind an authorization protocol so it can be implemented and tested without assuming every stream is downloadable.
5. Add a privacy/terms review before any public distribution.

## Sources

- [SoundCloud API Guide](https://developers.soundcloud.com/docs/api/)
- [SoundCloud API Terms of Use](https://developers.soundcloud.com/docs/api/terms-of-use)
- [CloudScrobble iOS](https://github.com/leonwwest/cloudscrobble-ios)
- [vlswmplayer for iOS](https://github.com/Vlad175cm/vlswmplayer-ios)
- [Osmium](https://github.com/cranci1/Osmium)
- [Deprecated SoundCloudAPI Swift package](https://github.com/SoundcloudUnofficialApp/SoundCloudAPI)
