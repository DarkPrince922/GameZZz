extends Node2D
## Builds a playable level from data/levels/<id>.json:
## geometry, platforms, ladders, traps, enemies, pickups, boss, HUD and touch UI.
## One script, one job: turn data into a scene and report the outcome.

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BossScene := preload("res://scenes/boss.tscn")
const SpikeTrap := preload("res://scripts/traps/spike_trap.gd")
const FallingPlatform := preload("res://scripts/traps/falling_platform.gd")
const LaserTrap := preload("res://scripts/traps/laser_trap.gd")
const MovingWall := preload("res://scripts/traps/moving_wall.gd")
const DreamShard := preload("res://scripts/pickups/dream_shard.gd")
const Chest := preload("res://scripts/pickups/chest.gd")
const Checkpoint := preload("res://scripts/pickups/checkpoint.gd")
const GoalDoor := preload("res://scripts/pickups/goal_door.gd")
const SecretZone := preload("res://scripts/level/secret_zone.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const VictoryScreen := preload("res://scripts/ui/victory_screen.gd")

var level_id: String = ""
var level_data: Dictionary = {}
var tile_size: int = 32
var level_height: int = 14
var world_width: int = 0

var player
var hud
var controls
var pause_menu
var victory
var boss
var _finished: bool = false
var _geometry: Node2D


func _ready() -> void:
	level_id = Game.pending_level_id
	level_data = DataDB.level(level_id)
	if level_data.is_empty():
		push_error("Level: no data for %s" % level_id)
		level_data = DataDB.level("world1_level1")
		level_id = "world1_level1"
	tile_size = int(level_data.get("tile_size", 32))
	level_height = int(level_data.get("height", 14))
	Game.begin_run(level_id)
	_build_geometry()
	_build_ladders()
	_build_traps()
	_spawn_player()
	_spawn_enemies()
	_spawn_pickups()
	_spawn_secrets()
	_spawn_boss()
	_build_ui()
	_start_audio()
	_bind_events()


# ---------------------------------------------------------------- geometry
func _expand_ground() -> Array:
	var columns: Array = []
	for run: Variant in level_data.get("ground_runs", []):
		var pair: Array = run
		var ground_row := int(pair[0])
		var count := int(pair[1])
		for i in count:
			columns.append(ground_row)
	world_width = columns.size()
	return columns


func _build_geometry() -> void:
	_geometry = Node2D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)
	var columns := _expand_ground()
	var index := 0
	while index < columns.size():
		var row := int(columns[index])
		if row <= 0:
			index += 1
			continue
		var run_end := index
		while run_end < columns.size() and int(columns[run_end]) == row:
			run_end += 1
		var count := run_end - index
		_add_solid(Rect2(float(index * tile_size), float(row * tile_size),
				float(count * tile_size), float((level_height - row) * tile_size)))
		index = run_end
	for platform: Variant in level_data.get("platforms", []):
		var p: Dictionary = platform
		var width := float(int(p.get("w", 3)) * tile_size)
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(width, 12.0)
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2(float(int(p.get("x", 0)) * tile_size) + width / 2.0,
				float(int(p.get("y", 6)) * tile_size))
		shape.one_way_collision = bool(p.get("one_way", true))
		_geometry.add_child(body)


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	body.position = rect.position + rect.size / 2.0
	var visual := ColorRect.new()
	visual.color = Color(0.16, 0.15, 0.24)
	visual.size = rect.size
	visual.position = -rect.size / 2.0
	body.add_child(visual)
	_geometry.add_child(body)


func _build_ladders() -> void:
	for ladder: Variant in level_data.get("ladders", []):
		var l: Dictionary = ladder
		var x := float(int(l.get("x", 0)) * tile_size) + tile_size / 2.0
		var top := int(l.get("top", 4))
		var bottom := int(l.get("bottom", 8))
		var height := float((bottom - top) * tile_size)
		var area := Area2D.new()
		area.add_to_group("ladders")
		area.position = Vector2(x, float(top * tile_size) + height / 2.0)
		area.set_meta("size", Vector2(tile_size * 0.8, height))
		area.monitoring = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tile_size * 0.8, height)
		shape.shape = rect
		area.add_child(shape)
		var visual := ColorRect.new()
		visual.color = Color(0.5, 0.42, 0.3, 0.7)
		visual.size = Vector2(8.0, height)
		visual.position = Vector2(-4.0, -height / 2.0)
		area.add_child(visual)
		add_child(area)


