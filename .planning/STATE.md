# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-11-15)

**Core value:** The owner can reliably find and play their SoundCloud music offline without duplicate local files or misleading download behavior.
**Current focus:** Phase 1 - API and Platform Foundation (Plan 01-03 complete; cloud-Mac verification pending)

## Current Position

- Project initialized from `Task.md`.
- Plan 01-01 added the dependency-free capability tracer and explicit download gate.
- Plan 01-02 added the SwiftUI adapter, Xcode project, and protocol-only `LocalStore` boundary.
- Plan 01-03 added the OAuth 2.1 + PKCE contract, token/refresh lifecycle, callback validation, and the documented API endpoint contract.
- Next action: execute Plan 01-04 to reconcile documentation with source and build artifacts.

## Decisions

- Offline-first personal MVP.
- Official authorization is required for downloads.
- Track ID is the local deduplication key.
- Windows is the authoring environment; cloud Mac is required for iOS build/signing.
- Capability states are decoded through a method/path transport fixture and registry.
- Stream playback capability cannot authorize a download; explicit official entitlement is required.
- OAuth uses the documented authorization-code flow with required S256 PKCE, an exact custom-scheme redirect, state validation, and one-time codes.
- Refresh tokens are single-use; the whole token bundle is replaced as one stored record.
- SoundCloud treats clients as confidential, so `client_secret` comes from build configuration, is redacted, and is a documented distribution limitation.
- API requests use only `https://api.soundcloud.com` with `Authorization: OAuth <token>`; undocumented operations are typed refusals.

## Blockers

- Current SoundCloud API capabilities and download authorization model must be verified before download implementation.
- No local Mac/Xcode is available for native build verification.
- Swift package description and Swift tests remain pending on a cloud Mac; Windows checks passed without claiming compilation.
- The Phase 1 Plan 01-02 Xcode project and SwiftUI adapter are authored, but cloud-Mac project listing, simulator tests, and SwiftData smoke verification remain pending.
- The Plan 01-03 OAuth and API contract suites are authored, but `swift test --filter OAuthPKCETests`, `--filter OAuthCallbackTests`, and `--filter APIContractTests` have not run.

---
*Last updated: 2026-11-15*
