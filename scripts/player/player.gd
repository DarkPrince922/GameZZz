extends CharacterBody2D
## The child with the light: movement, health, damage, respawn and combat hooks.
## Input is pushed in by TouchControls (multitouch) or read from the keyboard in
## desktop mode, so both paths use exactly the same movement code.

signal health_changed(current: float, maximum: float)
signal died()
signal respawned()
signal damaged(amount: float)
signal landed()
signal jumped(is_double: bool)
signal low_health()

enum State { NORMAL, CROUCH, CLIMB, DASH, DEAD }

const STEP_INTERVAL := 0.28
const COMBAT := preload("res://scripts/core/combat_math.gd")

var state: int = State.NORMAL
var hp: float = 100.0
var max_hp: float = 100.0
var facing: float = 1.0
var checkpoint: Vector2 = Vector2.ZERO
var keyboard_enabled: bool = true
var shield_hp: float = 0.0
var invincible_timer: float = 0.0
var move_axis: float = 0.0
var move_vertical: float = 0.0
var crouch_requested: bool = false

var _tuning: Dictionary = {}
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _jumps_left: int = 1
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _step_timer: float = 0.0
var _was_on_floor: bool = true
var _on_ladder: bool = false
var _keyboard_active: bool = false
var _respawn_timer: float = 0.0
var _low_health_announced: bool = false
var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _camera: Camera2D
var _weapon
var _skill_manager
var _flash: Color = Color(1.0, 0.62, 0.72)


func _ready() -> void:
	add_to_group("player")
	_tuning = DataDB.player_tuning()
	max_hp = _tuning.get("max_hp", 100.0)
	if get_node_or_null("/root/Game") != null:
		max_hp = Game.max_hp()
	hp = max_hp
	collision_layer = 1
	collision_mask = 2
	_build_body()
	_build_camera()
	_skill_manager = load("res://scripts/skills/skill_manager.gd").new()
	_skill_manager.name = "SkillManager"
	add_child(_skill_manager)
	_weapon = load("res://scripts/player/weapon_controller.gd").new()
	_weapon.name = "WeaponController"
	add_child(_weapon)
	checkpoint = global_position
	health_changed.emit(hp, max_hp)
	queue_redraw()


func _build_body() -> void:
	_shape = CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = Vector2(_tuning.get("body_width", 26.0), _tuning.get("stand_height", 46.0))
	_shape.shape = _rect
	add_child(_shape)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.zoom = Vector2(1.0, 1.0)
	add_child(_camera)
	_camera.make_current()


func camera() -> Camera2D:
	return _camera


func weapon_controller() -> Node:
	return _weapon


func skill_manager() -> Node:
	return _skill_manager


# ------------------------------------------------------------------- input API
func set_move_axis(axis: float) -> void:
	move_axis = clampf(axis, -1.0, 1.0)


func set_move_vertical(axis: float) -> void:
	move_vertical = clampf(axis, -1.0, 1.0)


func press_jump() -> void:
	_jump_buffer = _tuning.get("jump_buffer_time", 0.13)


func press_attack() -> void:
	if state == State.DEAD:
		return
	if _weapon != null:
		_weapon.attack()


func press_skill(slot: int) -> void:
	if state == State.DEAD:
		return
	if _skill_manager != null:
		_skill_manager.activate_slot(slot)


func press_dash() -> void:
	if not _can_dash():
		return
	_start_dash()


func set_crouch(pressed: bool) -> void:
	crouch_requested = pressed
	if pressed and state == State.NORMAL and is_on_floor():
		_enter_crouch()
	elif not pressed and state == State.CROUCH:
		_exit_crouch()


# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return
	if keyboard_enabled:
		_read_keyboard()
	_on_ladder = _ladder_at(global_position)
	_handle_climb(delta)
	if state == State.DASH:
		velocity.y = 0.0
	elif state != State.CLIMB:
		_handle_horizontal(delta)
		_apply_gravity(delta)
	_handle_jump()
	var was_floor := is_on_floor()
	move_and_slide()
	_after_move(was_floor)
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_coyote = maxf(0.0, _coyote - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	if state == State.DASH:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			state = State.NORMAL
			velocity.x *= 0.4
	if state == State.DEAD:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()


func _read_keyboard() -> void:
	var axis := 0.0
	if Input.is_action_pressed("move_left"):
		axis -= 1.0
	if Input.is_action_pressed("move_right"):
		axis += 1.0
	if axis != 0.0:
		move_axis = axis
		_keyboard_active = true
	elif _keyboard_active:
		move_axis = 0.0
		_keyboard_active = false
	if Input.is_action_just_pressed("jump"):
		press_jump()
	if Input.is_action_just_pressed("attack"):
		press_attack()
	if Input.is_action_just_pressed("dash"):
		press_dash()
	for slot in 3:
		if Input.is_action_just_pressed("skill_%d" % (slot + 1)):
			press_skill(slot)
	if Input.is_action_pressed("crouch") or Input.is_action_pressed("move_down"):
		set_crouch(true)
	elif Input.is_action_just_released("crouch") or Input.is_action_just_released("move_down"):
		set_crouch(false)


func _handle_horizontal(delta: float) -> void:
	var speed: float = _tuning.get("run_speed", 260.0)
	if get_node_or_null("/root/Game") != null:
		speed *= Game.speed_multiplier()
	if state == State.CROUCH:
		speed *= _tuning.get("crouch_speed_mult", 0.45)
	var target := move_axis * speed
	var accel: float = _tuning.get("acceleration", 1900.0)
	var friction: float = _tuning.get("friction", 2200.0)
	var rate := accel if absf(move_axis) > 0.01 else friction
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if absf(move_axis) > 0.01:
		facing = signf(move_axis)


func _apply_gravity(delta: float) -> void:
	var gravity: float = _tuning.get("gravity", 1400.0)
	velocity.y = minf(velocity.y + gravity * delta, _tuning.get("max_fall_speed", 900.0))


func _handle_jump() -> void:
	if is_on_floor() and state != State.CLIMB:
		_coyote = _tuning.get("coyote_time", 0.12)
		_jumps_left = _air_jumps() + 1
	if _jump_buffer <= 0.0:
		return
	if state == State.CLIMB:
		state = State.NORMAL
		velocity.y = _tuning.get("jump_velocity", -560.0)
		_jump_buffer = 0.0
		AudioManager.play("hero_jump")
		jumped.emit(false)
		return
	if _coyote > 0.0 and _jumps_left > 0:
		velocity.y = _tuning.get("jump_velocity", -560.0)
		_jumps_left -= 1
		_coyote = 0.0
		_jump_buffer = 0.0
		AudioManager.play("hero_jump")
		jumped.emit(false)
	elif _jumps_left > 0 and _can_double_jump():
		velocity.y = _tuning.get("double_jump_velocity", -500.0)
		_jumps_left -= 1
		_jump_buffer = 0.0
		AudioManager.play("hero_double_jump")
		jumped.emit(true)


func _air_jumps() -> int:
	if _can_double_jump():
		return 1
	return 0


func _can_double_jump() -> bool:
	if get_node_or_null("/root/Game") == null:
		return true
	return Game.has_double_jump()


func _after_move(was_floor: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_floor:
		AudioManager.play("hero_land")
		landed.emit()
		if Settings.vibration:
			Settings.vibrate(18, 0.35)
	if on_floor and absf(velocity.x) > 12.0 and state != State.CROUCH:
		_step_timer -= get_physics_process_delta_time()
		if _step_timer <= 0.0:
			_step_timer = STEP_INTERVAL
			AudioManager.play("hero_step")
	if not on_floor and _coyote <= 0.0 and _jumps_left == _air_jumps() + 1:
		# walked off a ledge: consume the ground jump so only air jumps remain
		_jumps_left = _air_jumps()
	_was_on_floor = on_floor


func _handle_climb(delta: float) -> void:
	if not _on_ladder:
		if state == State.CLIMB:
			state = State.NORMAL
		return
	var up_pressed := Input.is_action_pressed("move_up") or move_vertical < -0.3
	var down_pressed := Input.is_action_pressed("move_down") or move_vertical > 0.3
	if up_pressed or down_pressed:
		state = State.CLIMB
		velocity.x = 0.0
		velocity.y = -_tuning.get("climb_speed", 150.0) if up_pressed \
				else _tuning.get("climb_speed", 150.0)
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = STEP_INTERVAL * 1.4
			AudioManager.play("hero_climb")
	elif state == State.CLIMB:
		velocity = Vector2.ZERO


func _ladder_at(point: Vector2) -> bool:
	for node: Node in get_tree().get_nodes_in_group("ladders"):
		var area := node as Area2D
		if area == null:
			continue
		var rect_size: Vector2 = area.get_meta("size", Vector2(32, 128))
		var rect := Rect2(area.global_position - rect_size / 2.0, rect_size)
		if rect.has_point(point):
			return true
	return false


func _enter_crouch() -> void:
	state = State.CROUCH
	_rect.size = Vector2(_tuning.get("body_width", 26.0), _tuning.get("crouch_height", 26.0))
	_shape.position.y = (_tuning.get("stand_height", 46.0) - _tuning.get("crouch_height", 26.0)) / 2.0
	AudioManager.play("hero_crouch")
	queue_redraw()


func _exit_crouch() -> void:
	state = State.NORMAL
	_rect.size = Vector2(_tuning.get("body_width", 26.0), _tuning.get("stand_height", 46.0))
	_shape.position.y = 0.0
	queue_redraw()


func _can_dash() -> bool:
	if state == State.DEAD or state == State.DASH:
		return false
	if _dash_cooldown > 0.0:
		return false
	if get_node_or_null("/root/Game") != null and not Game.has_dash():
		return false
	return true


func _start_dash() -> void:
	state = State.DASH
	_dash_timer = _tuning.get("dash_time", 0.18)
	_dash_cooldown = _tuning.get("dash_cooldown", 0.7)
	velocity = Vector2(facing * _tuning.get("dash_speed", 640.0), 0.0)
	AudioManager.play("hero_dash")
	invincible_timer = maxf(invincible_timer, _dash_timer)


# ------------------------------------------------------------------ health
func is_dead() -> bool:
	return state == State.DEAD


func is_invincible() -> bool:
	return invincible_timer > 0.0


func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or invincible_timer > 0.0 or amount <= 0.0:
		return
	var scaled := amount
	if get_node_or_null("/root/Settings") != null:
		scaled = COMBAT.damage_taken(amount, Settings.difficulty)
	if shield_hp > 0.0:
		var absorbed := minf(shield_hp, scaled)
		shield_hp -= absorbed
		scaled -= absorbed
		if shield_hp <= 0.0 and _skill_manager != null:
			_skill_manager.on_shield_broken()
		if scaled <= 0.0:
			AudioManager.play("combat_block")
			invincible_timer = 0.25
			return
	hp = maxf(0.0, hp - scaled)
	invincible_timer = _tuning.get("invincible_time", 1.0)
	var knock: float = _tuning.get("hurt_knockback", 260.0)
	if from_position != Vector2.ZERO:
		var dir := signf(global_position.x - from_position.x)
		velocity.x = dir * knock if dir != 0.0 else -facing * knock
		velocity.y = -180.0
	AudioManager.play("hero_hurt")
	if Settings.vibration:
		Settings.vibrate(40, 0.8)
	damaged.emit(scaled)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	elif hp / max_hp <= float(_tuning.get("low_health_threshold", 0.3)) and not _low_health_announced:
		_low_health_announced = true
		AudioManager.play("hero_low_health")
		low_health.emit()


func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	if hp / max_hp > float(_tuning.get("low_health_threshold", 0.3)):
		_low_health_announced = false
	health_changed.emit(hp, max_hp)


func apply_shield(amount: float) -> void:
	shield_hp = maxf(shield_hp, amount)


func is_shielded() -> bool:
	return shield_hp > 0.0


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_respawn_timer = _tuning.get("respawn_delay", 1.2)
	AudioManager.play("hero_death")
	collision_layer = 0
	died.emit()
	if get_node_or_null("/root/Game") != null:
		Game.note_death()
	queue_redraw()


func _respawn() -> void:
	state = State.NORMAL
	hp = max_hp
	shield_hp = 0.0
	_low_health_announced = false
	global_position = checkpoint
	velocity = Vector2.ZERO
	collision_layer = 1
	invincible_timer = 1.5
	AudioManager.play("hero_respawn")
	health_changed.emit(hp, max_hp)
	respawned.emit()
	queue_redraw()


func set_checkpoint(point: Vector2) -> void:
	checkpoint = point


func _draw() -> void:
	var half := _rect.size / 2.0 if _rect != null else Vector2(13, 23)
	var body_color := Color(0.94, 0.95, 1.0)
	if invincible_timer > 0.0 and int(invincible_timer * 12.0) % 2 == 0:
		body_color = _flash
	if state == State.DEAD:
		body_color = Color(0.5, 0.5, 0.6, 0.5)
	draw_rect(Rect2(-half, _rect.size if _rect != null else Vector2(26, 46)), body_color)
	# the light in his hands
	var lamp := Vector2(facing * half.x * 0.9, -2.0)
	draw_circle(lamp, 16.0, Color(1.0, 0.86, 0.45, 0.20))
	draw_circle(lamp, 7.0, Color(1.0, 0.95, 0.7, 0.95))
	if shield_hp > 0.0:
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.8), 3.0)
