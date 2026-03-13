#import "game_center_plugin.h"

#import <GameKit/GKLeaderboard.h>
#import <GameKit/GKLeaderboardEntry.h>
#import <GameKit/GKLocalPlayer.h>
#import <GameKit/GKPlayer.h>
#import <GameKit/GKSavedGame.h>
#import <UIKit/UIKit.h>

#include "core/io/json.h"

static const char *SIGN_IN_SUCCESS_SIGNAL = "sign_in_success";
static const char *SIGN_IN_FAILED_SIGNAL = "sign_in_failed";
static const char *PLAYER_INFO_LOADED_SIGNAL = "player_info_loaded";
static const char *LOAD_GAME_SUCCESS_SIGNAL = "load_game_success";
static const char *LOAD_GAME_FAILED_SIGNAL = "load_game_failed";
static const char *SAVE_GAME_SUCCESS_SIGNAL = "save_game_success";
static const char *SAVE_GAME_FAILED_SIGNAL = "save_game_failed";
static const char *DELETE_GAME_SUCCESS_SIGNAL = "delete_game_success";
static const char *DELETE_GAME_FAILED_SIGNAL = "delete_game_failed";
static const char *LEADERBOARD_SUBMIT_SUCCESS_SIGNAL = "leaderboard_submit_success";
static const char *LEADERBOARD_SUBMIT_FAILED_SIGNAL = "leaderboard_submit_failed";
static const char *LEADERBOARD_TOP_SCORES_LOADED_SIGNAL = "leaderboard_top_scores_loaded";
static const char *LEADERBOARD_TOP_SCORES_FAILED_SIGNAL = "leaderboard_top_scores_failed";
static const char *LEADERBOARD_PLAYER_SCORE_LOADED_SIGNAL = "leaderboard_player_score_loaded";
static const char *LEADERBOARD_PLAYER_SCORE_FAILED_SIGNAL = "leaderboard_player_score_failed";

static NSString *StringToNSString(const String &value) {
	return [NSString stringWithUTF8String:value.utf8().get_data()];
}

static String NSStringToString(NSString *value) {
	if (value == nil) {
		return "";
	}
	return String::utf8([value UTF8String]);
}

static NSData *StringToNSData(const String &value) {
	CharString utf8 = value.utf8();
	return [NSData dataWithBytes:utf8.get_data() length:utf8.length()];
}

static String NSDataToString(NSData *value) {
	if (value == nil || value.length == 0) {
		return "";
	}
	NSString *string = [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
	return NSStringToString(string);
}

static UIViewController *GetTopViewController() {
	UIWindow *key_window = nil;
	if (@available(iOS 13.0, *)) {
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) {
				continue;
			}
			UIWindowScene *window_scene = (UIWindowScene *)scene;
			if (window_scene.activationState != UISceneActivationStateForegroundActive) {
				continue;
			}
			for (UIWindow *window in window_scene.windows) {
				if (window.isKeyWindow) {
					key_window = window;
					break;
				}
			}
			if (key_window != nil) {
				break;
			}
		}
	}
	if (key_window == nil) {
		key_window = UIApplication.sharedApplication.keyWindow;
	}
	UIViewController *controller = key_window.rootViewController;
	while (controller.presentedViewController != nil) {
		controller = controller.presentedViewController;
	}
	return controller;
}

