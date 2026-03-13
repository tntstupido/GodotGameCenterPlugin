# Native iOS Game Center Plugin

This directory contains the native Godot iOS bridge for `GodotGameCenter`.

## Scope

- singleton registration as `GodotGameCenter`
- Game Center local-player authentication
- leaderboard score submission
- leaderboard top-score loading
- leaderboard player-score loading
- `GKSavedGame` load/save/delete helpers for iCloud-backed saved-game slots
- iOS 14.0 minimum build target

## Build Dependency

Expected local dependency:

- `GODOT_HEADERS_DIR`
  - local Godot iOS source/header tree containing `core/`, `platform/ios/`, and Apple embedded driver headers

## Build

```bash
export GODOT_HEADERS_DIR="/path/to/godot-ios-source"
./scripts/build_xcframework.sh
```

Build output:

- `ios/plugins/game_center_plugin/GodotGameCenter.debug.xcframework`
- `ios/plugins/game_center_plugin/GodotGameCenter.release.xcframework`

Important:

- the script now emits real debug and real release xcframeworks
- release builds must compile without `DEBUG_ENABLED`, otherwise the plugin will target the debug-only Godot method-binding ABI and fail to link against the shipped iOS release library

Implementation notes:

- Uses narrow GameKit imports instead of the umbrella header to avoid symbol collisions with Godot headers.
- Uses `loadLeaderboardsWithIDs` before top/player score reads so the consuming project can provide leaderboard IDs directly.
- Saved-game methods are exposed as simple slot-name operations so consuming projects can mirror Android snapshot-style APIs.
