extends RefCounted
## Self-destructing nightmare: beeps, then explodes. Telegraph first, always.

var fuse: float = -1.0
var beep_timer: float = 0.0


func setup(_enemy) -> void:
	fuse = -1.0


func update(enemy, delta: float) -> void:
	var distance: float = enemy.distance_to_player()
	var chase_speed := float(enemy.data.get("chase_speed", enemy.speed * 1.6))
	if fuse < 0.0:
		enemy.facing = enemy.direction_to_player()
		enemy.velocity.x = move_toward(enemy.velocity.x, enemy.facing * chase_speed, 900.0 * delta)
		if distance <= enemy.attack_range:
			fuse = float(enemy.data.get("fuse_seconds", 1.1))
			beep_timer = 0.0
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1200.0 * delta)
		fuse -= delta
		beep_timer -= delta
		if beep_timer <= 0.0:
			beep_timer = 0.32
			AudioManager.play_spatial_or_global("enemy_bomber_beep", enemy.global_position)
		if fuse <= 0.0:
			_explode(enemy)
	enemy.apply_gravity(enemy, delta)


func _explode(enemy) -> void:
	var radius := float(enemy.data.get("explosion_radius", 72.0))
	AudioManager.play_spatial_or_global("enemy_bomber_explode", enemy.global_position)
	var target: Vector2 = enemy.player_position()
	if target != Vector2.INF and enemy.global_position.distance_to(target) <= radius:
		if enemy.player != null and enemy.player.has_method("take_damage"):
			enemy.player.take_damage(enemy.damage, enemy.global_position)
	enemy.kill(false)
