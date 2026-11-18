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

## Legal and policy boundary

The client implements only documented API behavior. The following are explicitly out of scope and have no implementation path:

- scraping of SoundCloud web pages or undocumented endpoints;
- hidden stream URL extraction;
- DRM or access-control bypass;
- ad skipping or advertising controls;
- unauthorized downloading, including turning a stream response into a file.

Streaming is playback, not download authorization. `DownloadAuthorization` denies a
download request unless a positive, track-specific, official entitlement is supplied
separately, and `EndpointDisposition.streamOnly` reports `allowsOfflineFile == false`.
When an operation is unavailable, the client surfaces a typed unsupported or
permission-gated state instead of a false success.

The source-to-document reconciliation for these claims is in
[`ARCHITECTURE.md`](ARCHITECTURE.md#source-to-document-reconciliation), and the audit
procedure is in [`TESTING.md`](TESTING.md#source-to-document-audit).

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

## Documented endpoint contract (Phase 1, Plan 01-03)

`APIEndpoint` in `Sources/SoundCloudCore/API/APIEndpoint.swift` represents only operations that
appear in the reviewed official OpenAPI document. Every request uses the official base URL
`https://api.soundcloud.com` and the documented header `Authorization: OAuth <access token>`.

| Kind | Method and path | Disposition |
|------|-----------------|-------------|
| `authenticatedProfile` | `GET /me` | read |
| `searchTracks` | `GET /tracks?q=` | read |
| `searchUsers` | `GET /users?q=` | read |
| `searchPlaylists` | `GET /playlists?q=` | read |
| `track` | `GET /tracks/{track_urn}` | read |
| `user` | `GET /users/{user_urn}` | read |
| `playlist` | `GET /playlists/{playlist_urn}` | read |
| `likedTracks` | `GET /me/likes/tracks` | read |
| `ownPlaylists` | `GET /me/playlists` | read |
| `likeTrack` / `unlikeTrack` | `POST` / `DELETE /likes/tracks/{track_urn}` | write |
| `followUser` / `unfollowUser` | `PUT` / `DELETE /me/followings/{user_urn}` | write |
| `trackStreams` | `GET /tracks/{track_urn}/streams` | **stream only** |
| `resolveURL` | `GET /resolve?url=` | read |
| `disconnect` | `POST /disconnect` | write |

Search is the resource collection with a `q` parameter (`/tracks`, `/users`, `/playlists`);
the OpenAPI document contains no `/search` alias and no album resource. `streamOnly` endpoints
report `allowsOfflineFile == false` for every disposition, because no documented endpoint grants
an offline file in Phase 1.

Path parameters are validated against an unreserved character set, so a track or user identifier
cannot inject a path segment, query, fragment, scheme, or traversal sequence.

### Typed unsupported operations

`UnsupportedAPIOperation` enumerates operations the reviewed material does not support — album
search, general downloads, original upload-file downloads, advertising controls, undocumented
media-URL extraction, content-protection circumvention, web-page harvesting, and unpermitted
downloading. Resolving one through `APIEndpoint.resolve(_:)` throws
`APIPolicyError.unsupportedOperation`; no caller can build a request for it.

### Error classification

Documented statuses are preserved as `APIError.httpStatus`. `401` is an authentication failure,
`403` is a permission failure, and `429`, `500`, `503`, and `504` are marked retryable with
backoff. A typed error is never converted into an optimistic capability state.

## Resource client (implemented, Phase 3+)

`SoundCloudResources` (`Sources/SoundCloudCore/API/SoundCloudResources.swift`) is the live
read/write client used by the UI. Every request is built through `APIEndpoint`, so host,
scheme, OAuth header, and path-parameter validation are enforced in one place; the app
supplies a `ResourceTransport` (URLSession) and an `AccessTokenProvider` (Keychain-backed,
refreshing near expiry).

- Search: `searchTracks`, `searchUsers`, `searchPlaylists` (paginated `SCCollection`, `nextHref`).
- Details: `track(urn:)`, `user(urn:)`, `playlist(urn:)`, `resolve(url:)`, `me()`.
- Account library: `likedTracks`, `ownPlaylists`.
- Social writes: `likeTrack`/`unlikeTrack` (`POST`/`DELETE /likes/tracks/{urn}`),
  `followUser`/`unfollowUser` (`PUT`/`DELETE /me/followings/{urn}`).
- Streaming: `streamURL(for:)` prefers the `progressive` transcoding from the track's
  documented `media.transcodings`, falls back to `GET /tracks/{urn}/streams`, and resolves
  the transcoding API URL with an authorized GET. The resolved media URL is stream-only and
  is never persisted as an offline file.
- Models decode with `.convertFromSnakeCase` (`SCUser`, `SCTrack`, `SCPlaylist`, `SCMedia`,
  `SCTranscoding`, `SCResolvedStream`); all fields beyond identity are optional.

There is still no documented album search and no documented download endpoint; album search
remains a typed refusal, and downloads stay gated on the per-track entitlement
(`SCTrack.downloadable` + an API-provided `download_url`), never on stream availability.
