# Native iOS Game Center Plugin

This directory contains the native Godot iOS bridge for `GodotGameCenter`.

## Scope

- singleton registration as `GodotGameCenter`
- Game Center local-player authentication
- leaderboard score submission
- leaderboard top-score loading
- leaderboard player-score loading
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

Implementation notes:

- Uses narrow GameKit imports instead of the umbrella header to avoid symbol collisions with Godot headers.
- Uses `loadLeaderboardsWithIDs` before top/player score reads so the consuming project can provide leaderboard IDs directly.
