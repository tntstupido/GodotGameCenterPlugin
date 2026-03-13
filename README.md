# Godot Game Center Plugin

Native iOS Game Center plugin for Godot 4 projects.

This repo contains:

- native iOS source for the Godot bridge
- a packaged Godot iOS plugin payload
- build and release-packaging scripts

## Scope

Current scope:

- iOS only
- Game Center local-player authentication
- iCloud-backed saved-game load/save/delete via `GKSavedGame`
- leaderboard score submission
- leaderboard top-score loading
- leaderboard player-score loading
- API shape aligned with the consuming project's existing Play Games leaderboard flow where practical

Out of scope in `v0.2.0`:

- achievements
- real-time or turn-based multiplayer

Current minimum iOS target:

- iOS 14.0

## Install

1. Copy `ios/plugins/game_center_plugin/` into a Godot project under:
   - `res://ios/plugins/game_center_plugin/`
2. Enable the plugin in the iOS export preset.
3. Re-export the iOS project.
4. Access the runtime singleton:
   - `GodotGameCenter`

Packaged payload contents:

- `game_center_plugin.gdip`
- `GodotGameCenter.debug.xcframework`
- `GodotGameCenter.release.xcframework`

Required consuming-project export settings:

- enable the plugin in the iOS export preset
- enable the Game Center entitlement in the iOS export preset
- enable iCloud CloudDocuments entitlements for the app bundle / provisioning profile
- configure real Game Center leaderboard identifiers in the consuming project
- users must be signed into Game Center/iCloud for `GKSavedGame` sync to function

## Godot API

Singleton name:

- `GodotGameCenter`

Methods:

- `sign_in()`
- `signIn()`
- `refresh_auth_status()`
- `refreshAuthStatus()`
- `is_signed_in() -> bool`
- `isSignedIn() -> bool`
- `is_cloud_available() -> bool`
- `isCloudAvailable() -> bool`
- `get_player_id() -> String`
- `getPlayerId() -> String`
- `get_player_display_name() -> String`
- `getPlayerDisplayName() -> String`
- `load_game(save_name: String)`
- `loadGame(save_name: String)`
- `save_game(save_name: String, data: String, description := "")`
- `saveGame(save_name: String, data: String, description := "")`
- `delete_game(save_name: String)`
- `deleteGame(save_name: String)`
- `delete_saved_game(save_name: String)`
- `deleteSavedGame(save_name: String)`
- `submit_score(leaderboard_id: String, score: int)`
- `submitScore(leaderboard_id: String, score: int)`
- `load_top_scores(leaderboard_id: String, time_span := "all_time", collection := "public", limit := 10, force_reload := true)`
- `loadTopScores(leaderboard_id: String, time_span := "all_time", collection := "public", limit := 10, force_reload := true)`
- `load_player_score(leaderboard_id: String, time_span := "all_time", collection := "public", force_reload := true)`
- `loadPlayerScore(leaderboard_id: String, time_span := "all_time", collection := "public", force_reload := true)`

Signals:

- `sign_in_success(player_id, player_name)`
- `sign_in_failed(status_code, message)`
- `player_info_loaded(player_id, player_name)`
- `load_game_success(save_name, data)`
- `load_game_failed(save_name, status_code, message)`
- `save_game_success(save_name)`
- `save_game_failed(save_name, status_code, message)`
- `delete_game_success(save_name)`
- `delete_game_failed(save_name, status_code, message)`
- `leaderboard_submit_success(leaderboard_id)`
- `leaderboard_submit_failed(leaderboard_id, status_code, message)`
- `leaderboard_top_scores_loaded(leaderboard_id, json)`
- `leaderboard_top_scores_failed(leaderboard_id, status_code, message)`
- `leaderboard_player_score_loaded(leaderboard_id, json)`
- `leaderboard_player_score_failed(leaderboard_id, status_code, message)`

## Build

```bash
export GODOT_HEADERS_DIR="/path/to/godot-ios-source"
./ios/native/GameCenterPlugin/scripts/build_xcframework.sh
```

Output:

- `ios/plugins/game_center_plugin/GodotGameCenter.debug.xcframework`
- `ios/plugins/game_center_plugin/GodotGameCenter.release.xcframework`

Validated local build flow:

```bash
GODOT_HEADERS_DIR="/Users/mladen/Documents/Plugins/GodotAdMobPlugin/third_party/godot-4.5.1-stable" \
./ios/native/GameCenterPlugin/scripts/build_xcframework.sh
```

## Release Packaging

```bash
./scripts/package_release.sh
```

Current zip output:

- `GodotGameCenterPlugin-v0.2.0-ios.zip`
