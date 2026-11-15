# SoundCloud API

Phase 1 must verify current official documentation before implementation. The app must use documented authentication and API endpoints, respect rate limits, and preserve pagination and error responses.

The official API guide currently documents:

- API base URL: `https://api.soundcloud.com`
- Authentication host: `https://secure.soundcloud.com`
- OAuth 2.1 with required PKCE for authorization-code flows.
- Access tokens that expire after approximately one hour.
- Single-use refresh tokens, which must be replaced after refresh.
- Custom protocol redirect schemes for mobile applications.

The critical capability matrix covers OAuth/session restore, discovery, search, track/artist metadata, likes, follows, playlist reads/writes, stream playback, and explicitly authorized downloads. A streamable response is not evidence that a downloadable file is permitted.

If a capability is unavailable, the UI must show a stable unavailable/unsupported state and never scrape hidden URLs or pretend the operation succeeded.

Source: [SoundCloud API Guide](https://developers.soundcloud.com/docs/api/) (accessed 2026-11-15). The exact download authorization mechanism remains a Phase 1 gate and must not be inferred from streaming endpoints.

SoundCloud's [API Terms of Use](https://developers.soundcloud.com/docs/api/terms-of-use) state that user content rights remain with uploaders, usage restrictions must be respected, and the API must not be used to rip, capture, copy, or circumvent content protections. Personal use does not remove those API restrictions.

## Phase 1 capability tracer

`SoundCloudCore` records API outcomes through a Foundation-only transport boundary. Sanitized
method/path fixtures are decoded by `SoundCloudAPI` and normalized by `CapabilityRegistry` into
`supported`, `unsupported`, `requiresUserPermission`, or `temporarilyUnavailable`.
HTTP status and API messages remain errors instead of becoming optimistic capability states.

Playback capability is intentionally separate from download authorization. The
`DownloadAuthorization` boundary denies missing, permission-gated, and stream-only results by
default. A future download request requires a positive, documented official entitlement supplied
separately; no playback URL is accepted as a file source.

The package and tests are authored on Windows, but `swift package describe` and `swift test`
remain pending for the cloud-Mac lane because Swift/Xcode is unavailable on the authoring host.
