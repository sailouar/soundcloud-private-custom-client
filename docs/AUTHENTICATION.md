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
| `TokenStore` | `TokenStore.swift` | Protocol-only secure storage boundary; the Keychain adapter arrives in Phase 2. |
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
`TokenStore` is protocol-only in Phase 1. The Keychain adapter must store the bundle as one
logical record and delete it on explicit sign-out.

## Known limitations

- **Client confidentiality:** SoundCloud currently treats all clients as confidential, so the
  token exchange requires a `client_secret`. A secret embedded in a distributed iOS binary can
  be extracted. The secret must come from build configuration (never committed), and this
  risk must be documented before any production distribution. Do not weaken the flow to a
  password grant to avoid it.
- **No password storage:** no code path accepts, stores, or transmits a user password.
- **Verification status:** the OAuth contract tests are authored but have not run yet.
  `swift test --filter OAuthPKCETests` and `--filter OAuthCallbackTests` remain pending on a
  cloud Mac because the Windows authoring host has no Swift toolchain.
- **Phase 2 work:** the system-browser adapter, registered URL scheme in the app target, and
  the Keychain-backed `TokenStore` implementation are not implemented in Phase 1.