static GKLeaderboardTimeScope ResolveTimeScope(NSString *time_span) {
	NSString *normalized = [[time_span lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([normalized isEqualToString:@"weekly"] || [normalized isEqualToString:@"week"]) {
		return GKLeaderboardTimeScopeWeek;
	}
	if ([normalized isEqualToString:@"daily"] || [normalized isEqualToString:@"today"]) {
		return GKLeaderboardTimeScopeToday;
	}
	return GKLeaderboardTimeScopeAllTime;
}

static Dictionary DictionaryForLeaderboardEntry(GKLeaderboardEntry *entry, NSString *fallback_name) {
	Dictionary result;
	if (entry == nil) {
		result["display_name"] = NSStringToString(fallback_name);
		result["score"] = int64_t(0);
		result["rank"] = -1;
		result["rank_value"] = -1;
		result["rank_known"] = false;
		result["is_player"] = true;
		result["player_id"] = "";
		return result;
	}

	NSString *display_name = fallback_name;
	if (entry.player.displayName != nil && entry.player.displayName.length > 0) {
		display_name = entry.player.displayName;
	}
	result["display_name"] = NSStringToString(display_name);
	result["score"] = int64_t(entry.score);
	result["rank"] = int(entry.rank);
	result["rank_value"] = int(entry.rank);
	result["rank_known"] = entry.rank > 0;
	result["is_player"] = entry.player != nil && [entry.player.gamePlayerID isEqualToString:GKLocalPlayer.localPlayer.gamePlayerID];
	result["player_id"] = NSStringToString(entry.player.gamePlayerID ?: @"");
	return result;
}

@interface GameCenterBridge : NSObject
@property(nonatomic, assign) GameCenterPlugin *plugin;
@property(nonatomic, assign) BOOL interactiveAuthPending;
- (instancetype)initWithPlugin:(GameCenterPlugin *)plugin;
- (void)signInInteractive;
- (void)refreshAuthStatus;
- (BOOL)isSignedIn;
- (NSString *)playerId;
- (NSString *)playerName;
- (BOOL)isCloudAvailable;
- (void)loadGame:(NSString *)saveName;
- (void)saveGame:(NSString *)saveName data:(NSString *)data description:(NSString *)description;
- (void)deleteGame:(NSString *)saveName;
- (void)submitScore:(int64_t)score leaderboardId:(NSString *)leaderboardId;
- (void)loadTopScores:(NSString *)leaderboardId timeSpan:(NSString *)timeSpan limit:(NSInteger)limit;
- (void)loadPlayerScore:(NSString *)leaderboardId timeSpan:(NSString *)timeSpan;
- (void)_withLeaderboard:(NSString *)leaderboardId onResolved:(void (^)(GKLeaderboard *leaderboard))onResolved onError:(void (^)(NSError *error))onError;
@end

GameCenterPlugin *GameCenterPlugin::instance = nullptr;

@implementation GameCenterBridge

- (instancetype)initWithPlugin:(GameCenterPlugin *)plugin {
	self = [super init];
	if (self != nil) {
		self.plugin = plugin;
		self.interactiveAuthPending = NO;
	}
	return self;
}

- (void)_emitSignedInSignalsIfAvailable {
	GKLocalPlayer *player = GKLocalPlayer.localPlayer;
	if (!player.isAuthenticated) {
		return;
	}
	String player_id = NSStringToString(player.gamePlayerID ?: @"");
	String player_name = NSStringToString(player.displayName ?: @"Game Center Player");
	self.plugin->notify_sign_in_success(player_id, player_name);
	self.plugin->notify_player_info_loaded(player_id, player_name);
}

- (void)_presentAuthControllerIfNeeded:(UIViewController *)controller interactive:(BOOL)interactive {
	if (controller == nil) {
		return;
	}
	if (!interactive) {
		self.plugin->notify_sign_in_failed(4, "SIGN_IN_REQUIRED");
		return;
	}
	UIViewController *top = GetTopViewController();
	if (top == nil) {
		self.plugin->notify_sign_in_failed(-1, "Unable to present Game Center login UI");
		return;
	}
	[top presentViewController:controller animated:YES completion:nil];
}

- (void)_authenticate:(BOOL)interactive {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.interactiveAuthPending = interactive;
		GKLocalPlayer *player = GKLocalPlayer.localPlayer;
		__weak GameCenterBridge *weak_self = self;
		player.authenticateHandler = ^(UIViewController *viewController, NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				GameCenterBridge *strong_self = weak_self;
				if (strong_self == nil) {
					return;
				}
				BOOL interactive_now = strong_self.interactiveAuthPending;
				strong_self.interactiveAuthPending = NO;

				if (error != nil) {
					strong_self.plugin->notify_sign_in_failed(int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center authentication failed"));
					return;
				}
				if (player.isAuthenticated) {
					[strong_self _emitSignedInSignalsIfAvailable];
					return;
				}
				if (viewController != nil) {
					[strong_self _presentAuthControllerIfNeeded:viewController interactive:interactive_now];
					return;
				}
				strong_self.plugin->notify_sign_in_failed(4, "SIGN_IN_REQUIRED");
			});
		};
	});
}

