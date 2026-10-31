extends Node
## Shared UI building blocks and colours so every screen looks like one game.

const BG := Color(0.043, 0.051, 0.102)
const PANEL := Color(0.09, 0.10, 0.18, 0.95)
const ACCENT := Color(1.0, 0.86, 0.45)
const TEXT := Color(0.92, 0.94, 1.0)
const MUTED := Color(0.62, 0.66, 0.8)
const DANGER := Color(0.9, 0.32, 0.4)


static func make_button(parent: Control, text: String, position: Vector2,
		size: Vector2 = Vector2(280, 64)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.size = size
	button.position = position
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", TEXT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: AudioManager.play("ui_click"))
	parent.add_child(button)
	return button


static func make_label(parent: Control, text: String, position: Vector2,
		font_size: int = 28, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func make_slider(parent: Control, position: Vector2, value: float,
		width: float = 320.0) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.position = position
	slider.size = Vector2(width, 28)
	slider.custom_minimum_size = Vector2(width, 28)
	parent.add_child(slider)
	return slider


static func background(parent: Control) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = BG
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect
