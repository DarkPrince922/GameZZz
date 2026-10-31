extends Control
## Virtual stick (left) + jump / attack / dash / skill buttons (right).
## True multitouch: every touch index is tracked separately, so running and
## attacking at the same time always works. Sizes and opacity come from Settings.

signal pause_requested()

const STICK_MAX := 96.0
const STICK_DEAD_ZONE := 0.12

var player
var _touches: Dictionary = {}
var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_vector: Vector2 = Vector2.ZERO
var _widgets: Dictionary = {}
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


func _layout() -> void:
	var view := get_viewport_rect().size
	_widgets.clear()
	var stick_center := Vector2(150.0 * _scale, view.y - 140.0 * _scale)
	_widgets["stick"] = {"center": stick_center, "radius": 104.0 * _scale}
	_widgets["attack"] = {
		"center": Vector2(view.x - 120.0 * _scale, view.y - 110.0 * _scale),
		"radius": 62.0 * _scale, "label": "A",
	}
	_widgets["jump"] = {
		"center": Vector2(view.x - 250.0 * _scale, view.y - 150.0 * _scale),
		"radius": 56.0 * _scale, "label": "J",
	}
	_widgets["dash"] = {
		"center": Vector2(view.x - 210.0 * _scale, view.y - 280.0 * _scale),
		"radius": 40.0 * _scale, "label": "D",
	}
	for slot in 3:
		_widgets["skill_%d" % slot] = {
			"center": Vector2(view.x - (330.0 + 78.0 * slot) * _scale, view.y - 44.0 * _scale),
			"radius": 34.0 * _scale, "label": str(slot + 1), "slot": slot,
		}
	_widgets["pause"] = {"center": Vector2(view.x - 40.0, 40.0), "radius": 26.0}
	queue_redraw()


func _widget_at(point: Vector2) -> String:
	# small widgets first, the stick last (it is the largest target)
	var keys := ["pause", "skill_0", "skill_1", "skill_2", "dash", "jump", "attack", "stick"]
	for key: String in keys:
		var widget: Dictionary = _widgets.get(key, {})
		if widget.is_empty():
			continue
		if point.distance_to(widget["center"]) <= float(widget["radius"]):
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
				var slot := int(widget.split("_")[1])
				player.press_skill(slot)
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
	var widget := str(_touches.get(index, ""))
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
	# stick
	var stick: Dictionary = _widgets.get("stick", {})
	if not stick.is_empty():
		var center: Vector2 = stick["center"]
		var radius: float = stick["radius"]
		draw_circle(center, radius, Color(0.16, 0.18, 0.3, 0.35 * alpha))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.7, 0.8, 1.0, 0.5 * alpha), 2.0)
		var knob := center + _stick_vector * radius * 0.62
		draw_circle(knob, radius * 0.42, Color(0.82, 0.88, 1.0, 0.65 * alpha))
	for key: String in _widgets.keys():
		if key == "stick":
			continue
		var widget: Dictionary = _widgets[key]
		var center: Vector2 = widget["center"]
		var radius: float = widget["radius"]
		var base := Color(0.2, 0.24, 0.42, 0.45 * alpha)
		var pressed := _touches.values().has(key)
		if pressed:
			base = Color(0.45, 0.55, 0.85, 0.6 * alpha)
		draw_circle(center, radius, base)
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.75, 0.82, 1.0, 0.55 * alpha), 2.0)
		if key == "pause":
			draw_rect(Rect2(center + Vector2(-7, -9), Vector2(4, 18)), Color(1, 1, 1, 0.85))
			draw_rect(Rect2(center + Vector2(3, -9), Vector2(4, 18)), Color(1, 1, 1, 0.85))
			continue
		if key.begins_with("skill_"):
			var slot: int = int(widget.get("slot", 0))
			_draw_skill(center, radius, slot, alpha)
			continue
		var label := str(widget.get("label", ""))
		draw_string(_font, center + Vector2(-radius * 0.4, 6.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * _scale), Color(1, 1, 1, 0.9))


func _draw_skill(center: Vector2, radius: float, slot: int, alpha: float) -> void:
	var ratio := 0.0
	var label := str(slot + 1)
	if player != null and player.has_method("skill_manager"):
		var manager = player.skill_manager()
		if manager != null:
			ratio = float(manager.cooldown_ratio(slot))
			var skill_name: String = str(manager.skill_id(slot))
			if skill_name == "":
				label = "-"
	if ratio > 0.0:
		draw_arc(center, radius * 0.85, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - ratio), 32,
				Color(1.0, 0.85, 0.4, 0.8 * alpha), 4.0)
	draw_string(_font, center + Vector2(-6, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(20 * _scale), Color(1, 1, 1, 0.9))
