# Build a Personal SoundCloud iOS Client with Offline Music Library

Build a polished, fully functional personal iOS application that integrates with SoundCloud and provides the same core experience as the official SoundCloud app, while adding a comprehensive local music download and management system.

## 1. Authentication
- Allow users to log in with their SoundCloud account.
- Use SoundCloud's officially supported authentication mechanisms.
- Securely store authentication tokens in the iOS Keychain.
- Maintain login sessions.
- Never store passwords in plaintext.

## 2. SoundCloud Integration
The application should provide a browsing experience similar to the official SoundCloud app.

Implement:
- Home/discovery feed.
- Search for tracks, artists, albums and playlists.
- Browse artist profiles.
- View track details.
- Stream music.
- Like and unlike tracks.
- Follow and unfollow artists.
- View liked tracks.
- View personal playlists.
- Create, edit and delete playlists.
- Add and remove tracks from playlists.
- Reorder playlist tracks.
- Display artwork, descriptions, artists and track metadata.

All changes should synchronize with the user's actual SoundCloud account whenever supported by the official API.

## 3. Local Music Download System

This is one of the application's most important features.

Allow users to download tracks locally when downloading is explicitly authorized by the track's uploader or SoundCloud.

Requirements:
- Download tracks into a dedicated local music directory.
- Preserve track metadata.
- Store the original SoundCloud track URL.
- Store the SoundCloud track ID.
- Store artwork and relevant metadata.
- Show download progress.
- Support download cancellation.
- Handle failed downloads and retries.
- Support offline playback.

## 4. Intelligent Download Management

Implement a centralized local music library.

The application must NEVER download the same track twice.

Use the SoundCloud track ID as the primary unique identifier.

Example:

A user downloads:
- Track A individually.
- Playlist 1 containing Track A, Track B and Track C.
- Playlist 2 containing Track A and Track D.

Track A must exist only once in local storage.

Both playlists should reference the same local Track A file.

Implement a database that tracks:
- Track ID.
- Original SoundCloud URL.
- Local file path.
- Download status.
- Metadata.
- Artwork.
- Playlists referencing the track.

Deleting a playlist must NOT delete its downloaded tracks.

Deleting a downloaded track should remove its local file and update all relevant references. Warn the user if the track is still referenced by playlists.

## 5. Playlist Management

Support both SoundCloud playlists and local download collections.

Users should be able to:
- Download an entire playlist.
- Download individual tracks.
- Download only tracks that aren't already available locally.
- Skip previously downloaded tracks automatically.
- Update an existing downloaded playlist when its SoundCloud version changes.
- Add and remove songs.
- Reorder songs.
- Delete playlists.
- Play downloaded playlists offline.

Keep local playlist information synchronized with SoundCloud whenever possible.

## 6. Local Music Player

Build a complete music player with:
- Background playback.
- Lock-screen controls.
- Play/pause.
- Previous/next.
- Shuffle.
- Repeat.
- Queue management.
- Playback progress.
- Album artwork.
- Offline playback.

Use native iOS audio capabilities.

## 7. User Interface

Create a beautiful, modern interface inspired by SoundCloud's visual language without copying its proprietary branding or assets.

Use:
- Dark theme by default.
- Orange accent color.
- Clean typography.
- Smooth transitions.
- Bottom navigation.

Navigation tabs:
1. Home
2. Search
3. Library
4. Downloads
5. Player

The Downloads section should provide:
- Downloaded tracks.
- Downloaded playlists.
- Download queue.
- Storage usage.
- Download management.
- Delete functionality.

## 8. Technical Architecture

Build this as a native iOS application using Swift and SwiftUI.

Use:
- SwiftUI for the interface.
- AVFoundation for audio playback.
- URLSession for networking and authorized downloads.
- SwiftData or SQLite for persistent metadata.
- Keychain for authentication credentials.
- FileManager for local file management.

Use a modular architecture with separate services for:
- SoundCloud API.
- Authentication.
- Music playback.
- Download management.
- Local database.
- Playlist synchronization.
- File management.

## 9. Important API and Legal Requirements

- Use officially supported SoundCloud API functionality.
- Respect SoundCloud's API terms and rate limits.
- Never bypass access restrictions, DRM or streaming protections.
- Never extract unauthorized streaming URLs.
- Only download tracks when downloading is explicitly permitted.
- Do not pretend that a streamable track is downloadable.
- Clearly distinguish locally downloaded tracks from streamed tracks.
- Never fake successful synchronization if the API does not support an operation.

If an API capability is unavailable, explain the limitation and implement a clean alternative rather than using undocumented endpoints.

## 10. Development Expectations

Do not just create a visual prototype.

Build a working application with real authentication, networking, persistent storage, download management and playback.

Start by:
1. Designing the application architecture.
2. Identifying available SoundCloud API capabilities and limitations.
3. Setting up the SwiftUI project.
4. Implementing authentication.
5. Implementing browsing and playback.
6. Implementing local downloads and deduplication.
7. Implementing playlist synchronization.
8. Completing the UI and testing.

Make sensible technical decisions independently. Keep the code modular, maintainable and well documented.

The final result should feel like a complete personal SoundCloud client with a seamlessly integrated offline music library.

## 11. Development Environment

The development environment is Windows 11 with VS Code and GitHub Copilot.

Requirements:
- Optimize all development workflows for Windows.
- Do not require WSL or Linux-specific tooling.
- Use Windows-compatible scripts and commands.
- Document all setup requirements and dependencies.
- Provide clear instructions for building, testing and troubleshooting.
- Keep the project compatible with a future cloud-based iOS build/signing workflow, since no Mac is available locally.

## 12. Documentation Requirements (Mandatory)

Documentation must be maintained throughout the entire development process.

Create and maintain Markdown (.md) files in a dedicated `/docs` directory.

Required documentation:

- `README.md` – Project overview, features and setup instructions.
- `ARCHITECTURE.md` – Application architecture and technical decisions.
- `API.md` – SoundCloud API integration, supported endpoints and limitations.
- `AUTHENTICATION.md` – Login, OAuth and token management.
- `DATABASE.md` – Database structure, relationships and deduplication logic.
- `DOWNLOADS.md` – Download system, file management and offline playback.
- `PLAYLISTS.md` – Playlist synchronization and local playlist management.
- `PLAYER.md` – Audio playback architecture and background playback.
- `BUILD.md` – Windows development setup and iOS build instructions.
- `TESTING.md` – Testing strategy and test instructions.
- `CHANGELOG.md` – Chronological record of significant changes.
- `ROADMAP.md` – Planned features, outstanding tasks and known limitations.

### Documentation Rules

1. Update relevant Markdown files whenever functionality, architecture, dependencies or behavior changes.
2. Never leave documentation describing outdated functionality.
3. Document important technical decisions and explain why they were made.
4. Record API limitations and workarounds.
5. Keep setup instructions reproducible.
6. Update the README when major features are added.
7. Document known bugs and unresolved issues.
8. Create additional Markdown files whenever a feature or subsystem requires dedicated documentation.
9. Keep all documentation version-controlled through Git.
10. Never claim a feature is implemented unless it actually works.

### GitHub Copilot Instructions

Create a root-level `AGENTS.md` containing persistent instructions for GitHub Copilot.

Copilot must:
- Read `AGENTS.md` before making changes.
- Keep documentation synchronized with code.
- Update relevant `.md` files as part of every meaningful implementation task.
- Avoid unnecessary documentation duplication.
- Maintain consistent terminology and project structure.
- Never silently remove existing documentation.

**Documentation is part of the implementation, not an optional final step.**