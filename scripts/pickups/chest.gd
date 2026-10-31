extends Node2D
## Chest: opens on touch, pays shards, counts as a collectible.

var shards: int = 3
var opened: bool = false
var _player: Node2D = null


func _ready() -> void:
	add_to_group("pickups")
	z_index = 2


func _physics_process(_delta: float) -> void:
	if opened:
		return
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null:
		return
	if _player.global_position.distance_to(global_position) <= 34.0:
		open()


func open() -> void:
	if opened:
		return
	opened = true
	AudioManager.play("chest_open")
	if get_node_or_null("/root/Game") != null:
		for i in shards:
			Game.collect_shard(1)
	queue_redraw()


func _draw() -> void:
	var body := Rect2(-16, -22, 32, 22)
	draw_rect(body, Color(0.55, 0.4, 0.28))
	draw_rect(Rect2(-17, -26, 34, 8), Color(0.7, 0.52, 0.34))
	if opened:
		draw_rect(Rect2(-14, -18, 28, 8), Color(1.0, 0.92, 0.6, 0.9))
	else:
		draw_rect(Rect2(-3, -16, 6, 8), Color(0.95, 0.85, 0.5))
