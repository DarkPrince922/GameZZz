extends Node2D
## Spikes: static hazard, damages on touch with a short personal cooldown.

var width_tiles: int = 2
var tile_size: int = 32
var damage: float = 10.0
var cooldown: float = 0.9
var _timer: float = 0.0
var _player = null


func setup(config: Dictionary) -> void:
	width_tiles = int(config.get("w", 2))
	tile_size = int(config.get("tile_size", 32))
	damage = float(config.get("damage", 10.0))
	position = config.get("position", Vector2.ZERO)


func _ready() -> void:
	add_to_group("traps")
	z_index = 1


func hit_rect() -> Rect2:
	var size := Vector2(width_tiles * tile_size, tile_size * 0.5)
	return Rect2(global_position - Vector2(0.0, size.y), size)


func _physics_process(delta: float) -> void:
	_timer = maxf(0.0, _timer - delta)
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null or _timer > 0.0:
		return
	var probe := _player.global_position + Vector2(0.0, 10.0)
	if not hit_rect().has_point(probe):
		return
	_timer = cooldown
	AudioManager.play_at("trap_spikes", global_position)
	if _player.has_method("take_damage"):
		_player.take_damage(damage, global_position)


func _draw() -> void:
	var w := float(width_tiles * tile_size)
	var h := float(tile_size) * 0.5
	var count := maxi(1, width_tiles * 2)
	var step := w / float(count)
	for i in count:
		var x := -w / 2.0 + step * float(i)
		draw_colored_polygon(
			PackedVector2Array([Vector2(x, 0.0), Vector2(x + step / 2.0, -h), Vector2(x + step, 0.0)]),
			Color(0.75, 0.78, 0.9))
