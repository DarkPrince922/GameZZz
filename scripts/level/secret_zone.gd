extends Node2D
## Secret area: first entry pays bonus shards and plays the secret jingle.

var area_size: Vector2 = Vector2(96, 96)
var found: bool = false
var _player: Node2D = null


func setup(config: Dictionary) -> void:
	area_size = Vector2(float(config.get("w", 3)) * 32.0, float(config.get("h", 3)) * 32.0)
	position = config.get("position", Vector2.ZERO)


func _ready() -> void:
	add_to_group("secrets")


func contains(point: Vector2) -> bool:
	return Rect2(global_position - area_size / 2.0, area_size).has_point(point)


func _physics_process(_delta: float) -> void:
	if found:
		return
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null or not contains(_player.global_position):
		return
	found = true
	AudioManager.play("secret_found")
	if get_node_or_null("/root/Game") != null:
		for i in 2:
			Game.collect_shard(1)
	queue_redraw()


func _draw() -> void:
	if found:
		draw_rect(Rect2(-area_size / 2.0, area_size), Color(0.6, 1.0, 0.8, 0.06))
