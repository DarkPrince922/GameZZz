extends AnimatableBody2D
## Platform that shakes, falls and comes back. Telegraph sound plays on touch.

var tile_size: int = 32
var platform_width: int = 3
var shake_time: float = 0.45
var fall_gravity: float = 900.0
var respawn_time: float = 2.6
var state: int = 0  # 0 idle, 1 shaking, 2 falling, 3 waiting
var _timer: float = 0.0
var _origin: Vector2
var _fall_speed: float = 0.0
var _player = null
var _shape: CollisionShape2D


func setup(config: Dictionary) -> void:
	tile_size = int(config.get("tile_size", 32))
	platform_width = int(config.get("w", 3))
	position = config.get("position", Vector2.ZERO)


func _ready() -> void:
	add_to_group("traps")
	sync_to_physics = false
	collision_layer = 2
	collision_mask = 0
	_origin = global_position
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width * tile_size, 12.0)
	_shape.shape = rect
	add_child(_shape)


func _physics_process(delta: float) -> void:
	if get_tree() == null:
		return
	match state:
		0:
			if _player_on_top():
				state = 1
				_timer = shake_time
				AudioManager.play_at("trap_falling_platform", global_position)
		1:
			_timer -= delta
			position.x = _origin.x + sin(_timer * 60.0) * 2.0
			if _timer <= 0.0:
				state = 2
				_fall_speed = 0.0
				_shape.set_deferred("disabled", true)
		2:
			_fall_speed += fall_gravity * delta
			position.y += _fall_speed * delta
			if position.y > _origin.y + 400.0:
				state = 3
				_timer = respawn_time
				visible = false
		3:
			_timer -= delta
			if _timer <= 0.0:
				position = _origin
				visible = true
				_shape.set_deferred("disabled", false)
				state = 0
				AudioManager.play_at("trap_falling_platform", global_position)


func _player_on_top() -> bool:
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null:
		return false
	var feet: Vector2 = _player.global_position + Vector2(0.0, 22.0)
	var half := float(platform_width * tile_size) / 2.0
	return absf(feet.x - global_position.x) < half and absf(feet.y - global_position.y) < 16.0


func _draw() -> void:
	var size := Vector2(float(platform_width * tile_size), 12.0)
	draw_rect(Rect2(-size / 2.0, size), Color(0.55, 0.45, 0.7))
	draw_line(Vector2(-size.x / 2.0, 0.0), Vector2(size.x / 2.0, 0.0), Color(0.85, 0.75, 0.95), 2.0)
