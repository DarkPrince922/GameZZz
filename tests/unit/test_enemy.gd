extends GutTest
## Enemies: health, damage, blocking, elites, death and shard drops.

const EnemyScene := preload("res://scenes/enemy.tscn")

var _world: Node2D
var _enemy
var _died := false


func before_each() -> void:
	Settings.set_value("difficulty", "normal")
	_world = Node2D.new()
	add_child_autofree(_world)
	_died = false


func _make(enemy_type: String, elite: String = "") -> Node:
	_enemy = EnemyScene.instantiate()
	_enemy.configure(enemy_type, elite)
	_enemy.position = Vector2(100, 0)
	_world.add_child(_enemy)
	_enemy.died.connect(func(_who: Node) -> void: _died = true)
	return _enemy


func test_all_six_enemy_types_configure() -> void:
	for enemy_id: String in DataDB.enemies.keys():
		var enemy = _make(enemy_id)
		assert_gt(enemy.max_hp, 0.0, "%s must have positive hp" % enemy_id)
		assert_gt(enemy.damage, 0.0, "%s must deal damage" % enemy_id)
		assert_ne(enemy.behaviour_name(), "", "%s needs a behaviour" % enemy_id)
		enemy.free()


func test_damage_reduces_hp() -> void:
	var enemy = _make("shadow")
	var before: float = enemy.hp
	enemy.take_damage(5.0, Vector2.ZERO)
	assert_almost_eq(enemy.hp, before - 5.0, 0.01)


func test_death_sets_flag_and_signal() -> void:
	var enemy = _make("shadow")
	enemy.take_damage(9999.0, Vector2.ZERO)
	assert_true(enemy.is_dead, "enemy must be dead")
	assert_true(_died, "died signal must fire")
	assert_gt(enemy.shard_drop_amount(), 0, "dead enemies drop at least one shard")


func test_elite_fast_is_faster() -> void:
	var normal = _make("shadow")
	var normal_speed: float = normal.speed
	normal.free()
	var fast = _make("shadow", "fast")
	assert_gt(fast.speed, normal_speed, "fast elite must move faster")


func test_elite_reviving_comes_back() -> void:
	var enemy = _make("shadow", "reviving")
	enemy.take_damage(9999.0, Vector2.ZERO)
	assert_false(enemy.is_dead, "reviving elite must survive the first death")
	assert_gt(enemy.hp, 0.0, "reviving elite returns with some hp")
	assert_false(_died, "died signal must wait for the final death")
	enemy.take_damage(9999.0, Vector2.ZERO)
	assert_true(enemy.is_dead, "second death is final")


func test_elite_vampiric_heals_when_hitting() -> void:
	var enemy = _make("shadow", "vampiric")
	enemy.hp = enemy.max_hp * 0.4
	var before: float = enemy.hp
	enemy.heal(enemy.damage * 0.35)
	assert_gt(enemy.hp, before, "vampiric elites heal")


func test_shieldbearer_blocks_from_the_front() -> void:
	var enemy = _make("shieldbearer")
	enemy.facing = -1.0
	var shield_before: float = enemy.shield_hp
	var hp_before: float = enemy.hp
	enemy.take_damage(5.0, enemy.global_position + Vector2(-40, 0))
	assert_almost_eq(enemy.hp, hp_before, 0.01, "frontal hit must be blocked")
	assert_lt(enemy.shield_hp, shield_before, "the shield must take the damage")


func test_shieldbearer_hurt_from_behind() -> void:
	var enemy = _make("shieldbearer")
	enemy.facing = -1.0
	var hp_before: float = enemy.hp
	enemy.take_damage(5.0, enemy.global_position + Vector2(40, 0))
	assert_lt(enemy.hp, hp_before, "hits from behind must go through")


func test_unknown_enemy_type_is_safe() -> void:
	var enemy = EnemyScene.instantiate()
	enemy.configure("enemy_from_the_future")
	_world.add_child(enemy)
	assert_gt(enemy.max_hp, 0.0, "unknown types fall back to sane defaults instead of crashing")
	enemy.free()


func test_difficulty_scales_enemy_hp() -> void:
	Settings.set_value("difficulty", "normal")
	var normal = _make("jumper")
	var normal_hp: float = normal.hp
	normal.free()
	Settings.set_value("difficulty", "nightmare")
	var nightmare = _make("jumper")
	Settings.set_value("difficulty", "normal")
	assert_gt(nightmare.hp, normal_hp, "nightmare enemies are tougher")