- (void)_withLeaderboard:(NSString *)leaderboardId onResolved:(void (^)(GKLeaderboard *leaderboard))onResolved onError:(void (^)(NSError *error))onError {
	[GKLeaderboard loadLeaderboardsWithIDs:@[ leaderboardId ] completionHandler:^(NSArray<GKLeaderboard *> * _Nullable leaderboards, NSError * _Nullable error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (error != nil) {
				onError(error);
				return;
			}
			GKLeaderboard *leaderboard = leaderboards.firstObject;
			if (leaderboard == nil) {
				NSError *missing_error = [NSError errorWithDomain:@"GodotGameCenter" code:-2 userInfo:@{ NSLocalizedDescriptionKey: @"Leaderboard not found in Game Center." }];
				onError(missing_error);
				return;
			}
			onResolved(leaderboard);
		});
	}];
}

- (void)signInInteractive {
	[self _authenticate:YES];
}

- (void)refreshAuthStatus {
	dispatch_async(dispatch_get_main_queue(), ^{
		GKLocalPlayer *player = GKLocalPlayer.localPlayer;
		if (player.isAuthenticated) {
			[self _emitSignedInSignalsIfAvailable];
			return;
		}
		[self _authenticate:NO];
	});
}

- (BOOL)isSignedIn {
	return GKLocalPlayer.localPlayer.isAuthenticated;
}

- (NSString *)playerId {
	if (!GKLocalPlayer.localPlayer.isAuthenticated) {
		return @"";
	}
	return GKLocalPlayer.localPlayer.gamePlayerID ?: @"";
}

- (NSString *)playerName {
	if (!GKLocalPlayer.localPlayer.isAuthenticated) {
		return @"";
	}
	return GKLocalPlayer.localPlayer.displayName ?: @"";
}

- (BOOL)isCloudAvailable {
	return GKLocalPlayer.localPlayer.isAuthenticated;
}

- (void)loadGame:(NSString *)saveName {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isCloudAvailable]) {
			self.plugin->notify_load_game_failed(NSStringToString(saveName), 4, "SIGN_IN_REQUIRED");
			return;
		}
		[GKLocalPlayer.localPlayer fetchSavedGamesWithCompletionHandler:^(NSArray<GKSavedGame *> * _Nullable savedGames, NSError * _Nullable error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (error != nil) {
					self.plugin->notify_load_game_failed(NSStringToString(saveName), int(error.code), NSStringToString(error.localizedDescription ?: @"Saved game load failed"));
					return;
				}
				GKSavedGame *matchingGame = nil;
				for (GKSavedGame *savedGame in savedGames) {
					if ([savedGame.name isEqualToString:saveName]) {
						matchingGame = savedGame;
						break;
					}
				}
				if (matchingGame == nil) {
					self.plugin->notify_load_game_success(NSStringToString(saveName), "");
					return;
				}
				[matchingGame loadDataWithCompletionHandler:^(NSData * _Nullable data, NSError * _Nullable loadError) {
					dispatch_async(dispatch_get_main_queue(), ^{
						if (loadError != nil) {
							self.plugin->notify_load_game_failed(NSStringToString(saveName), int(loadError.code), NSStringToString(loadError.localizedDescription ?: @"Saved game data load failed"));
							return;
						}
						self.plugin->notify_load_game_success(NSStringToString(saveName), NSDataToString(data));
					});
				}];
			});
		}];
	});
}

- (void)saveGame:(NSString *)saveName data:(NSString *)data description:(NSString *)description {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isCloudAvailable]) {
			self.plugin->notify_save_game_failed(NSStringToString(saveName), 4, "SIGN_IN_REQUIRED");
			return;
		}
		NSData *payload = StringToNSData(NSStringToString(data));
		(void)description;
		[GKLocalPlayer.localPlayer saveGameData:payload withName:saveName completionHandler:^(GKSavedGame * _Nullable savedGame, NSError * _Nullable error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (error != nil) {
					self.plugin->notify_save_game_failed(NSStringToString(saveName), int(error.code), NSStringToString(error.localizedDescription ?: @"Saved game save failed"));
					return;
				}
				NSString *resolvedName = savedGame.name ?: saveName;
				self.plugin->notify_save_game_success(NSStringToString(resolvedName));
			});
		}];
	});
}

