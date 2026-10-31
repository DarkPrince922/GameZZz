extends Control
## Settings: three volume sliders (master / music / effects), button size and
## opacity, vibration, language and difficulty. Everything is saved immediately.

signal closed()

const Theme := preload("res://scripts/ui/ui_theme.gd")

var _rows: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.09, 0.96)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_build()


func _build() -> void:
	var view := get_viewport_rect().size
	var x := view.x / 2.0 - 220.0
	var title := Theme.make_label(self, Loc.text("settings"), Vector2(x, 40.0), 40)
	title.add_theme_color_override("font_color", Theme.ACCENT)
	var y := 110.0
	y = _add_slider(Loc.text("master_volume"), "master_volume", x, y)
	y = _add_slider(Loc.text("music_volume"), "music_volume", x, y)
	y = _add_slider(Loc.text("sfx_volume"), "sfx_volume", x, y)
	y = _add_slider(Loc.text("button_scale"), "button_scale", x, y, 0.6, 1.6)
	y = _add_slider(Loc.text("button_opacity"), "button_opacity", x, y, 0.15, 1.0)
	var vibration := Theme.make_button(self,
			"%s: %s" % [Loc.text("vibration"), Loc.text("on") if Settings.vibration else Loc.text("off")],
			Vector2(x, y), Vector2(300, 52))
	vibration.pressed.connect(_toggle_vibration)
	_rows["vibration"] = vibration
	var language := Theme.make_button(self, "%s: %s" % [Loc.text("language"),
			Settings.language.to_upper()], Vector2(x + 320.0, y), Vector2(160, 52))
	language.pressed.connect(_toggle_language)
	y += 70.0
	var difficulty := Theme.make_button(self, "%s: %s" % [Loc.text("difficulty"),
			Loc.text("difficulty_%s" % Settings.difficulty)], Vector2(x, y), Vector2(300, 52))
	difficulty.pressed.connect(_cycle_difficulty)
	var close := Theme.make_button(self, Loc.text("back"),
			Vector2(x, minf(y + 80.0, view.y - 90.0)), Vector2(200, 56))
	close.pressed.connect(func() -> void: closed.emit())


func _add_slider(label_text: String, key: String, x: float, y: float,
		minimum: float = 0.0, maximum: float = 1.0) -> float:
	var label := Theme.make_label(self, label_text, Vector2(x, y), 22)
	label.add_theme_color_override("font_color", Theme.MUTED)
	var value: float = float(Settings.get_value(key))
	var slider := Theme.make_slider(self, Vector2(x, y + 30.0), value, 480.0)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void:
		Settings.set_value(key, new_value)
		AudioManager.play("ui_toggle")
		label.text = "%s  %d%%" % [label_text, int(round(new_value * 100.0))]
	)
	label.text = "%s  %d%%" % [label_text, int(round(value * 100.0))]
	_rows[key] = {"label": label, "slider": slider}
	return y + 76.0


func _toggle_vibration() -> void:
	Settings.set_value("vibration", not Settings.vibration)
	_rows["vibration"].text = "%s: %s" % [Loc.text("vibration"),
			Loc.text("on") if Settings.vibration else Loc.text("off")]
	AudioManager.play("ui_toggle")


func _toggle_language() -> void:
	var next_language := "en" if Settings.language == "ru" else "ru"
	Settings.set_language(next_language)
	Loc.set_language(next_language)
	AudioManager.play("ui_toggle")
	closed.emit()


func _cycle_difficulty() -> void:
	var order := ["easy", "normal", "nightmare"]
	var index := order.find(Settings.difficulty)
	Settings.set_value("difficulty", order[(index + 1) % order.size()])
	AudioManager.play("ui_toggle")
