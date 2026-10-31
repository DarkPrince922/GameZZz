extends RefCounted
## Flying nightmare: hovers with a sine bob and drifts toward the player.

var anchor: Vector2 = Vector2.ZERO
var time: float = 0.0
var fly_sound_timer: float = 0.0


func setup(enemy) -> void:
	anchor = enemy.global_position


func update(enemy, delta: float) -> void:
	time += delta
	fly_sound_timer = maxf(0.0, fly_sound_timer - delta)
	var amplitude := float(enemy.data.get("fly_amplitude", 26.0))
	var frequency := float(enemy.data.get("fly_frequency", 2.2))
	var bob := sin(time * frequency) * amplitude
	if enemy.sees_player():
		enemy.facing = enemy.direction_to_player()
		var chase_speed := float(enemy.data.get("chase_speed", enemy.speed * 1.4))
		var target: Vector2 = enemy.player.global_position + Vector2(-enemy.facing * 12.0, -34.0 + bob)
		var to_target: Vector2 = target - enemy.global_position
		enemy.velocity = to_target.normalized() * minf(chase_speed, to_target.length() * 2.4)
		if fly_sound_timer <= 0.0:
			fly_sound_timer = 1.8
			enemy.play_at("enemy_flyer_fly")
		if enemy.distance_to_player() < enemy.attack_range:
			enemy.try_attack(delta)
	else:
		var drift: float = enemy.global_position.x - anchor.x
		enemy.facing = signf(drift) if absf(drift) > 4.0 else enemy.facing
		enemy.velocity = Vector2(0.0, cos(time * frequency) * amplitude * 0.4)
