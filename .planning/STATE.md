# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-11-15)

**Core value:** The owner can reliably find and play their SoundCloud music offline without duplicate local files or misleading download behavior.
**Current focus:** Phase 1 - API and Platform Foundation (Plan 01-02 complete; cloud-Mac verification pending)

## Current Position

- Project initialized from `Task.md`.
- Plan 01-01 added the dependency-free capability tracer and explicit download gate.
- Next action: execute Plan 01-03.

## Decisions

- Offline-first personal MVP.
- Official authorization is required for downloads.
- Track ID is the local deduplication key.
- Windows is the authoring environment; cloud Mac is required for iOS build/signing.
- Capability states are decoded through a method/path transport fixture and registry.
- Stream playback capability cannot authorize a download; explicit official entitlement is required.

## Blockers

- Current SoundCloud API capabilities and download authorization model must be verified before download implementation.
- No local Mac/Xcode is available for native build verification.
- Swift package description and Swift tests remain pending on a cloud Mac; Windows checks passed without claiming compilation.
- The Phase 1 Plan 01-02 Xcode project and SwiftUI adapter are authored, but cloud-Mac project listing, simulator tests, and SwiftData smoke verification remain pending.

---
*Last updated: 2026-11-15*
