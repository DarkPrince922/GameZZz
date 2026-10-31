extends Node
## Skill slots, cooldowns and effects. Every activation plays its own sound (spec 4)
## and every cooldown finishing plays the shared "skill_ready" cue.

signal skill_used(slot: int, skill_id: String)
signal skill_ready(slot: int, skill_id: String)

const PlushFriend := preload("res://scripts/skills/plush_friend.gd")
const FireZone := preload("res://scripts/skills/fire_zone.gd")

var slots: Array = []
var cooldowns: Array = []
var shield_timer: float = 0.0
var stealth_timer: float = 0.0
var slow_timer: float = 0.0

var _player
var _effects: Array = []
var _announced: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = get_parent() as Node2D
	_rng.randomize()
	refresh_slots()


func refresh_slots() -> void:
	slots.clear()
	cooldowns.clear()
	_announced.clear()
	var equipped: Array = []
	if get_node_or_null("/root/Game") != null:
		equipped = Game.equipped_skills()
	for entry: Variant in equipped:
		var dict: Dictionary = entry
		slots.append(dict)
		cooldowns.append(0.0)
		_announced.append(true)
	while slots.size() < 3:
		slots.append({})
		cooldowns.append(0.0)
		_announced.append(true)


func _process(delta: float) -> void:
	for i in cooldowns.size():
		if cooldowns[i] > 0.0:
			cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
			if cooldowns[i] <= 0.0 and i < slots.size() and not (slots[i] as Dictionary).is_empty():
				_announced[i] = true
				AudioManager.play("skill_ready")
				skill_ready.emit(i, str(slots[i].get("id", "")))
	_tick_effects(delta)


func is_ready(slot: int) -> bool:
	if slot < 0 or slot >= slots.size():
		return false
	if (slots[slot] as Dictionary).is_empty():
		return false
	return cooldowns[slot] <= 0.0


func cooldown_left(slot: int) -> float:
	if slot < 0 or slot >= slots.size():
		return 0.0
	return cooldowns[slot]


func cooldown_ratio(slot: int) -> float:
	if slot < 0 or slot >= slots.size():
		return 0.0
	var data: Dictionary = slots[slot]
	if data.is_empty():
		return 0.0
	var total := float((data.get("data", {}) as Dictionary).get("cooldown", 1.0))
	if total <= 0.0:
		return 0.0
	return clampf(cooldowns[slot] / total, 0.0, 1.0)


func skill_id(slot: int) -> String:
	if slot < 0 or slot >= slots.size():
		return ""
	return str((slots[slot] as Dictionary).get("id", ""))


func activate_slot(slot: int) -> bool:
	if not is_ready(slot):
		return false
	var entry: Dictionary = slots[slot]
	var data: Dictionary = entry.get("data", {})
	var skill_name := str(data.get("effect", ""))
	cooldowns[slot] = float(data.get("cooldown", 1.0))
	_announced[slot] = false
	var sfx := str(data.get("sfx", ""))
	if sfx != "":
		AudioManager.play(sfx)
	_apply_effect(skill_name, data)
	skill_used.emit(slot, str(entry.get("id", "")))
	return true