func _build_traps() -> void:
	for spike: Variant in level_data.get("spikes", []):
		var s: Dictionary = spike
		var trap := SpikeTrap.new()
		trap.setup({
			"w": int(s.get("w", 2)),
			"tile_size": tile_size,
			"position": Vector2(float(int(s.get("x", 0)) * tile_size)
					+ float(int(s.get("w", 2)) * tile_size) / 2.0,
					float(int(s.get("y", 10)) * tile_size)),
		})
		add_child(trap)
	for trap_data: Variant in level_data.get("traps", []):
		var t: Dictionary = trap_data
		var kind := str(t.get("type", ""))
		var pos := Vector2(float(int(t.get("x", 0)) * tile_size) + tile_size / 2.0,
				float(int(t.get("y", 6)) * tile_size))
		match kind:
			"falling_platform":
				var platform := FallingPlatform.new()
				platform.setup({"tile_size": tile_size, "w": int(t.get("w", 3)),
						"position": pos})
				add_child(platform)
			"laser":
				var laser := LaserTrap.new()
				laser.setup({"tile_size": tile_size, "w": int(t.get("w", 3)),
						"position": pos})
				add_child(laser)
			"moving_wall":
				var wall := MovingWall.new()
				wall.setup({"tile_size": tile_size, "h": int(t.get("h", 4)),
						"position": pos})
				add_child(wall)
			"spikes":
				var extra := SpikeTrap.new()
				extra.setup({"w": int(t.get("w", 2)), "tile_size": tile_size,
						"position": Vector2(pos.x + float(int(t.get("w", 2)) * tile_size) / 2.0,
								pos.y)})
				add_child(extra)
			_:
				print("WARNING: ", "Level: unknown trap type %s" % kind)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	var spawn: Array = level_data.get("spawn", [2, 11])
	player.position = Vector2(float(int(spawn[0]) * tile_size) + tile_size / 2.0,
			float(int(spawn[1]) * tile_size) - 24.0)
	add_child(player)
	player.set_checkpoint(player.position)
	var camera: Camera2D = player.camera()
	if camera != null:
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = maxi(world_width, 30) * tile_size
		camera.limit_bottom = level_height * tile_size


func _spawn_enemies() -> void:
	for enemy_data: Variant in level_data.get("enemies", []):
		var e: Dictionary = enemy_data
		var enemy = EnemyScene.instantiate()
		enemy.position = Vector2(float(int(e.get("x", 0)) * tile_size) + tile_size / 2.0,
				float(int(e.get("y", 10)) * tile_size))
		# add first: configure() reads autoloads, which need the node in the tree
		add_child(enemy)
		enemy.configure(str(e.get("type", "shadow")), str(e.get("elite", "")))


func _spawn_pickups() -> void:
	for shard_data: Variant in level_data.get("shards", []):
		var pair: Array = shard_data
		var shard := DreamShard.new()
		shard.position = Vector2(float(int(pair[0]) * tile_size) + tile_size / 2.0,
				float(int(pair[1]) * tile_size) - 18.0)
		add_child(shard)
	for chest_data: Variant in level_data.get("chests", []):
		var pair: Array = chest_data
		var chest := Chest.new()
		chest.position = Vector2(float(int(pair[0]) * tile_size) + tile_size / 2.0,
				float(int(pair[1]) * tile_size) - 4.0)
		add_child(chest)
	for checkpoint_data: Variant in level_data.get("checkpoints", []):
		var pair: Array = checkpoint_data
		var checkpoint := Checkpoint.new()
		checkpoint.position = Vector2(float(int(pair[0]) * tile_size) + tile_size / 2.0,
				float(int(pair[1]) * tile_size) - 4.0)
		add_child(checkpoint)
	if level_data.has("goal"):
		var goal := GoalDoor.new()
		var goal_pair: Array = level_data["goal"]
		goal.position = Vector2(float(int(goal_pair[0]) * tile_size) + tile_size / 2.0,
				float(int(goal_pair[1]) * tile_size) - 4.0)
		goal.reached.connect(_on_goal_reached)
		add_child(goal)