- (void)deleteGame:(NSString *)saveName {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isCloudAvailable]) {
			self.plugin->notify_delete_game_failed(NSStringToString(saveName), 4, "SIGN_IN_REQUIRED");
			return;
		}
		[GKLocalPlayer.localPlayer deleteSavedGamesWithName:saveName completionHandler:^(NSError * _Nullable error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (error != nil) {
					self.plugin->notify_delete_game_failed(NSStringToString(saveName), int(error.code), NSStringToString(error.localizedDescription ?: @"Saved game delete failed"));
					return;
				}
				self.plugin->notify_delete_game_success(NSStringToString(saveName));
			});
		}];
	});
}

- (void)submitScore:(int64_t)score leaderboardId:(NSString *)leaderboardId {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isSignedIn]) {
			self.plugin->notify_leaderboard_submit_failed(NSStringToString(leaderboardId), 4, "SIGN_IN_REQUIRED");
			return;
		}
		NSArray<NSString *> *leaderboard_ids = @[ leaderboardId ];
		[GKLeaderboard submitScore:score context:0 player:GKLocalPlayer.localPlayer leaderboardIDs:leaderboard_ids completionHandler:^(NSError * _Nullable error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (error != nil) {
					self.plugin->notify_leaderboard_submit_failed(NSStringToString(leaderboardId), int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center submit failed"));
					return;
				}
				self.plugin->notify_leaderboard_submit_success(NSStringToString(leaderboardId));
			});
		}];
	});
}

- (void)loadTopScores:(NSString *)leaderboardId timeSpan:(NSString *)timeSpan limit:(NSInteger)limit {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isSignedIn]) {
			self.plugin->notify_leaderboard_top_scores_failed(NSStringToString(leaderboardId), 4, "SIGN_IN_REQUIRED");
			return;
		}
		[self _withLeaderboard:leaderboardId onResolved:^(GKLeaderboard *leaderboard) {
			NSRange range = NSMakeRange(1, MAX(1, limit));
			[leaderboard loadEntriesForPlayerScope:GKLeaderboardPlayerScopeGlobal timeScope:ResolveTimeScope(timeSpan) range:range completionHandler:^(GKLeaderboardEntry * _Nullable localPlayerEntry, NSArray<GKLeaderboardEntry *> * _Nullable entries, NSInteger totalPlayerCount, NSError * _Nullable error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (error != nil) {
						self.plugin->notify_leaderboard_top_scores_failed(NSStringToString(leaderboardId), int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center top scores failed"));
						return;
					}
					Array scores;
					for (GKLeaderboardEntry *entry in entries) {
						scores.push_back(DictionaryForLeaderboardEntry(entry, @"Unknown"));
					}
					Dictionary payload;
					payload["scores"] = scores;
					payload["total_player_count"] = int(totalPlayerCount);
					payload["leaderboard_id"] = NSStringToString(leaderboardId);
					String json = JSON::stringify(payload);
					self.plugin->notify_leaderboard_top_scores_loaded(NSStringToString(leaderboardId), json);
				});
			}];
		} onError:^(NSError *error) {
			self.plugin->notify_leaderboard_top_scores_failed(NSStringToString(leaderboardId), int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center top scores failed"));
		}];
	});
}

- (void)loadPlayerScore:(NSString *)leaderboardId timeSpan:(NSString *)timeSpan {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isSignedIn]) {
			self.plugin->notify_leaderboard_player_score_failed(NSStringToString(leaderboardId), 4, "SIGN_IN_REQUIRED");
			return;
		}
		[self _withLeaderboard:leaderboardId onResolved:^(GKLeaderboard *leaderboard) {
			[leaderboard loadEntriesForPlayerScope:GKLeaderboardPlayerScopeGlobal timeScope:ResolveTimeScope(timeSpan) range:NSMakeRange(1, 1) completionHandler:^(GKLeaderboardEntry * _Nullable localPlayerEntry, NSArray<GKLeaderboardEntry *> * _Nullable entries, NSInteger totalPlayerCount, NSError * _Nullable error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (error != nil) {
						self.plugin->notify_leaderboard_player_score_failed(NSStringToString(leaderboardId), int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center player score failed"));
						return;
					}
					Dictionary payload = DictionaryForLeaderboardEntry(localPlayerEntry, GKLocalPlayer.localPlayer.displayName ?: @"You");
					payload["leaderboard_id"] = NSStringToString(leaderboardId);
					payload["total_player_count"] = int(totalPlayerCount);
					String json = JSON::stringify(payload);
					self.plugin->notify_leaderboard_player_score_loaded(NSStringToString(leaderboardId), json);
				});
			}];
		} onError:^(NSError *error) {
			self.plugin->notify_leaderboard_player_score_failed(NSStringToString(leaderboardId), int(error.code), NSStringToString(error.localizedDescription ?: @"Game Center player score failed"));
		}];
	});
}

