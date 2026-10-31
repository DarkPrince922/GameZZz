extends GutTest
## Movement: gravity, running, jumping, coyote time, jump buffer, double jump,
## dash gating and crouching. Uses a small test room built in code.

const PlayerScene := preload("res://scenes/player.tscn")

var _world: Node2D
var _player


func before_each() -> void:
	SaveManager.set_upgrade_level("ability_double_jump", 0)
	SaveManager.set_upgrade_level("ability_dash", 0)
	_world = Node2D.new()
	add_child_autofree(_world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 40)
	_world.add_child(floor_body)
	_player = PlayerScene.instantiate()
	_player.keyboard_enabled = false
	_player.position = Vector2(0, -300)
	_world.add_child(_player)


func after_each() -> void:
	SaveManager.set_upgrade_level("ability_double_jump", 0)
	SaveManager.set_upgrade_level("ability_dash", 0)


func _settle() -> void:
	for i in 90:
		await wait_physics_frames(1)
		if _player.is_on_floor():
			return


func test_player_falls_and_lands() -> void:
	await _settle()
	assert_true(_player.is_on_floor(), "player must land on the floor")
	assert_almost_eq(_player.velocity.y, 0.0, 5.0, "vertical speed must settle on ground")


func test_runs_right() -> void:
	await _settle()
	var start_x: float = _player.position.x
	_player.set_move_axis(1.0)
	await wait_physics_frames(30)
	assert_gt(_player.position.x - start_x, 20.0, "player should move to the right")
	assert_gt(_player.velocity.x, 0.0)


func test_runs_left_and_faces_left() -> void:
	await _settle()
	_player.set_move_axis(-1.0)
	await wait_physics_frames(20)
	assert_lt(_player.velocity.x, 0.0)
	assert_lt(_player.facing, 0.0, "facing must flip")


func test_jump_leaves_the_ground() -> void:
	await _settle()
	_player.press_jump()
	await wait_physics_frames(3)
	assert_lt(_player.velocity.y, 0.0, "jump must give upward velocity")
	assert_false(_player.is_on_floor())


func test_double_jump_is_locked_by_default() -> void:
	await _settle()
	_player.press_jump()
	await wait_physics_frames(8)
	var before: float = _player.velocity.y
	_player.press_jump()
	await wait_physics_frames(2)
	assert_gt(_player.velocity.y, before, "without the upgrade a second press must not lift the player")


func test_double_jump_after_unlock() -> void:
	SaveManager.set_upgrade_level("ability_double_jump", 1)
	await _settle()
	_player.press_jump()
	await wait_physics_frames(8)
	_player.press_jump()
	await wait_physics_frames(2)
	assert_lt(_player.velocity.y, 0.0, "double jump must push the player up again")


func test_coyote_time_allows_late_jump() -> void:
	await _settle()
	_player.position.x = 1800.0
	await wait_physics_frames(1)
	# step off the edge of the floor (floor ends at x = 2000)
	_player.set_move_axis(1.0)
	for i in 40:
		await wait_physics_frames(1)
		if not _player.is_on_floor():
			break
	_player.press_jump()
	await wait_physics_frames(2)
	assert_lt(_player.velocity.y, 0.0, "jump shortly after leaving the ledge must still work")


func test_jump_buffer_presses_before_landing() -> void:
	await _settle()
	_player.position.y -= 24.0
	_player.velocity = Vector2(0.0, 350.0)
	await wait_physics_frames(1)
	_player.press_jump()
	var jumped := false
	for i in 40:
		await wait_physics_frames(1)
		if _player.velocity.y < -50.0:
			jumped = true
			break
	assert_true(jumped, "a jump pressed slightly before landing must fire on landing")


func test_dash_requires_unlock() -> void:
	await _settle()
	_player.facing = 1.0
	_player.press_dash()
	await wait_physics_frames(2)
	assert_lt(absf(_player.velocity.x), 100.0, "dash must not work before it is unlocked")


func test_dash_after_unlock() -> void:
	SaveManager.set_upgrade_level("ability_dash", 1)
	await _settle()
	_player.facing = 1.0
	_player.press_dash()
	await wait_physics_frames(2)
	assert_gt(absf(_player.velocity.x), 300.0, "unlocked dash must move the player fast")
	assert_true(_player.is_invincible(), "dash gives a short invincibility window")


func test_crouch_changes_state_and_height() -> void:
	await _settle()
	var stand_height: float = _player._rect.size.y
	_player.set_crouch(true)
	await wait_physics_frames(2)
	assert_eq(_player.state, 1, "state must be CROUCH (enum value 1)")
	assert_lt(_player._rect.size.y, stand_height, "crouching must lower the hitbox")
	_player.set_crouch(false)
	await wait_physics_frames(2)
	assert_eq(_player.state, _player.State.NORMAL)


func test_speed_upgrade_increases_run_speed() -> void:
	await _settle()
	SaveManager.set_upgrade_level("speed", 0)
	_player.set_move_axis(1.0)
	await wait_physics_frames(40)
	var base_speed: float = _player.velocity.x
	SaveManager.set_upgrade_level("speed", 5)
	await wait_physics_frames(40)
	var upgraded_speed: float = _player.velocity.x
	SaveManager.set_upgrade_level("speed", 0)
	assert_gt(upgraded_speed, base_speed, "speed upgrade must be visible in movement")
