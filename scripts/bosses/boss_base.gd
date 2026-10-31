extends CharacterBody2D
## Boss framework: phases, weak point, vulnerability window, stun and death.
## Attack patterns live in the subclass (scripts/bosses/boss_bed_monster.gd).

signal health_changed(current: float, maximum: float)
signal phase_changed(index: int)
signal exposed()
signal died()
signal victory_line()

const EnemyProjectile := preload("res://scripts/enemies/enemy_projectile.gd")
const EnemyScene := preload("res://scenes/enemy.tscn")

var boss_id: String = "bed_monster"
var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var phase_index: int = 0
var phase: Dictionary = {}
var attack_timer: float = 2.0
var attacks_since_stun: int = 0
var stun_timer: float = 0.0
var vulnerable: bool = false
var is_dead: bool = false
var facing: float = -1.0
var player = null

var _pending_attack: String = ""
var _pending_timer: float = 0.0
var _recovery_timer: float = 0.0
var _shape: CollisionShape2D
var _rect: RectangleShape2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 2
	if data.is_empty():
		configure(boss_id)


func configure(id: String) -> void:
	boss_id = id
	data = DataDB.boss(id)
	if data.is_empty():
		push_warning("Boss: unknown boss %s" % id)
		data = {"max_hp": 100, "phases": [{"hp_to": 0.0, "attack_interval": 2.0, "attacks": []}]}
	max_hp = float(data.get("max_hp", 100.0))
	if get_node_or_null("/root/Settings") != null:
		max_hp = CombatMath.enemy_health(max_hp, Settings.difficulty)
	hp = max_hp
	phase_index = 0
	var phases: Array = data.get("phases", [])
	if not phases.is_empty():
		phase = phases[0]
	_build_body()
	health_changed.emit(hp, max_hp)


func _build_body() -> void:
	if _shape != null:
		return
	_shape = CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	var size: Array = data.get("size", [140, 120])
	_rect.size = Vector2(float(size[0]), float(size[1]))
	_shape.shape = _rect
	_shape.position = Vector2(0, -_rect.size.y / 2.0)
	add_child(_shape)
	collision_layer = 4


func boss_name_key() -> String:
	return str(data.get("name_key", "boss"))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	player = _find_player()
	velocity.y = minf(velocity.y + 1400.0 * delta, 900.0)
	if player != null:
		facing = signf(player.global_position.x - global_position.x)
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		velocity.x = 0.0
		if stun_timer <= 0.0:
			_set_vulnerable(false)
	elif _pending_attack != "":
		_pending_timer -= delta
		if _pending_timer <= 0.0:
			_execute_attack(_pending_attack)
			_pending_attack = ""
			_recovery_timer = 0.35
	else:
		if _recovery_timer > 0.0:
			_recovery_timer = maxf(0.0, _recovery_timer - delta)
		else:
			attack_timer -= delta
			if attack_timer <= 0.0:
				_pick_attack()
	move_and_slide()
	queue_redraw()


func _find_player() -> Node2D:
	if player != null and is_instance_valid(player):
		return player
	var nodes := get_tree().get_nodes_in_group("player") if get_tree() != null else []
	return nodes[0] as Node2D if not nodes.is_empty() else null


# -------------------------------------------------------------------- phases
func phase_for_ratio(ratio: float) -> int:
	var phases: Array = data.get("phases", [])
	for i in phases.size():
		if ratio > float((phases[i] as Dictionary).get("hp_to", 0.0)):
			return i
	return maxi(0, phases.size() - 1)


func _pick_attack() -> void:
	var attacks: Array = phase.get("attacks", [])
	if attacks.is_empty():
		attack_timer = 2.0
		return
	var choice := str(attacks[randi_range(0, attacks.size() - 1)])
	var attack_data: Dictionary = (data.get("attacks", {}) as Dictionary).get(choice, {})
	_pending_attack = choice
	_pending_timer = float(attack_data.get("telegraph", 0.6))
	var telegraph_sfx := str(attack_data.get("telegraph_sfx", "boss_telegraph"))
	AudioManager.play_spatial_or_global(telegraph_sfx, global_position)


func _execute_attack(attack_name: String) -> void:
	var attack_data: Dictionary = (data.get("attacks", {}) as Dictionary).get(attack_name, {})
	var sfx := str(attack_data.get("sfx", "boss_attack_claw"))
	AudioManager.play_spatial_or_global(sfx, global_position)
	attacks_since_stun += 1
	attack_timer = float(phase.get("attack_interval", 2.0))
	_apply_attack(attack_name, attack_data)
	if attacks_since_stun >= int(data.get("stun_after_attacks", 3)):
		attacks_since_stun = 0
		_begin_stun()