@end

void GameCenterPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("sign_in"), &GameCenterPlugin::sign_in);
	ClassDB::bind_method(D_METHOD("signIn"), &GameCenterPlugin::signIn);
	ClassDB::bind_method(D_METHOD("refresh_auth_status"), &GameCenterPlugin::refresh_auth_status);
	ClassDB::bind_method(D_METHOD("refreshAuthStatus"), &GameCenterPlugin::refreshAuthStatus);
	ClassDB::bind_method(D_METHOD("is_signed_in"), &GameCenterPlugin::is_signed_in);
	ClassDB::bind_method(D_METHOD("isSignedIn"), &GameCenterPlugin::isSignedIn);
	ClassDB::bind_method(D_METHOD("is_cloud_available"), &GameCenterPlugin::is_cloud_available);
	ClassDB::bind_method(D_METHOD("isCloudAvailable"), &GameCenterPlugin::isCloudAvailable);
	ClassDB::bind_method(D_METHOD("get_player_id"), &GameCenterPlugin::get_player_id);
	ClassDB::bind_method(D_METHOD("getPlayerId"), &GameCenterPlugin::getPlayerId);
	ClassDB::bind_method(D_METHOD("get_player_display_name"), &GameCenterPlugin::get_player_display_name);
	ClassDB::bind_method(D_METHOD("getPlayerDisplayName"), &GameCenterPlugin::getPlayerDisplayName);
	ClassDB::bind_method(D_METHOD("submit_score", "leaderboard_id", "score"), &GameCenterPlugin::submit_score);
	ClassDB::bind_method(D_METHOD("submitScore", "leaderboard_id", "score"), &GameCenterPlugin::submitScore);
	ClassDB::bind_method(D_METHOD("load_game", "save_name"), &GameCenterPlugin::load_game);
	ClassDB::bind_method(D_METHOD("loadGame", "save_name"), &GameCenterPlugin::loadGame);
	ClassDB::bind_method(D_METHOD("save_game", "save_name", "data", "description"), &GameCenterPlugin::save_game, DEFVAL(""));
	ClassDB::bind_method(D_METHOD("saveGame", "save_name", "data", "description"), &GameCenterPlugin::saveGame, DEFVAL(""));
	ClassDB::bind_method(D_METHOD("delete_game", "save_name"), &GameCenterPlugin::delete_game);
	ClassDB::bind_method(D_METHOD("deleteGame", "save_name"), &GameCenterPlugin::deleteGame);
	ClassDB::bind_method(D_METHOD("delete_saved_game", "save_name"), &GameCenterPlugin::delete_saved_game);
	ClassDB::bind_method(D_METHOD("deleteSavedGame", "save_name"), &GameCenterPlugin::deleteSavedGame);
	ClassDB::bind_method(D_METHOD("load_top_scores", "leaderboard_id", "time_span", "collection", "limit", "force_reload"), &GameCenterPlugin::load_top_scores, DEFVAL("all_time"), DEFVAL("public"), DEFVAL(10), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("loadTopScores", "leaderboard_id", "time_span", "collection", "limit", "force_reload"), &GameCenterPlugin::loadTopScores, DEFVAL("all_time"), DEFVAL("public"), DEFVAL(10), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("load_player_score", "leaderboard_id", "time_span", "collection", "force_reload"), &GameCenterPlugin::load_player_score, DEFVAL("all_time"), DEFVAL("public"), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("loadPlayerScore", "leaderboard_id", "time_span", "collection", "force_reload"), &GameCenterPlugin::loadPlayerScore, DEFVAL("all_time"), DEFVAL("public"), DEFVAL(true));

	ADD_SIGNAL(MethodInfo(SIGN_IN_SUCCESS_SIGNAL, PropertyInfo(Variant::STRING, "player_id"), PropertyInfo(Variant::STRING, "player_name")));
	ADD_SIGNAL(MethodInfo(SIGN_IN_FAILED_SIGNAL, PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(PLAYER_INFO_LOADED_SIGNAL, PropertyInfo(Variant::STRING, "player_id"), PropertyInfo(Variant::STRING, "player_name")));
	ADD_SIGNAL(MethodInfo(LOAD_GAME_SUCCESS_SIGNAL, PropertyInfo(Variant::STRING, "save_name"), PropertyInfo(Variant::STRING, "data")));
	ADD_SIGNAL(MethodInfo(LOAD_GAME_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "save_name"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(SAVE_GAME_SUCCESS_SIGNAL, PropertyInfo(Variant::STRING, "save_name")));
	ADD_SIGNAL(MethodInfo(SAVE_GAME_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "save_name"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(DELETE_GAME_SUCCESS_SIGNAL, PropertyInfo(Variant::STRING, "save_name")));
	ADD_SIGNAL(MethodInfo(DELETE_GAME_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "save_name"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_SUBMIT_SUCCESS_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_SUBMIT_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_TOP_SCORES_LOADED_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::STRING, "json")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_TOP_SCORES_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_PLAYER_SCORE_LOADED_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::STRING, "json")));
	ADD_SIGNAL(MethodInfo(LEADERBOARD_PLAYER_SCORE_FAILED_SIGNAL, PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::INT, "status_code"), PropertyInfo(Variant::STRING, "message")));
}

