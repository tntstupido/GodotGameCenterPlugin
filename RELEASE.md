# Release Workflow

## Build

```bash
export GODOT_HEADERS_DIR="/path/to/godot-ios-source"
./ios/native/GameCenterPlugin/scripts/build_xcframework.sh
```

Expected outputs:

- `ios/plugins/game_center_plugin/GodotGameCenter.debug.xcframework`
- `ios/plugins/game_center_plugin/GodotGameCenter.release.xcframework`

## Package

```bash
./scripts/package_release.sh
```

Current output:

- `GodotGameCenterPlugin-v0.1.0-ios.zip`

