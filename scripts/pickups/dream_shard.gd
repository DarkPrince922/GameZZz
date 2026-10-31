extends Node2D
## Dream shard pickup: bobs, can be attracted by a skill, feeds the run counter.

var value: int = 1
var bobbing: bool = true
var attracted: bool = false
var _time: float = 0.0
var _base_y: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group("shards")
	add_to_group("pickups")
	_base_y = position.y
	_time = randf() * TAU
	z_index = 3


func _physics_process(delta: float) -> void:
	_time += delta
	if bobbing and not attracted:
		position.y = _base_y + sin(_time * 3.0) * 3.0
	if _player == null or not is_instance_valid(_player):
		var nodes := get_tree().get_nodes_in_group("player")
		_player = nodes[0] as Node2D if not nodes.is_empty() else null
	if _player == null:
		return
	var distance := _player.global_position.distance_to(global_position)
	if attracted and distance > 6.0:
		var dir := (_player.global_position - global_position).normalized()
		position += dir * 420.0 * delta
		return
	if distance <= 26.0:
		_collect()


func set_attracted(value_on: bool) -> void:
	attracted = value_on


func _collect() -> void:
	if get_node_or_null("/root/Game") != null:
		Game.collect_shard(value)
		var chain := Game.shards_in_run
		AudioManager.play("shard_pickup", CombatMath.shard_chain_pitch(chain % 9))
	else:
		AudioManager.play("shard_pickup")
	queue_free()


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -9), Vector2(6, 0), Vector2(0, 9), Vector2(-6, 0),
	])
	draw_colored_polygon(points, Color(0.75, 0.9, 1.0))
	draw_circle(Vector2.ZERO, 13.0, Color(0.6, 0.8, 1.0, 0.18))
