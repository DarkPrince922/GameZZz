extends Node2D
## Level exit door. Touching it finishes the level and shows the star screen.

signal reached()

var locked: bool = false
var _player: Node2D = null
var _triggered: bool = false


func _ready() -> void:
	add_to_group("goal")
	z_index = 1


func _physics_process(_delta: float) -> void:
	if _triggered or locked:
		return
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null:
		return
	if _player.global_position.distance_to(global_position) <= 42.0:
		_triggered = true
		AudioManager.play("door_open")
		reached.emit()


func _draw() -> void:
	var frame := Rect2(-22, -70, 44, 70)
	draw_rect(frame, Color(0.3, 0.28, 0.4))
	draw_rect(Rect2(-16, -62, 32, 62), Color(0.9, 0.85, 0.6, 0.85))
	draw_circle(Vector2(8, -32), 3.0, Color(0.3, 0.25, 0.2))