GameCenterPlugin *GameCenterPlugin::get_singleton() {
	return instance;
}

GameCenterPlugin::GameCenterPlugin() {
	instance = this;
	bridge = [[GameCenterBridge alloc] initWithPlugin:this];
}

GameCenterPlugin::~GameCenterPlugin() {
	bridge = nil;
	if (instance == this) {
		instance = nullptr;
	}
}

void GameCenterPlugin::sign_in() {
	[bridge signInInteractive];
}

void GameCenterPlugin::signIn() {
	sign_in();
}

void GameCenterPlugin::refresh_auth_status() {
	[bridge refreshAuthStatus];
}

void GameCenterPlugin::refreshAuthStatus() {
	refresh_auth_status();
}

bool GameCenterPlugin::is_signed_in() const {
	return [bridge isSignedIn];
}

bool GameCenterPlugin::isSignedIn() const {
	return is_signed_in();
}

bool GameCenterPlugin::is_cloud_available() const {
	return [bridge isCloudAvailable];
}

bool GameCenterPlugin::isCloudAvailable() const {
	return is_cloud_available();
}

String GameCenterPlugin::get_player_id() const {
	return NSStringToString([bridge playerId]);
}

String GameCenterPlugin::getPlayerId() const {
	return get_player_id();
}

String GameCenterPlugin::get_player_display_name() const {
	return NSStringToString([bridge playerName]);
}

String GameCenterPlugin::getPlayerDisplayName() const {
	return get_player_display_name();
}

void GameCenterPlugin::submit_score(String leaderboard_id, int score) {
	[bridge submitScore:score leaderboardId:StringToNSString(leaderboard_id)];
}

void GameCenterPlugin::submitScore(String leaderboard_id, int score) {
	submit_score(leaderboard_id, score);
}

void GameCenterPlugin::load_game(String save_name) {
	[bridge loadGame:StringToNSString(save_name)];
}

void GameCenterPlugin::loadGame(String save_name) {
	load_game(save_name);
}

void GameCenterPlugin::save_game(String save_name, String data, String description) {
	[bridge saveGame:StringToNSString(save_name) data:StringToNSString(data) description:StringToNSString(description)];
}

void GameCenterPlugin::saveGame(String save_name, String data, String description) {
	save_game(save_name, data, description);
}

void GameCenterPlugin::delete_game(String save_name) {
	[bridge deleteGame:StringToNSString(save_name)];
}

void GameCenterPlugin::deleteGame(String save_name) {
	delete_game(save_name);
}

