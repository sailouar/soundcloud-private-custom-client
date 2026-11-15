# Phase 1: API and Platform Foundation - Research

**Researched:** 2026-11-15  
**Domain:** SoundCloud official API capability mapping, OAuth 2.1 PKCE, native SwiftUI modularization, and Windows-to-cloud-Mac delivery  
**Confidence:** HIGH for documented SoundCloud authentication and API surface; MEDIUM for the proposed Swift package boundaries; LOW for any conclusion about permitted audio downloads because the official material reviewed does not document a general download entitlement.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| PLAT-01 | The project documents a Windows-first workflow and a cloud Mac build/signing path. [VERIFIED: .planning/REQUIREMENTS.md:10,71] “**PLAT-01**: The project documents a Windows-first workflow and a cloud Mac build/signing path.” | Windows can author Swift package sources, fixtures, scripts, and documentation; a macOS/Xcode lane must own iOS compilation, simulator, signing, and device checks. |
| API-01 | The app uses a documented, officially supported SoundCloud authentication flow. [VERIFIED: .planning/REQUIREMENTS.md:11,71] “**API-01**: The app uses a documented, officially supported SoundCloud authentication flow.” | Use SoundCloud’s authorization-code flow with required PKCE, exact registered redirect URI matching, state validation, and token refresh replacement. |
| API-02 | The app records supported, unsupported, and permission-gated API operations without faking success. [VERIFIED: .planning/REQUIREMENTS.md:12,71] “**API-02**: The app records supported, unsupported, and permission-gated API operations without faking success.” | Create a capability registry and typed capability result; a stream response is playback capability only, never download authorization. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Read project instructions before changes. [VERIFIED: AGENTS.md:3] “Read this file before making changes.”
- Keep implementation and Markdown in `docs/` synchronized. [VERIFIED: AGENTS.md:4] “Keep implementation and the Markdown files in `docs/` synchronized.”
- Use only officially supported SoundCloud APIs and authorization flows. [VERIFIED: AGENTS.md:7] “Use only officially supported SoundCloud APIs and authorization flows.”
- Never scrape hidden media URLs, bypass access controls, or circumvent DRM. [VERIFIED: AGENTS.md:8] “Never scrape hidden media URLs, bypass access controls, or circumvent DRM.”
- Keep the app native Swift/SwiftUI and preserve a modular service boundary. [VERIFIED: AGENTS.md:9] “Keep the app native Swift/SwiftUI and preserve a modular service boundary.”
- Treat offline files as permitted downloads only; streaming is not download authorization. [VERIFIED: AGENTS.md:10] “Treat offline files as permitted downloads only; streaming is not download authorization.”
- Prefer small, testable changes and document platform limitations. [VERIFIED: AGENTS.md:13] “Prefer small, testable changes and document known platform limitations.”

## Summary

