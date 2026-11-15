# Requirements: SoundCloud Personal Offline Client

**Defined:** 2026-11-15
**Core Value:** The owner can reliably find and play their SoundCloud music offline without duplicate local files or misleading download behavior.

## v1 Requirements

### Platform and API

- [ ] **PLAT-01**: The project documents a Windows-first workflow and a cloud Mac build/signing path.
- [ ] **API-01**: The app uses a documented, officially supported SoundCloud authentication flow.
- [ ] **API-02**: The app records supported, unsupported, and permission-gated API operations without faking success.

### Authentication

- [ ] **AUTH-01**: A user can sign in through the supported SoundCloud flow without entering a password into app storage.
- [ ] **AUTH-02**: Tokens are stored in Keychain and sessions can be restored or explicitly signed out.
- [ ] **AUTH-03**: Authentication failures and expired sessions are visible and recoverable.

### Discovery and Account

- [ ] **DISC-01**: The user can browse a home/discovery surface backed by supported API data.
- [ ] **DISC-02**: The user can search tracks, artists, albums, and playlists where supported.
- [ ] **DISC-03**: The user can view track and artist details with artwork and metadata.
- [ ] **SOCIAL-01**: The user can like/unlike tracks and follow/unfollow artists where supported.
- [ ] **SOCIAL-02**: The user can view liked tracks and personal playlists.

### Streaming and Player

- [ ] **PLAY-01**: The user can stream an available track using native audio playback.
- [ ] **PLAY-02**: The player supports queue, play/pause, previous/next, shuffle, repeat, and progress.
- [ ] **PLAY-03**: Playback supports background audio, lock-screen controls, and artwork.
- [ ] **PLAY-04**: The UI distinguishes streamed content from locally downloaded content.

### Local Library and Downloads

- [ ] **DL-01**: The app downloads audio only when an official, explicitly authorized download path exists.
- [ ] **DL-02**: A local track is unique by SoundCloud track ID and is never downloaded twice.
- [ ] **DL-03**: The app persists original URL, track ID, local path, status, metadata, artwork, and error state.
- [ ] **DL-04**: Downloads expose progress, cancellation, retry, and failure states.
- [ ] **DL-05**: The app can play completed local files offline.
- [ ] **DL-06**: Deleting a playlist never deletes a shared track file; deleting a track warns about playlist references and updates them.

### Playlists

- [ ] **LIST-01**: The user can manage local downloaded collections independently from file ownership.
- [ ] **LIST-02**: The user can download a supported playlist and skip tracks already available locally.
- [ ] **LIST-03**: The user can add, remove, reorder, and delete local playlist entries.
- [ ] **LIST-04**: Supported remote playlist changes can be reconciled without duplicate tracks or false synchronization.

## v2 Requirements

- Public multi-user distribution and account administration.
- Rich playlist editing operations when the official API does not support them in v1.
- Automatic background synchronization of all remote playlist changes.
- Cross-device cloud synchronization of the local file library.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Unauthorized downloading or hidden URL scraping | Violates the product's legal/API constraints. |
| DRM or access-control bypass | Not an acceptable implementation path. |
| Password storage | SoundCloud credentials belong in the official auth flow and tokens in Keychain. |
| Proprietary SoundCloud branding/assets | Avoids copying protected brand material. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01, API-01, API-02 | Phase 1 | In progress — contracts authored; Windows doc audit passed; cloud-Mac verification pending |
| AUTH-01..03 | Phase 2 | Authored — Keychain/browser/transport adapters and sign-in UI added; device verification pending |
| DISC-01..03, SOCIAL-01..02 | Phase 3 | Pending |
| PLAY-01..04 | Phase 4 | Pending |
| DL-01..06 | Phase 5 | Pending |
| LIST-01..04 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-11-15*
*Last updated: 2026-11-15 after project initialization*
