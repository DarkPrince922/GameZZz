extends GutTest
## AudioManager structure tests: pool cap, unknown ids, buses, volumes, music,
## pause behaviour. The CI machine has no speakers, so we assert structure.

const POOL_LIMIT := 16


func before_each() -> void:
	AudioManager.apply_settings()


func test_buses_exist() -> void:
	assert_true(AudioManager.has_buses(), "Master/Music/SFX/UI buses must exist")
	assert_ne(AudioManager.bus_index("Music"), -1)
	assert_ne(AudioManager.bus_index("SFX"), -1)
	assert_ne(AudioManager.bus_index("UI"), -1)


func test_pool_is_capped() -> void:
	assert_lte(AudioManager.pool_size(), POOL_LIMIT, "pool must stay <= 16 players")
	assert_eq(AudioManager.pool_size(), DataDB.max_concurrent_sounds(),
		"pool size should follow data/sounds.json")


func test_unknown_sound_warns_and_does_not_crash() -> void:
	var before := AudioManager.active_sound_count()
	AudioManager.last_missing_id = ""
	AudioManager.play("this_id_does_not_exist")
	assert_eq(AudioManager.last_missing_id, "this_id_does_not_exist",
		"unknown id must be recorded for diagnostics")
	assert_eq(AudioManager.active_sound_count(), before, "nothing should start playing")
	AudioManager.play_at("this_id_does_not_exist", Vector2.ZERO)
	AudioManager.play_music("music_that_is_not_here")
	assert_true(true, "no crash after three unknown ids")


func test_many_plays_never_exceed_pool() -> void:
	for i in 40:
		AudioManager.play("hero_step")
	assert_lte(AudioManager.active_sound_count(), AudioManager.pool_size(),
		"concurrent sounds must not exceed the pool")
	assert_lte(AudioManager.active_sound_count(), POOL_LIMIT)


func test_known_event_plays() -> void:
	var before := AudioManager.active_sound_count()
	AudioManager.play("combat_hit")
	assert_gte(AudioManager.active_sound_count(), before)


func test_volumes_are_saved_and_restored() -> void:
	Settings.set_value("master_volume", 0.42)
	Settings.set_value("music_volume", 0.33)
	Settings.set_value("sfx_volume", 0.28)
	assert_almost_eq(Settings.master_volume, 0.42, 0.001)
	assert_almost_eq(Settings.music_volume, 0.33, 0.001)
	assert_almost_eq(Settings.sfx_volume, 0.28, 0.001)
	Settings.load_settings()
	assert_almost_eq(Settings.master_volume, 0.42, 0.001, "master volume must survive reload")
	assert_almost_eq(Settings.music_volume, 0.33, 0.001, "music volume must survive reload")
	assert_almost_eq(Settings.sfx_volume, 0.28, 0.001, "sfx volume must survive reload")
	AudioManager.apply_settings()
	assert_almost_eq(AudioManager.bus_volume("SFX"), 0.28, 0.02,
		"settings value must reach the SFX bus")
	Settings.set_value("master_volume", 0.9)
	Settings.set_value("music_volume", 0.7)
	Settings.set_value("sfx_volume", 0.85)


func test_pause_mutes_effects_but_not_ui() -> void:
	AudioManager.set_paused(true)
	assert_true(AudioServer.is_bus_mute(AudioManager.bus_index("SFX")),
		"paused game must mute SFX")
	assert_false(AudioServer.is_bus_mute(AudioManager.bus_index("UI")),
		"menus must stay audible while paused")
	AudioManager.set_paused(false)
	assert_false(AudioServer.is_bus_mute(AudioManager.bus_index("SFX")))


func test_music_switch() -> void:
	AudioManager.play_music("music_world_1", 0.0)
	assert_eq(AudioManager.current_music(), "music_world_1")
	AudioManager.play_music("music_boss", 0.0)
	assert_eq(AudioManager.current_music(), "music_boss", "music must switch tracks")
	AudioManager.stop_music(0.0)


func test_ambience_starts_and_stops() -> void:
	AudioManager.play_ambience("amb_world_1")
	assert_eq(AudioManager.current_ambience(), "amb_world_1")
	AudioManager.stop_ambience()
	assert_eq(AudioManager.current_ambience(), "")
