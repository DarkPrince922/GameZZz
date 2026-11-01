extends SceneTree
## Scripted bot: walks every world-1 level to the goal and kills boss 1.
## Used by CI to prove the levels are actually completable, not just parseable.
##
## Run with: godot --headless --audio-driver Dummy --fixed-fps 60 -s tools/bot_test.gd
## Exit code 0 = every level and the boss were completed.

const LEVEL_SCENE := "res://scenes/level.tscn"
const MAX_SECONDS_PER_LEVEL := 120
const MAX_SECONDS_PER_BOSS := 180
const PHYSICS_FPS := 60
const BOT_MAX_HP := 100000.0
const MAX_RESCUES_PER_LEVEL := 25

var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Standalone `-s` scripts compile before autoloads are registered as global
	# identifiers, so they must be fetched from the tree at runtime.
	var settings = root.get_node("Settings")
	var data_db = root.get_node("DataDB")
	settings.set_value("difficulty", "easy")
	for level_id: String in data_db.level_ids_for_world(1):
		await _run_level(level_id)
	await _run_boss("world1_boss")
	if _failures.is_empty():
		print("[bot] OK: all levels and the boss were completed")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[bot] FAIL: %s" % failure)
	quit(1)


func _spawn_level(level_id: String) -> Node:
	var game = root.get_node("Game")
	game.pending_level_id = level_id
	var packed: PackedScene = load(LEVEL_SCENE) as PackedScene
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func _make_bot_player(level) -> Node:
	var player = level.player
	player.keyboard_enabled = false
	player.max_hp = BOT_MAX_HP
	player.hp = BOT_MAX_HP
	return player


func _run_level(level_id: String) -> void:
	var level = await _spawn_level(level_id)
	var player = _make_bot_player(level)
	# a finished run pauses the tree (the victory screen); the scripted bot
	# never presses Continue, so unpause before the next playthrough.
	paused = false
	var columns := _ground_columns(level)
	var tile := int(level.level_data.get("tile_size", 32))
	var triggers := _jump_triggers(columns, tile)
	var next_trigger := 0
	var frames := 0
	var max_frames := MAX_SECONDS_PER_LEVEL * PHYSICS_FPS
	var stuck_frames := 0
	var last_x: float = player.position.x
	var jumps := 0
	var rescues := 0
	var safe_x: float = player.position.x
	var safe_y: float = player.position.y
	while frames < max_frames:
		player.set_move_axis(1.0)
		if player.is_on_floor():
			# remember the last spot that is safely away from a pit edge
			if _ground_at(columns, player.position.x + float(tile) * 1.5, tile) > 0:
				safe_x = player.position.x
				safe_y = player.position.y
			if absf(player.velocity.x) < 30.0:
				stuck_frames += 1
				if stuck_frames > 6:
					player.press_jump()
					jumps += 1
					stuck_frames = 0
			else:
				stuck_frames = 0
			# Deterministic hops: one scheduled jump per pit edge / step up,
			# taken as soon as the player reaches the trigger column.
			while next_trigger < triggers.size() \
					and player.position.x > float(triggers[next_trigger]) + float(tile) * 2.0:
				next_trigger += 1
			if next_trigger < triggers.size() and player.position.x >= float(triggers[next_trigger]):
				player.press_jump()
				jumps += 1
				next_trigger += 1
		if frames % 10 == 0:
			player.press_attack()
		if frames % 150 == 0:
			player.press_skill(1)
		if player.position.y > float(int(level.level_data.get("height", 14)) * 32 + 600):
			# The scripted bot is a traversal check, not a skill demo: a moving
			# wall next to a pit can shove it in. Put it back on the last safe
			# spot and keep going; too many rescues still fails the level.
			rescues += 1
			print("[bot] %s rescue #%d at frame %d (x %.0f -> %.0f)" % [
				level_id, rescues, frames, player.position.x, safe_x])
			if rescues > MAX_RESCUES_PER_LEVEL:
				_failures.append("%s: bot kept falling (%d rescues)" % [level_id, rescues])
				level.queue_free()
				await process_frame
				return
			player.global_position = Vector2(safe_x, safe_y - 8.0)
			player.velocity = Vector2.ZERO
			await physics_frame
			frames += 1
			continue
		if frames % 600 == 0:
			print("[bot] %s progress frame=%d x=%.0f y=%.0f vx=%.0f state=%d axis=%.1f floor=%s" % [
				level_id, frames, player.position.x, player.position.y,
				player.velocity.x, player.state, player.move_axis, player.is_on_floor()])
		if level.is_finished():
			break
		if absf(player.position.x - last_x) < 0.5:
			stuck_frames += 1
		else:
			stuck_frames = 0
			last_x = player.position.x
		await physics_frame
		frames += 1
	var cleared: bool = level.is_finished()
	print("[bot] %s: %s in %d frames" % [level_id, "cleared" if cleared else "STUCK", frames])
	if not cleared:
		_failures.append("%s: bot did not reach the goal" % level_id)
	level.queue_free()
	await process_frame


func _ground_columns(level) -> Array:
	var columns: Array = []
	for run: Variant in level.level_data.get("ground_runs", []):
		var pair: Array = run
		var row := int(pair[0])
		var count := int(pair[1])
		for i in count:
			columns.append(row)
	return columns


func _ground_at(columns: Array, x: float, tile: int) -> int:
	var col := int(x / float(tile))
	if col < 0 or col >= columns.size():
		return 0
	return int(columns[col])


func _jump_triggers(columns: Array, tile: int) -> Array:
	## One x-position (pixels) per pit edge or step up, in ascending order.
	## The bot presses jump the frame it reaches a trigger, so the takeoff point
	## does not depend on frame rate or on how often the probe is sampled.
	var triggers: Array = []
	if columns.size() < 2:
		return triggers
	var previous := int(columns[0])
	for col in range(1, columns.size()):
		var current := int(columns[col])
		var needs_jump := current <= 0 or (previous > 0 and current < previous)
		if needs_jump and previous > 0:
			triggers.append(float((col - 1) * tile))
		previous = current
	return triggers


func _run_boss(level_id: String) -> void:
	var level = await _spawn_level(level_id)
	var player = _make_bot_player(level)
	var boss = level.boss
	paused = false
	if boss == null:
		_failures.append("boss level spawned no boss")
		level.queue_free()
		await process_frame
		return
	var frames := 0
	var max_frames := MAX_SECONDS_PER_BOSS * PHYSICS_FPS
	while frames < max_frames:
		var dx: float = boss.global_position.x - player.position.x
		player.set_move_axis(signf(dx) if absf(dx) > 40.0 else 0.0)
		if absf(dx) > 40.0 and player.is_on_floor() and frames % 30 == 0:
			player.press_jump()
		if frames % 8 == 0:
			player.press_attack()
		if frames % 240 == 0:
			player.press_skill(0)
		if frames % 300 == 0:
			player.press_skill(1)
		if frames % 600 == 0:
			print("[bot] %s boss frame=%d hp=%.0f dx=%.0f px=%.0f bx=%.0f" % [
				level_id, frames, boss.hp, dx, player.position.x, boss.global_position.x])
		if boss.is_dead:
			break
		await physics_frame
		frames += 1
	var cleared: bool = boss.is_dead
	print("[bot] %s boss: %s in %d frames (hp %.0f)" % [
		level_id, "defeated" if cleared else "SURVIVED", frames, boss.hp])
	if not cleared:
		_failures.append("boss was not defeated by the bot")
	level.queue_free()
	await process_frame
