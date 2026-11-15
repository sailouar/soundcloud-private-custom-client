# Roadmap: SoundCloud Personal Offline Client

## Overview

The roadmap gates implementation on official API capability research, then builds a vertical native client from authentication through playback and deduplicated offline storage.

## Phases

### Phase 1: API and Platform Foundation
**Goal:** Confirm official authentication, streaming, metadata, write, and download capabilities and establish a buildable SwiftUI architecture for Windows-to-cloud-Mac development.
**Requirements:** PLAT-01, API-01, API-02
**Plans:** 4 plans

Plans:
- [x] 01-01-PLAN.md — Build the transport-to-core capability tracer and download gate
- [x] 01-02-PLAN.md — Prove the SwiftUI adapter and cloud-Mac Xcode boundary
- [x] 01-03-PLAN.md — Implement official OAuth and API contracts
- [ ] 01-04-PLAN.md — Reconcile documentation with source and build artifacts

### Phase 2: Authentication and Secure Session
**Goal:** Sign in through the supported flow, persist tokens in Keychain, restore sessions, and handle expiry/sign-out.
**Requirements:** AUTH-01, AUTH-02, AUTH-03

### Phase 3: Discovery and Account Library
**Goal:** Browse, search, inspect details, and access supported likes, follows, and playlists with honest capability/error states.
**Requirements:** DISC-01..03, SOCIAL-01..02

### Phase 4: Native Streaming Player
**Goal:** Stream tracks with queue controls, background audio, lock-screen controls, artwork, and a clear local-vs-streamed state.
**Requirements:** PLAY-01..04

### Phase 5: Authorized Downloads and Deduplicated Library
**Goal:** Add a centralized download manager and persistent local track store with authorization gating, progress, cancellation, retries, atomic files, and offline playback.
**Requirements:** DL-01..06

### Phase 6: Local and Remote Playlist Management
**Goal:** Manage downloaded collections, reuse shared local tracks, reorder entries, and reconcile supported remote playlist changes.
**Requirements:** LIST-01..04

## Dependencies

- Phase 1 must establish whether the official API exposes a permitted download path before Phase 5 can implement actual audio downloads.
- Phase 2 precedes all authenticated API calls.
- Phase 4 provides the playback abstraction used by Phase 5 offline playback.
- Phase 5 provides the track identity and file ownership model used by Phase 6.

## Progress

| Phase | Status | Requirements |
|-------|--------|--------------|
| 1 | Pending | 3 |
| 2 | Pending | 3 |
| 3 | Pending | 5 |
| 4 | Pending | 4 |
| 5 | Pending | 6 |
| 6 | Pending | 4 |

---
*Created: 2026-11-15*
