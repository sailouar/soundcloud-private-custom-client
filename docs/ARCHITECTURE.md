# Architecture

The planned app is a native SwiftUI client with feature-oriented UI and protocol-based services:

- `SoundCloudAPI`: authenticated requests, pagination, decoding, rate-limit handling.
- `Authentication`: official OAuth/session flow and Keychain token storage.
- `LocalStore`: protocol boundary for the selected SwiftData storage adapter;
  persistence implementation is deferred until the cloud-Mac smoke test passes.
- `DownloadManager`: authorization gate, queue, progress, cancellation, retry, atomic file moves.
- `Playback`: AVFoundation player, queue, background session, Now Playing and remote commands.
- `FileStore`: dedicated app library directory, artwork files, cleanup and free-space checks.

The download manager owns file lifecycle. Playlist deletion removes references only; shared track files are removed only through explicit track deletion after warning about references.

The SwiftUI app target lives under `ios/SoundCloudPersonal/` and consumes the
Foundation-only `SoundCloudCore` package. Capability state is injected through
`AppEnvironment` and rendered without inferring support from a URL or stream
response.

## Phase 1 core contracts

| Area | Stable symbols | Source | Documented behavior |
|------|----------------|--------|---------------------|
| Capability | `CapabilityState`, `CapabilityOperation`, `CapabilityRegistry` | `Sources/SoundCloudCore/API/` | Supported, unsupported, permission-gated, and temporarily unavailable states; never inferred from a URL. |
| Transport | `HTTPTransport`, `MockAPITransport` | `Sources/SoundCloudCore/Transport/` | Method/path fixtures that preserve HTTP status and API messages. |
| Authentication | `OAuthConfiguration`, `OAuthTransaction`, `OAuthCallback`, `TokenBundle`, `TokenStore`, `AuthenticationService` | `Sources/SoundCloudCore/Auth/` | Official OAuth 2.1 + PKCE, exact redirect/state validation, single-use refresh replacement, protocol-only secure storage. |
| API endpoints | `APIEndpoint`, `APIEndpointKind`, `UnsupportedAPIOperation` | `Sources/SoundCloudCore/API/APIEndpoint.swift` | Documented operations only, official host and `OAuth` header, typed refusals, stream-only disposition. |
| Download policy | `DownloadAuthorization` | `Sources/SoundCloudCore/Downloads/DownloadAuthorization.swift` | Deny until an explicit official entitlement exists; playback never authorizes a file. |
| Storage | `LocalStore` | `Sources/SoundCloudCore/Storage/LocalStore.swift` | Protocol-only; the SwiftData adapter is deferred until the cloud-Mac smoke test passes. |

`SoundCloudCore` imports only Foundation and, where available, CryptoKit for the
S256 challenge. It never imports SwiftUI, UIKit, AVFoundation, or Security; the app
target supplies those adapters.

## Phase 2 app adapters

| Adapter | File | Platform boundary |
|---------|------|-------------------|
| Keychain records and token store | `ios/SoundCloudPersonal/Auth/KeychainStore.swift` | `Security` generic-password items; one JSON session record; credentials and tokens never touch files. |
| System browser sign-in | `ios/SoundCloudPersonal/Auth/BrowserAuthenticator.swift` | `ASWebAuthenticationSession` returns only the registered custom-scheme callback. |
| OAuth network transport | `ios/SoundCloudPersonal/Auth/URLSessionOAuthTransport.swift` | `URLSession` against the documented token endpoint only. |
| Sign-in coordinator | `ios/SoundCloudPersonal/Auth/AuthenticationCoordinator.swift` | Credential validation, transaction lifetime, restore/refresh/sign-out, typed retryable failures. |
| Account UI | `ios/SoundCloudPersonal/Views/AuthenticationView.swift` | Setup and account states rendered from the coordinator. |


## Source-to-document reconciliation

This source-to-document table keeps each documentation claim anchored to a
concrete declaration or test. `docs/TESTING.md` describes the automated audit
that fails when a stable source claim is missing from these documents.

