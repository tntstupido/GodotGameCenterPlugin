# Godot iOS Payload

Copy this folder into a Godot project under:

- `res://ios/plugins/game_center_plugin/`

Contents:

- `game_center_plugin.gdip`
- `GodotGameCenter.debug.xcframework`
- `GodotGameCenter.release.xcframework`

Enable the plugin in the consuming project's iOS export preset after copying it.
Also enable the Game Center entitlement in the iOS export preset.

Runtime singleton:

- `GodotGameCenter`
