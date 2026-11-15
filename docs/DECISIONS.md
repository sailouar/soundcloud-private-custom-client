# Phase 1 Platform Decisions

## Deployment target

- **Candidate:** iOS 17.0, shared by `Package.swift` and the Xcode app/test
  configurations as `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- **Cloud-Mac status:** Pending. The Windows authoring environment has no
  `xcodebuild`, simulator, or SwiftData runtime, so the selected Xcode image
  must confirm that iOS 17.0 is supported before this value is treated as
  final.
- **Measured Windows result:** `Get-Command xcodebuild` and
  `Get-Command swift` return no command. No native build result is claimed.

## Storage technology: SwiftData

The candidate iOS 17.0 target selects **SwiftData** because it supplies the
native relationship and migration model required by the local track/playlist
boundary. The storage contract remains `LocalStore`; persistence is not
implemented in this phase.

- Package marker: `SOUNDCLOUD_STORAGE_SWIFTDATA`
- Xcode target marker: `SOUNDCLOUD_STORAGE_SWIFTDATA = 1`
- Smoke test: `testSwiftDataRelationshipAndMigration`
- Rejected alternative: SQLite through the system interface. It was not
  selected because the candidate deployment target provides the required
  native model framework and avoids introducing a second persistence
  implementation before the `LocalStore` contract is exercised.
- Cloud-Mac evidence: pending. The smoke test must run on the cloud Mac and
  prove an in-memory relationship plus save/reload behavior before this
  decision is finalized.

## Scope boundary

`LocalStore` is a protocol-only boundary. This phase does not create database
files, download files, stream caches, or any unauthorized content-copying
path. Streaming capability remains distinct from download authorization.
