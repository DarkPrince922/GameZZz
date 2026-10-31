extends Control
## In-game HUD: health, dream shards, stars of the current level, boss bar hook.
## Drawn with primitives so no UI textures are needed.

var _player
var _boss
var _hp_ratio: float = 1.0
var _shards: int = 0
var _death_flash: float = 0.0
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_shards = SaveManager.shards() if get_node_or_null("/root/SaveManager") != null else 0


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
	_shards = total
	queue_redraw()


func flash_death() -> void:
	_death_flash = 0.9
	queue_redraw()


func _process(delta: float) -> void:
	if _death_flash > 0.0:
		_death_flash = maxf(0.0, _death_flash - delta)
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var view := get_viewport_rect().size
	# health
	var bar := Rect2(Vector2(24, 22), Vector2(320, 22))
	draw_rect(bar, Color(0.06, 0.06, 0.1, 0.8))
	var color := Color(0.4, 0.9, 0.55) if _hp_ratio > 0.3 else Color(0.95, 0.35, 0.4)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * _hp_ratio, 18)), color)
	draw_rect(bar, Color(0.8, 0.85, 1.0, 0.5), false, 2.0)
	draw_string(_font, Vector2(24, 66), "%s %.0f%%" % [Loc.text("hp_short"), _hp_ratio * 100.0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.94, 1.0))
	# shards counter
	var shard_text := "%s: %d" % [Loc.text("shards"), _shards]
	draw_string(_font, Vector2(view.x - 330, 42), shard_text, HORIZONTAL_ALIGNMENT_RIGHT, 300, 24,
			Color(0.8, 0.92, 1.0))
	if _boss != null and is_instance_valid(_boss) and not bool(_boss.get("is_dead")):
		_draw_boss_bar(view)
	if _death_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view),
				Color(0.8, 0.1, 0.15, 0.25 * _death_flash))


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
