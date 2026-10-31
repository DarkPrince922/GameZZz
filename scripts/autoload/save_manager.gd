extends Node
## Versioned local progress saving with migrations and corruption recovery.
## Files: user://save.json, user://save.backup.json, user://save.corrupt.json

signal progress_changed()
signal shards_changed(total: int)

const PATH := "user://save.json"
const BACKUP := "user://save.backup.json"
const CORRUPT := "user://save.corrupt.json"
const CURRENT_VERSION := 2

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func defaults() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"shards": 0,
		"total_shards": 0,
		"upgrade_levels": {},
		"unlocked_worlds": [1],
		"unlocked_levels": ["world1_level1"],
		"level_stars": {},
		"weapon": "light_sword",
		"owned_weapons": ["light_sword"],
		"skills": ["dash", "light_burst", "shield"],
		"achievements": {},
		"bestiary": {},
		"deaths": 0,
		"wins": 0,
		"play_time": 0.0,
	}


func load_game() -> void:
	data = defaults()
	var used_recovery := false
	var loaded: Variant = _read_json(PATH)
	if not (loaded is Dictionary):
		if FileAccess.file_exists(PATH):
			_keep_corrupt_copy()
			used_recovery = true
		var backup: Variant = _read_json(BACKUP)
		if backup is Dictionary:
			loaded = backup
	if loaded is Dictionary:
		data = _normalise(loaded)
		_migrate()
		if used_recovery:
			print("WARNING: ", "SaveManager: restored save from backup")
			save_game()
	progress_changed.emit()


func save_game() -> bool:
	data["version"] = CURRENT_VERSION
	var ok := _write_json(PATH, data)
	_write_json(BACKUP, data)
	progress_changed.emit()
	return ok


func reset(all_shards_zero: bool = true) -> void:
	data = defaults()
	if not all_shards_zero:
		data["shards"] = 0
	save_game()


# ---------------------------------------------------------------- economy
func shards() -> int:
	return int(data.get("shards", 0))


func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	data["shards"] = shards() + amount
	data["total_shards"] = int(data.get("total_shards", 0)) + amount
	save_game()
	shards_changed.emit(shards())


func spend_shards(amount: int) -> bool:
	if amount < 0 or shards() < amount:
		return false
	data["shards"] = shards() - amount
	save_game()
	shards_changed.emit(shards())
	return true


func upgrade_level(upgrade_id: String) -> int:
	var levels: Dictionary = data.get("upgrade_levels", {})
	return int(levels.get(upgrade_id, 0))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var levels: Dictionary = data.get("upgrade_levels", {})
	levels[upgrade_id] = level
	data["upgrade_levels"] = levels
	save_game()


# ---------------------------------------------------------------- progress
func unlock_level(level_id: String) -> void:
	var levels: Array = data.get("unlocked_levels", [])
	if not levels.has(level_id):
		levels.append(level_id)
		data["unlocked_levels"] = levels
		save_game()


func unlock_world(world: int) -> void:
	var worlds: Array = data.get("unlocked_worlds", [1])
	if not worlds.has(world):
		worlds.append(world)
		data["unlocked_worlds"] = worlds
		save_game()


func is_level_unlocked(level_id: String) -> bool:
	return (data.get("unlocked_levels", []) as Array).has(level_id)


func is_world_unlocked(world: int) -> bool:
	return (data.get("unlocked_worlds", [1]) as Array).has(world)


func level_stars(level_id: String) -> int:
	return int((data.get("level_stars", {}) as Dictionary).get(level_id, 0))


func set_level_stars(level_id: String, stars: int) -> void:
	var stars_map: Dictionary = data.get("level_stars", {})
	if stars > level_stars(level_id):
		stars_map[level_id] = clampi(stars, 0, 3)
		data["level_stars"] = stars_map
		save_game()


func total_stars() -> int:
	var sum := 0
	for value: Variant in (data.get("level_stars", {}) as Dictionary).values():
		sum += int(value)
	return sum


func add_death() -> void:
	data["deaths"] = int(data.get("deaths", 0)) + 1
	save_game()


func add_win() -> void:
	data["wins"] = int(data.get("wins", 0)) + 1
	save_game()


func unlock_achievement(achievement_id: String) -> bool:
	var achievements: Dictionary = data.get("achievements", {})
	if achievements.has(achievement_id):
		return false
	achievements[achievement_id] = true
	data["achievements"] = achievements
	save_game()
	return true


func has_achievement(achievement_id: String) -> bool:
	return (data.get("achievements", {}) as Dictionary).has(achievement_id)


func register_bestiary(enemy_id: String) -> bool:
	var bestiary: Dictionary = data.get("bestiary", {})
	if bestiary.has(enemy_id):
		return false
	bestiary[enemy_id] = true
	data["bestiary"] = bestiary
	save_game()
	return true


# ---------------------------------------------------------------- equipment
func equipped_skills() -> Array:
	return data.get("skills", [])


func set_equipped_skills(skills: Array) -> void:
	data["skills"] = skills.slice(0, 3)
	save_game()


func equipped_weapon() -> String:
	return str(data.get("weapon", "light_sword"))


func set_weapon(weapon_id: String) -> void:
	data["weapon"] = weapon_id
	var owned: Array = data.get("owned_weapons", ["light_sword"])
	if not owned.has(weapon_id):
		owned.append(weapon_id)
		data["owned_weapons"] = owned
	save_game()


func owns_weapon(weapon_id: String) -> bool:
	return (data.get("owned_weapons", []) as Array).has(weapon_id)


# ---------------------------------------------------------------- internals
func _read_json(path: String) -> Variant:
	## JSON.new().parse() instead of JSON.parse_string(): the latter reports a
	## broken file as an engine ERROR, which pollutes the log and (correctly)
	## fails GUT's unexpected-error tracking.
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


func _write_json(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("WARNING: ", "SaveManager: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return true


func _keep_corrupt_copy() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var file := FileAccess.open(CORRUPT, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	print("WARNING: ", "SaveManager: save file was corrupt, copy kept in %s" % CORRUPT)


func _normalise(raw: Dictionary) -> Dictionary:
	## JSON.parse_string returns every number as float, so ints must be coerced
	## back or progress (shards, version codes) would be silently dropped.
	var base := defaults()
	for key: String in base.keys():
		if not raw.has(key):
			continue
		var value: Variant = raw[key]
		match typeof(base[key]):
			TYPE_INT:
				if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
					base[key] = int(value)
			TYPE_FLOAT:
				if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
					base[key] = float(value)
			TYPE_BOOL:
				if typeof(value) == TYPE_BOOL:
					base[key] = value
			TYPE_STRING:
				if typeof(value) == TYPE_STRING:
					base[key] = value
			TYPE_ARRAY:
				if typeof(value) == TYPE_ARRAY:
					base[key] = value
			TYPE_DICTIONARY:
				if typeof(value) == TYPE_DICTIONARY:
					base[key] = value
	base["version"] = int(raw.get("version", 1))
	return base


func _migrate() -> void:
	var version := int(data.get("version", 1))
	if version < 2:
		# v1 -> v2: skills/weapons did not exist; give the starting loadout
		if not data.has("skills") or (data.get("skills", []) as Array).is_empty():
			data["skills"] = ["dash", "light_burst", "shield"]
		if not data.has("weapon"):
			data["weapon"] = "light_sword"
		if not (data.get("owned_weapons", []) as Array).has("light_sword"):
			data["owned_weapons"] = ["light_sword"]
		data["version"] = 2
		save_game()
