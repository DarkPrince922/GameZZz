extends Node2D
## Simple enemy bullet: flies straight, damages the player once, then disappears.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 6.0
var lifetime: float = 2.6
var source_position: Vector2 = Vector2.ZERO


func setup(config: Dictionary) -> void:
	position = config.get("position", Vector2.ZERO)
	velocity = config.get("velocity", Vector2.RIGHT * 240.0)
	damage = float(config.get("damage", 6.0))
	source_position = config.get("owner_position", position)


func _ready() -> void:
	z_index = 4


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	position += velocity * delta
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player = node as Node2D
		if player == null:
			continue
		if player.global_position.distance_to(global_position) > 26.0:
			continue
		if player.has_method("take_damage"):
			player.take_damage(damage, global_position)
		queue_free()
		return


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.85, 0.45, 0.95))
	draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.45, 0.95, 0.25))
