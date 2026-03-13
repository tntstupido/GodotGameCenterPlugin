# Changelog

## v0.2.0 - 2026-03-13

### Added
- Initial iOS Game Center plugin source scaffold and packaged Godot iOS payload.
- Native singleton `GodotGameCenter` with authentication, leaderboard submit, top-score, and player-score helpers.
- Native saved-game helpers backed by `GKSavedGame` for slot-based load/save/delete flows.
- Release packaging script for the iOS plugin payload.
- Standardized source docs (`README.md`, `iOS_implementation.md`, native README) describing install, build, entitlement, and payload expectations.

### Scope
- Supports Game Center auth, leaderboards, and iCloud-backed GameKit saved games for the consuming project.
- Does not include achievements or multiplayer behavior in this version.

### Validation
- xcframework build validated locally against Godot `4.5.1-stable` headers.
- Consuming project iOS export/archive validated with Game Center entitlement enabled.
- Consuming project now detects `GodotGameCenter` as the iOS cloud backend and exports cleanly with the saved-game-capable payload present.
- Device validation now confirms iOS saved-game save and next-launch cloud-load behavior through `GKSavedGame`.
