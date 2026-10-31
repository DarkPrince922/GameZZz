extends Node2D
## Burning footprint left by the Fire Trail skill.

var damage: float = 5.0
var radius: float = 44.0
var lifetime: float = 1.8
var tick: float = 0.0


func _ready() -> void:
	z_index = 1


func _physics_process(delta: float) -> void:
	lifetime -= delta
	tick -= delta
	if tick <= 0.0:
		tick = 0.4
		_burn()
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()


func _burn() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy = node as Node2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if enemy.global_position.distance_to(global_position) <= radius:
			enemy.take_damage(damage, global_position, false)


func _draw() -> void:
	var alpha: float = clampf(lifetime / 1.8, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * 0.8, Color(1.0, 0.45, 0.15, 0.18 * alpha))
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 0.75, 0.3, 0.3 * alpha))
