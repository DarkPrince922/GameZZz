extends Control
## Virtual stick (left) + jump / attack / dash / skill buttons (right).
##
## True multitouch: every touch index is tracked separately, so running and
## attacking at the same time always works, and releasing a finger always
## clears its action (no stuck presses).
##
## Layout is anchored to the viewport edges (not absolute pixels) and honours
## the display safe area, so nothing is clipped on 20:9 or 4:3 screens. Button
## size and opacity come from Settings and apply immediately.
##
## Buttons call the player's press methods directly (press_jump / press_attack /
## press_dash / press_skill), the same edge-triggered entry points the keyboard
## path ends up in. This avoids `Input.action_press`, whose synthetic presses are
## not seen by `Input.is_action_just_pressed` from a physics frame (the engine
## only advances `pressed_physics_frame` for events parsed through
## `Input.parse_input_event`). The stick is analog and drives the player directly.

signal pause_requested()

const STICK_MAX := 96.0
const STICK_DEAD_ZONE := 0.12
const MIN_BUTTON_DIAMETER := 64.0
const EDGE_PAD := 24.0

## Exposed so layout tests can assert bounds and overlaps without rendering.
var widgets: Dictionary = {}

var player
var _touches: Dictionary = {}
var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vector: Vector2 = Vector2.ZERO
var _font: Font
var _scale: float = 1.0
var _opacity: float = 0.75


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_scale = Settings.button_scale
	_opacity = Settings.button_opacity
	Settings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func bind_player(new_player: Node) -> void:
	player = new_player


func _on_settings_changed(key: String) -> void:
	if key == "button_scale" or key == "button_opacity" or key == "all":
		_scale = Settings.button_scale
		_opacity = Settings.button_opacity
		_layout()


## Safe-area insets in canvas pixels: never less than EDGE_PAD, larger where
## the device has a notch, rounded corners or a gesture bar.
func _safe_insets(view: Vector2) -> Dictionary:
	var insets := {"top": EDGE_PAD, "bottom": EDGE_PAD, "left": EDGE_PAD, "right": EDGE_PAD}
	if DisplayServer.get_name() == "headless":
		return insets
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return insets
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return insets
	var sx := view.x / float(win.x)
	var sy := view.y / float(win.y)
	insets["left"] = maxf(EDGE_PAD, float(safe.position.x) * sx)
	insets["top"] = maxf(EDGE_PAD, float(safe.position.y) * sy)
	insets["right"] = maxf(EDGE_PAD, float(win.x - safe.end.x) * sx)
	insets["bottom"] = maxf(EDGE_PAD, float(win.y - safe.end.y) * sy)
	return insets


func _layout() -> void:
	layout_for(get_viewport().get_visible_rect().size)


## Compute widget geometry for an explicit view size. Kept separate from
## `_layout` so layout tests can pass any resolution deterministically.
func layout_for(view: Vector2) -> void:
	var insets := _safe_insets(view)
	widgets.clear()
	var left := float(insets["left"])
	var right := float(insets["right"])
	var top := float(insets["top"])
	var bottom := float(insets["bottom"])

	# Stick: bottom-left, diameter ~22% of the screen height.
	var stick_radius := clampf(view.y * 0.11, 60.0, 96.0) * _scale
	var stick_center := Vector2(left + stick_radius, view.y - bottom - stick_radius)
	widgets["stick"] = _make_widget(stick_center, stick_radius, "move")

	# Attack and jump: bottom-right, large and easy to hit.
	var attack_radius := clampf(view.y * 0.085, 54.0, 78.0) * _scale
	var jump_radius := clampf(view.y * 0.075, 48.0, 68.0) * _scale
	var attack_center := Vector2(view.x - right - attack_radius, view.y - bottom - attack_radius)
	var jump_center := Vector2(attack_center.x - attack_radius - jump_radius - 16.0 * _scale,
			view.y - bottom - jump_radius)
	widgets["attack"] = _make_widget(attack_center, attack_radius, "attack")
	widgets["jump"] = _make_widget(jump_center, jump_radius, "jump")

	# Dash: above and between the two main buttons.
	var dash_radius := clampf(view.y * 0.052, 38.0, 46.0) * _scale
	var dash_center := Vector2((attack_center.x + jump_center.x) * 0.5,
			attack_center.y - attack_radius - dash_radius - 8.0 * _scale)
	widgets["dash"] = _make_widget(dash_center, dash_radius, "dash")

	# Skills: an arc above the attack/jump cluster, with cooldown arcs.
	var skill_radius := clampf(view.y * 0.048, 36.0, 44.0) * _scale
	var arc_center := Vector2((attack_center.x + jump_center.x) * 0.5,
			dash_center.y - dash_radius - 6.0 * _scale)
	var arc_radius := skill_radius * 2.6 + 16.0 * _scale
	for slot in 3:
		var angle := PI + (slot + 1) * (PI / 4.0)
		var center := arc_center + Vector2(cos(angle), sin(angle) * 0.9) * arc_radius
		widgets["skill_%d" % slot] = _make_widget(center, skill_radius, "skill_%d" % (slot + 1))
		widgets["skill_%d" % slot]["slot"] = slot

	# Pause: top-right corner (>= 64px diameter like every other button).
	var pause_radius := clampf(view.y * 0.042, 32.0, 40.0) * _scale
	widgets["pause"] = _make_widget(Vector2(view.x - right - pause_radius,
			top + pause_radius), pause_radius, "pause")
	queue_redraw()


