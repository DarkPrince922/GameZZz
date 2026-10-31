extends Node2D
## Pulsing laser: off/on cycle, damages only while active.

var tile_size: int = 32
var width_tiles: int = 3
var damage: float = 8.0
var on_time: float = 1.4
var off_time: float = 1.6
var warmup: float = 0.45
var active: bool = false
var _timer: float = 0.0
var _player = null
var _cooldown: float = 0.0


func setup(config: Dictionary) -> void:
	tile_size = int(config.get("tile_size", 32))
	width_tiles = int(config.get("w", 3))
	position = config.get("position", Vector2.ZERO)


func _ready() -> void:
	add_to_group("traps")
	_timer = off_time
	z_index = 2


func beam_rect() -> Rect2:
	var size := Vector2(float(width_tiles * tile_size), 10.0)
	return Rect2(global_position - size / 2.0, size)


func _physics_process(delta: float) -> void:
	_timer -= delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if _timer <= 0.0:
		active = not active
		_timer = on_time if active else off_time
		if active:
			AudioManager.play_at("trap_laser", global_position)
		queue_redraw()
	if not active:
		return
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null or _cooldown > 0.0:
		return
	if beam_rect().has_point(_player.global_position + Vector2(0.0, 6.0)):
		_cooldown = 0.8
		if _player.has_method("take_damage"):
			_player.take_damage(damage, global_position)


func _draw() -> void:
	var size := Vector2(float(width_tiles * tile_size), 10.0)
	var color := Color(1.0, 0.35, 0.4, 0.95) if active else Color(0.4, 0.2, 0.3, 0.5)
	draw_rect(Rect2(-size / 2.0, size), color)
	if active:
		draw_rect(Rect2(-size / 2.0 - Vector2(0, 2), size + Vector2(0, 4)),
				Color(1.0, 0.6, 0.6, 0.3))
