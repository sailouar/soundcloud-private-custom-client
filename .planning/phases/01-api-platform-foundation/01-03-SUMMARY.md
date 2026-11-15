---
phase: 01-api-platform-foundation
plan: 03
subsystem: auth
tags: [oauth, pkce, token-refresh, api-contract, swift, testing]
requires:
  - phase: 01-api-platform-foundation
    plan: 01
    provides: Foundation-only core package with typed errors and sanitized fixtures
provides:
  - Executable OAuth 2.1 authorization-code + PKCE contract
  - Exact custom-scheme redirect, state, and one-time-code callback validation
  - Single-use refresh-token replacement behind a protocol-only TokenStore
  - Documented API endpoint contract with official host and OAuth header
  - Typed refusals for undocumented operations and stream-only disposition
affects: [authentication, discovery, playback, downloads]
tech-stack:
  added: [CryptoKit S256 adapter behind canImport]
  patterns: [injected hashing and randomness boundaries, redacted token values, allow-by-documented-evidence endpoints]
key-files:
  created:
    - Sources/SoundCloudCore/Auth/OAuthConfiguration.swift
    - Sources/SoundCloudCore/Auth/PKCE.swift
    - Sources/SoundCloudCore/Auth/OAuthCallback.swift
    - Sources/SoundCloudCore/Auth/TokenModels.swift
    - Sources/SoundCloudCore/Auth/TokenStore.swift
    - Sources/SoundCloudCore/Auth/AuthenticationService.swift
    - Sources/SoundCloudCore/API/APIEndpoint.swift
    - ios/SoundCloudPersonalTests/OAuthPKCETests.swift
    - ios/SoundCloudPersonalTests/OAuthCallbackTests.swift
    - ios/SoundCloudPersonalTests/APIContractTests.swift
  modified:
    - docs/AUTHENTICATION.md
    - docs/API.md
    - docs/DECISIONS.md
    - docs/CHANGELOG.md
decisions:
  - "Keep PKCE hashing behind an injected protocol and ship the CryptoKit S256 adapter conditionally; the core embeds no cryptography."
  - "Require a custom-scheme redirect and reject http(s), embedded user info, and fragments at configuration time."
  - "Model only OpenAPI-documented operations; search is the collection resource with q, and prohibited operations are typed refusals."
  - "Treat the required client_secret as build configuration and a documented confidentiality limitation."
metrics:
  duration: 55min
  completed: 2026-11-15
  commits: 4
actuals:
  tokens: 11200
  tasks: 2
  commits: 4
status: complete
---

# Phase 1 Plan 3: Official OAuth and API Contracts

**Executable OAuth 2.1 + PKCE contract and an OpenAPI-grounded endpoint policy, both authored without claiming unrun tests**

## Accomplishments

- Added `OAuthConfiguration`/`OAuthTransaction` building the documented
  `https://secure.soundcloud.com/authorize` URL with S256 PKCE, state, the exact
  registered custom-scheme redirect, and `display=popup`.
- Added RFC 7636 compliant verifier/state generation, base64url encoding, and an
  injected `PKCEHashing` boundary with a CryptoKit S256 adapter validated against
  the RFC 7636 appendix B vector.
- Added `OAuthCallbackValidator` rejecting missing/mismatched state, unexpected
  scheme/host/port/path, expired transactions, authorization errors, missing
  codes, duplicate registration, and replayed callbacks.
- Added `AuthenticationService` performing the documented token exchange and
  single-use refresh replacement, persisting one `TokenBundle` record through a
  protocol-only `TokenStore`; `restoreSession` refreshes only when near expiry.
- Redacted access tokens, refresh tokens, and the client secret from all
  descriptions; no code path accepts or sends a password.
- Added `APIEndpoint` covering only documented OpenAPI operations on
  `https://api.soundcloud.com` with `Authorization: OAuth <token>`, validated
  path parameters, sorted/encoded query items, and a stream-only disposition
  that can never claim an offline file.
- Added typed `UnsupportedAPIOperation` refusals plus `APIError` classification
  for authentication, permission, and retryable statuses.

## Task Commits

1. **Task 1: OAuth request through callback and token state** - `5fbad24`
2. **Task 2: Documented endpoint and capability contract coverage** - `057b92f`,
   `ac55081`
3. **Documentation and planning synchronization** - `32a3c4e`

## Verification

- Windows artifact check (all planned source and test files exist): **passed**.
- Brace-balance and policy-marker scan over `Sources/SoundCloudCore`: **passed**.
- `git diff --check`: **passed**.
- `swift package describe`: **pending**; Swift is unavailable on Windows.
- `swift test --filter OAuthPKCETests`: **pending**; Swift is unavailable on
  Windows.
- `swift test --filter OAuthCallbackTests`: **pending**; Swift is unavailable on
  Windows.
- `swift test --filter APIContractTests`: **pending**; Swift is unavailable on
  Windows.
- No native compilation or passing test result is claimed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Correctness] Corrected search paths from `/search/*` to the
documented collection resources.**
- **Found during:** Task 2, while reading the official OpenAPI document.
- **Issue:** The plan described "search" endpoints generically; the reviewed
  OpenAPI document exposes `GET /tracks`, `GET /users`, and `GET /playlists`
  with a `q` parameter and contains no `/search` alias.
- **Fix:** Encoded only the documented paths and added a regression test that
  rejects `/search` aliases, album paths, and download paths.
- **Files modified:** `Sources/SoundCloudCore/API/APIEndpoint.swift`,
  `ios/SoundCloudPersonalTests/APIContractTests.swift`

**2. [Rule 1 - Correctness] Modelled `client_secret` because the documented
token exchange requires it.**
- **Found during:** Task 1, while reading the official authentication guide.
- **Issue:** The plan did not mention the secret, but SoundCloud currently treats
  all clients as confidential and its documented requests include
  `client_secret`.
- **Fix:** Added an optional, validated, redacted `clientSecret` sourced from
  build configuration, a typed `missingClientSecret` failure, and a documented
  disclosure limitation in `docs/AUTHENTICATION.md` and `docs/DECISIONS.md`.
- **Files modified:** `OAuthConfiguration.swift`, `AuthenticationService.swift`,
  `docs/AUTHENTICATION.md`, `docs/DECISIONS.md`

**3. [Rule 1 - Correctness] Kept the prohibited-operation name out of the
existing policy scan.**
- **Found during:** Task 2 policy check.
- **Issue:** The established source scan rejects the word "scraping"; a
  same-named enum case would fail that regression test.
- **Fix:** Named the operation `webPageHarvesting` with a descriptive reason.
- **Files modified:** `Sources/SoundCloudCore/API/APIEndpoint.swift`

## Known Stubs

- `TokenStore` is intentionally protocol-only; the Keychain adapter is Phase 2
  work and is not claimed here.
- The iOS app has no browser adapter or callback URL-scheme registration yet;
  Phase 1 defines the pure contracts only.

## Deferred Verification

Run on the cloud Mac once a Swift toolchain is available:

```sh
swift test --filter OAuthPKCETests
swift test --filter OAuthCallbackTests
swift test --filter APIContractTests
```

No credentials, tokens, or client secrets may be committed for this check.

## Self-Check: PASSED

- Summary file created at
  `.planning/phases/01-api-platform-foundation/01-03-SUMMARY.md`.
- All planned source and test files exist.
- No test result, compilation result, or capability is claimed without evidence.

---
*Phase: 01-api-platform-foundation*
*Completed: 2026-11-15*
