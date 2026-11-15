# Testing

Testing is layered and must never require capturing or copying audio.

- Unit tests for authorization gates, track-ID deduplication, playlist references, retry/cancellation state, and metadata persistence.
- API contract tests using sanitized fixtures and explicit unsupported/error cases.
- Playback tests around queue transitions and local versus stream resolution.
- iOS integration and manual tests on a macOS/Xcode environment for Keychain, background audio, lock-screen controls, and offline playback.

No test may use or require unauthorized audio extraction, hidden media locations,
or content-protection circumvention.

## Phase 1 suites

| Suite | File | Proves |
|-------|------|--------|
| `CapabilityMatrixTests` | `ios/SoundCloudPersonalTests/CapabilityMatrixTests.swift` | Fixtures travel through `SoundCloudAPI` into typed `CapabilityState` values; HTTP errors stay errors. |
| `MockTransportTests` | `ios/SoundCloudPersonalTests/MockTransportTests.swift` | Method/path fixture lookup and missing/transport failures. |
| `DownloadAuthorizationTests` | `ios/SoundCloudPersonalTests/DownloadAuthorizationTests.swift` | Stream capability cannot create a download request; the production source keeps the policy boundary. |
| `OAuthPKCETests` | `ios/SoundCloudPersonalTests/OAuthPKCETests.swift` | RFC 7636 vector, official authorization/token hosts, callback-to-token flow, single-use refresh replacement, redaction. |
| `OAuthCallbackTests` | `ios/SoundCloudPersonalTests/OAuthCallbackTests.swift` | Exact redirect, state, expiry, error-callback, and replay rejection. |
| `APIContractTests` | `ios/SoundCloudPersonalTests/APIContractTests.swift` | Official host and `OAuth` header, path parameter validation, stream-only disposition, typed unsupported operations, retry classification. |
| `CapabilityAdapterIntegrationTests` | `ios/SoundCloudPersonalTests/CapabilityAdapterIntegrationTests.swift` | `MockAPITransport -> SoundCloudAPI -> AppEnvironment -> CapabilityStatusViewModel`; runs in the Xcode test target, not the SwiftPM core tests. |
| `StorageMigrationSmokeTests` | `ios/SoundCloudPersonalTests/StorageMigrationSmokeTests.swift` | Candidate SwiftData relationship and migration; runs in the Xcode test target. |

## Phase 2 manual device checks

These require a signed-in device or simulator with network access and the owner's
SoundCloud developer app; they cannot run on the Windows host.

| Check | Expected result |
|-------|-----------------|
| First launch with no credentials | Setup screen; no network call, no crash. |
| Save credentials | Values appear only in the Keychain item; relaunch restores the setup and skips re-entry. |
| Sign in | System browser opens the official authorization page; returning via `soundcloudpersonal://oauth/callback` shows the signed-in state. |
| Cancel sign-in | "Sign-in was cancelled." with a retry action; no partial session stored. |
| Kill and relaunch while signed in | Session restores from the Keychain; an expired access token refreshes once. |
| Sign out | Session record is gone; app credentials remain for the next sign-in. |
| Reset configuration | Both Keychain records are gone; the setup screen returns. |
| AltServer re-sign after 7 days | Same bundle identifier; the stored session still restores. |

## Windows authoring lane

The Windows host has no Swift toolchain or Xcode, so it runs artifact, policy, and
documentation checks only. It must not claim compilation or test success.

```powershell
$required = @(
  "Package.swift",
  "Sources/SoundCloudCore/Auth/OAuthConfiguration.swift",
  "Sources/SoundCloudCore/API/APIEndpoint.swift",
  "Sources/SoundCloudCore/Support/ErrorDescriptions.swift",
  "ios/SoundCloudPersonal/Auth/AuthenticationCoordinator.swift",
  "ios/SoundCloudPersonal/Auth/KeychainStore.swift",
  "ios/SoundCloudPersonal/Views/AuthenticationView.swift",
  "ios/SoundCloudPersonalTests/OAuthPKCETests.swift",
  "ios/SoundCloudPersonalTests/APIContractTests.swift",
  "SoundCloudPersonal.xcodeproj/xcshareddata/xcschemes/SoundCloudPersonal.xcscheme"
)
foreach ($path in $required) {
  if (-not (Test-Path $path)) { throw "Missing required artifact: $path" }
}
```

## Source-to-document audit

The source-to-document audit extracts official hosts, stable contract symbols, test
names, project/scheme names, and the deployment target from the repository and fails
when documentation is missing a corresponding claim. It also rejects prohibited
implementation markers in production paths (`Sources/SoundCloudCore`,
`ios/SoundCloudPersonal`) while allowing policy prose in `docs/` and policy-test
identifiers under `ios/SoundCloudPersonalTests`.

```powershell
$source = (Get-ChildItem Sources/SoundCloudCore, ios/SoundCloudPersonal -Recurse -File |
  Get-Content -Raw) -join "`n"
$docs = (Get-ChildItem docs -Filter *.md | Get-Content -Raw) -join "`n"
foreach ($needle in @(
  "secure.soundcloud.com", "api.soundcloud.com", "CapabilityState",
  "OAuthConfiguration", "OAuthTransaction", "OAuthCallback",
  "TokenBundle", "TokenStore", "SoundCloudPersonal"
)) {
  if ($source -match [regex]::Escape($needle) -and $docs -notmatch [regex]::Escape($needle)) {
    throw "Undocumented source claim: $needle"
  }
}
```

## Cloud-Mac lane

`swift test` runs the SwiftPM core suites; the Xcode scheme runs the app-target
integration tests and the SwiftData smoke test. Required commands:

```bash
swift package describe
swift test
swift test --filter OAuthPKCETests
swift test --filter OAuthCallbackTests
swift test --filter APIContractTests
xcodebuild test -project SoundCloudPersonal.xcodeproj -scheme SoundCloudPersonal \
  -destination "id=$SIMULATOR_UDID"
```

These commands have not run yet. Until they do, the authored suites are reported as
pending, not passed.