func _make_widget(center: Vector2, radius: float, action: String) -> Dictionary:
	return {"center": center, "radius": radius, "action": action,
			"rect": Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))}


## Bounding rectangles in canvas coordinates, for layout assertions.
func widget_rects() -> Dictionary:
	var out := {}
	for key: String in widgets.keys():
		out[key] = widgets[key]["rect"]
	return out


func _widget_at(point: Vector2) -> String:
	# small widgets first, the stick last (it is the largest target)
	var keys := ["pause", "skill_0", "skill_1", "skill_2", "dash", "jump", "attack", "stick"]
	for key: String in keys:
		var widget: Dictionary = widgets.get(key, {})
		if widget.is_empty():
			continue
		if widget["rect"].has_point(point):
			return key
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move_touch(drag.index, drag.position)
		accept_event()


func _begin_touch(index: int, position: Vector2) -> void:
	var widget := _widget_at(position)
	if widget == "":
		return
	_touches[index] = widget
	if Settings.vibration:
		Settings.vibrate(12, 0.25)
	match widget:
		"stick":
			_stick_index = index
			_stick_origin = position
			_stick_vector = Vector2.ZERO
			_apply_stick(Vector2.ZERO)
		"pause":
			pause_requested.emit()
		"jump":
			if player != null:
				player.press_jump()
		"attack":
			if player != null:
				player.press_attack()
		"dash":
			if player != null:
				player.press_dash()
		_:
			if widget.begins_with("skill_") and player != null:
				player.press_skill(int(widgets[widget].get("slot", 0)))
	queue_redraw()


func _move_touch(index: int, position: Vector2) -> void:
	if index != _stick_index:
		return
	var offset := position - _stick_origin
	if offset.length() > STICK_MAX:
		offset = offset.normalized() * STICK_MAX
	_apply_stick(offset / STICK_MAX)
	queue_redraw()


func _apply_stick(vector: Vector2) -> void:
	_stick_vector = vector
	if player == null:
		return
	var axis := vector.x if absf(vector.x) > STICK_DEAD_ZONE else 0.0
	var vertical := vector.y if absf(vector.y) > STICK_DEAD_ZONE else 0.0
	player.set_move_axis(axis)
	player.set_move_vertical(vertical)
	if vertical > 0.65:
		player.set_crouch(true)
	elif vertical <= 0.3:
		player.set_crouch(false)


func _end_touch(index: int) -> void:
	_touches.erase(index)
	if index == _stick_index:
		_stick_index = -1
		_stick_vector = Vector2.ZERO
		if player != null:
			player.set_move_axis(0.0)
			player.set_move_vertical(0.0)
			player.set_crouch(false)
	queue_redraw()


func stick_vector() -> Vector2:
	return _stick_vector


func active_touch_count() -> int:
	return _touches.size()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var alpha := _opacity
	var stick: Dictionary = widgets.get("stick", {})
	if not stick.is_empty():
		_draw_stick(stick, alpha)
	for key: String in widgets.keys():
		if key == "stick":
			continue
		var widget: Dictionary = widgets[key]
		var center: Vector2 = widget["center"]
		var radius: float = widget["radius"]
		var pressed := _touches.values().has(key)
		var base := Color(0.2, 0.24, 0.42, 0.45 * alpha)
		if pressed:
			base = Color(0.45, 0.55, 0.85, 0.6 * alpha)
		draw_circle(center, radius, base)
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.75, 0.82, 1.0, 0.55 * alpha), 2.0)
		match key:
			"pause":
				_draw_pause_icon(center, radius)
			"attack":
				_draw_sword_icon(center, radius)
			"jump":
				_draw_jump_icon(center, radius)
			"dash":
				_draw_dash_icon(center, radius)
			_:
				if key.begins_with("skill_"):
					_draw_skill(center, radius, int(widget.get("slot", 0)), alpha)


