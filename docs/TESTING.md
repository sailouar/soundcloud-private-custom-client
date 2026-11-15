# Testing

Testing will be layered:

- Unit tests for authorization gates, track-ID deduplication, playlist references, retry/cancellation state, and metadata persistence.
- API contract tests using sanitized fixtures and explicit unsupported/error cases.
- Playback tests around queue transitions and local versus stream resolution.
- iOS integration and manual tests on a macOS/Xcode environment for Keychain, background audio, lock-screen controls, and offline playback.

No test may use or require unauthorized audio extraction.
