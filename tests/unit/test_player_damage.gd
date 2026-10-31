extends GutTest
## Damage, invincibility, shield and respawn. Spec stage 1 requires these tests.

const PlayerScene := preload("res://scenes/player.tscn")

var _world: Node2D
var _player


func before_each() -> void:
	Settings.set_value("difficulty", "normal")
	_world = Node2D.new()
	add_child_autofree(_world)
	_player = PlayerScene.instantiate()
	_player.keyboard_enabled = false
	_player.position = Vector2(0, -200)
	_world.add_child(_player)
	await wait_physics_frames(2)


func test_damage_reduces_health() -> void:
	var before: float = _player.hp
	_player.take_damage(15.0, Vector2(10, 0))
	assert_almost_eq(_player.hp, before - 15.0, 0.8, "damage must reduce hp")


func test_invincibility_blocks_repeated_hits() -> void:
	_player.take_damage(10.0, Vector2.ZERO)
	var after_first: float = _player.hp
	_player.take_damage(10.0, Vector2.ZERO)
	assert_almost_eq(_player.hp, after_first, 0.01,
		"a second hit inside the invincibility window must be ignored")


func test_invincibility_expires() -> void:
	_player.take_damage(10.0, Vector2.ZERO)
	var after_first: float = _player.hp
	await wait_physics_frames(80)
	_player.take_damage(10.0, Vector2.ZERO)
	assert_lt(_player.hp, after_first, "damage must work again after invincibility ends")


func test_shield_absorbs_damage() -> void:
	var before: float = _player.hp
	_player.apply_shield(20.0)
	_player.take_damage(10.0, Vector2.ZERO)
	assert_almost_eq(_player.hp, before, 0.01, "shield must absorb the hit")
	_player.take_damage(10.0, Vector2.ZERO)
	assert_almost_eq(_player.hp, before, 0.01, "shield must absorb a second hit")


func test_death_and_respawn() -> void:
	var deaths_before: int = int(SaveManager.data.get("deaths", 0))
	_player.take_damage(9999.0, Vector2.ZERO)
	assert_true(_player.is_dead(), "player must die at zero hp")
	assert_eq(int(SaveManager.data.get("deaths", 0)), deaths_before + 1,
		"death counter must be persisted")
	await wait_physics_frames(100)
	assert_false(_player.is_dead(), "player must respawn after the delay")
	assert_almost_eq(_player.hp, _player.max_hp, 0.5, "respawn restores full health")


func test_heal_is_capped() -> void:
	_player.take_damage(20.0, Vector2.ZERO)
	await wait_physics_frames(70)
	_player.heal(999.0)
	assert_almost_eq(_player.hp, _player.max_hp, 0.01, "healing must not exceed max hp")


func test_easy_difficulty_reduces_damage() -> void:
	Settings.set_value("difficulty", "easy")
	var before: float = _player.hp
	_player.take_damage(20.0, Vector2.ZERO)
	var easy_loss: float = before - _player.hp
	Settings.set_value("difficulty", "normal")
	_player.invincible_timer = 0.0
	before = _player.hp
	_player.take_damage(20.0, Vector2.ZERO)
	var normal_loss: float = before - _player.hp
	assert_lt(easy_loss, normal_loss, "easy mode must hurt less")
