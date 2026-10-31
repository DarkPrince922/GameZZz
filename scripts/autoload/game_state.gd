extends Node
## Global run state, input map and scene navigation.
## Gameplay reads upgrades from SaveManager through this node so that the rest of
## the code never needs to know about save internals.

signal shards_changed(total: int)
signal run_started(level_id: String)
signal run_finished(level_id: String, stars: int)

const LEVEL_SCENE := "res://scenes/level.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_K],
	"attack": [KEY_J, KEY_X],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"dash": [KEY_SHIFT, KEY_L],
	"pause": [KEY_ESCAPE, KEY_P],
	"crouch": [KEY_CTRL],
}

var pending_level_id: String = "world1_level1"
var current_level_id: String = ""
var current_world: int = 1
var shards_in_run: int = 0
var deaths_in_run: int = 0
var collectibles_found: int = 0
var collectibles_total: int = 0
var last_stars: int = 0
var is_boss_level: bool = false
var enemy_slow: float = 1.0
var stealth: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()


func _register_actions() -> void:
	for action: String in ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


# ------------------------------------------------------------------ abilities
func set_enemy_slow(scale: float) -> void:
	enemy_slow = clampf(scale, 0.1, 1.0)


func set_stealth(enabled: bool) -> void:
	stealth = enabled


func max_hp() -> float:
	var base := float(DataDB.player_tuning().get("max_hp", 100.0))
	var level := SaveManager.upgrade_level("health")
	return base + 10.0 * float(level)


func damage_multiplier() -> float:
	var level := SaveManager.upgrade_level("damage")
	return 1.0 + 0.08 * float(level)


func speed_multiplier() -> float:
	var level := SaveManager.upgrade_level("speed")
	return 1.0 + 0.05 * float(level)


func has_double_jump() -> bool:
	return SaveManager.upgrade_level("ability_double_jump") >= 1


func has_dash() -> bool:
	return SaveManager.upgrade_level("ability_dash") >= 1


func equipped_weapon() -> Dictionary:
	return DataDB.weapon(SaveManager.equipped_weapon())


func equipped_skills() -> Array:
	var loaded: Array = []
	for skill_id: Variant in SaveManager.equipped_skills():
		var entry := DataDB.skill(str(skill_id))
		if not entry.is_empty():
			loaded.append({"id": str(skill_id), "data": entry})
	return loaded


# ------------------------------------------------------------------- run flow
func begin_run(level_id: String) -> void:
	pending_level_id = level_id
	current_level_id = level_id
	var level := DataDB.level(level_id)
	current_world = int(level.get("world", 1))
	is_boss_level = not str(level.get("boss", "")).is_empty()
	shards_in_run = 0
	deaths_in_run = 0
	collectibles_found = 0
	var shards: Array = level.get("shards", [])
	collectibles_total = shards.size() + (level.get("chests", []) as Array).size()
	run_started.emit(level_id)


func collect_shard(amount: int = 1) -> void:
	shards_in_run += amount
	collectibles_found += 1
	SaveManager.add_shards(amount)
	shards_changed.emit(SaveManager.shards())


func note_death() -> void:
	deaths_in_run += 1
	SaveManager.add_death()


func finish_level(cleared: bool = true) -> int:
	var level := DataDB.level(current_level_id)
	var conditions: Dictionary = level.get("star_conditions", {})
	var collected_all := collectibles_total == 0 or collectibles_found >= collectibles_total
	var no_deaths := deaths_in_run == 0
	var stars := 0
	if cleared:
		stars = 1
		if bool(conditions.get("collect_all", true)) and collected_all:
			stars += 1
		if bool(conditions.get("no_deaths", true)) and no_deaths:
			stars += 1
		SaveManager.set_level_stars(current_level_id, stars)
		SaveManager.add_win()
		_unlock_next(level)
	last_stars = stars
	run_finished.emit(current_level_id, stars)
	return stars


func _unlock_next(level: Dictionary) -> void:
	var world_number := int(level.get("world", 1))
	var ids: Array = DataDB.level_ids_for_world(world_number)
	var index := ids.find(current_level_id)
	if index >= 0 and index + 1 < ids.size():
		SaveManager.unlock_level(str(ids[index + 1]))
	elif index == ids.size() - 1:
		var boss_level := str(DataDB.world(world_number).get("boss_level", ""))
		if boss_level != "":
			SaveManager.unlock_level(boss_level)


func complete_boss(world_number: int) -> void:
	SaveManager.unlock_world(world_number + 1)
	for next_level: Variant in DataDB.level_ids_for_world(world_number + 1):
		SaveManager.unlock_level(str(next_level))


# ---------------------------------------------------------------- navigation
func goto_level(level_id: String) -> void:
	pending_level_id = level_id
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func goto_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func goto_menu_scene(path: String) -> void:
	get_tree().paused = false
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.set_paused(false)
	get_tree().change_scene_to_file(path)


func next_level_after(level_id: String) -> String:
	var level := DataDB.level(level_id)
	var ids: Array = DataDB.level_ids_for_world(int(level.get("world", 1)))
	var index := ids.find(level_id)
	if index >= 0 and index + 1 < ids.size():
		return str(ids[index + 1])
	return ""