void GameCenterPlugin::delete_saved_game(String save_name) {
	delete_game(save_name);
}

void GameCenterPlugin::deleteSavedGame(String save_name) {
	delete_game(save_name);
}

void GameCenterPlugin::load_top_scores(String leaderboard_id, String time_span, String collection, int limit, bool force_reload) {
	[bridge loadTopScores:StringToNSString(leaderboard_id) timeSpan:StringToNSString(time_span) limit:limit];
}

void GameCenterPlugin::loadTopScores(String leaderboard_id, String time_span, String collection, int limit, bool force_reload) {
	load_top_scores(leaderboard_id, time_span, collection, limit, force_reload);
}

void GameCenterPlugin::load_player_score(String leaderboard_id, String time_span, String collection, bool force_reload) {
	[bridge loadPlayerScore:StringToNSString(leaderboard_id) timeSpan:StringToNSString(time_span)];
}

void GameCenterPlugin::loadPlayerScore(String leaderboard_id, String time_span, String collection, bool force_reload) {
	load_player_score(leaderboard_id, time_span, collection, force_reload);
}

void GameCenterPlugin::notify_sign_in_success(const String &player_id, const String &player_name) {
	emit_signal(SIGN_IN_SUCCESS_SIGNAL, player_id, player_name);
}

void GameCenterPlugin::notify_sign_in_failed(int status_code, const String &message) {
	emit_signal(SIGN_IN_FAILED_SIGNAL, status_code, message);
}

void GameCenterPlugin::notify_player_info_loaded(const String &player_id, const String &player_name) {
	emit_signal(PLAYER_INFO_LOADED_SIGNAL, player_id, player_name);
}

void GameCenterPlugin::notify_load_game_success(const String &save_name, const String &data) {
	emit_signal(LOAD_GAME_SUCCESS_SIGNAL, save_name, data);
}

void GameCenterPlugin::notify_load_game_failed(const String &save_name, int status_code, const String &message) {
	emit_signal(LOAD_GAME_FAILED_SIGNAL, save_name, status_code, message);
}

void GameCenterPlugin::notify_save_game_success(const String &save_name) {
	emit_signal(SAVE_GAME_SUCCESS_SIGNAL, save_name);
}

void GameCenterPlugin::notify_save_game_failed(const String &save_name, int status_code, const String &message) {
	emit_signal(SAVE_GAME_FAILED_SIGNAL, save_name, status_code, message);
}

void GameCenterPlugin::notify_delete_game_success(const String &save_name) {
	emit_signal(DELETE_GAME_SUCCESS_SIGNAL, save_name);
}

void GameCenterPlugin::notify_delete_game_failed(const String &save_name, int status_code, const String &message) {
	emit_signal(DELETE_GAME_FAILED_SIGNAL, save_name, status_code, message);
}

void GameCenterPlugin::notify_leaderboard_submit_success(const String &leaderboard_id) {
	emit_signal(LEADERBOARD_SUBMIT_SUCCESS_SIGNAL, leaderboard_id);
}

void GameCenterPlugin::notify_leaderboard_submit_failed(const String &leaderboard_id, int status_code, const String &message) {
	emit_signal(LEADERBOARD_SUBMIT_FAILED_SIGNAL, leaderboard_id, status_code, message);
}

void GameCenterPlugin::notify_leaderboard_top_scores_loaded(const String &leaderboard_id, const String &json) {
	emit_signal(LEADERBOARD_TOP_SCORES_LOADED_SIGNAL, leaderboard_id, json);
}

void GameCenterPlugin::notify_leaderboard_top_scores_failed(const String &leaderboard_id, int status_code, const String &message) {
	emit_signal(LEADERBOARD_TOP_SCORES_FAILED_SIGNAL, leaderboard_id, status_code, message);
}

void GameCenterPlugin::notify_leaderboard_player_score_loaded(const String &leaderboard_id, const String &json) {
	emit_signal(LEADERBOARD_PLAYER_SCORE_LOADED_SIGNAL, leaderboard_id, json);
}

void GameCenterPlugin::notify_leaderboard_player_score_failed(const String &leaderboard_id, int status_code, const String &message) {
	emit_signal(LEADERBOARD_PLAYER_SCORE_FAILED_SIGNAL, leaderboard_id, status_code, message);
}
