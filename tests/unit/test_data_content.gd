extends GutTest
## Content integrity: levels are playable on paper, every referenced id exists,
## both languages cover every key, and each weapon/skill has its own sound.

const LEVEL_DIR := "res://data/levels/"


func test_world_one_has_four_levels_and_a_boss() -> void:
	var ids: Array = DataDB.level_ids_for_world(1)
	assert_eq(ids.size(), 4, "world 1 ships four levels")
	var boss_level := str(DataDB.world(1).get("boss_level", ""))
	assert_ne(boss_level, "", "world 1 needs a boss level")
	var boss_data := DataDB.level(boss_level)
	assert_eq(str(boss_data.get("boss", "")), "bed_monster")
	assert_true(DataDB.boss("bed_monster").size() > 0)


func test_every_level_file_is_valid() -> void:
	for level_id: String in DataDB.level_ids():
		var level := DataDB.level(level_id)
		assert_false(level.is_empty(), "%s must parse" % level_id)
		assert_true(level.has("ground_runs"), "%s needs ground_runs" % level_id)
		assert_true(level.has("spawn"), "%s needs a spawn point" % level_id)
		assert_true(level.has("goal"), "%s needs a goal" % level_id)
		var width := _width(level)
		var spawn: Array = level.get("spawn", [0, 0])
		var goal: Array = level.get("goal", [0, 0])
		assert_between(int(spawn[0]), 0, width - 1, "%s spawn inside the map" % level_id)
		assert_between(int(goal[0]), 0, width - 1, "%s goal inside the map" % level_id)
		var height := int(level.get("height", 14))
		assert_lt(int(spawn[1]), height, "%s spawn row inside the map" % level_id)
		assert_lt(int(goal[1]), height, "%s goal row inside the map" % level_id)


func test_level_audio_ids_exist() -> void:
	for level_id: String in DataDB.level_ids():
		var level := DataDB.level(level_id)
		var music := str(level.get("music", ""))
		assert_false(DataDB.music_track(music).is_empty(),
			"%s music %s missing" % [level_id, music])
		var ambience := str(level.get("ambient", ""))
		if ambience != "":
			assert_false(DataDB.sound_event(ambience).is_empty(),
				"%s ambience %s missing" % [level_id, ambience])


func test_level_enemy_types_exist() -> void:
	for level_id: String in DataDB.level_ids():
		for enemy_data: Variant in DataDB.level(level_id).get("enemies", []):
			var enemy_type := str((enemy_data as Dictionary).get("type", ""))
			assert_false(DataDB.enemy(enemy_type).is_empty(),
				"%s references unknown enemy %s" % [level_id, enemy_type])
			var elite := str((enemy_data as Dictionary).get("elite", ""))
			if elite != "":
				assert_false(DataDB.elite(elite).is_empty(),
					"%s references unknown elite %s" % [level_id, elite])


func test_levels_are_jumpable() -> void:
	## A jump clears about 2.5 tiles and 4 tiles of gap, so the data must not ask
	## for more than that, otherwise the bot and the player would be stuck.
	for level_id: String in DataDB.level_ids():
		var level := DataDB.level(level_id)
		var heights: Array = _heights(level)
		var previous_height := 0
		var gap := 0
		for height: int in heights:
			if height == 0:
				gap += 1
				continue
			if gap > 0:
				assert_lte(gap, 4, "%s has a %d-tile gap" % [level_id, gap])
				gap = 0
			if previous_height > 0 and height < previous_height:
				assert_lte(previous_height - height, 2,
					"%s asks for a %d-tile climb" % [level_id, previous_height - height])
			previous_height = height


func test_every_upgrade_is_priced() -> void:
	for upgrade_id: String in DataDB.upgrades.keys():
		var data := DataDB.upgrade(upgrade_id)
		assert_gt(int(data.get("price_base", 0)), 0, "%s needs a price" % upgrade_id)
		assert_gt(int(data.get("max_level", 0)), 0, "%s needs levels" % upgrade_id)