func _apply_attack(_attack_name: String, _attack_data: Dictionary) -> void:
	pass


func _begin_stun() -> void:
	stun_timer = float(data.get("stun_duration", 2.5))
	_set_vulnerable(true)
	AudioManager.play_spatial_or_global("boss_stun", global_position)
	exposed.emit()


func _set_vulnerable(value_on: bool) -> void:
	vulnerable = value_on
	queue_redraw()


func is_vulnerable() -> bool:
	return vulnerable


# -------------------------------------------------------------------- damage
func body_radius() -> float:
	return 70.0


func weak_point_offset() -> Vector2:
	var offset: Array = (data.get("weak_point", {}) as Dictionary).get("offset", [0, -40])
	return Vector2(float(offset[0]), float(offset[1]))


func is_weak_point_hit(source_position: Vector2) -> bool:
	var weak := global_position + weak_point_offset()
	var size: Array = (data.get("weak_point", {}) as Dictionary).get("size", [50, 40])
	return absf(source_position.x - weak.x) <= float(size[0]) * 0.9 \
			and absf(source_position.y - weak.y) <= float(size[1])


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, _crit: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	var final_damage := amount
	var weak_hit := is_weak_point_hit(source_position)
	if weak_hit and vulnerable:
		var mult := float((data.get("weak_point", {}) as Dictionary).get("damage_mult", 1.8))
		final_damage *= mult
		AudioManager.play_spatial_or_global("boss_weakpoint_break", global_position)
	elif not vulnerable:
		final_damage *= 0.55  # armoured while not exposing the weak point
	hp = maxf(0.0, hp - final_damage)
	AudioManager.play_spatial_or_global("boss_hurt", global_position)
	health_changed.emit(hp, max_hp)
	_check_phase()
	if hp <= 0.0:
		_die()
	queue_redraw()


func _check_phase() -> void:
	var ratio := hp / max_hp
	var target := phase_for_ratio(ratio)
	if target != phase_index:
		phase_index = target
		var phases: Array = data.get("phases", [])
		phase = phases[clampi(target, 0, phases.size() - 1)]
		attack_timer = 0.8
		AudioManager.play_spatial_or_global("boss_phase", global_position)
		phase_changed.emit(phase_index)
		var summon: Dictionary = phase.get("summon", {})
		if not summon.is_empty():
			_summon_minions(summon)


func _summon_minions(summon: Dictionary) -> void:
	var host := get_parent()
	if host == null:
		return
	for i in int(summon.get("count", 1)):
		var minion = EnemyScene.instantiate()
		minion.position = position + Vector2(randf_range(-90.0, 90.0), -20.0)
		# add first, configure after: configure() reads autoloads
		host.call_deferred("add_child", minion)
		minion.call_deferred("configure", str(summon.get("type", "shadow")),
				str(summon.get("elite", "")))


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	collision_layer = 0
	AudioManager.play_spatial_or_global("boss_death", global_position)
	died.emit()
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		AudioManager.play("boss_victory_line")
		victory_line.emit())


func _draw() -> void:
	var size: Array = data.get("size", [140, 120])
	var body := Vector2(float(size[0]), float(size[1]))
	var color: Array = data.get("color", [0.32, 0.22, 0.36])
	var base := Color(float(color[0]), float(color[1]), float(color[2]))
	if vulnerable:
		base = base.lerp(Color(1.0, 0.85, 0.5), 0.35)
	draw_rect(Rect2(Vector2(-body.x / 2.0, -body.y), body), base)
	# eyes
	draw_circle(Vector2(facing * 22.0 - 8.0, -body.y * 0.7), 7.0, Color(1.0, 0.9, 0.5))
	draw_circle(Vector2(facing * 22.0 + 8.0, -body.y * 0.7), 7.0, Color(1.0, 0.9, 0.5))
	# weak point glows while exposed
	if vulnerable:
		draw_circle(weak_point_offset(), 16.0, Color(1.0, 0.95, 0.7, 0.85))
	if _pending_attack != "":
		draw_arc(Vector2.ZERO, body.x * 0.8, 0.0, TAU, 32, Color(1.0, 0.4, 0.4, 0.6), 3.0)
