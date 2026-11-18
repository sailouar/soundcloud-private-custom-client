# Player

Playback uses AVFoundation (`PlayerService` in `ios/SoundCloudPersonal/Services/PlayerService.swift`)
with a single queue abstraction (`PlayableItem`) that resolves to either:

- a **permitted local file** (`PlayableItem.local`) — chosen first when the track is in the
  download library (`PlaybackResolver`, offline-first, default on), or
- a **stream URL** (`PlayableItem.stream`) from the stream-only API path, which is never
  persisted as a file.

## Features

- Queue management: `setQueue`, play a single item, up-next list in the Player tab.
- Play/pause, previous (restarts when >3s in), next, seek via progress slider.
- Shuffle (reorders the playback order, keeps the current track first) and repeat
  (off / all / one, cycled from the UI; repeat-one replays on end-of-item).
- Progress reporting via periodic time observer; duration from the current item.
- **Background audio:** `AVAudioSession` category `.playback` and `UIBackgroundModes = audio`
  in `Info.plist`.
- **Lock screen:** `MPNowPlayingInfoCenter` (title, artist, duration, elapsed, artwork,
  offline flag) and `MPRemoteCommandCenter` (play, pause, next, previous, scrub).
- The UI always distinguishes offline playback from streaming with a badge.

## Verification status

Authored but not compiled: the player requires a cloud-Mac build plus a simulator/device
run. Unit coverage exists for the offline-first resolution (`PlaybackResolverTests`).