func _spawn_secrets() -> void:
	for secret_data: Variant in level_data.get("secrets", []):
		var s: Dictionary = secret_data
		var zone := SecretZone.new()
		zone.setup({
			"w": int(s.get("w", 3)), "h": int(s.get("h", 3)),
			"position": Vector2(float(int(s.get("x", 0)) * tile_size) + tile_size / 2.0,
					float(int(s.get("y", 6)) * tile_size) + tile_size / 2.0),
		})
		add_child(zone)


func _spawn_boss() -> void:
	var boss_id := str(level_data.get("boss", ""))
	if boss_id == "":
		return
	boss = BossScene.instantiate()
	var arena_center := float(maxi(world_width, 30)) * tile_size * 0.62
	boss.position = Vector2(arena_center, float((level_height - 3) * tile_size))
	add_child(boss)
	boss.configure(boss_id)
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died)


func _build_ui() -> void:
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	controls = TouchControls.new()
	controls.name = "TouchControls"
	add_child(controls)
	controls.bind_player(player)
	hud.bind_player(player)
	controls.pause_requested.connect(_open_pause)
	if boss != null and hud.has_method("bind_boss"):
		hud.bind_boss(boss)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.hide()
	pause_menu.resume_requested.connect(_close_pause)
	pause_menu.menu_requested.connect(_go_menu)


func _start_audio() -> void:
	var music := str(level_data.get("music", "music_world_1"))
	AudioManager.play_music(music)
	var ambience := str(level_data.get("ambient", ""))
	if ambience != "":
		AudioManager.play_ambience(ambience)
	AudioManager.play("ui_level_start")


func _bind_events() -> void:
	if player.has_signal("died"):
		player.died.connect(_on_player_died)
	if player.has_signal("respawned"):
		player.respawned.connect(_on_player_respawned)


# ------------------------------------------------------------------ events
func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or _finished:
		return
	var bottom := float(level_height * tile_size) + float(tile_size) * 3.0
	if player.global_position.y > bottom:
		player.fall_into_pit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_close_pause()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	if _finished:
		return
	get_tree().paused = true
	AudioManager.set_paused(true)
	AudioManager.play("ui_pause")
	pause_menu.show()


func _close_pause() -> void:
	pause_menu.hide()
	get_tree().paused = false
	AudioManager.set_paused(false)


func _go_menu() -> void:
	get_tree().paused = false
	AudioManager.set_paused(false)
	AudioManager.stop_ambience()
	Game.goto_menu()


func _on_player_died() -> void:
	if hud != null:
		hud.flash_death()


func _on_player_respawned() -> void:
	pass


func _on_goal_reached() -> void:
	_finish(true)


func is_finished() -> bool:
	return _finished


func _on_boss_died() -> void:
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.unlock_achievement("achievement_boss_1")
	Game.complete_boss(int(level_data.get("world", 1)))
	# let the death sound and the victory line finish before the star screen
	await get_tree().create_timer(1.6).timeout
	_finish(true)


func _finish(cleared: bool) -> void:
	if _finished:
		return
	_finished = true
	var stars := Game.finish_level(cleared)
	if stars >= 3:
		AudioManager.play("ui_achievement")
	victory = VictoryScreen.new()
	victory.name = "Victory"
	add_child(victory)
	victory.setup({
		"level_id": level_id,
		"stars": stars,
		"shards": Game.shards_in_run,
		"deaths": Game.deaths_in_run,
		"collected": Game.collectibles_found,
		"total": Game.collectibles_total,
	})
	victory.continue_requested.connect(_on_victory_continue)
	victory.menu_requested.connect(_go_menu)
	get_tree().paused = true
	AudioManager.set_paused(true)
	if cleared:
		AudioManager.play_music("music_victory", 0.5)


func _on_victory_continue() -> void:
	get_tree().paused = false
	AudioManager.set_paused(false)
	AudioManager.stop_ambience()
	var next := Game.next_level_after(level_id)
	if next == "":
		Game.goto_menu()
	else:
		Game.goto_level(next)
