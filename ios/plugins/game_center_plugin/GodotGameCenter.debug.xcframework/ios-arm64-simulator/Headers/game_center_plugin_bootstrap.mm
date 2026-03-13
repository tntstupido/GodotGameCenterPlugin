#import "game_center_plugin.h"
#import "game_center_plugin_bootstrap.h"

#include "core/config/engine.h"

static GameCenterPlugin *game_center_plugin = nullptr;

void init_game_center_plugin() {
	game_center_plugin = memnew(GameCenterPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotGameCenter", game_center_plugin));
}

void deinit_game_center_plugin() {
	if (game_center_plugin != nullptr) {
		memdelete(game_center_plugin);
		game_center_plugin = nullptr;
	}
}

