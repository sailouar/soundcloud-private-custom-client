# Player

Playback will use AVFoundation with a single queue abstraction that can resolve either a permitted local file or a stream URL returned by the supported API.

The player must configure background audio, Now Playing metadata, lock-screen controls, queue navigation, shuffle, repeat, progress, and artwork. It must identify offline playback separately from streaming.
