extends GutTest
## Saving: versioned format, migrations, corruption recovery, economy, progress.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.backup.json"
const CORRUPT_PATH := "user://save.corrupt.json"


func before_each() -> void:
	_remove(SAVE_PATH)
	_remove(BACKUP_PATH)
	_remove(CORRUPT_PATH)
	SaveManager.reset()


func after_each() -> void:
	_remove(CORRUPT_PATH)


func test_defaults_are_sane() -> void:
	assert_eq(int(SaveManager.data.get("version", 0)), 2)
	assert_eq(SaveManager.shards(), 0)
	assert_true(SaveManager.is_level_unlocked("world1_level1"))
	assert_true(SaveManager.is_world_unlocked(1))
	assert_eq((SaveManager.equipped_skills() as Array).size(), 3, "start with three skills")
	assert_eq(SaveManager.equipped_weapon(), "light_sword")


func test_save_and_load_roundtrip() -> void:
	SaveManager.add_shards(45)
	SaveManager.set_upgrade_level("health", 2)
	SaveManager.unlock_level("world1_level2")
	SaveManager.set_weapon("moon_bow")
	assert_true(SaveManager.save_game())
	SaveManager.data = {}
	SaveManager.load_game()
	assert_eq(SaveManager.shards(), 45, "shards must survive a reload")
	assert_eq(SaveManager.upgrade_level("health"), 2)
	assert_true(SaveManager.is_level_unlocked("world1_level2"))
	assert_eq(SaveManager.equipped_weapon(), "moon_bow")


func test_spending_shards_never_goes_negative() -> void:
	SaveManager.add_shards(10)
	assert_false(SaveManager.spend_shards(11), "cannot overspend")
	assert_eq(SaveManager.shards(), 10)
	assert_true(SaveManager.spend_shards(10))
	assert_eq(SaveManager.shards(), 0)


func test_stars_keep_the_best_result() -> void:
	SaveManager.set_level_stars("world1_level1", 2)
	SaveManager.set_level_stars("world1_level1", 1)
	assert_eq(SaveManager.level_stars("world1_level1"), 2, "a worse run must not lower stars")
	SaveManager.set_level_stars("world1_level2", 3)
	assert_eq(SaveManager.total_stars(), 5)


func test_corrupt_save_is_replaced_with_backup() -> void:
	SaveManager.add_shards(30)
	SaveManager.save_game()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json ")
	file.close()
	SaveManager.load_game()
	assert_eq(SaveManager.shards(), 30, "backup must be used when the save is corrupt")
	assert_true(FileAccess.file_exists(CORRUPT_PATH), "the corrupt file must be kept for debugging")


func test_corrupt_save_without_backup_falls_back_to_defaults() -> void:
	_remove(BACKUP_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("garbage")
	file.close()
	SaveManager.load_game()
	assert_eq(SaveManager.shards(), 0)
	assert_true(SaveManager.is_level_unlocked("world1_level1"), "the game must stay playable")


func test_v1_save_is_migrated() -> void:
	var legacy := {
		"version": 1,
		"shards": 12,
		"upgrade_levels": {"health": 1},
		"unlocked_levels": ["world1_level1", "world1_level2"],
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	SaveManager.load_game()
	assert_eq(SaveManager.shards(), 12, "old progress must be preserved")
	assert_eq(int(SaveManager.data.get("version", 0)), 2, "save must be upgraded")
	assert_eq(SaveManager.upgrade_level("health"), 1)
	assert_eq((SaveManager.equipped_skills() as Array).size(), 3, "migration grants a loadout")


func test_achievements_and_bestiary_are_unique() -> void:
	assert_true(SaveManager.unlock_achievement("achievement_first_blood"))
	assert_false(SaveManager.unlock_achievement("achievement_first_blood"),
		"the same achievement cannot unlock twice")
	assert_true(SaveManager.has_achievement("achievement_first_blood"))
	assert_true(SaveManager.register_bestiary("shadow"))
	assert_false(SaveManager.register_bestiary("shadow"))


func test_equipped_skills_are_limited_to_three() -> void:
	SaveManager.set_equipped_skills(["dash", "shield", "heal", "dawn"])
	assert_eq((SaveManager.equipped_skills() as Array).size(), 3, "only three slots exist")


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
