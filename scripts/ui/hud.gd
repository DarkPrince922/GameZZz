extends Control
## In-game HUD: health with a heart icon, dream shard counter with a crystal
## icon, and a boss bar hook. Anchored to the viewport so it stays put on any
## aspect ratio, and drawn with primitives so no UI textures are needed.

var _player
var _boss
var _hp_ratio: float = 1.0
var _shards: int = 0
var _death_flash: float = 0.0
var _low_hp_pulse: float = 0.0
var _font: Font
var _shard_pop: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_shards = SaveManager.shards() if get_node_or_null("/root/SaveManager") != null else 0
	get_viewport().size_changed.connect(queue_redraw)


func bind_player(player: Node) -> void:
	_player = player
	if player.has_signal("health_changed"):
		player.connect("health_changed", _on_health_changed)
	if player.has_signal("damaged"):
		player.connect("damaged", _on_damaged)
	if get_node_or_null("/root/Game") != null:
		Game.shards_changed.connect(_on_shards_changed)


func bind_boss(boss: Node) -> void:
	_boss = boss


func _on_health_changed(current: float, maximum: float) -> void:
	_hp_ratio = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	queue_redraw()


func _on_damaged(_amount: float) -> void:
	_death_flash = 0.25
	queue_redraw()


func _on_shards_changed(total: int) -> void:
	if total > _shards:
		_shard_pop = 0.35
	_shards = total
	queue_redraw()


func flash_death() -> void:
	_death_flash = 0.9
	queue_redraw()


func _process(delta: float) -> void:
	if _death_flash > 0.0:
		_death_flash = maxf(0.0, _death_flash - delta)
	if _shard_pop > 0.0:
		_shard_pop = maxf(0.0, _shard_pop - delta)
	_low_hp_pulse += delta
	queue_redraw()


func _safe_insets() -> Dictionary:
	var view := get_viewport().get_visible_rect().size
	var insets := {"top": 20.0, "bottom": 20.0, "left": 20.0, "right": 20.0}
	if DisplayServer.get_name() == "headless":
		return insets
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return insets
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return insets
	insets["left"] = maxf(20.0, float(safe.position.x) * view.x / float(win.x))
	insets["top"] = maxf(20.0, float(safe.position.y) * view.y / float(win.y))
	insets["right"] = maxf(20.0, float(win.x - safe.end.x) * view.x / float(win.x))
	insets["bottom"] = maxf(20.0, float(win.y - safe.end.y) * view.y / float(win.y))
	return insets


func _draw() -> void:
	if _font == null:
		return
	var view := get_viewport().get_visible_rect().size
	var insets := _safe_insets()
	var left := float(insets["left"])
	var top := float(insets["top"])

	_draw_health(left, top)
	_draw_shards(top, view)
	if _boss != null and is_instance_valid(_boss) and not bool(_boss.get("is_dead")):
		_draw_boss_bar(view)
	if _death_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.8, 0.1, 0.15, 0.25 * _death_flash))


func _draw_health(left: float, top: float) -> void:
	var bar := Rect2(Vector2(left, top), Vector2(300, 22))
	# Heart icon to the left of the bar.
	var heart_center := Vector2(left + 12.0, top + 11.0)
	_draw_heart(heart_center, 9.0)
	bar.position.x += 26.0
	draw_rect(bar, Color(0.06, 0.06, 0.1, 0.8))
	var low := _hp_ratio <= 0.3
	var color := Color(0.4, 0.9, 0.55)
	if low:
		# pulse between two reds at low health
		var t := 0.5 + 0.5 * sin(_low_hp_pulse * 8.0)
		color = Color(0.95, 0.35, 0.4).lerp(Color(1.0, 0.2, 0.25), t)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * _hp_ratio, 18)), color)
	draw_rect(bar, Color(0.8, 0.85, 1.0, 0.5), false, 2.0)


func _draw_heart(center: Vector2, r: float) -> void:
	# Two circles and a triangle make a simple heart.
	draw_circle(center + Vector2(-r * 0.5, -r * 0.3), r * 0.55, Color(0.95, 0.3, 0.4, 1.0))
	draw_circle(center + Vector2(r * 0.5, -r * 0.3), r * 0.55, Color(0.95, 0.3, 0.4, 1.0))
	var a := center + Vector2(-r, 0.0)
	var b := center + Vector2(r, 0.0)
	var c := center + Vector2(0.0, r * 1.15)
	draw_colored_polygon(PackedVector2Array([a, b, c]), Color(0.95, 0.3, 0.4, 1.0))


func _draw_shards(top: float, view: Vector2) -> void:
	# Shard counter sits top-right, to the LEFT of the pause button.
	var text := str(_shards)
	var font_size := 26
	var text_width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Pause button occupies ~64px + padding at the top-right corner.
	var right_edge := view.x - 64.0 - 28.0
	var text_pos := Vector2(right_edge - text_width, top + 24.0)
	_draw_crystal(text_pos + Vector2(-20.0, -14.0), 11.0)
	var pop := 1.0
	if _shard_pop > 0.0:
		pop = 1.0 + 0.25 * (_shard_pop / 0.35)
	var color := Color(0.8, 0.92, 1.0)
	draw_string(_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * pop), color)


func _draw_crystal(center: Vector2, r: float) -> void:
	var color := Color(0.7, 0.85, 1.0, 0.95)
	var top := center + Vector2(0, -r)
	var right := center + Vector2(r, r * 0.2)
	var bottom := center + Vector2(0, r)
	var left := center + Vector2(-r, r * 0.2)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), color)
	draw_colored_polygon(PackedVector2Array([top, center, bottom]), Color(0.5, 0.7, 1.0, 0.7))


func _draw_boss_bar(view: Vector2) -> void:
	var width := view.x * 0.5
	var origin := Vector2((view.x - width) / 2.0, 26.0)
	var max_hp: float = maxf(1.0, float(_boss.get("max_hp")))
	var ratio: float = clampf(float(_boss.get("hp")) / max_hp, 0.0, 1.0)
	draw_rect(Rect2(origin, Vector2(width, 20.0)), Color(0.06, 0.06, 0.1, 0.85))
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2((width - 4.0) * ratio, 16.0)),
			Color(0.85, 0.25, 0.35))
	draw_rect(Rect2(origin, Vector2(width, 20.0)), Color(0.8, 0.85, 1.0, 0.45), false, 2.0)
	var boss_data: Dictionary = _boss.get("data")
	var phases: Array = boss_data.get("phases", [])
	var phase_count := maxi(1, phases.size())
	for i in phase_count:
		var x := origin.x + width * float(i + 1) / float(phase_count)
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + 20.0),
				Color(0.02, 0.02, 0.05, 0.9), 2.0)
	var name_key := str(boss_data.get("name_key", ""))
	if name_key != "":
		draw_string(_font, origin + Vector2(0, -6), Loc.text(name_key),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