func _draw_stick(stick: Dictionary, alpha: float) -> void:
	var center: Vector2 = stick["center"]
	var radius: float = stick["radius"]
	draw_circle(center, radius, Color(0.16, 0.18, 0.3, 0.35 * alpha))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.7, 0.8, 1.0, 0.5 * alpha), 2.0)
	var knob := center + _stick_vector * radius * 0.62
	draw_circle(knob, radius * 0.42, Color(0.82, 0.88, 1.0, 0.65 * alpha))


func _draw_pause_icon(center: Vector2, radius: float) -> void:
	var w := radius * 0.28
	var h := radius * 0.7
	var color := Color(1, 1, 1, 0.9)
	draw_rect(Rect2(center + Vector2(-radius * 0.38, -h * 0.5), Vector2(w, h)), color)
	draw_rect(Rect2(center + Vector2(radius * 0.38 - w, -h * 0.5), Vector2(w, h)), color)


func _draw_sword_icon(center: Vector2, radius: float) -> void:
	var color := Color(1.0, 0.95, 0.8, 0.95)
	var tip := center + Vector2(radius * 0.55, -radius * 0.55)
	var base := center + Vector2(-radius * 0.45, radius * 0.45)
	draw_line(tip, base, color, maxf(3.0, radius * 0.22))
	draw_line(center + Vector2(-radius * 0.5, radius * 0.1),
			center + Vector2(radius * 0.1, radius * 0.7), color, maxf(2.0, radius * 0.14))
	draw_line(center + Vector2(radius * 0.25, radius * 0.15),
			center + Vector2(radius * 0.25, radius * 0.85), Color(0.55, 0.4, 0.2, 0.95), maxf(3.0, radius * 0.18))


func _draw_jump_icon(center: Vector2, radius: float) -> void:
	var color := Color(1, 1, 1, 0.95)
	var y0 := center.y + radius * 0.45
	var y1 := center.y - radius * 0.45
	draw_line(Vector2(center.x, y1), Vector2(center.x, y0), color, maxf(3.0, radius * 0.2))
	draw_line(Vector2(center.x - radius * 0.4, y1 + radius * 0.4),
			Vector2(center.x, y1), color, maxf(3.0, radius * 0.2))
	draw_line(Vector2(center.x + radius * 0.4, y1 + radius * 0.4),
			Vector2(center.x, y1), color, maxf(3.0, radius * 0.2))


func _draw_dash_icon(center: Vector2, radius: float) -> void:
	var color := Color(0.85, 0.95, 1.0, 0.95)
	var dx := radius * 0.5
	var dy := radius * 0.4
	draw_line(center + Vector2(-dx, -dy), center + Vector2(0, 0), color, maxf(3.0, radius * 0.18))
	draw_line(center + Vector2(-dx, dy), center + Vector2(0, 0), color, maxf(3.0, radius * 0.18))
	draw_line(center + Vector2(0, 0), center + Vector2(dx, -dy), color, maxf(3.0, radius * 0.18))
	draw_line(center + Vector2(0, 0), center + Vector2(dx, dy), color, maxf(3.0, radius * 0.18))


func _draw_skill(center: Vector2, radius: float, slot: int, alpha: float) -> void:
	var ratio := 0.0
	var active := false
	if player != null and player.has_method("skill_manager"):
		var manager = player.skill_manager()
		if manager != null:
			ratio = float(manager.cooldown_ratio(slot))
			active = str(manager.skill_id(slot)) != ""
	if ratio > 0.0:
		draw_arc(center, radius * 0.85, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio), 32,
				Color(1.0, 0.85, 0.4, 0.8 * alpha), 4.0)
	# A small four-pointed "dream spark" glyph stands in for each skill.
	var color := Color(1.0, 0.95, 0.7, 0.6 * alpha)
	if active:
		color = Color(1.0, 0.95, 0.7, 0.95 * alpha)
	var r := radius * 0.45
	draw_line(center + Vector2(-r, 0), center + Vector2(r, 0), color, maxf(2.0, radius * 0.16))
	draw_line(center + Vector2(0, -r), center + Vector2(0, r), color, maxf(2.0, radius * 0.16))
	draw_line(center + Vector2(-r * 0.5, -r * 0.5),
			center + Vector2(r * 0.5, r * 0.5), color, maxf(2.0, radius * 0.14))
	draw_line(center + Vector2(-r * 0.5, r * 0.5),
			center + Vector2(r * 0.5, -r * 0.5), color, maxf(2.0, radius * 0.14))
