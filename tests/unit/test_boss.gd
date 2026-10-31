extends GutTest
## Boss framework: phases, weak point windows, stun and death.

const BossScene := preload("res://scenes/boss.tscn")

var _world: Node2D
var _boss
var _phase_events: Array = []
var _died := false


func before_each() -> void:
	Settings.set_value("difficulty", "normal")
	_world = Node2D.new()
	add_child_autofree(_world)
	_phase_events.clear()
	_died = false
	_boss = BossScene.instantiate()
	_boss.position = Vector2(0, 0)
	_world.add_child(_boss)
	_boss.configure("bed_monster")
	_boss.phase_changed.connect(func(index: int) -> void: _phase_events.append(index))
	_boss.died.connect(func() -> void: _died = true)


func test_boss_has_three_phases() -> void:
	var phases: Array = DataDB.boss("bed_monster").get("phases", [])
	assert_eq(phases.size(), 3, "the Bed Monster is a three-phase fight")
	assert_almost_eq(_boss.max_hp, 420.0, 0.5)


func test_phase_for_ratio() -> void:
	assert_eq(_boss.phase_for_ratio(1.0), 0)
	assert_eq(_boss.phase_for_ratio(0.7), 0)
	assert_eq(_boss.phase_for_ratio(0.5), 1)
	assert_eq(_boss.phase_for_ratio(0.2), 2)
	assert_eq(_boss.phase_for_ratio(0.0), 2)


func test_phase_changes_when_health_drops() -> void:
	_boss.take_damage(_boss.max_hp * 0.8, Vector2.ZERO)
	assert_eq(_boss.phase_index, 1, "crossing 66% moves the boss to phase 2")
	assert_eq(_phase_events, [1], "phase_changed must fire once")
	_boss.take_damage(_boss.max_hp * 0.8, Vector2.ZERO)
	assert_eq(_boss.phase_index, 2, "crossing 33% moves the boss to phase 3")


func test_armour_reduces_damage_when_not_vulnerable() -> void:
	var before: float = _boss.hp
	_boss.take_damage(100.0, Vector2.ZERO)
	var armoured_loss: float = before - _boss.hp
	_boss._set_vulnerable(true)
	before = _boss.hp
	_boss.take_damage(100.0, Vector2.ZERO)
	var exposed_loss: float = before - _boss.hp
	assert_lt(armoured_loss, exposed_loss, "an exposed boss takes more damage")


func test_weak_point_hit_while_exposed_hurts_more() -> void:
	_boss._set_vulnerable(true)
	var weak_point: Vector2 = _boss.global_position + _boss.weak_point_offset()
	var before: float = _boss.hp
	_boss.take_damage(50.0, weak_point)
	var weak_loss: float = before - _boss.hp
	before = _boss.hp
	_boss.take_damage(50.0, _boss.global_position + Vector2(200, 200))
	var body_loss: float = before - _boss.hp
	assert_gt(weak_loss, body_loss, "hitting the glowing weak point must pay off")


func test_stun_window_opens_after_attacks() -> void:
	_boss.attacks_since_stun = 0
	for i in 3:
		_boss._execute_attack("claw")
	assert_true(_boss.is_vulnerable(), "after the attack streak the boss must become vulnerable")
	assert_gt(_boss.stun_timer, 0.0, "and stay exposed for the stun duration")


func test_every_attack_in_phases_has_data() -> void:
	var attacks: Dictionary = DataDB.boss("bed_monster").get("attacks", {})
	for phase: Variant in DataDB.boss("bed_monster").get("phases", []):
		for attack_name: Variant in (phase as Dictionary).get("attacks", []):
			assert_true(attacks.has(str(attack_name)),
				"phase attack %s must exist in attacks" % attack_name)
			var entry: Dictionary = attacks[str(attack_name)]
			assert_true(entry.has("telegraph"), "%s needs a telegraph time" % attack_name)
			assert_true(entry.has("telegraph_sfx"), "%s needs a telegraph sound" % attack_name)
			assert_true(entry.has("sfx"), "%s needs its own sound" % attack_name)


func test_boss_dies_at_zero_hp() -> void:
	_boss.take_damage(99999.0, Vector2.ZERO)
	assert_true(_boss.is_dead, "boss must die")
	assert_true(_died, "died signal must fire")


func test_boss_ignores_damage_after_death() -> void:
	_boss.take_damage(99999.0, Vector2.ZERO)
	var hp_after: float = _boss.hp
	_boss.take_damage(100.0, Vector2.ZERO)
	assert_almost_eq(_boss.hp, hp_after, 0.01, "no further damage after death")


func test_boss_attack_sounds_exist_in_registry() -> void:
	for attack_name: Variant in DataDB.boss("bed_monster").get("attacks", {}).keys():
		var entry: Dictionary = DataDB.boss("bed_monster")["attacks"][attack_name]
		assert_false(DataDB.sound_event(str(entry["sfx"])).is_empty(),
			"%s sound missing from registry" % attack_name)
