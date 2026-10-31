extends Control
## Level select: worlds on the left, levels + boss on the right, stars per level.
## Locked worlds say so honestly instead of pretending to have content.

const Theme := preload("res://scripts/ui/ui_theme.gd")

var _content: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Theme.background(self)
	AudioManager.play_music("music_menu")
	var view := get_viewport_rect().size
	var title := Theme.make_label(self, Loc.text("levels"), Vector2(60.0, 40.0), 42)
	title.add_theme_color_override("font_color", Theme.ACCENT)
	_content = VBoxContainer.new()
	_content.position = Vector2(60.0, 120.0)
	_content.custom_minimum_size = Vector2(view.x - 120.0, view.y - 220.0)
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)
	var back := Theme.make_button(self, Loc.text("back"), Vector2(60.0, view.y - 80.0),
			Vector2(200, 54))
	back.pressed.connect(func() -> void: Game.goto_menu())
	_populate()


func _populate() -> void:
	for world_number: int in DataDB.world_numbers():
		var world := DataDB.world(world_number)
		var unlocked := SaveManager.is_world_unlocked(world_number)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 16)
		var world_label := Label.new()
		world_label.text = "%d. %s" % [world_number, Loc.text(str(world.get("name_key", "")))]
		world_label.add_theme_font_size_override("font_size", 26)
		world_label.add_theme_color_override("font_color", Theme.ACCENT if unlocked else Theme.MUTED)
		header.add_child(world_label)
		var subtitle := Label.new()
		subtitle.text = Loc.text(str(world.get("subtitle_key", "")))
		subtitle.add_theme_font_size_override("font_size", 18)
		subtitle.add_theme_color_override("font_color", Theme.MUTED)
		header.add_child(subtitle)
		_content.add_child(header)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_content.add_child(row)
		var level_ids: Array = world.get("levels", [])
		if level_ids.is_empty():
			var locked := Label.new()
			locked.text = Loc.text(str("locked")) + " — " + Loc.text("loading")
			locked.add_theme_color_override("font_color", Theme.MUTED)
			row.add_child(locked)
			continue
		for level_id: Variant in level_ids:
			row.add_child(_level_button(str(level_id), unlocked))
		var boss_level := str(world.get("boss_level", ""))
		if boss_level != "":
			row.add_child(_level_button(boss_level, unlocked, true))


func _level_button(level_id: String, world_unlocked: bool, is_boss: bool = false) -> Button:
	var button := Button.new()
	var unlocked := world_unlocked and SaveManager.is_level_unlocked(level_id)
	var stars := SaveManager.level_stars(level_id)
	var name := Loc.text("boss") if is_boss else Loc.text(level_id)
	button.text = "%s\n%s" % [name, "★".repeat(stars) + "☆".repeat(3 - stars)]
	button.custom_minimum_size = Vector2(190, 84)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	if unlocked:
		button.pressed.connect(func() -> void:
			AudioManager.play("ui_click")
			Game.goto_level(level_id)
		)
	else:
		button.text = "%s\n%s" % [name, Loc.text("locked")]
	return button
