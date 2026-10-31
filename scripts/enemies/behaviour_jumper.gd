extends RefCounted
## Hopping nightmare: patrols on the ground and leaps at the player.

var anchor: Vector2 = Vector2.ZERO
var patrol_dir: float = 1.0
var patrol_range: float = 110.0
var jump_timer: float = 0.0


func setup(enemy) -> void:
	anchor = enemy.global_position
	jump_timer = float(enemy.data.get("jump_interval", 1.35))


func update(enemy, delta: float) -> void:
	jump_timer -= delta
	var on_floor: bool = enemy.is_on_floor()
	if enemy.sees_player():
		enemy.facing = enemy.direction_to_player()
		if on_floor:
			enemy.velocity.x = move_toward(enemy.velocity.x, enemy.facing * enemy.speed, 800.0 * delta)
		if jump_timer <= 0.0 and on_floor:
			jump_timer = float(enemy.data.get("jump_interval", 1.35))
			enemy.velocity.y = float(enemy.data.get("jump_velocity", -420.0))
			enemy.velocity.x = enemy.facing * enemy.speed * 1.6
		if enemy.distance_to_player() <= enemy.attack_range:
			enemy.try_attack(delta)
	else:
		if absf(enemy.global_position.x - anchor.x) > patrol_range:
			patrol_dir = -signf(enemy.global_position.x - anchor.x)
		enemy.facing = patrol_dir
		if on_floor:
			enemy.velocity.x = move_toward(enemy.velocity.x, patrol_dir * enemy.speed * 0.6, 500.0 * delta)
	enemy.apply_gravity(enemy, delta)
