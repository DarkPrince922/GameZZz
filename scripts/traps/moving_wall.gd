extends AnimatableBody2D
## Sliding wall that crushes careless runners. Moves back and forth.

var tile_size: int = 32
var height_tiles: int = 4
var travel: float = 96.0
var speed: float = 70.0
var damage: float = 12.0
var _origin: Vector2
var _dir: float = 1.0
var _player = null
var _hit_cooldown: float = 0.0
var _was_active: bool = false


func setup(config: Dictionary) -> void:
	tile_size = int(config.get("tile_size", 32))
	height_tiles = int(config.get("h", 4))
	travel = float(config.get("travel", 96.0))
	position = config.get("position", Vector2.ZERO)


func _ready() -> void:
	add_to_group("traps")
	sync_to_physics = false
	collision_layer = 2
	collision_mask = 0
	_origin = global_position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, float(height_tiles * tile_size))
	shape.shape = rect
	add_child(shape)


func wall_rect() -> Rect2:
	var size := Vector2(24.0, float(height_tiles * tile_size))
	return Rect2(global_position - size / 2.0, size)


func _physics_process(delta: float) -> void:
	if get_tree() == null:
		return
	position.x += _dir * speed * delta
	if position.x > _origin.x + travel:
		position.x = _origin.x + travel
		_dir = -1.0
		if not _was_active:
			AudioManager.play_at("trap_moving_wall", global_position)
			_was_active = true
	elif position.x < _origin.x - travel:
		position.x = _origin.x - travel
		_dir = 1.0
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null or _hit_cooldown > 0.0:
		return
	if wall_rect().grow(6.0).has_point(_player.global_position):
		_hit_cooldown = 0.9
		if _player.has_method("take_damage"):
			_player.take_damage(damage, global_position)
	queue_redraw()


func _draw() -> void:
	var size := Vector2(24.0, float(height_tiles * tile_size))
	draw_rect(Rect2(-size / 2.0, size), Color(0.32, 0.3, 0.42))
	draw_rect(Rect2(-size / 2.0, size), Color(0.55, 0.5, 0.7), false, 2.0)
