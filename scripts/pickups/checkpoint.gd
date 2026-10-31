extends Node2D
## Checkpoint lantern: touching it moves the respawn point and saves it in the run.

signal activated(position: Vector2)

var active: bool = false
var _player = null


func _ready() -> void:
	add_to_group("checkpoints")
	z_index = 2


func _physics_process(_delta: float) -> void:
	if active:
		return
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null:
		return
	if _player.global_position.distance_to(global_position) <= 40.0:
		activate()


func activate() -> void:
	if active:
		return
	active = true
	if _player != null and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(global_position + Vector2(0.0, -24.0))
	AudioManager.play("ui_toggle")
	activated.emit(global_position)
	queue_redraw()


func _draw() -> void:
	var color := Color(1.0, 0.85, 0.45) if active else Color(0.5, 0.5, 0.6)
	draw_rect(Rect2(-3, -34, 6, 34), Color(0.35, 0.32, 0.4))
	draw_circle(Vector2(0, -40), 9.0, color)
	draw_circle(Vector2(0, -40), 18.0, Color(color.r, color.g, color.b, 0.18))
