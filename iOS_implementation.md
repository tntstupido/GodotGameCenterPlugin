# iOS Implementation

## Summary

This plugin provides a dedicated iOS Game Center bridge for Godot 4.

Chosen defaults:

- singleton name: `GodotGameCenter`
- local-player auth support
- leaderboard submit/load support
- no achievements in phase 1
- minimum iOS target: `14.0`

## Runtime Model

- Consuming projects should keep their own game-facing auth and leaderboard abstraction.
- This plugin should act as the iOS backend for that abstraction.
- The first intended consuming project is `monsterchromatic`, which already has Android Play Games flows that this plugin mirrors at the API/signal level where practical.
- The consuming project is expected to provide real Game Center leaderboard identifiers; this plugin does not define product-specific IDs.

## Public API

Supported methods:

- `sign_in()`
- `refresh_auth_status()`
- `is_signed_in()`
- `get_player_id()`
- `get_player_display_name()`
- `submit_score(leaderboard_id, score)`
- `load_top_scores(leaderboard_id, time_span, collection, limit, force_reload)`
- `load_player_score(leaderboard_id, time_span, collection, force_reload)`

Supported signals:

- `sign_in_success`
- `sign_in_failed`
- `player_info_loaded`
- `leaderboard_submit_success`
- `leaderboard_submit_failed`
- `leaderboard_top_scores_loaded`
- `leaderboard_top_scores_failed`
- `leaderboard_player_score_loaded`
- `leaderboard_player_score_failed`

## Payload Notes

- The generated Godot iOS plugin descriptor depends only on Apple system frameworks.
- The packaged descriptor uses:
  - `Foundation.framework`
  - `GameKit.framework`
  - `UIKit.framework`
- The native bridge is implemented in Objective-C++.
- The bridge resolves leaderboard objects via `loadLeaderboardsWithIDs` before score reads, avoiding fragile property assignment on newer Game Center APIs.
- The current source build targets iOS `14.0` for both device and simulator slices to match the consuming project's export baseline.

## Acceptance Checklist

- `Engine.has_singleton("GodotGameCenter")` is true on iOS
- `sign_in()` can present Game Center auth UI when needed
- `is_signed_in()` reflects local-player auth state
- `submit_score()` reports leaderboard scores successfully
- `load_top_scores()` returns a JSON payload compatible with the consuming project leaderboard screens
- `load_player_score()` returns a JSON payload for the local player
- Godot iOS export succeeds with the packaged plugin payload
- consuming project enables Game Center entitlement in the iOS export preset
