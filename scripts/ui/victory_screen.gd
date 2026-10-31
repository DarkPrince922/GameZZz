extends Control
## Star screen after a level: stars appear one by one with their own sound.

signal continue_requested()
signal menu_requested()

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _stats: Dictionary = {}
var _stars_shown: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.03, 0.08, 0.92)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	set_process(true)


func setup(stats: Dictionary) -> void:
	_stats = stats
	_build()


func _build() -> void:
	var view := get_viewport_rect().size
	_stats.get("stars", 0)
	var title := UITheme.make_label(self, Loc.text("level_complete"),
			Vector2(view.x / 2.0 - 200.0, 90.0), 44)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	var level_name := Loc.text(str(_stats.get("level_id", "")))
	UITheme.make_label(self, level_name, Vector2(view.x / 2.0 - 160.0, 150.0), 26, UITheme.MUTED)
	var stars_row := HBoxContainer.new()
	stars_row.position = Vector2(view.x / 2.0 - 120.0, 200.0)
	stars_row.add_theme_constant_override("separation", 20)
	add_child(stars_row)
	var total_stars := int(_stats.get("stars", 0))
	for i in 3:
		var star := Label.new()
		star.text = "★" if i < total_stars else "☆"
		star.add_theme_font_size_override("font_size", 56)
		star.add_theme_color_override("font_color",
				UITheme.ACCENT if i < total_stars else UITheme.MUTED)
		stars_row.add_child(star)
	var details := "%s: %d/%d    %s: %d    %s: %d" % [
		Loc.text("collectibles"), int(_stats.get("collected", 0)), int(_stats.get("total", 0)),
		Loc.text("deaths"), int(_stats.get("deaths", 0)),
		Loc.text("shards"), int(_stats.get("shards", 0)),
	]
	UITheme.make_label(self, details, Vector2(view.x / 2.0 - 280.0, 300.0), 22, UITheme.MUTED)
	var cont := UITheme.make_button(self, Loc.text("next_level"),
			Vector2(view.x / 2.0 - 140.0, 380.0))
	cont.pressed.connect(func() -> void: continue_requested.emit())
	var menu := UITheme.make_button(self, Loc.text("quit_to_menu"),
			Vector2(view.x / 2.0 - 140.0, 460.0))
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_animate_stars(total_stars)


func _animate_stars(total: int) -> void:
	for i in total:
		var timer := get_tree().create_timer(0.45 * float(i) + 0.2)
		timer.timeout.connect(_play_star)


func _play_star() -> void:
	_stars_shown += 1
	AudioManager.play("ui_star", 1.0 + 0.06 * float(_stars_shown))


func stars_shown() -> int:
	return _stars_shown
