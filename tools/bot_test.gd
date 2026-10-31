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

var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Settings.set_value("difficulty", "easy")
	for level_id: String in DataDB.level_ids_for_world(1):
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
	Game.pending_level_id = level_id
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
	var frames := 0
	var max_frames := MAX_SECONDS_PER_LEVEL * PHYSICS_FPS
	var stuck_frames := 0
	var last_x: float = player.position.x
	while frames < max_frames:
		player.set_move_axis(1.0)
		if player.is_on_floor():
			if absf(player.velocity.x) < 30.0:
				stuck_frames += 1
				if stuck_frames > 6:
					player.press_jump()
					stuck_frames = 0
			else:
				stuck_frames = 0
		if frames % 10 == 0:
			player.press_attack()
		if frames % 45 == 0 and player.is_on_floor():
			player.press_jump()
		if player.position.y > float(int(level.level_data.get("height", 14)) * 32 + 600):
			_failures.append("%s: bot fell out of the world" % level_id)
			level.queue_free()
			await process_frame
			return
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


func _run_boss(level_id: String) -> void:
	var level = await _spawn_level(level_id)
	var player = _make_bot_player(level)
	var boss = level.boss
	if boss == null:
		_failures.append("boss level spawned no boss")
		level.queue_free()
		await process_frame
		return
	var frames := 0
	var max_frames := MAX_SECONDS_PER_BOSS * PHYSICS_FPS
	while frames < max_frames:
		var dx: float = boss.global_position.x - player.position.x
		player.set_move_axis(signf(dx) if absf(dx) > 70.0 else 0.0)
		if absf(dx) > 40.0 and player.is_on_floor() and frames % 30 == 0:
			player.press_jump()
		if frames % 8 == 0:
			player.press_attack()
		if frames % 240 == 0:
			player.press_skill(0)
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