func test_five_weapons_with_sounds() -> void:
	assert_eq(DataDB.weapons.size(), 5, "five weapons are required")
	for weapon_id: String in DataDB.weapons.keys():
		var data := DataDB.weapon(weapon_id)
		assert_false(DataDB.sound_event(str(data.get("swing_sfx", ""))).is_empty(),
			"%s swing sound missing" % weapon_id)
		assert_false(DataDB.sound_event(str(data.get("hit_sfx", ""))).is_empty(),
			"%s hit sound missing" % weapon_id)
		assert_gt(float(data.get("damage", 0.0)), 0.0, "%s needs damage" % weapon_id)


func test_twelve_skills_with_unique_sounds() -> void:
	assert_eq(DataDB.skills.size(), 12, "twelve skills are required")
	var sounds: Dictionary = {}
	for skill_id: String in DataDB.skills.keys():
		var data := DataDB.skill(skill_id)
		var sfx := str(data.get("sfx", ""))
		assert_false(DataDB.sound_event(sfx).is_empty(), "%s sound missing" % skill_id)
		assert_false(sounds.has(sfx), "%s reuses the sound of %s" % [skill_id, sounds.get(sfx, "")])
		sounds[sfx] = skill_id
		assert_gt(float(data.get("cooldown", 0.0)), 0.0, "%s needs a cooldown" % skill_id)


func test_six_enemies_and_three_elites() -> void:
	assert_eq(DataDB.enemies.size(), 6, "six enemy types are required")
	assert_eq(DataDB.elites.size(), 3, "three elite modifiers are required")


func test_translations_have_the_same_keys() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/en.json"))
	var ru: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/ru.json"))
	var missing_ru: Array = []
	var missing_en: Array = []
	for key: Variant in en.keys():
		if not ru.has(key):
			missing_ru.append(key)
	for key: Variant in ru.keys():
		if not en.has(key):
			missing_en.append(key)
	assert_eq(missing_ru, [], "keys missing in ru.json: %s" % str(missing_ru))
	assert_eq(missing_en, [], "keys missing in en.json: %s" % str(missing_en))


func test_all_referenced_names_are_translated() -> void:
	var needed: Array = []
	for weapon_id: String in DataDB.weapons.keys():
		needed.append(str(DataDB.weapon(weapon_id).get("name_key", "")))
		needed.append(str(DataDB.weapon(weapon_id).get("desc_key", "")))
	for skill_id: String in DataDB.skills.keys():
		needed.append(str(DataDB.skill(skill_id).get("name_key", "")))
		needed.append(str(DataDB.skill(skill_id).get("desc_key", "")))
	for enemy_id: String in DataDB.enemies.keys():
		needed.append(str(DataDB.enemy(enemy_id).get("name_key", "")))
	for elite_id: String in DataDB.elites.keys():
		needed.append(str(DataDB.elite(elite_id).get("name_key", "")))
	for upgrade_id: String in DataDB.upgrades.keys():
		needed.append(str(DataDB.upgrade(upgrade_id).get("name_key", "")))
		needed.append(str(DataDB.upgrade(upgrade_id).get("desc_key", "")))
	for world_number: int in DataDB.world_numbers():
		needed.append(str(DataDB.world(world_number).get("name_key", "")))
	for level_id: String in DataDB.level_ids():
		needed.append(str(DataDB.level(level_id).get("name_key", "")))
	for boss_id: String in DataDB.bosses.keys():
		needed.append(str(DataDB.boss(boss_id).get("name_key", "")))
	Loc.set_language("en")
	var missing: Array = []
	for key: String in needed:
		if key == "":
			continue
		if not Loc.has_key(key):
			missing.append(key)
	assert_eq(missing, [], "untranslated keys: %s" % str(missing))


func _width(level: Dictionary) -> int:
	var total := 0
	for run: Variant in level.get("ground_runs", []):
		total += int((run as Array)[1])
	return total


func _heights(level: Dictionary) -> Array:
	var heights: Array = []
	for run: Variant in level.get("ground_runs", []):
		var pair: Array = run
		for i in int(pair[1]):
			heights.append(int(pair[0]))
	return heights
