extends Node
## Weapon behaviour: melee combos, boomerang and arrows.
## Reads numbers from data/weapons.json, spawns hit effects and owns the swing
## sounds, so the player script stays about movement.

const COMBAT := preload("res://scripts/core/combat_math.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")

var weapon_id: String = "light_sword"
var data: Dictionary = {}
var combo_index: int = 0
var combo_timer: float = 0.0
var cooldown_timer: float = 0.0
var swings: int = 0
var hits: int = 0

var _player: CharacterBody2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	_rng.randomize()
	equip(str(SaveManager.equipped_weapon()) if get_node_or_null("/root/SaveManager") else "light_sword")


func equip(new_weapon_id: String) -> void:
	weapon_id = new_weapon_id
	if get_node_or_null("/root/DataDB") != null:
		data = DataDB.weapon(weapon_id)
	if data.is_empty():
		data = {
			"style": "melee", "damage": 8, "combo_hits": 1, "cooldown": 0.3,
			"reach": 48.0, "swing_sfx": "weapon_swing_light_sword",
			"hit_sfx": "combat_hit", "crit_chance": 0.1,
		}
	combo_index = 0


func _process(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_index = 0


func attack() -> Dictionary:
	if _player == null or cooldown_timer > 0.0:
		return {"hit": false, "blocked": true, "combo": combo_index}
	cooldown_timer = float(data.get("cooldown", 0.3))
	swings += 1
	var swing_sfx := str(data.get("swing_sfx", "weapon_swing_light_sword"))
	AudioManager.play(swing_sfx)
	var result: Dictionary
	if str(data.get("style", "melee")) == "melee":
		result = _melee_attack()
	else:
		result = _ranged_attack()
	combo_index = (combo_index + 1) % maxi(1, int(data.get("combo_hits", 1)))
	combo_timer = float(data.get("combo_window", 0.3))
	if combo_index > 0:
		AudioManager.play("combat_combo")
	return result


func _melee_attack() -> Dictionary:
	var reach := float(data.get("reach", 48.0))
	var damage_mult := 0.0
	if get_node_or_null("/root/Game") != null:
		damage_mult = Game.damage_multiplier()
	var step_mult := COMBAT.combo_step(combo_index, data.get("combo_step_damage", [1.0]))
	var crit_chance := COMBAT.clamp_crit(float(data.get("crit_chance", 0.1)))
	var origin := _player.global_position
	var facing: float = float(_player.get("facing")) if _player.get("facing") != null else 1.0
	var victims := _enemies_in_arc(origin, reach, float(facing))
	var any_hit := false
	for enemy: Node in victims:
		var crit := COMBAT.roll_crit(_rng, crit_chance)
		var final_damage := COMBAT.hit_damage(float(data.get("damage", 8.0)), damage_mult * step_mult, crit)
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", final_damage, origin, crit)
		any_hit = true
		hits += 1
		if crit:
			AudioManager.play("combat_crit")
		else:
			AudioManager.play("combat_hit")
		var hit_node := enemy as Node2D
		_spawn_hit_flash(hit_node.global_position if hit_node != null else origin)
	if not any_hit:
		AudioManager.play("combat_miss")
	return {"hit": any_hit, "combo": combo_index, "count": victims.size()}


func _ranged_attack() -> Dictionary:
	var projectile := Projectile.new()
	var speed := float(data.get("projectile_speed", 420.0))
	var facing: float = float(_player.get("facing")) if _player.get("facing") != null else 1.0
	projectile.setup({
		"position": _player.global_position + Vector2(facing * 20.0, -4.0),
		"velocity": Vector2(facing * speed, 0.0),
		"damage": float(data.get("damage", 8.0)),
		"crit_chance": float(data.get("crit_chance", 0.1)),
		"range": float(data.get("projectile_range", 320.0)),
		"boomerang": str(data.get("style", "")) == "boomerang",
		"return_speed": speed,
		"hit_sfx": str(data.get("hit_sfx", "combat_hit")),
		"owner": _player,
	})
	var host := _player.get_parent() if _player.get_parent() != null else _player
	host.add_child(projectile)
	return {"hit": false, "projectile": true, "combo": combo_index}


func _enemies_in_arc(origin: Vector2, reach: float, facing: float) -> Array:
	var found: Array = []
	if _player.get_tree() == null:
		return found
	for node: Node in _player.get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") != null and bool(enemy.get("is_dead")):
			continue
		var offset := enemy.global_position - origin
		var allowed := reach + _enemy_radius(enemy)
		if absf(offset.y) > 70.0:
			continue
		if absf(offset.x) > allowed and offset.length() > allowed:
			continue
		if signf(offset.x) != signf(facing) and absf(offset.x) > 20.0:
			continue
		found.append(enemy)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return found


func _enemy_radius(enemy) -> float:
	if enemy.has_method("body_radius"):
		return float(enemy.body_radius())
	return 20.0


func _spawn_hit_flash(at: Vector2) -> void:
	var flash = load("res://scripts/combat/hit_flash.gd").new()
	flash.position = at
	var host := _player.get_parent() if _player.get_parent() != null else _player
	host.add_child(flash)
