extends Control
## Equipment: pick one weapon and three skills. Saves immediately, so the next
## run starts with the chosen loadout.

const Theme := preload("res://scripts/ui/ui_theme.gd")

var _weapon_row: HBoxContainer
var _skill_grid: GridContainer
var _status: Label
var _error: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Theme.background(self)
	AudioManager.play_music("music_menu")
	var view := get_viewport_rect().size
	var title := Theme.make_label(self, Loc.text("equip"), Vector2(60.0, 36.0), 42)
	title.add_theme_color_override("font_color", Theme.ACCENT)
	Theme.make_label(self, Loc.text("equip_weapon"), Vector2(60.0, 104.0), 24, Theme.MUTED)
	_weapon_row = HBoxContainer.new()
	_weapon_row.position = Vector2(60.0, 140.0)
	_weapon_row.add_theme_constant_override("separation", 12)
	add_child(_weapon_row)
	Theme.make_label(self, Loc.text("equip_title"), Vector2(60.0, 240.0), 24, Theme.MUTED)
	_skill_grid = GridContainer.new()
	_skill_grid.columns = 4
	_skill_grid.position = Vector2(60.0, 276.0)
	_skill_grid.add_theme_constant_override("h_separation", 12)
	_skill_grid.add_theme_constant_override("v_separation", 12)
	add_child(_skill_grid)
	_status = Theme.make_label(self, "", Vector2(60.0, view.y - 156.0), 20, Theme.MUTED)
	_error = Theme.make_label(self, "", Vector2(60.0, view.y - 126.0), 20, Theme.DANGER)
	var back := Theme.make_button(self, Loc.text("back"), Vector2(60.0, view.y - 76.0),
			Vector2(200, 54))
	back.pressed.connect(func() -> void: Game.goto_menu())
	_refresh()


func _refresh() -> void:
	for child: Node in _weapon_row.get_children():
		child.queue_free()
	for weapon_id: String in DataDB.weapons.keys():
		_weapon_row.add_child(_weapon_button(weapon_id))
	for child: Node in _skill_grid.get_children():
		child.queue_free()
	for skill_id: String in DataDB.skills.keys():
		_skill_grid.add_child(_skill_button(skill_id))
	var equipped: Array = SaveManager.equipped_skills()
	_status.text = "%s: %s" % [Loc.text("equipped"), ", ".join(
			equipped.map(func(id: Variant) -> String: return Loc.text(str(id))))]


func _weapon_button(weapon_id: String) -> Button:
	var data := DataDB.weapon(weapon_id)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(230, 72)
	button.add_theme_font_size_override("font_size", 18)
	var owned := SaveManager.owns_weapon(weapon_id)
	button.text = Loc.text(str(data.get("name_key", weapon_id)))
	if SaveManager.equipped_weapon() == weapon_id:
		button.text += "  ✔"
	if not owned:
		button.text += "\n" + Loc.text("locked")
		button.disabled = true
	else:
		button.pressed.connect(func() -> void:
			SaveManager.set_weapon(weapon_id)
			AudioManager.play("ui_toggle")
			_error.text = ""
			_refresh()
		)
	return button


func _skill_button(skill_id: String) -> Button:
	var data := DataDB.skill(skill_id)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(280, 76)
	button.add_theme_font_size_override("font_size", 18)
	var equipped: Array = SaveManager.equipped_skills()
	var is_equipped := equipped.has(skill_id)
	button.text = Loc.text(str(data.get("name_key", skill_id)))
	if is_equipped:
		button.text += "  ✔"
	button.pressed.connect(func() -> void: _toggle_skill(skill_id))
	return button


func _toggle_skill(skill_id: String) -> void:
	var equipped: Array = SaveManager.equipped_skills()
	if equipped.has(skill_id):
		equipped.erase(skill_id)
		SaveManager.set_equipped_skills(equipped)
		AudioManager.play("ui_toggle")
		_error.text = ""
	else:
		if equipped.size() >= 3:
			AudioManager.play("ui_denied")
			_error.text = Loc.text("not_enough_slots")
			return
		equipped.append(skill_id)
		SaveManager.set_equipped_skills(equipped)
		AudioManager.play("ui_purchase")
		_error.text = ""
	_refresh()