The foundation should be a native Swift package containing pure domain contracts, capability decisions, OAuth request/response models, and a protocol-based SoundCloud client, with a thin SwiftUI application target supplying navigation and platform adapters. This follows Apple’s documented Swift Package model: a package has a `Package.swift` manifest, can expose library products, and can declare platform deployment targets and resources. [CITED: https://developer.apple.com/documentation/packagedescription.md] A CloudScrobble-style separation is a useful architectural reference because its public repository describes a `CloudScrobbleCore` package, protocol-driven app dependencies, PKCE/state validation, Keychain sessions, fixtures, and CI; it is a reference only, not an authority for SoundCloud permissions. [CITED: https://github.com/leonwwest/cloudscrobble-ios]

SoundCloud’s current API Guide documents `https://api.soundcloud.com` as the API host, `https://secure.soundcloud.com` as the authentication host, OAuth 2.1 with required PKCE, approximately one-hour access-token expiry, single-use refresh tokens, and `Authorization: OAuth ACCESS_TOKEN` for API calls. [CITED: https://developers.soundcloud.com/docs/api/] The phase should encode those facts in tests and documentation, not hide them in view code. The official OpenAPI document exposes authenticated user, search, track, user, likes, follows, playlist, metadata, and stream operations in the reviewed specification. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json]

The download decision is a hard safety gate. The official terms say not to rip, capture, or copy User Content through the API and not to circumvent uploader restrictions or content protection. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] The reviewed official API material documents stream playback but does not document a general offline-download entitlement; this is **no observation, not proof of absence**. Therefore Phase 1 must implement an explicit `DownloadAuthorization` decision boundary and record “permission-gated pending positive evidence” until an official, track-specific permitted path is positively documented. Never turn `/tracks/{track_urn}/streams`, a redirect, or a cached playback response into a downloadable file.

**Primary recommendation:** Build a dependency-free Swift package core with capability-aware API contracts and mock transport first; keep Keychain, browser callbacks, URLSession background transfers, AVFoundation, and SwiftUI in platform/app adapters, and make “no explicit official download authorization” a visible non-downloadable result.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| OAuth authorization URL, callback validation, token exchange | API / Backend contract in `SoundCloudCore`; browser callback in app | Browser / Client | OAuth protocol state and parsing should be testable without SwiftUI; the app owns the system browser and callback URL. [CITED: https://developers.soundcloud.com/docs/api/] |
| Keychain token persistence | Browser / Client platform adapter | API / Backend contract | Keychain is an Apple Security service for small secure values; the core should depend on a `TokenStore` protocol, not Security framework calls. [CITED: https://developer.apple.com/documentation/security/keychain-services] |
| SoundCloud requests, decoding, pagination, rate/error mapping | API / Backend contract | Browser / Client | API host, authorization header, response models, and capability states are integration concerns, independent of views. [CITED: https://developers.soundcloud.com/docs/api/] |
| Capability matrix and download authorization | API / Backend contract | Browser / Client | A single decision service prevents streamability from being mistaken for permission to create a local file. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] |
| SwiftUI navigation and honest unavailable states | Browser / Client | API / Backend contract | Views render typed state and do not infer support from URL presence. [ASSUMED] |
| Audio playback and future authorized transfer | Browser / Client | CDN / Static | AVFoundation/URLSession are platform adapters; this phase should define protocols, not implement prohibited extraction. [ASSUMED] |

## Standard Stack

### Core

| Library / framework | Version | Purpose | Why standard |
|---|---|---|---|
| Swift Package Manager | Swift toolchain version selected by the cloud Mac image | Package manifest, core target, test target | Apple documents `Package.swift`, library products, targets, deployment platforms, and resources as the standard package structure. [CITED: https://developer.apple.com/documentation/packagedescription.md] |
| Foundation | Apple SDK supplied by the cloud Mac | `URL`, `URLRequest`, Codable models, URL loading abstractions, clock/date types | It is the native foundation for URL loading and value modeling; keep it behind protocols where test determinism matters. [ASSUMED] |
| SwiftUI | Apple SDK supplied by the cloud Mac | Native app shell and capability-aware views | Required by the project constraints and appropriate for a thin declarative app target. [VERIFIED: .planning/PROJECT.md:43] “**Platform**: Swift and SwiftUI with AVFoundation, URLSession, Keychain, FileManager, and SwiftData or SQLite - required native architecture.” |
| Security / Keychain Services | Apple SDK supplied by the cloud Mac | Secure storage for access/refresh token material | Apple documents Keychain services as secure storage for small chunks of user data. [CITED: https://developer.apple.com/documentation/security/keychain-services] |
| URLSession | Apple SDK supplied by the cloud Mac | Authenticated API transport; later, only authorized downloads | Apple documents background download sessions with a stable identifier, delegate delivery, relaunch handling, and moving the temporary file to permanent storage. [CITED: https://developer.apple.com/documentation/foundation/downloading-files-in-the-background.md] |

### Supporting

| Component | Version | Purpose | When to use |
|---|---|---|---|
| `SoundCloudCore` local Swift package | Phase 1 source | Domain types, capability registry, auth contracts, API protocols, fixture transport | Always; this is the testable boundary consumed by the iOS app. [ASSUMED] |
| `SoundCloudCoreTests` | Swift Testing/XCTest supported by the selected cloud Mac SDK | PKCE/state/capability/API contract tests | Always; use sanitized fixtures and never real audio or credentials. [ASSUMED] |
| `KeychainTokenStore` app adapter | Apple Security framework | Persist token bundle, atomically replace single-use refresh token | Phase 2 implementation behind the Phase 1 protocol. [CITED: https://developer.apple.com/documentation/security/keychain-services] |
| `MockAPITransport` | In-memory Swift type | Deterministic API response/error fixtures | Windows-authored tests and cloud Mac unit tests. [ASSUMED] |

**External package recommendation:** none for Phase 1. Prefer Apple SDKs and local protocols so the initial package has no third-party dependency or package-legitimacy risk. [ASSUMED]

## Official API Capability Matrix

The matrix is a planning contract, not a promise that every account, scope, or content item succeeds. The official OpenAPI specification is the source for endpoint existence and method shape; the app must still preserve HTTP errors, permissions, pagination, and deprecation metadata. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json]

| Capability | Official evidence reviewed | Phase 1 disposition |
|---|---|---|
| User OAuth | Authorization-code flow, PKCE required, custom protocol redirect for mobile/desktop, token exchange and refresh documented. [CITED: https://developers.soundcloud.com/docs/api/] | **Supported contract.** Implement URL construction, state/PKCE, callback parsing, token response decoding, refresh replacement, and explicit disconnect/sign-out semantics. |
| Public-only access | Client credentials flow is documented for public resources and has token-rate limits. [CITED: https://developers.soundcloud.com/docs/api/] | **Document, do not use as a user-session substitute.** Personal account features require authorization-code user consent. |
| Authenticated profile/feed | `/me`, `/me/feed`, `/me/likes/tracks`, `/me/followings`, and `/me/playlists` appear in the official OpenAPI specification. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Supported where response/status permits.** Mark deprecated feed variants as deprecated and prefer the current feed operation. |
| Search | Official OpenAPI paths include track, playlist, and user search. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Supported contract.** Model search kind explicitly; album search should not be claimed unless a documented official operation is confirmed. |
| Track/user/playlist metadata | Official OpenAPI paths include track, user, playlist, and playlist-track reads. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Supported contract.** Decode stable IDs/URNs, URLs, artwork, title, user, duration, and optional fields defensively. |
| Likes/follows | Official OpenAPI includes authenticated likes and follow/unfollow methods. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Supported contract with account/error states.** No optimistic “success” unless the response is accepted. |
| Playlist writes | Official OpenAPI includes playlist create/update/delete. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Supported contract, subject to authorization and API response.** Local playlist ownership remains separate from future remote sync. |
| Stream playback | Official OpenAPI documents `/tracks/{track_urn}/streams` as returning streamable URLs and requiring continued authentication. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json] | **Playback only.** Pass the authorized result to the playback adapter; never persist the resolved stream as an offline file. |
| Download authorization | No official download entitlement was observed in the reviewed API Guide/OpenAPI material; the terms explicitly prohibit ripping/copying and circumvention. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] | **Permission-gated pending evidence.** `DownloadAuthorization.denied(reason: .noOfficialEntitlement)` is the safe default until a positive official document and response field/control are identified. Do not label this an authoritative absence. |
| Hidden URLs, scraping, DRM bypass | Project instructions prohibit them and official terms prohibit circumventing restrictions. [VERIFIED: AGENTS.md:7-10] “Use only officially supported SoundCloud APIs and authorization flows.” / “Never scrape hidden media URLs, bypass access controls, or circumvent DRM.” | **Prohibited.** No code path, fixture, or verification command may depend on them. |

## Recommended Package and File Layout

Use one local package and one future Xcode app target. Keep the app target small enough that a cloud Mac can add it to an Xcode project without moving domain code. [ASSUMED]

```text
Package.swift
Sources/
  SoundCloudCore/
    API/
      SoundCloudAPI.swift
      APIEndpoint.swift
      APIError.swift
      Capability.swift
      CapabilityRegistry.swift
      Pagination.swift
      Models/
    Auth/
      OAuthConfiguration.swift
      PKCE.swift
      OAuthCallback.swift
      TokenModels.swift
      AuthenticationService.swift
      TokenStore.swift
    Downloads/
      DownloadAuthorization.swift
      DownloadRequest.swift
    Transport/
      HTTPTransport.swift
      URLSessionTransport.swift
      MockAPITransport.swift
Tests/
  SoundCloudCoreTests/
    OAuthPKCETests.swift
    OAuthCallbackTests.swift
    CapabilityMatrixTests.swift
    APIContractTests.swift
    MockTransportTests.swift
ios/
  SoundCloudPersonal/
    SoundCloudPersonalApp.swift
    AppEnvironment.swift
    Auth/
      CallbackURLHandler.swift
      KeychainTokenStore.swift
    Views/
docs/
  API.md
  AUTHENTICATION.md
  ARCHITECTURE.md
  BUILD.md
  TESTING.md
```

The exact app directory is a recommendation, not an existing path; Phase 1 should create it only when the cloud Mac Xcode project is initialized. [ASSUMED]

### Boundary rules

1. `SoundCloudCore` may know Foundation value types and protocol abstractions, but it should not import SwiftUI, AVFoundation, UIKit, or Security. [ASSUMED]
2. `TokenStore` exposes async read/write/delete operations and stores a token bundle as one logical record so a single-use refresh token is replaced atomically. [CITED: https://developers.soundcloud.com/docs/api/]
3. `HTTPTransport` accepts a fully formed request and returns status/data/headers; `SoundCloudAPI` maps endpoint responses into typed values and typed errors. [ASSUMED]
4. `CapabilityRegistry` is data, not UI logic. A view can render `supported`, `unsupported`, `requiresUserPermission`, or `temporarilyUnavailable` without guessing. [ASSUMED]
5. `DownloadManager` must request a `DownloadAuthorization` decision before constructing any file transfer. A playback URL alone cannot satisfy that protocol. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]
6. Fixtures contain metadata and sanitized errors only; no access token, refresh token, hidden media URL, or copied audio. [VERIFIED: AGENTS.md:8-10] “Never scrape hidden media URLs...” / “Treat offline files as permitted downloads only; streaming is not download authorization.”

## Architecture Patterns

### Pattern 1: Protocol-first core with platform adapters

**What:** Define `HTTPTransport`, `TokenStore`, `Clock`, `BrowserAuthenticator`, and `DownloadAuthorizationProvider` protocols in `SoundCloudCore`; implement them in the iOS app or test target. [ASSUMED]  
**When to use:** For every boundary involving network, Keychain, browser callbacks, time, or filesystem. [ASSUMED]  
**Why:** Windows can validate pure Swift contracts and fixtures while the cloud Mac validates Apple frameworks. [ASSUMED]

### Pattern 2: Explicit capability state, not boolean URL inference

```swift
public enum CapabilityState: Equatable, Sendable {
    case supported
    case unsupported(reason: String)
    case requiresUserPermission(reason: String)
    case temporarilyUnavailable(reason: String)
}

public struct DownloadAuthorization: Equatable, Sendable {
    public let state: CapabilityState
    public let source: String?
}
```

This shape is a recommended domain contract. The safe default for an unrecognized track is `.requiresUserPermission` or `.unsupported`, never `.supported` because a stream URL exists. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]

### Pattern 3: OAuth transaction object

```swift
public struct OAuthTransaction: Sendable {
    public let state: String
    public let codeVerifier: String
    public let redirectURI: URL
    public let createdAt: Date
}
```

Generate a high-entropy verifier and state, send the S256 challenge, retain the transaction only long enough to validate the callback, require an exact redirect URI match, and exchange the one-time authorization code. [CITED: https://developers.soundcloud.com/docs/api/]

### Pattern 4: Fixture-backed contract tests

```swift
struct MockAPITransport: HTTPTransport {
    var responses: [String: Result<HTTPResponse, APIError>]

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let key = "\(request.httpMethod ?? "GET") \(request.url!.path)"
        guard let result = responses[key] else { throw APIError.missingFixture(key) }
        return try result.get()
    }
}
```

Use fixture keys for method/path and assert status/error decoding, pagination, auth header construction, and capability disposition. [ASSUMED] Do not add a fixture that calls an undocumented host or presents a stream response as a file download. [VERIFIED: AGENTS.md:7-10] “Use only officially supported SoundCloud APIs and authorization flows.” / “Treat offline files as permitted downloads only; streaming is not download authorization.”

### Pattern 5: Cloud-Mac build boundary

**Windows lane:** edit Swift/package/docs, run repository checks, validate JSON/Markdown, and run Swift tests only if a Windows Swift toolchain is explicitly installed. [VERIFIED: .planning/PROJECT.md:37,46] “Development occurs on Windows 11 with VS Code and no local Mac...” / “Windows-compatible scripts and documentation; cloud Mac workflow required for actual iOS build/signing.”  
**Cloud-Mac lane:** resolve the package in Xcode, compile the iOS target, run simulator/unit/UI tests, validate Keychain and callback registration, and sign only in the macOS environment. [ASSUMED]

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| OAuth PKCE cryptography | A custom hash/randomness implementation | `CryptoKit`/system-secure randomness in the Apple adapter plus a pure protocol tested against known vectors | PKCE and state need secure randomness and exact encoding; SoundCloud requires PKCE. [CITED: https://developers.soundcloud.com/docs/api/] |
| Secret persistence | UserDefaults, plaintext JSON, or logs | Keychain Services behind `TokenStore` | Apple documents Keychain as secure storage for small user data. [CITED: https://developer.apple.com/documentation/security/keychain-services] |
| HTTP client | A third-party downloader or custom socket layer | URLSession behind `HTTPTransport` | Native URL loading and background transfer have platform lifecycle semantics that must be respected. [CITED: https://developer.apple.com/documentation/foundation/downloading-files-in-the-background.md] |
| Download permission | Inferring authorization from `streams` or a redirect | An allow-by-explicit-evidence `DownloadAuthorizationProvider` | The terms prohibit ripping/copying and streaming is not authorization. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] |
| Capability truth | Scattered endpoint checks in views | One registry and typed result | Prevents false success and makes unsupported operations testable. [ASSUMED] |
| Shared file ownership | Deleting files from playlist UI | Future centralized local-store/download manager | The project requires playlist references to be independent of track-file ownership. [VERIFIED: .planning/PROJECT.md:43-47] “Download operations need cancellation, retry, progress, failure states, and atomic file handling.” |

## Common Pitfalls

### Pitfall 1: Treating a stream response as a download

**What goes wrong:** A playback URL is saved or copied into a local file without explicit official authorization. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]  
**Prevention:** Require a positive authorization decision before any download task is created; default unknowns to unavailable and show a streaming-only explanation. [ASSUMED]  
**Verification:** Unit test that a stream response cannot satisfy `DownloadAuthorization`; review source for no `/streams`-to-file shortcut. [ASSUMED]

### Pitfall 2: Refresh-token reuse

**What goes wrong:** The consumed refresh token is retained after refresh, causing the next refresh to fail because SoundCloud documents refresh tokens as single-use. [CITED: https://developers.soundcloud.com/docs/api/]  
**Prevention:** Persist the complete replacement token bundle as one transaction and never log token values. [ASSUMED]  
**Verification:** Fixture test refreshes twice and asserts the second request uses the replacement token, not the original. [ASSUMED]

### Pitfall 3: Skipping state or redirect validation

**What goes wrong:** A callback is accepted without matching the pending OAuth transaction or without exact redirect URI consistency. [CITED: https://developers.soundcloud.com/docs/api/]  
**Prevention:** Reject missing/mismatched state, unexpected error callbacks, duplicate callbacks, and redirect URI mismatch before token exchange. [ASSUMED]  
**Verification:** Negative callback tests for each rejection path. [ASSUMED]

### Pitfall 4: Hiding unsupported API operations

**What goes wrong:** UI says “saved” or “downloaded” after a missing, forbidden, deprecated, or failed endpoint. [VERIFIED: .planning/REQUIREMENTS.md:12] “records supported, unsupported, and permission-gated API operations without faking success.”  
**Prevention:** Return typed `APIError`/`CapabilityState`; only mutate local success state after an accepted official response. [ASSUMED]  
**Verification:** Fixture tests for 401, 403, 404, 409, 422, and 429 mapping where the API schema exposes them, plus an explicit unsupported fixture. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json]

### Pitfall 5: Building only on Windows and discovering Xcode issues late

**What goes wrong:** Package syntax, iOS deployment settings, URL-scheme registration, Keychain entitlements, or SwiftUI imports fail at the cloud-Mac boundary. [ASSUMED]  
**Prevention:** Keep a minimal Xcode app target and a documented cloud-Mac smoke lane from the first phase; keep pure-core tests runnable independently. [VERIFIED: docs/BUILD.md:3-5] “Native iOS compilation, simulator testing, signing, and App Store packaging require macOS with Xcode.”  
**Verification:** Cloud-Mac command sequence below and CI/package validation before Phase 2. [ASSUMED]

## Code Examples

### OAuth authorization request

```swift
var components = URLComponents(string: "https://secure.soundcloud.com/authorize")!
components.queryItems = [
    URLQueryItem(name: "client_id", value: configuration.clientID),
    URLQueryItem(name: "redirect_uri", value: transaction.redirectURI.absoluteString),
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "code_challenge", value: transaction.codeChallenge),
    URLQueryItem(name: "code_challenge_method", value: "S256"),
    URLQueryItem(name: "state", value: transaction.state),
    URLQueryItem(name: "display", value: "popup")
]
```

The parameter names and hosts are from SoundCloud’s official authorization example and mobile guidance. [CITED: https://developers.soundcloud.com/docs/api/] The `configuration.clientID` and registered redirect URI must come from deployment configuration, never a committed secret. [ASSUMED]

### Authenticated API request

```swift
var request = URLRequest(url: URL(string: "https://api.soundcloud.com/me")!)
request.httpMethod = "GET"
request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
```

The host, `/me` example, and `Authorization: OAuth ACCESS_TOKEN` header are documented by SoundCloud. [CITED: https://developers.soundcloud.com/docs/api/]

### Safe download decision

```swift
func requestDownload(for track: Track) async -> Result<DownloadRequest, DownloadError> {
    let decision = await authorizationProvider.authorization(for: track)
    guard decision.state == .supported, let source = decision.source else {
        return .failure(.notAuthorized)
    }
    return .success(DownloadRequest(trackID: track.id, source: source))
}
```

This is a recommended guard shape, not an assertion that a supported source currently exists. The implementation must not populate `source` from a stream-resolution endpoint unless an official permission contract explicitly authorizes that operation. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]

## Windows and Cloud-Mac Verification

### Windows-safe checks

Run from PowerShell at the repository root; these checks do not require Xcode. [ASSUMED]

```powershell
# Confirm required documentation and planning inputs exist.
$required = @(
  "AGENTS.md",
  ".planning\PROJECT.md",
  ".planning\REQUIREMENTS.md",
  ".planning\ROADMAP.md",
  "docs\API.md",
  "docs\AUTHENTICATION.md",
  "docs\BUILD.md",
  "docs\TESTING.md"
)
$required | ForEach-Object {
  if (-not (Test-Path $_)) { throw "Missing $_" }
}

# Detect prohibited implementation vocabulary in new source/docs review.
rg -n -i "scrape|hidden.?url|drm|bypass|api-v2|client.?id extraction" .

# Validate the official OpenAPI document is reachable without adding it to the app.
Invoke-WebRequest `
  -Uri "https://developers.soundcloud.com/docs/api/explorer/api.json" `
  -Method Head
```

The search is a review aid, not a proof of absence; it must be inspected to distinguish policy documentation from prohibited implementation. [ASSUMED] The OpenAPI URL is official and documented by the API Guide. [CITED: https://developers.soundcloud.com/docs/api/]

### Cloud-Mac checks

```bash
swift package describe
swift test
xcodebuild -list -project SoundCloudPersonal.xcodeproj
xcodebuild test -scheme SoundCloudPersonal -destination 'platform=iOS Simulator,name=iPhone'
```

These commands are recommended verification commands for the package/app boundary; exact project and scheme names depend on the cloud-Mac project created during execution. [ASSUMED] Native iOS compile, simulator, signing, and packaging belong on macOS/Xcode. [VERIFIED: docs/BUILD.md:5] “Native iOS compilation, simulator testing, signing, and App Store packaging require macOS with Xcode.”

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | Swift package test target using the test framework available in the selected cloud-Mac Swift toolchain. [ASSUMED] |
| Config file | `Package.swift` — Wave 0 must create it. [ASSUMED] |
| Quick run command | `swift test --filter SoundCloudCoreTests`. [ASSUMED] |
| Full suite command | `swift test`. [ASSUMED] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| PLAT-01 | Package describes successfully and docs state Windows authoring/cloud-Mac build split | package/docs smoke | `swift package describe` plus PowerShell required-file check | ❌ Wave 0 |
| API-01 | PKCE/state request and callback contracts use official hosts/parameters and reject mismatches | unit/contract | `swift test --filter OAuthPKCETests` | ❌ Wave 0 |
| API-02 | Capability matrix distinguishes supported, unsupported, permission-gated, and API error states | unit/contract | `swift test --filter CapabilityMatrixTests` | ❌ Wave 0 |
| API-02 | Official stream capability cannot authorize a download | unit/security regression | `swift test --filter DownloadAuthorizationTests` | ❌ Wave 0 |

The test mapping is based on the phase requirements and the existing testing strategy, which calls for unit tests, sanitized API fixtures, explicit unsupported/error cases, and no unauthorized extraction. [VERIFIED: docs/TESTING.md:3-10] “Unit tests for authorization gates...” / “API contract tests using sanitized fixtures...” / “No test may use or require unauthorized audio extraction.”

### Sampling Rate

- **Per task commit:** `swift test --filter SoundCloudCoreTests` on cloud Mac; Windows runs the available package/docs checks. [ASSUMED]
- **Per wave merge:** `swift test` plus `xcodebuild test` on cloud Mac. [ASSUMED]
- **Phase gate:** no Phase 2 handoff until the capability matrix, OAuth contract tests, and explicit download-denial regression test pass. [ASSUMED]

### Wave 0 Gaps

- [ ] `Package.swift` — package manifest and deployment target. [ASSUMED]
- [ ] `Sources/SoundCloudCore/` — core protocols and models. [ASSUMED]
- [ ] `Tests/SoundCloudCoreTests/` — OAuth/capability/transport fixtures. [ASSUMED]
- [ ] `docs/API.md` — replace broad capability language with the verified matrix and permission-gated download status. [VERIFIED: AGENTS.md:4] “Keep the implementation and the Markdown files in `docs/` synchronized.”
- [ ] `docs/AUTHENTICATION.md` — document exact PKCE/state/token lifecycle and no-password handling. [VERIFIED: AGENTS.md:4] “Keep the implementation and the Markdown files in `docs/` synchronized.”
- [ ] `docs/BUILD.md` — document the exact Windows checks and cloud-Mac commands once project names exist. [VERIFIED: .planning/REQUIREMENTS.md:10] “The project documents a Windows-first workflow and a cloud Mac build/signing path.”

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard control |
|---|---|---|
| V2 Authentication | Yes | SoundCloud authorization-code OAuth with PKCE; no password collection/storage. [CITED: https://developers.soundcloud.com/docs/api/] |
| V3 Session Management | Yes | Keychain token bundle, expiry handling, single-use refresh replacement, explicit disconnect/sign-out. [CITED: https://developers.soundcloud.com/docs/api/] |
| V4 Access Control | Yes | Capability and download authorization gate; deny unknown permissions; preserve API 401/403/422 states. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] |
| V5 Input Validation | Yes | Validate callback scheme/host/path, state, code, redirect URI, JSON decoding, and endpoint parameters before use. [ASSUMED] |
| V6 Cryptography | Yes | Use PKCE S256 and system cryptographic randomness; do not implement cryptography or token storage ad hoc. [CITED: https://developers.soundcloud.com/docs/api/] |

### Known Threat Patterns

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| OAuth callback injection or CSRF | Spoofing/Tampering | State nonce, exact redirect URI, one-time transaction, reject unexpected callbacks. [CITED: https://developers.soundcloud.com/docs/api/] |
| Token leakage | Information disclosure | Keychain only; redact authorization headers and token fields in logs/fixtures. [CITED: https://developer.apple.com/documentation/security/keychain-services] |
| Unauthorized content copying | Elevation of privilege / Information disclosure | Explicit download authorization provider; no stream-to-file path; comply with uploader restrictions. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use] |
| False capability reporting | Tampering | Typed capability registry and response-driven state transitions; never optimistic success on unsupported operations. [VERIFIED: .planning/REQUIREMENTS.md:12] “records supported, unsupported, and permission-gated API operations without faking success.” |
| Replay/stale refresh | Spoofing | Treat authorization code and refresh token as one-use material; atomically replace token bundle. [CITED: https://developers.soundcloud.com/docs/api/] |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | A local Swift package with a core target and a thin iOS app target is the best first implementation boundary. | Summary / Package Layout | The cloud-Mac project may need a different Xcode integration shape. |
| A2 | Phase 1 should use no third-party packages. | Standard Stack | A required cloud-Mac integration may later justify a dependency after legitimacy review. |
| A3 | The exact Xcode project and scheme names can be chosen during implementation. | Verification | Copy-pasted commands may need adjustment. |
| A4 | Swift package tests can be run on Windows only if a compatible Swift toolchain is installed. | Verification | Windows may be documentation-only for Swift compilation. |
| A5 | No general download entitlement was observed in the reviewed official API material. | Capability Matrix | This is explicitly a policy-closed observation, not a verified absence; re-check official OpenAPI/docs before Phase 5. |

## Resolved Planning Decisions

The former open questions are deliberately converted into executable decisions before Phase 1
completion. They are explicit implementation decisions:

1. **Download authorization policy — resolved to deny until positive official evidence.**
   Phase 1 will implement `DownloadAuthorization` as denied or permission-gated by default. A
   stream response, redirect, cached playback result, or uploader metadata without an explicit
   documented authorization signal can never create a file transfer. Plan `01-01` and `01-03`
   test this boundary. A future Phase 5 may enable a transfer only after a fresh official API
   and Terms review identifies a positive track-specific signal and a sanitized authorized
   fixture; otherwise the honest product result remains streaming-only. [CITED:
   https://developers.soundcloud.com/docs/api/terms-of-use]

2. **Deployment target — resolved by a measurable cloud-Mac selection task.**
   Plan `01-02` must select the lowest iOS deployment target supported by the selected Xcode image
   while compiling the SwiftUI adapter and its integration test, then record the same value in
   `Package.swift`, the Xcode target, and `docs/BUILD.md`. The task fails unless project settings,
   `xcodebuild -showBuildSettings`, and the documented value agree. [CITED:
   https://developer.apple.com/documentation/packagedescription.md]

3. **Persistence technology — resolved to a protocol-first decision with an executable choice.**
   Phase 1 defines `LocalStore` without claiming persistence is implemented. Plan `01-02` records
   the cloud-Mac choice as **SwiftData when the selected deployment target supports the required
   model relationships and migration test; otherwise SQLite using the system SQLite interface**.
   The decision task must add a decision record and relationship/migration smoke output to the
   project artifacts. Later phases consume only `LocalStore`, so changing the implementation does
   not change the API/core contract. [VERIFIED: .planning/PROJECT.md:43-47] “SwiftData or SQLite” /
   “Track ID is the local identity.”

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---:|---|---|
| Windows PowerShell | Documentation and repository checks | ✓ | Windows environment; version not probed | Use `cmd` only for simple checks if needed. [ASSUMED] |
| `rg` | Prohibited-pattern and source checks | ✓ in requested tool environment | Version not probed | PowerShell `Select-String`. [ASSUMED] |
| Swift toolchain | Package/unit tests | Unknown | Not observed | Run the same package/test commands on the cloud Mac. [ASSUMED] |
| Xcode/macOS | iOS compile, simulator, signing | ✗ locally by project documentation | — | Cloud Mac is required. [VERIFIED: docs/BUILD.md:5] “require macOS with Xcode.” |
| SoundCloud developer application credentials | Real OAuth integration | Not available in repository and must not be committed | — | Sanitized mock fixtures for Windows; injected secrets on cloud Mac. [ASSUMED] |

**Missing dependencies with no local fallback:** macOS/Xcode for native iOS compilation/signing; a registered SoundCloud application for real OAuth testing. [ASSUMED]  
**Missing dependencies with fallback:** Swift/Xcode can be deferred for pure documentation and fixture design; use mock transport until the cloud Mac is available. [ASSUMED]

## Sources

### Primary (HIGH confidence)

- SoundCloud API Guide — hosts, OAuth 2.1 + PKCE, token lifecycle, mobile redirect guidance, authorization header, and official OpenAPI reference. [CITED: https://developers.soundcloud.com/docs/api/]
- SoundCloud OpenAPI JSON — endpoint/method capability evidence for `/me`, search, metadata, social, playlists, and streams. [CITED: https://developers.soundcloud.com/docs/api/explorer/api.json]
- SoundCloud API Terms of Use — uploader rights, restrictions, and prohibition on ripping/copying/circumvention. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]
- Apple PackageDescription documentation — Swift package manifest, products, targets, platforms, and resources. [CITED: https://developer.apple.com/documentation/packagedescription.md]
- Apple Keychain Services documentation — secure storage for small user data. [CITED: https://developer.apple.com/documentation/security/keychain-services]
- Apple “Downloading files in the background” — background URLSession lifecycle and permanent-file handling. [CITED: https://developer.apple.com/documentation/foundation/downloading-files-in-the-background.md]

### Secondary (MEDIUM confidence)

- CloudScrobble iOS repository — architectural reference for a SwiftUI app, testable Swift core, OAuth/Keychain patterns, mock/demo catalog, and CI. [CITED: https://github.com/leonwwest/cloudscrobble-ios]

### Tertiary (LOW confidence)

- None used for a normative product decision. The repository reference is not authoritative for SoundCloud permissions. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH for Apple-native components; MEDIUM for exact package decomposition because it is a recommendation. [CITED: https://developer.apple.com/documentation/packagedescription.md]
- Architecture: MEDIUM; grounded in project constraints and a public reference implementation; Plan `01-02` contains the executable deployment-target and Xcode integration decision/verification. [VERIFIED: AGENTS.md:9] “Keep the app native Swift/SwiftUI and preserve a modular service boundary.”
- API capability matrix: HIGH for documented endpoints and OAuth; LOW/MEDIUM for download conclusion because the reviewed material supplies a prohibition and stream operation, not a positive general download contract. [CITED: https://developers.soundcloud.com/docs/api/terms-of-use]

**Research date:** 2026-11-15  
**Valid until:** 2026-11-22 for SoundCloud API capability details; 30 days for stable Apple package patterns. Re-check the official OpenAPI document and Terms before any Phase 5 download implementation. [ASSUMED]
