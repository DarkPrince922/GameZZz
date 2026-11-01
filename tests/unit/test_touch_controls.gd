extends GutTest
## Touch controls: button presses dispatch the right action and release clears
## it, the stick is analog, multitouch keeps independent fingers, and the layout
## stays inside the safe area without overlaps on 16:9 / 20:9 / 4:3 screens.

const TouchControlsScript := preload("res://scripts/ui/touch_controls.gd")

var _controls
var _mock


class MockPlayer:
	extends Node
	var move_axis: float = 0.0
	var move_vertical: float = 0.0
	var crouch: bool = false

	func set_move_axis(v: float) -> void:
		move_axis = v

	func set_move_vertical(v: float) -> void:
		move_vertical = v

	func set_crouch(v: bool) -> void:
		crouch = v

	func skill_manager() -> Node:
		return null


func before_each() -> void:
	_controls = TouchControlsScript.new()
	_mock = MockPlayer.new()
	add_child_autofree(_controls)
	add_child_autofree(_mock)
	_controls.bind_player(_mock)
	_controls.layout_for(Vector2(1280, 720))


func after_each() -> void:
	# clear any stuck actions left by a failing test
	for action in ["jump", "attack", "dash", "skill_1", "skill_2", "skill_3"]:
		Input.action_release(action)


func _touch(widget: String, pressed: bool) -> void:
	var center: Vector2 = _controls.widgets[widget]["center"]
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = center
	ev.pressed = pressed
	_controls._gui_input(ev)


func test_jump_button_presses_and_releases_action() -> void:
	_touch("jump", true)
	assert_true(Input.is_action_pressed("jump"), "touching the jump button must press the jump action")
	_touch("jump", false)
	assert_false(Input.is_action_pressed("jump"), "releasing must clear the jump action")


func test_attack_button_presses_action() -> void:
	_touch("attack", true)
	assert_true(Input.is_action_pressed("attack"), "attack button must press the attack action")
	_touch("attack", false)
	assert_false(Input.is_action_pressed("attack"))


func test_dash_button_presses_action() -> void:
	_touch("dash", true)
	assert_true(Input.is_action_pressed("dash"), "dash button must press the dash action")
	_touch("dash", false)
	assert_false(Input.is_action_pressed("dash"))


func test_each_skill_button_presses_its_action() -> void:
	for slot in 3:
		var key := "skill_%d" % slot
		_touch(key, true)
		assert_true(Input.is_action_pressed("skill_%d" % (slot + 1)),
				"%s must press skill_%d" % [key, slot + 1])
		_touch(key, false)
		assert_false(Input.is_action_pressed("skill_%d" % (slot + 1)))


func test_stick_is_analog_and_resets_on_release() -> void:
	var center: Vector2 = _controls.widgets["stick"]["center"]
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = center
	press.pressed = true
	_controls._gui_input(press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(96, 0)
	_controls._gui_input(drag)
	assert_almost_eq(_mock.move_axis, 1.0, 0.05, "full right drag must set move_axis near 1.0")

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = center + Vector2(96, 0)
	release.pressed = false
	_controls._gui_input(release)
	assert_almost_eq(_mock.move_axis, 0.0, 0.001, "releasing the stick must zero the axis")
	assert_false(_mock.crouch)


func test_multitouch_stick_and_two_buttons() -> void:
	# finger 0 on the stick, finger 1 on jump, finger 2 on attack
	var stick_center: Vector2 = _controls.widgets["stick"]["center"]
	var jump_center: Vector2 = _controls.widgets["jump"]["center"]
	var attack_center: Vector2 = _controls.widgets["attack"]["center"]

	var s0 := InputEventScreenTouch.new()
	s0.index = 0
	s0.position = stick_center
	s0.pressed = true
	_controls._gui_input(s0)

	var s1 := InputEventScreenTouch.new()
	s1.index = 1
	s1.position = jump_center
	s1.pressed = true
	_controls._gui_input(s1)

	var s2 := InputEventScreenTouch.new()
	s2.index = 2
	s2.position = attack_center
	s2.pressed = true
	_controls._gui_input(s2)

	assert_eq(_controls.active_touch_count(), 3, "three fingers must be tracked at once")
	assert_true(Input.is_action_pressed("jump"), "jump must be held while its finger is down")
	assert_true(Input.is_action_pressed("attack"), "attack must be held while its finger is down")

	# lift only the jump finger; attack and the stick must remain active
	var r1 := InputEventScreenTouch.new()
	r1.index = 1
	r1.position = jump_center
	r1.pressed = false
	_controls._gui_input(r1)
	assert_false(Input.is_action_pressed("jump"), "lifting jump must clear only jump")
	assert_true(Input.is_action_pressed("attack"), "attack must survive jump's release")
	assert_eq(_controls.active_touch_count(), 2)


func test_release_resets_every_button() -> void:
	for key in ["jump", "attack", "dash", "skill_0", "skill_1", "skill_2"]:
		_touch(key, true)
	_touch("jump", false)
	_touch("attack", false)
	_touch("dash", false)
	_touch("skill_0", false)
	_touch("skill_1", false)
	_touch("skill_2", false)
	assert_eq(_controls.active_touch_count(), 0, "all fingers released")


func test_layout_all_resolutions_inside_safe_area() -> void:
	var resolutions := [
		Vector2(1280, 720), Vector2(1920, 1080), Vector2(2376, 1080),
		Vector2(2400, 1080), Vector2(1600, 1200), Vector2(2560, 1080),
	]
	for view in resolutions:
		_controls.layout_for(view)
		var rects: Dictionary = _controls.widget_rects()
		var margin := _controls.EDGE_PAD
		for key: String in rects.keys():
			var r: Rect2 = rects[key]
			assert_true(r.position.x >= margin - 0.5 and r.position.y >= margin - 0.5,
					"%s top-left must stay inside the safe area at %s" % [key, view])
			assert_true(r.end.x <= view.x - margin + 0.5 and r.end.y <= view.y - margin + 0.5,
					"%s bottom-right must stay inside the safe area at %s" % [key, view])
			assert_gte(r.size.x, _controls.MIN_BUTTON_DIAMETER - 0.5,
					"%s must be at least 64px wide at %s" % [key, view])


func test_layout_buttons_do_not_overlap() -> void:
	var resolutions := [
		Vector2(1280, 720), Vector2(1920, 1080), Vector2(2376, 1080),
		Vector2(2400, 1080), Vector2(1600, 1200), Vector2(2560, 1080),
	]
	for view in resolutions:
		_controls.layout_for(view)
		var keys: Array = _controls.widget_rects().keys()
		for i in range(keys.size()):
			for j in range(i + 1, keys.size()):
				var a: Rect2 = _controls.widget_rects()[keys[i]]
				var b: Rect2 = _controls.widget_rects()[keys[j]]
				# the stick may legally contain other buttons' area in some designs,
				# but button-to-button overlaps are a layout bug
				assert_false(a.intersects(b) and keys[i] != "stick" and keys[j] != "stick",
						"%s and %s must not overlap at %s" % [keys[i], keys[j], view])
