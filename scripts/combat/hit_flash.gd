extends Node2D
## Tiny expanding flash used when a hit lands. Purely cosmetic, frees itself.

var color: Color = Color(1.0, 0.95, 0.7)
var lifetime: float = 0.18
var radius: float = 26.0
var _progress: float = 0.0


func _ready() -> void:
	z_index = 8
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, lifetime)
	tween.tween_callback(queue_free)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - _progress
	draw_circle(Vector2.ZERO, radius * (0.4 + _progress), Color(color.r, color.g, color.b, 0.5 * alpha))
	for i in 6:
		var angle := TAU * float(i) / 6.0 + _progress * 1.2
		var from := Vector2(cos(angle), sin(angle)) * radius * 0.3
		var to := Vector2(cos(angle), sin(angle)) * radius * (0.8 + _progress)
		draw_line(from, to, Color(color.r, color.g, color.b, alpha), 2.0)
