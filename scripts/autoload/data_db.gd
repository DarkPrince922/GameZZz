extends Node
## Single entry point for all content: enemies, elites, weapons, skills, upgrades,
## levels, bosses, worlds, player tuning and the sound registry.
## Everything is JSON in data/ so content can be added without code changes.

const DATA_DIR := "res://data/"
const LEVEL_DIR := "res://data/levels/"

var enemies: Dictionary = {}
var elites: Dictionary = {}
var weapons: Dictionary = {}
var skills: Dictionary = {}
var upgrades: Dictionary = {}
var bosses: Dictionary = {}
var worlds: Dictionary = {}
var player_config: Dictionary = {}
var sounds: Dictionary = {}
var required_events: Dictionary = {}

var _level_cache: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	enemies = _json("enemies.json").get("enemies", {})
	elites = _json("enemies.json").get("elites", {})
	weapons = _json("weapons.json").get("weapons", {})
	skills = _json("skills.json").get("skills", {})
	upgrades = _json("upgrades.json").get("upgrades", {})
	bosses = _json("bosses.json").get("bosses", {})
	worlds = _json("worlds.json").get("worlds", {})
	player_config = _json("player.json")
	sounds = _json("sounds.json")
	required_events = _json("sound_events.json")
	_level_cache.clear()


# ------------------------------------------------------------------ content
func enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func elite(elite_id: String) -> Dictionary:
	return elites.get(elite_id, {})


func weapon(weapon_id: String) -> Dictionary:
	return weapons.get(weapon_id, weapons.values()[0] if not weapons.is_empty() else {})


func skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})


func upgrade(upgrade_id: String) -> Dictionary:
	return upgrades.get(upgrade_id, {})


func boss(boss_id: String) -> Dictionary:
	return bosses.get(boss_id, {})


func world(number: int) -> Dictionary:
	return worlds.get(str(number), {})


func world_numbers() -> Array:
	var numbers: Array = []
	for key: String in worlds.keys():
		numbers.append(int(key))
	numbers.sort()
	return numbers


func level_ids_for_world(number: int) -> Array:
	return world(number).get("levels", [])


func level(level_id: String) -> Dictionary:
	if _level_cache.has(level_id):
		return _level_cache[level_id]
	var path := LEVEL_DIR + level_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("DataDB: level not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("DataDB: level %s is not valid JSON" % path)
		return {}
	_level_cache[level_id] = parsed
	return parsed


func level_ids() -> Array:
	var ids: Array = []
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		return ids
	for name: String in dir.get_files():
		if name.ends_with(".json"):
			ids.append(name.get_basename())
	ids.sort()
	return ids


func player_tuning() -> Dictionary:
	return player_config


# -------------------------------------------------------------------- audio
func sound_event(event_id: String) -> Dictionary:
	return (sounds.get("events", {}) as Dictionary).get(event_id, {})


func music_track(track_id: String) -> Dictionary:
	return (sounds.get("music", {}) as Dictionary).get(track_id, {})


func sound_event_ids() -> Array:
	return (sounds.get("events", {}) as Dictionary).keys()


func music_ids() -> Array:
	return (sounds.get("music", {}) as Dictionary).keys()


func max_concurrent_sounds() -> int:
	return int(sounds.get("max_concurrent", 16))


func required_sound_ids() -> Array:
	return required_events.get("required_events", [])


func required_music_ids() -> Array:
	return required_events.get("required_music", [])


func missing_sound_ids() -> Array:
	var missing: Array = []
	for event_id: String in required_sound_ids():
		if sound_event(event_id).is_empty():
			missing.append(event_id)
	for track_id: String in required_music_ids():
		if music_track(track_id).is_empty():
			missing.append(track_id)
	return missing


func audio_budget_bytes() -> int:
	return int(required_events.get("max_audio_dir_bytes", 12582912))


# ------------------------------------------------------------------ helpers
func _json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("DataDB: missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("DataDB: %s is not a JSON object" % path)
		return {}
	return parsed
