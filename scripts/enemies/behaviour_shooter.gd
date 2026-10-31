extends RefCounted
## Ranged nightmare: keeps its distance and fires slow projectiles.

const EnemyProjectile := preload("res://scripts/enemies/enemy_projectile.gd")

var preferred_min: float = 150.0
var preferred_max: float = 300.0


func setup(enemy) -> void:
	preferred_min = enemy.attack_range * 0.45
	preferred_max = enemy.attack_range


func update(enemy, delta: float) -> void:
	var distance: float = enemy.distance_to_player()
	if enemy.sees_player():
		enemy.facing = enemy.direction_to_player()
		if distance < preferred_min:
			enemy.velocity.x = move_toward(enemy.velocity.x, -enemy.facing * enemy.speed,
					600.0 * delta)
		elif distance > preferred_max:
			enemy.velocity.x = move_toward(enemy.velocity.x, enemy.facing * enemy.speed,
					600.0 * delta)
		else:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
		if enemy.attack_timer <= 0.0 and distance <= preferred_max:
			enemy.attack_timer = enemy.attack_cooldown
			_shoot(enemy)
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 600.0 * delta)
	enemy.apply_gravity(enemy, delta)


func _shoot(enemy) -> void:
	enemy.play_at("enemy_shooter_shoot")
	var host: Node = enemy.get_parent()
	if host == null:
		return
	var projectile := EnemyProjectile.new()
	var target: Vector2 = enemy.player_position()
	var direction: Vector2 = (target - enemy.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(enemy.facing, 0.0)
	projectile.setup({
		"position": enemy.global_position + Vector2(0.0, -20.0),
		"velocity": direction * float(enemy.data.get("projectile_speed", 260.0)),
		"damage": float(enemy.data.get("projectile_damage", enemy.damage)),
		"owner_position": enemy.global_position,
	})
	host.call_deferred("add_child", projectile)
