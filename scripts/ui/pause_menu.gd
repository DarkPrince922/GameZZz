extends Control
## Pause overlay: keeps running while the tree is paused, darkens the game,
## offers resume, settings and main menu.

signal resume_requested()
signal menu_requested()

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")

var _settings: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _unhandled_input(event: InputEvent) -> void:
	## This node is PROCESS_MODE_ALWAYS so it can unpause the tree; the level
	## (pausable) cannot receive input while paused.
	if not visible:
		return
	if event.is_action_pressed("pause"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.06, 0.85)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var view := get_viewport_rect().size
	var title := UITheme.make_label(self, Loc.text("pause"), Vector2(view.x / 2.0 - 60.0, 120.0), 48)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	var resume := UITheme.make_button(self, Loc.text("resume"), Vector2(view.x / 2.0 - 140.0, 220.0))
	resume.pressed.connect(func() -> void: resume_requested.emit())
	var settings := UITheme.make_button(self, Loc.text("settings"),
			Vector2(view.x / 2.0 - 140.0, 300.0))
	settings.pressed.connect(_open_settings)
	var menu := UITheme.make_button(self, Loc.text("quit_to_menu"),
			Vector2(view.x / 2.0 - 140.0, 380.0))
	menu.pressed.connect(func() -> void: menu_requested.emit())


func _open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		_settings.queue_free()
	_settings = SettingsMenu.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings)
	if _settings.has_signal("closed"):
		_settings.connect("closed", func() -> void: _settings.queue_free())
