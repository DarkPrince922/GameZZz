extends Node2D
## Plush friend summon: follows the player, chases the nearest nightmare, bites it.

var damage: float = 6.0
var lifetime: float = 8.0
var speed: float = 190.0
var attack_cooldown: float = 0.55

var _player: Node2D
var _timer: float = 0.0
var _target


func setup_player(player: Node2D) -> void:
	_player = player


func _ready() -> void:
	z_index = 4


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_timer = maxf(0.0, _timer - delta)
	if lifetime <= 0.0:
		queue_free()
		return
	_target = _nearest_enemy()
	var destination: Vector2 = _player.global_position + Vector2(-24.0, -8.0) \
			if _player != null else global_position
	if _target != null:
		destination = _target.global_position
	var to_destination := destination - global_position
	if to_destination.length() > 8.0:
		global_position += to_destination.normalized() * minf(speed * delta, to_destination.length())
	if _target != null and _target.global_position.distance_to(global_position) < 30.0 and _timer <= 0.0:
		_timer = attack_cooldown
		if _target.has_method("take_damage"):
			_target.take_damage(damage, global_position, false)
		AudioManager.play_at("enemy_hurt", global_position)
	queue_redraw()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") != null and bool(enemy.get("is_dead")):
			continue
		var distance: float = enemy.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.85, 0.68, 0.5))
	draw_circle(Vector2(-5, -14), 5.0, Color(0.85, 0.68, 0.5))
	draw_circle(Vector2(5, -14), 5.0, Color(0.85, 0.68, 0.5))
	draw_circle(Vector2(-2, -2), 1.8, Color(0.15, 0.12, 0.1))
	draw_circle(Vector2(3, -2), 1.8, Color(0.15, 0.12, 0.1))
