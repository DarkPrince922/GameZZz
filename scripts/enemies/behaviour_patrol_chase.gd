extends RefCounted
## Ground patroller that chases the player when it notices them.
## Used by "shadow" and as the default behaviour.

var anchor: Vector2 = Vector2.ZERO
var patrol_dir: float = 1.0
var patrol_range: float = 96.0


func setup(enemy) -> void:
	anchor = enemy.global_position


func update(enemy, delta: float) -> void:
	if enemy.sees_player():
		enemy.facing = enemy.direction_to_player()
		if enemy.distance_to_player() > enemy.attack_range:
			var chase_speed := float(enemy.data.get("chase_speed", enemy.speed * 1.7))
			enemy.velocity.x = move_toward(enemy.velocity.x, enemy.facing * chase_speed,
					900.0 * delta)
		else:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1200.0 * delta)
			enemy.try_attack(delta)
	else:
		if absf(enemy.global_position.x - anchor.x) > patrol_range:
			patrol_dir = -signf(enemy.global_position.x - anchor.x)
		enemy.facing = patrol_dir
		enemy.velocity.x = move_toward(enemy.velocity.x, patrol_dir * enemy.speed, 600.0 * delta)
	enemy.apply_gravity(enemy, delta)
