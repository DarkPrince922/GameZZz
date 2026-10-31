extends SceneTree
## Headless smoke test: loads every scene in scenes/ and every level, runs 60
## frames each and fails on a crash, an empty instance or a level that dies.
##
## Run with:  godot --headless --audio-driver Dummy -s tools/smoke_test.gd
## CI additionally greps the log for ERROR/SCRIPT ERROR lines.

const SCENES_DIR := "res://scenes"
const FRAMES_PER_SCENE := 60

var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenes := _scene_list()
	print("[smoke] scene files: %d" % scenes.size())
	# Standalone `-s` scripts compile before autoloads are registered as global
	# identifiers, so they must be fetched from the tree at runtime.
	var data_db = root.get_node("DataDB")
	var game = root.get_node("Game")
	for path: String in scenes:
		await _check_scene(path)
	for level_id: String in data_db.level_ids():
		game.pending_level_id = level_id
		await _check_scene("res://scenes/level.tscn", " with %s" % level_id)
	print("[smoke] checked %d scene instances" % (scenes.size() + data_db.level_ids().size()))
	if _failures.is_empty():
		print("[smoke] OK")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[smoke] FAIL: %s" % failure)
	quit(1)


func _scene_list() -> Array:
	var scenes: Array = []
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		_failures.append("cannot open %s" % SCENES_DIR)
		return scenes
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			scenes.append(SCENES_DIR + "/" + file_name)
	scenes.sort()
	return scenes


func _check_scene(path: String, suffix: String = "") -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_failures.append("cannot load %s" % path)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		_failures.append("cannot instantiate %s" % path)
		return
	root.add_child(instance)
	for i in FRAMES_PER_SCENE:
		await process_frame
		if not is_instance_valid(instance):
			_failures.append("%s freed itself after %d frames%s" % [path, i, suffix])
			return
	instance.queue_free()
	await process_frame
	print("[smoke] ok: %s%s" % [path, suffix])
