extends "res://scripts/bosses/boss_base.gd"
## Boss 1 — the Bed Monster. Three phases: claws, thrown toys, tantrum shockwaves.
## Every attack is telegraphed with a sound before it can hurt the player.

var _paw_offset: float = 0.0


func _ready() -> void:
	super._ready()
	boss_id = "bed_monster"
	if data.is_empty():
		configure("bed_monster")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_paw_offset = sin(Time.get_ticks_msec() / 220.0) * 6.0
	if player != null and not is_dead and stun_timer <= 0.0 and _pending_attack == "":
		var speed := float(phase.get("move_speed", 50.0))
		var distance := absf(player.global_position.x - global_position.x)
		if distance > 140.0:
			velocity.x = facing * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * 2.0)


func _apply_attack(attack_name: String, attack_data: Dictionary) -> void:
	match attack_name:
		"claw":
			var reach := float(attack_data.get("reach", 180.0))
			if player != null and absf(player.global_position.x - global_position.x) <= reach:
				_damage_player(float(attack_data.get("damage", 12.0)))
		"toys":
			var count := int(attack_data.get("projectiles", 3))
			for i in count:
				_throw_toy(i, count, float(attack_data.get("projectile_speed", 260.0)))
		"tantrum":
			var radius := float(attack_data.get("shockwave_radius", 260.0))
			if player != null and player.global_position.distance_to(global_position) <= radius:
				_damage_player(float(attack_data.get("damage", 16.0)))
			_shake_camera()


func _damage_player(amount: float) -> void:
	if player != null and player.has_method("take_damage"):
		player.take_damage(amount, global_position)


func _throw_toy(index: int, total: int, speed: float) -> void:
	var host := get_parent()
	if host == null or player == null:
		return
	var projectile := EnemyProjectile.new()
	var spread := (float(index) - float(total - 1) / 2.0) * 0.28
	var size: Array = data.get("size", [140, 120])
	var origin := global_position + Vector2(facing * 40.0, -float(size[1]) * 0.6)
	var direction := (player.global_position - origin).normalized().rotated(spread)
	projectile.setup({
		"position": origin,
		"velocity": direction * speed,
		"damage": 8.0,
		"owner_position": global_position,
	})
	host.call_deferred("add_child", projectile)


func _shake_camera() -> void:
	if get_tree() == null:
		return
	var player_nodes := get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return
	var player_node = player_nodes[0]
	if player_node.has_method("camera"):
		var cam: Camera2D = player_node.camera()
		if cam != null:
			var tween := create_tween()
			tween.tween_property(cam, "offset", Vector2(6, -4), 0.05)
			tween.tween_property(cam, "offset", Vector2(-5, 3), 0.05)
			tween.tween_property(cam, "offset", Vector2.ZERO, 0.08)


func _draw() -> void:
	super._draw()
	var size: Array = data.get("size", [140, 120])
	var body := Vector2(float(size[0]), float(size[1]))
	# claw paws on both sides
	for side in [-1.0, 1.0]:
		var paw := Vector2(side * body.x * 0.6, _paw_offset)
		draw_circle(paw, 16.0, Color(0.24, 0.16, 0.28))
		draw_circle(paw + Vector2(side * 6.0, 10.0), 10.0, Color(0.3, 0.2, 0.34))
	# blanket teeth
	var teeth_y := -body.y * 0.35
	for i in 6:
		var x := -body.x / 2.0 + body.x * float(i) / 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6.0, teeth_y), Vector2(x + 6.0, teeth_y), Vector2(x, teeth_y + 12.0),
		]), Color(0.95, 0.92, 0.85))
