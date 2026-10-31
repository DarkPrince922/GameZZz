extends Control
## Main menu: play, level select, shelter, equipment, settings. Offline only.

const Theme := preload("res://scripts/ui/ui_theme.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")

var _settings: Control
var _shards_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Theme.background(self)
	AudioManager.set_paused(false)
	AudioManager.play_music("music_menu")
	AudioManager.stop_ambience()
	_build()


func _build() -> void:
	for child: Node in get_children():
		if child is Label or child is Button or child.name == "MenuColumn":
			child.queue_free()
	var view := get_viewport_rect().size
	var title := Theme.make_label(self, Loc.text("game_title"),
			Vector2(view.x / 2.0 - 230.0, 70.0), 56)
	title.add_theme_color_override("font_color", Theme.ACCENT)
	Theme.make_label(self, Loc.text("tagline"), Vector2(view.x / 2.0 - 220.0, 140.0), 22,
			Theme.MUTED)
	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.position = Vector2(view.x / 2.0 - 150.0, 200.0)
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var play := _add_menu_button(column, Loc.text("play"))
	play.pressed.connect(_on_play)
	var levels := _add_menu_button(column, Loc.text("levels"))
	levels.pressed.connect(func() -> void: Game.goto_menu_scene("res://scenes/level_select.tscn"))
	var shelter := _add_menu_button(column, Loc.text("shelter"))
	shelter.pressed.connect(func() -> void: Game.goto_menu_scene("res://scenes/shelter.tscn"))
	var equip := _add_menu_button(column, Loc.text("equip"))
	equip.pressed.connect(func() -> void: Game.goto_menu_scene("res://scenes/equip.tscn"))
	var settings := _add_menu_button(column, Loc.text("settings"))
	settings.pressed.connect(_open_settings)
	_shards_label = Theme.make_label(self,
			"%s: %d" % [Loc.text("shards"), SaveManager.shards()],
			Vector2(view.x - 320.0, 40.0), 24, Color(0.8, 0.92, 1.0))
	Theme.make_label(self, "v%s" % ProjectSettings.get_setting("application/config/version", "0.1"),
			Vector2(24.0, view.y - 40.0), 18, Theme.MUTED)


func _add_menu_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 58)
	button.add_theme_font_size_override("font_size", 26)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: AudioManager.play("ui_click"))
	parent.add_child(button)
	return button


func _on_play() -> void:
	var level_id := _next_playable_level()
	Game.goto_level(level_id)


func _next_playable_level() -> String:
	var unlocked: Array = SaveManager.data.get("unlocked_levels", ["world1_level1"])
	if unlocked.is_empty():
		return "world1_level1"
	return str(unlocked[unlocked.size() - 1])


func _open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
	_settings = SettingsMenu.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings)
	if _settings.has_signal("closed"):
		_settings.connect("closed", func() -> void:
			_settings.queue_free()
			_build()
		)
