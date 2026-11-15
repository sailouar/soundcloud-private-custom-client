# Authentication

Authentication uses SoundCloud's officially supported OAuth 2.1 authorization-code flow with PKCE. The app never collects or persists a SoundCloud password.

Source: [SoundCloud API Guide](https://developers.soundcloud.com/docs/api/) and the
[OpenAPI document](https://developers.soundcloud.com/docs/api/explorer/api.json)
(accessed 2026-11-15).

## Implemented contract (Phase 1, Plan 01-03)

The pure, testable pieces live in `Sources/SoundCloudCore/Auth/`:

| Symbol | File | Responsibility |
|--------|------|----------------|
| `OAuthConfiguration` | `OAuthConfiguration.swift` | Official hosts, registered custom-scheme redirect, client credentials, authorization URL with S256 PKCE and state. |
| `OAuthTransaction` | `OAuthConfiguration.swift` | One-time state, verifier, challenge, redirect URI, and creation time. |
| `PKCE`, `PKCEHashing`, `SecureRandomSource` | `PKCE.swift` | RFC 7636 verifier/state generation, base64url encoding, and an injected S256 hasher. |
| `OAuthCallbackValidator`, `OAuthCallback` | `OAuthCallback.swift` | Exact redirect/state/error/one-time validation of the browser callback. |
| `TokenBundle`, `OAuthTokenResponse` | `TokenModels.swift` | Redacted session record and documented token-response decoding. |
| `TokenStore` | `TokenStore.swift` | Protocol-only secure storage boundary; the Keychain adapter lives in the app target. |
| `AuthenticationService` | `AuthenticationService.swift` | Sign-in, documented token exchange, single-use refresh replacement, restore, and sign-out. |

### Authorization request

The authorization URL is `https://secure.soundcloud.com/authorize` with the documented
parameters (`client_id`, `redirect_uri`, `response_type=code`, `code_challenge`,
`code_challenge_method=S256`, `state`) plus `display=popup` for the mobile connect screen.
The redirect URI must be an absolute custom-protocol URI such as
`soundcloudpersonal://oauth/callback`; `http`/`https` redirects and embedded user info are
rejected at configuration time.

### Callback validation

`OAuthCallbackValidator` rejects a callback unless all of the following hold:

- the `state` is present and matches a pending transaction exactly once;
- the scheme, host, port, and path equal the registered redirect URI;
- the transaction is no older than ten minutes;
- an `error` callback is surfaced as a typed denial instead of a code;
- the `code` is present and has not already been consumed.

A replayed callback is rejected, not treated as a second sign-in.

### Token exchange and refresh

The token endpoint is `https://secure.soundcloud.com/oauth/token`, called as
`application/x-www-form-urlencoded` with `grant_type`, `client_id`, `client_secret`,
`redirect_uri`, `code_verifier`, and `code`. The response supplies `access_token`,
`refresh_token`, `expires_in`, and `scope`.

Access tokens expire after roughly one hour. Refresh passes
`grant_type=refresh_token` with the current refresh token and stores the complete
replacement bundle as one record, so a consumed single-use refresh token is never reused.
The refresh test exercises two consecutive refreshes and asserts that the second request
uses the replacement token.

### Stored data and redaction

`TokenBundle` and `OAuthConfiguration` redact token material and the client secret in
`description`/`debugDescription`; token values never appear in fixtures, logs, or Markdown.
The app target supplies the Keychain adapter: it stores the bundle as one logical record
and deletes it on explicit sign-out.

## Phase 2 app adapter (personal AltStore build)

The iOS target wires the core contract to real platform services. These files are
app-only and deliberately outside `SoundCloudCore`, which still imports no UI or
Security framework:

| Symbol | File | Responsibility |
|--------|------|----------------|
| `OAuthAppCredentials`, `AppOAuthConfiguration` | `ios/SoundCloudPersonal/Auth/OAuthAppCredentials.swift` | Stored client ID/secret model; derives the redirect URI from the registered URL scheme. |
| `KeychainRecord`, `KeychainTokenStore`, `AppCredentialStore` | `ios/SoundCloudPersonal/Auth/KeychainStore.swift` | Generic-password Keychain records for the token bundle and the personal app credentials. |
| `BrowserAuthenticator` | `ios/SoundCloudPersonal/Auth/BrowserAuthenticator.swift` | `ASWebAuthenticationSession` wrapper; the authorization page never renders inside the app. |
| `URLSessionOAuthTransport` | `ios/SoundCloudPersonal/Auth/URLSessionOAuthTransport.swift` | `OAuthTransport` implementation for the documented token endpoint. |
| `AuthenticationCoordinator` | `ios/SoundCloudPersonal/Auth/AuthenticationCoordinator.swift` | Sign-in state machine, credential validation, session restore, refresh, sign-out. |
| `AuthenticationView` | `ios/SoundCloudPersonal/Views/AuthenticationView.swift` | Setup and account UI with visible, retryable failures. |

### Credential entry

This build is personal and sideloaded, so it does **not** read a secret from build
configuration. On first launch the owner creates a SoundCloud developer app, registers
`soundcloudpersonal://oauth/callback` as its redirect URI, and enters the app's client ID
and client secret once. Both values are stored in the device Keychain
(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); nothing is committed, embedded in the
built IPA, or written to files. The redirect URI is derived from the `CFBundleURLTypes`
entry in `Info.plist`, so the request and the app handoff cannot drift apart.

### Session lifecycle

1. Launch: load credentials, build `OAuthConfiguration`, call
   `AuthenticationService.restoreSession()`. An expired access token is refreshed with the
   single-use refresh token before any API call.
2. Sign-in: `beginSignIn()` produces the state/PKCE transaction, the system browser loads
   the official authorization page, and `OAuthCallbackValidator.consume` checks the
   callback before `completeSignIn()` exchanges the code.
3. Sign-out: delete the Keychain session record; the application credentials remain so
   signing in again does not require retyping the secret.
4. Reset configuration: delete both Keychain records and return to the setup screen.

### Failure handling

`AuthenticationError`, `OAuthCallbackError`, `OAuthConfigurationError`, `APIEndpointError`,
`TokenError`, `APIPolicyError`, and `PKCEError` conform to `LocalizedError` through
`Sources/SoundCloudCore/Support/ErrorDescriptions.swift`. The messages describe the failed
step (configuration, callback, token exchange, refresh) without token values or response
bodies, and every failure screen offers a retry that does not require reinstalling.

## Authorization is not download authorization

Signing in proves who the user is; it never grants an offline file. A
`DownloadAuthorization` decision requires a separate, positive, track-specific
official entitlement, and a streaming response remains playback only. See
[`API.md`](API.md) for the legal boundary and
[`ARCHITECTURE.md`](ARCHITECTURE.md#source-to-document-reconciliation) for the
source-to-document reconciliation.

## Known limitations

- **Client confidentiality:** SoundCloud currently treats all clients as confidential, so the
  token exchange requires a `client_secret`. For this personal sideload the secret is entered
  on the device and kept in the Keychain instead of a build configuration. A secret present on
  a device can still be extracted by someone with full control of that device; this is an
  accepted risk for a single-owner personal build and must be revisited before any
  multi-user distribution. Do not weaken the flow to a password grant to avoid it.
- **Registered developer app:** sign-in requires a SoundCloud developer app owned by the
  user. If SoundCloud gates app registration behind a paid plan on the owner's account, the
  flow cannot complete until that is resolved; retry after fixing the account.
- **No password storage:** no code path accepts, stores, or transmits a user password.
- **Verification status:** the OAuth contract tests are authored but have not run yet.
  `swift test --filter OAuthPKCETests` and `--filter OAuthCallbackTests` remain pending on a
  cloud Mac because the Windows authoring host has no Swift toolchain. The Phase 2 app
  adapters (Keychain, `ASWebAuthenticationSession`, `URLSession`) require the same cloud-Mac
  or device run and are not yet verified.
- **AltStore lifetime:** a free-Apple-ID sideload must be refreshed every 7 days; the
  Keychain session survives re-signing because the bundle identifier stays the same, but the
  sign-in cannot be tested until the IPA is installed on a device.
