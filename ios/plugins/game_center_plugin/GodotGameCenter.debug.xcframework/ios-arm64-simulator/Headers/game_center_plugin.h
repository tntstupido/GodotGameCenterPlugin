#ifndef GAME_CENTER_PLUGIN_H
#define GAME_CENTER_PLUGIN_H

#import <Foundation/Foundation.h>

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/string/ustring.h"

@class GameCenterBridge;

class GameCenterPlugin : public Object {
	GDCLASS(GameCenterPlugin, Object);

private:
	static GameCenterPlugin *instance;

	__strong GameCenterBridge *bridge;

	static void _bind_methods();

public:
	static GameCenterPlugin *get_singleton();

	GameCenterPlugin();
	~GameCenterPlugin();

	void sign_in();
	void signIn();
	void refresh_auth_status();
	void refreshAuthStatus();
	bool is_signed_in() const;
	bool isSignedIn() const;
	bool is_cloud_available() const;
	bool isCloudAvailable() const;
	String get_player_id() const;
	String getPlayerId() const;
	String get_player_display_name() const;
	String getPlayerDisplayName() const;
	void submit_score(String leaderboard_id, int score);
	void submitScore(String leaderboard_id, int score);
	void load_game(String save_name);
	void loadGame(String save_name);
	void save_game(String save_name, String data, String description = "");
	void saveGame(String save_name, String data, String description = "");
	void delete_game(String save_name);
	void deleteGame(String save_name);
	void delete_saved_game(String save_name);
	void deleteSavedGame(String save_name);
	void load_top_scores(String leaderboard_id, String time_span = "all_time", String collection = "public", int limit = 10, bool force_reload = true);
	void loadTopScores(String leaderboard_id, String time_span = "all_time", String collection = "public", int limit = 10, bool force_reload = true);
	void load_player_score(String leaderboard_id, String time_span = "all_time", String collection = "public", bool force_reload = true);
	void loadPlayerScore(String leaderboard_id, String time_span = "all_time", String collection = "public", bool force_reload = true);

	void notify_sign_in_success(const String &player_id, const String &player_name);
	void notify_sign_in_failed(int status_code, const String &message);
	void notify_player_info_loaded(const String &player_id, const String &player_name);
	void notify_load_game_success(const String &save_name, const String &data);
	void notify_load_game_failed(const String &save_name, int status_code, const String &message);
	void notify_save_game_success(const String &save_name);
	void notify_save_game_failed(const String &save_name, int status_code, const String &message);
	void notify_delete_game_success(const String &save_name);
	void notify_delete_game_failed(const String &save_name, int status_code, const String &message);
	void notify_leaderboard_submit_success(const String &leaderboard_id);
	void notify_leaderboard_submit_failed(const String &leaderboard_id, int status_code, const String &message);
	void notify_leaderboard_top_scores_loaded(const String &leaderboard_id, const String &json);
	void notify_leaderboard_top_scores_failed(const String &leaderboard_id, int status_code, const String &message);
	void notify_leaderboard_player_score_loaded(const String &leaderboard_id, const String &json);
	void notify_leaderboard_player_score_failed(const String &leaderboard_id, int status_code, const String &message);
};

#endif
