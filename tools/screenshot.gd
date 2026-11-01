extends SceneTree
## Renders key screens to PNG so the appearance can be reviewed from CI
## artifacts. Run under xvfb with a software GL driver (llvmpipe), e.g.:
##
##   xvfb-run -a godot --audio-driver Dummy \
##     --rendering-driver opengl3 -s tools/screenshot.gd -- --out=build/shots
##
## Captures the main menu and every world-1 level (which shows the HUD and the
## touch controls) at three aspect ratios: 16:9, 20:9 and 4:3.

const RESOLUTIONS := [
	{"name": "16x9", "size": Vector2i(1920, 1080)},
	{"name": "20x9", "size": Vector2i(2376, 1080)},
	{"name": "4x3", "size": Vector2i(1600, 1200)},
]

const LEVELS := [
	"world1_level1", "world1_level2", "world1_level3", "world1_level4", "world1_boss",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir := _arg("out", "build/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game = root.get_node("Game")
	var shots := 0
	for res: Dictionary in RESOLUTIONS:
		var size: Vector2i = res["size"]
		root.size = size
		await _capture_scene("res://scenes/main_menu.tscn", out_dir, "menu_%s" % res["name"])
		shots += 1
		for level_id: String in LEVELS:
			game.pending_level_id = level_id
			await _capture_scene("res://scenes/level.tscn", out_dir, "%s_%s" % [level_id, res["name"]])
			shots += 1
	print("[screenshot] captured %d images to %s" % [shots, out_dir])
	quit(0)


func _capture_scene(path: String, out_dir: String, name: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	# give layout, physics and one render a chance to settle
	for i in 4:
		await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var file := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(file)
	if err != OK:
		push_error("screenshot: failed to save %s (%d)" % [file, err])
	else:
		print("[screenshot] %s" % file)
	instance.queue_free()
	await process_frame


func _arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(len("--%s=" % key))
	return default
