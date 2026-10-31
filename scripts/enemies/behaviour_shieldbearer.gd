extends RefCounted
## Shield nightmare: blocks hits that come from the front until the shield breaks.

var anchor: Vector2 = Vector2.ZERO


func setup(enemy) -> void:
	anchor = enemy.global_position


func update(enemy, delta: float) -> void:
	if enemy.sees_player():
		enemy.facing = enemy.direction_to_player()
		var chase_speed := float(enemy.data.get("chase_speed", enemy.speed * 1.5))
		enemy.velocity.x = move_toward(enemy.velocity.x, enemy.facing * chase_speed, 400.0 * delta)
		enemy.try_attack(delta)
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 800.0 * delta)
	enemy.apply_gravity(enemy, delta)


func blocks_hit(enemy, from_position: Vector2) -> bool:
	if enemy.shield_hp <= 0.0:
		return false
	var side := signf(from_position.x - enemy.global_position.x)
	if side == 0.0:
		side = -enemy.facing
	return side == enemy.facing
