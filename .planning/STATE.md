# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-11-15)

**Core value:** The owner can reliably find and play their SoundCloud music offline without duplicate local files or misleading download behavior.
**Current focus:** Phase 2 - Authentication and Secure Session (Plan 02-01 authored; device/IPA verification pending)

## Current Position

- Project initialized from `Task.md`.
- Plan 01-01 added the dependency-free capability tracer and explicit download gate.
- Plan 01-02 added the SwiftUI adapter, Xcode project, and protocol-only `LocalStore` boundary.
- Plan 01-03 added the OAuth 2.1 + PKCE contract, token/refresh lifecycle, callback validation, and the documented API endpoint contract.
- Plan 01-04 reconciled API, authentication, architecture, testing, and changelog documentation and passed the Windows source-to-document audit.
- Plan 02-01 added the personal AltStore sign-in path: on-device Keychain credentials, `ASWebAuthenticationSession`, `URLSession` token transport, a restore/refresh/sign-out coordinator, typed error descriptions, the registered URL scheme, and an unsigned IPA build script. All Swift/iOS execution remains pending on a cloud Mac or device.
- Next action: build the unsigned IPA on macOS, run the Swift/Xcode suites, install with AltServer, and complete a real SoundCloud sign-in with the owner's developer app.

## Decisions

- Offline-first personal MVP.
- Official authorization is required for downloads.
- Track ID is the local deduplication key.
- Windows is the authoring environment; cloud Mac is required for iOS build/signing.
- Capability states are decoded through a method/path transport fixture and registry.
- Stream playback capability cannot authorize a download; explicit official entitlement is required.
- OAuth uses the documented authorization-code flow with required S256 PKCE, an exact custom-scheme redirect, state validation, and one-time codes.
- Refresh tokens are single-use; the whole token bundle is replaced as one stored record.
- SoundCloud treats clients as confidential, so `client_secret` comes from a runtime Keychain entry for the personal build, is redacted, and is a documented distribution limitation.
- API requests use only `https://api.soundcloud.com` with `Authorization: OAuth <token>`; undocumented operations are typed refusals.
- The app is a single-owner personal AltStore sideload; no secret is committed or embedded in the IPA, and free-Apple-ID signing requires a 7-day refresh.

## Blockers

- Current SoundCloud API capabilities and download authorization model must be verified before download implementation.
- No local Mac/Xcode is available for native build verification.
- Swift package description and Swift tests remain pending on a cloud Mac; Windows checks passed without claiming compilation.
- The Phase 1 Plan 01-02 Xcode project and SwiftUI adapter are authored, but cloud-Mac project listing, simulator tests, and SwiftData smoke verification remain pending.
- The Plan 01-03 OAuth and API contract suites are authored, but `swift test --filter OAuthPKCETests`, `--filter OAuthCallbackTests`, and `--filter APIContractTests` have not run.
- The Plan 01-04 documentation audit passes on Windows; native compilation and the Xcode/Swift test suites still require the cloud Mac.
- The Plan 02-01 Keychain, `ASWebAuthenticationSession`, and `URLSession` adapters have not been compiled or run; the AltStore IPA has not been built or installed.
- SoundCloud developer app registration may require a paid plan on the owner's account; confirm before attributing a sign-in failure to the app.

---
*Last updated: 2026-11-15*
