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
