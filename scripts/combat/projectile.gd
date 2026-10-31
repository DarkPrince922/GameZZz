extends Node2D
## Flying weapon hitbox (lantern boomerang, moon bow arrows).
## Manual distance checks against the "enemies" group keep it deterministic and
## easy to cover in tests (no physics layers to configure).

const COMBAT := preload("res://scripts/core/combat_math.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: float = 8.0
var crit_chance: float = 0.1
var max_range: float = 320.0
var boomerang: bool = false
var return_speed: float = 420.0
var hit_sfx: String = "combat_hit"
var owner_node: Node2D = null

var _travelled: float = 0.0
var _returning: bool = false
var _hit_targets: Array = []
var _rng := RandomNumberGenerator.new()


func setup(config: Dictionary) -> void:
	position = config.get("position", Vector2.ZERO)
	velocity = config.get("velocity", Vector2.RIGHT * 400.0)
	damage = float(config.get("damage", 8.0))
	crit_chance = float(config.get("crit_chance", 0.1))
	max_range = float(config.get("range", 320.0))
	boomerang = bool(config.get("boomerang", false))
	return_speed = float(config.get("return_speed", 420.0))
	hit_sfx = str(config.get("hit_sfx", "combat_hit"))
	owner_node = config.get("owner", null)
	_rng.randomize()


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	if _returning and owner_node != null and is_instance_valid(owner_node):
		var to_owner := owner_node.global_position - global_position
		if to_owner.length() < 26.0:
			queue_free()
			return
		velocity = to_owner.normalized() * return_speed
	var step := velocity * delta
	position += step
	_travelled += step.length()
	_check_hits()
	if not boomerang and _travelled >= max_range:
		queue_free()
	elif boomerang and not _returning and _travelled >= max_range:
		_returning = true


func _check_hits() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or _hit_targets.has(enemy):
			continue
		if enemy.get("is_dead") != null and bool(enemy.get("is_dead")):
			continue
		if enemy.global_position.distance_to(global_position) > 34.0:
			continue
		_apply_hit(enemy)


func _apply_hit(enemy) -> void:
	_hit_targets.append(enemy)
	var mult := 1.0
	if get_node_or_null("/root/Game") != null:
		mult = Game.damage_multiplier()
	var crit := COMBAT.roll_crit(_rng, crit_chance)
	var final_damage := COMBAT.hit_damage(damage, mult, crit)
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage, global_position, crit)
	AudioManager.play(hit_sfx)
	if crit:
		AudioManager.play("combat_crit")
	if not boomerang:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.92, 0.6, 0.95))
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.85, 0.4, 0.25))