| Claim | Source anchor | Test anchor |
|-------|---------------|-------------|
| Capability states are typed and never inferred from a URL | `Sources/SoundCloudCore/API/Capability.swift` | `ios/SoundCloudPersonalTests/CapabilityMatrixTests.swift` |
| Sanitized fixtures preserve HTTP/API errors | `Sources/SoundCloudCore/Transport/MockAPITransport.swift` | `ios/SoundCloudPersonalTests/MockTransportTests.swift` |
| Streaming cannot authorize an offline file | `Sources/SoundCloudCore/Downloads/DownloadAuthorization.swift` | `ios/SoundCloudPersonalTests/DownloadAuthorizationTests.swift` |
| OAuth uses the official hosts, S256 PKCE, and state | `Sources/SoundCloudCore/Auth/OAuthConfiguration.swift`, `PKCE.swift` | `ios/SoundCloudPersonalTests/OAuthPKCETests.swift` |
| Callbacks require exact redirect, state, and one-time codes | `Sources/SoundCloudCore/Auth/OAuthCallback.swift` | `ios/SoundCloudPersonalTests/OAuthCallbackTests.swift` |
| Tokens are redacted, refreshed as a single-use replacement, and stored behind `TokenStore` | `Sources/SoundCloudCore/Auth/TokenModels.swift`, `TokenStore.swift`, `AuthenticationService.swift` | `ios/SoundCloudPersonalTests/OAuthPKCETests.swift` |
| API requests use `api.soundcloud.com` and `OAuth` auth only | `Sources/SoundCloudCore/API/APIEndpoint.swift` | `ios/SoundCloudPersonalTests/APIContractTests.swift` |
| The SwiftUI adapter renders injected core state | `ios/SoundCloudPersonal/AppEnvironment.swift` | `ios/SoundCloudPersonalTests/CapabilityAdapterIntegrationTests.swift` |
| Sign-in uses the system browser and a Keychain session | `ios/SoundCloudPersonal/Auth/AuthenticationCoordinator.swift`, `KeychainStore.swift` | Cloud-Mac/device run (pending) |
| SwiftData candidate relationship/migration | `Sources/SoundCloudCore/Storage/LocalStore.swift`, `ios/SoundCloudPersonal/Views/CapabilityStatusView.swift` | `ios/SoundCloudPersonalTests/StorageMigrationSmokeTests.swift` |
| Cloud-Mac project, scheme, and iOS 17.0 target | `SoundCloudPersonal.xcodeproj/project.pbxproj`, shared scheme | `docs/BUILD.md` cloud-Mac lane (execution pending) |

CloudScrobble is an architectural reference for a split core/app package and
mock-backed tests only. It is not an authority on SoundCloud permissions, and no
downloader behavior from any third-party project is reproduced here.

## Implemented app layer (Phases 3-6, authored — CI verification pending)

| Area | Files | Notes |
|------|-------|-------|
| Resource client | `Sources/SoundCloudCore/API/{Models,ResourceTransport,SoundCloudResources}.swift` | Search, profiles, likes/follows, playlists, stream resolution (stream-only). |
| Downloads | `Sources/SoundCloudCore/Downloads/{DownloadJob,DownloadManager}.swift` | Per-track entitlement gate, track-ID dedup, atomic temp-to-library moves, progress/cancel/retry. |
| Library | `Sources/SoundCloudCore/Storage/{LocalLibrary,InMemoryLocalStore}.swift`, `ios/.../Storage/{SwiftDataModels,SwiftDataLocalStore}.swift` | Protocol boundary + SwiftData adapter; playlists reference shared track files. |
| Playlists | `Sources/SoundCloudCore/Playlists/PlaylistSync.swift` | Missing-vs-local planning and remote-order reconciliation. |
| Playback | `Sources/SoundCloudCore/Playback/PlaybackResolver.swift`, `ios/.../Services/PlayerService.swift` | Offline-first resolution; AVFoundation queue, background audio, Now Playing + remote commands. |
| UI | `ios/SoundCloudPersonal/Views/*.swift`, `ViewModels/*.swift` | 5 tabs (Home/Search/Library/Downloads/Player), dark theme, orange accent, detail sheets, sign-in gate. |
| CI | `.github/workflows/build-ipa.yml` | Free macOS runner on the public repo: tests + unsigned IPA artifact. |