func _apply_effect(effect: String, data: Dictionary) -> void:
	var power := float(data.get("power", 0.0))
	match effect:
		"dash":
			if _player != null and _player.has_method("press_dash"):
				_player.press_dash()
		"area_damage":
			_damage_nearby(float(data.get("radius", 130.0)), power, 99)
		"shield":
			if _player != null and _player.has_method("apply_shield"):
				_player.apply_shield(power)
			shield_timer = float(data.get("duration", 6.0))
		"chain_damage":
			_damage_nearest(int(data.get("chains", 3)), float(data.get("radius", 220.0)), power)
		"time_scale":
			Game.set_enemy_slow(power)
			slow_timer = float(data.get("duration", 3.0))
			_effects.append({"kind": "slow", "remaining": slow_timer, "data": data})
		"summon":
			_summon_plush(float(data.get("duration", 8.0)), power)
		"trail_damage":
			_effects.append({"kind": "fire_trail", "remaining": float(data.get("duration", 4.0)),
					"tick": 0.0, "power": power})
		"pull_shards":
			for node: Node in get_tree().get_nodes_in_group("shards"):
				if node.has_method("set_attracted"):
					node.call("set_attracted", true)
			_effects.append({"kind": "attract", "remaining": float(data.get("duration", 1.2))})
		"stealth":
			stealth_timer = float(data.get("duration", 4.0))
			Game.set_stealth(true)
			if _player is CanvasItem:
				(_player as CanvasItem).modulate.a = 0.55
		"heal":
			if _player != null and _player.has_method("heal"):
				_player.heal(power)
		"rain_damage":
			_effects.append({"kind": "rain", "remaining": float(data.get("duration", 2.0)),
					"tick": 0.0, "power": power, "radius": float(data.get("radius", 260.0))})
		"ultimate":
			_damage_nearby(float(data.get("radius", 420.0)), power, 99)
			Game.set_enemy_slow(0.35)
			_effects.append({"kind": "slow", "remaining": float(data.get("duration", 2.5)),
					"data": data})
		_:
			push_warning("SkillManager: unknown effect %s" % effect)


func _tick_effects(delta: float) -> void:
	if shield_timer > 0.0:
		shield_timer = maxf(0.0, shield_timer - delta)
	if stealth_timer > 0.0:
		stealth_timer = maxf(0.0, stealth_timer - delta)
		if stealth_timer <= 0.0:
			Game.set_stealth(false)
			if _player is CanvasItem:
				(_player as CanvasItem).modulate.a = 1.0
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			Game.set_enemy_slow(1.0)
	var finished: Array = []
	for effect: Dictionary in _effects:
		effect["remaining"] = float(effect["remaining"]) - delta
		match str(effect["kind"]):
			"fire_trail":
				effect["tick"] = float(effect["tick"]) - delta
				if float(effect["tick"]) <= 0.0:
					effect["tick"] = 0.35
					_spawn_fire_zone(float(effect["power"]))
			"rain":
				effect["tick"] = float(effect["tick"]) - delta
				if float(effect["tick"]) <= 0.0:
					effect["tick"] = 0.45
					_damage_nearby(float(effect["radius"]), float(effect["power"]), 4)
			"attract":
				pass
		if float(effect["remaining"]) <= 0.0:
			finished.append(effect)
	for effect: Dictionary in finished:
		_effects.erase(effect)


func on_shield_broken() -> void:
	AudioManager.play("skill_shield_break")
	shield_timer = 0.0


func active_effect_count() -> int:
	return _effects.size()


func _damage_nearby(radius: float, power: float, max_targets: int) -> int:
	if _player == null:
		return 0
	var hit := 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if enemy.global_position.distance_to(_player.global_position) > radius:
			continue
		enemy.take_damage(power, _player.global_position, true)
		hit += 1
		if hit >= max_targets:
			break
	return hit


func _damage_nearest(count: int, radius: float, power: float) -> int:
	if _player == null:
		return 0
	var candidates: Array = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance <= radius:
			candidates.append({"node": enemy, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"]))
	var hit := 0
	for entry: Dictionary in candidates:
		var enemy = entry["node"] as Node2D
		enemy.take_damage(power, _player.global_position, true)
		hit += 1
		if hit >= count:
			break
	return hit


func _summon_plush(duration: float, power: float) -> void:
	if _player == null:
		return
	var host := _player.get_parent()
	if host == null:
		return
	var plush := PlushFriend.new()
	plush.position = _player.global_position + Vector2(-30.0 * float(_player.get("facing")), 0.0)
	plush.setup_player(_player)
	plush.damage = power
	plush.lifetime = duration
	host.add_child(plush)


func _spawn_fire_zone(power: float) -> void:
	if _player == null:
		return
	var host := _player.get_parent()
	if host == null:
		return
	var zone := FireZone.new()
	zone.position = _player.global_position
	zone.damage = power
	host.add_child(zone)
