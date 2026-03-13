# Changelog

## v0.1.0 - 2026-03-13

### Added
- Initial iOS Game Center plugin source scaffold and packaged Godot iOS payload.
- Native singleton `GodotGameCenter` with authentication, leaderboard submit, top-score, and player-score helpers.
- Release packaging script for the iOS plugin payload.
- Standardized source docs (`README.md`, `iOS_implementation.md`, native README) describing install, build, entitlement, and payload expectations.

### Scope
- Supports Game Center auth and leaderboards for the consuming project.
- Does not include achievements or cloud-save behavior in this version.

### Validation
- xcframework build validated locally against Godot `4.5.1-stable` headers.
- Consuming project iOS export/archive validated with Game Center entitlement enabled.
