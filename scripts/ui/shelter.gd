extends Control
## Shelter: permanent upgrades bought with dream shards.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _rows: VBoxContainer
var _shards_label: Label
var _error: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UITheme.background(self)
	AudioManager.play_music("music_shelter")
	var view := get_viewport_rect().size
	var title := UITheme.make_label(self, Loc.text("shelter"), Vector2(60.0, 40.0), 42)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	UITheme.make_label(self, Loc.text("shelter_hint"), Vector2(60.0, 96.0), 20, UITheme.MUTED)
	_shards_label = UITheme.make_label(self, "", Vector2(view.x - 340.0, 46.0), 24,
			Color(0.8, 0.92, 1.0))
	_rows = VBoxContainer.new()
	_rows.position = Vector2(60.0, 140.0)
	_rows.add_theme_constant_override("separation", 10)
	add_child(_rows)
	_error = UITheme.make_label(self, "", Vector2(60.0, view.y - 120.0), 20, UITheme.DANGER)
	var back := UITheme.make_button(self, Loc.text("back"), Vector2(60.0, view.y - 76.0),
			Vector2(200, 54))
	back.pressed.connect(func() -> void: Game.goto_menu())
	_refresh()


func _refresh() -> void:
	_shards_label.text = "%s: %d" % [Loc.text("shards"), SaveManager.shards()]
	for child: Node in _rows.get_children():
		child.queue_free()
	for upgrade_id: String in DataDB.upgrades.keys():
		_rows.add_child(_upgrade_row(upgrade_id))


func _upgrade_row(upgrade_id: String) -> HBoxContainer:
	var data := DataDB.upgrade(upgrade_id)
	var level := SaveManager.upgrade_level(upgrade_id)
	var max_level := int(data.get("max_level", 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(620, 64)
	var name_label := Label.new()
	name_label.text = "%s  (%d/%d)" % [Loc.text(str(data.get("name_key", upgrade_id))),
			level, max_level]
	name_label.add_theme_font_size_override("font_size", 24)
	info.add_child(name_label)
	var desc := Label.new()
	desc.text = Loc.text(str(data.get("desc_key", "")))
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", UITheme.MUTED)
	info.add_child(desc)
	row.add_child(info)
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 56)
	button.focus_mode = Control.FOCUS_NONE
	if level >= max_level:
		button.text = Loc.text("equipped")
		button.disabled = true
	else:
		var price := CombatMath.upgrade_price(int(data.get("price_base", 10)),
				float(data.get("price_growth", 1.5)), level)
		button.text = "%s  %d" % [Loc.text("buy"), price]
		button.pressed.connect(func() -> void: _buy(upgrade_id, price))
	row.add_child(button)
	return row


func _buy(upgrade_id: String, price: int) -> void:
	if SaveManager.spend_shards(price):
		SaveManager.set_upgrade_level(upgrade_id, SaveManager.upgrade_level(upgrade_id) + 1)
		AudioManager.play("ui_purchase")
		_error.text = ""
	else:
		AudioManager.play("ui_denied")
		_error.text = Loc.text("buy_failed")
	_refresh()
