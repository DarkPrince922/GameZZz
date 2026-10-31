extends CharacterBody2D
## One scene, six behaviours. All numbers come from data/enemies.json; the
## behaviour script only decides *what to do*, never how hard it hits.

signal died(enemy: Node)
signal damaged(amount: float)

const BEHAVIOURS := {
	"patrol_chase": preload("res://scripts/enemies/behaviour_patrol_chase.gd"),
	"flyer": preload("res://scripts/enemies/behaviour_flyer.gd"),
	"jumper": preload("res://scripts/enemies/behaviour_jumper.gd"),
	"shooter": preload("res://scripts/enemies/behaviour_shooter.gd"),
	"bomber": preload("res://scripts/enemies/behaviour_bomber.gd"),
	"shieldbearer": preload("res://scripts/enemies/behaviour_shieldbearer.gd"),
}
const DreamShard := preload("res://scripts/pickups/dream_shard.gd")

var type_id: String = "shadow"
var elite_id: String = ""
var data: Dictionary = {}
var elite: Dictionary = {}
var hp: float = 10.0
var max_hp: float = 10.0
var damage: float = 5.0
var speed: float = 60.0
var sight: float = 280.0
var attack_range: float = 34.0
var attack_cooldown: float = 1.2
var is_dead: bool = false
var facing: float = -1.0
var player = null
var shield_hp: float = 0.0
var revives_left: int = 0
var attack_timer: float = 0.0
var hurt_flash: float = 0.0

var _behaviour
var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _patrol_origin: Vector2
var _patrol_dir: float = 1.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 2
	if data.is_empty():
		configure(type_id, elite_id)
	_patrol_origin = global_position


func patrol_origin() -> Vector2:
	return _patrol_origin


func configure(enemy_type: String, elite_type: String = "") -> void:
	type_id = enemy_type
	elite_id = elite_type
	data = DataDB.enemy(enemy_type)
	if data.is_empty():
		push_warning("Enemy: unknown type %s" % enemy_type)
		data = {"hp": 10, "damage": 5, "speed": 50, "size": [28, 40], "behavior": "patrol_chase"}
	elite = DataDB.elite(elite_type) if elite_type != "" else {}
	hp = CombatMath.enemy_health(float(data.get("hp", 10.0)), Settings.difficulty)
	max_hp = hp
	damage = float(data.get("damage", 5.0))
	speed = float(data.get("speed", 50.0)) * float(elite.get("speed_mult", 1.0))
	sight = float(data.get("sight", 280.0))
	attack_range = float(data.get("attack_range", 34.0))
	attack_cooldown = float(data.get("attack_cooldown", 1.2))
	shield_hp = float(data.get("shield_hp", 0.0))
	if elite.has("revive_count"):
		revives_left = int(elite.get("revive_count", 0))
	_build_body()
	_make_behaviour(str(data.get("behavior", "patrol_chase")))
	_patrol_origin = global_position
	queue_redraw()


func _build_body() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		_rect = RectangleShape2D.new()
		_shape.shape = _rect
		add_child(_shape)
	var size: Array = data.get("size", [28, 40])
	_rect.size = Vector2(float(size[0]), float(size[1]))
	_shape.position = Vector2(0, -_rect.size.y / 2.0)
	collision_layer = 4


func _make_behaviour(behaviour_name: String) -> void:
	var script_ref: Variant = BEHAVIOURS.get(behaviour_name, BEHAVIOURS["patrol_chase"])
	_behaviour = script_ref.new()
	if _behaviour.has_method("setup"):
		_behaviour.setup(self)


func behaviour_name() -> String:
	return str(data.get("behavior", "patrol_chase"))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var scaled_delta := delta
	if get_node_or_null("/root/Game") != null:
		scaled_delta *= Game.enemy_slow
	hurt_flash = maxf(0.0, hurt_flash - delta)
	attack_timer = maxf(0.0, attack_timer - scaled_delta)
	player = _find_player()
	if _behaviour != null and _behaviour.has_method("update"):
		_behaviour.update(self, scaled_delta)
	move_and_slide()
	queue_redraw()


func _find_player() -> Node2D:
	if player != null and is_instance_valid(player):
		return player
	var nodes := get_tree().get_nodes_in_group("player") if get_tree() != null else []
	return nodes[0] as Node2D if not nodes.is_empty() else null


# ------------------------------------------------------------- enemy helpers
func player_position() -> Vector2:
	return player.global_position if player != null and is_instance_valid(player) else Vector2.INF


func distance_to_player() -> float:
	var target := player_position()
	if target == Vector2.INF:
		return INF
	return global_position.distance_to(target)


func direction_to_player() -> float:
	var target := player_position()
	if target == Vector2.INF:
		return facing
	return signf(target.x - global_position.x)


func sees_player() -> bool:
	var distance := distance_to_player()
	if get_node_or_null("/root/Game") != null and Game.stealth and distance > 60.0:
		return false
	return distance <= sight


func apply_gravity(enemy: CharacterBody2D, delta: float, gravity: float = 1400.0) -> void:
	enemy.velocity.y = minf(enemy.velocity.y + gravity * delta, 900.0)


func surface_velocity() -> float:
	return 0.0


func try_attack(_delta: float, reach: float = -1.0) -> bool:
	var range_limit := reach if reach >= 0.0 else attack_range
	if attack_timer > 0.0:
		return false
	if distance_to_player() > range_limit:
		return false
	attack_timer = attack_cooldown
	AudioManager.play_spatial_or_global("enemy_attack", global_position)
	attack_player()
	return true


func attack_player() -> void:
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		if elite.has("lifesteal_fraction"):
			heal(damage * float(elite["lifesteal_fraction"]))


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func body_radius() -> float:
	var size: Array = data.get("size", [28, 40])
	return maxf(float(size[0]), float(size[1])) * 0.6


func play_at(event_id: String) -> void:
	## Behaviours are RefCounted helpers: they must not touch autoloads
	## directly (Godot cannot resolve /root singletons outside the tree).
	AudioManager.play_spatial_or_global(event_id, global_position)


func blocks_hit(from_position: Vector2) -> bool:
	if _behaviour != null and _behaviour.has_method("blocks_hit"):
		return bool(_behaviour.blocks_hit(self, from_position))
	return false


func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO, _crit: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	if blocks_hit(source_position) and shield_hp > 0.0:
		shield_hp = maxf(0.0, shield_hp - amount)
		AudioManager.play_spatial_or_global("combat_block", global_position)
		hurt_flash = 0.1
		queue_redraw()
		return
	hp -= amount
	hurt_flash = 0.18
	damaged.emit(amount)
	AudioManager.play_spatial_or_global("enemy_hurt", global_position)
	if hp <= 0.0:
		_die()
	else:
		var push := signf(global_position.x - source_position.x)
		velocity.x = push * 90.0 * (1.0 - float(data.get("knockback_resist", 0.0)))
	queue_redraw()


func kill(play_death_sound: bool = true) -> void:
	_die(play_death_sound)


func _die(play_death_sound: bool = true) -> void:
	if is_dead:
		return
	if revives_left > 0 and play_death_sound:
		revives_left -= 1
		hp = max_hp * float(elite.get("revive_hp_fraction", 0.5))
		AudioManager.play_spatial_or_global("enemy_revive", global_position)
		queue_redraw()
		return
	is_dead = true
	collision_layer = 0
	if play_death_sound:
		AudioManager.play_spatial_or_global("enemy_death", global_position)
	_drop_shards()
	if get_node_or_null("/root/SaveManager") != null:
		SaveManager.register_bestiary(type_id)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
	set_physics_process(false)


func shard_drop_amount() -> int:
	var drops: Array = data.get("shards", [1, 1])
	var base := 1
	if drops.size() >= 2:
		base = randi_range(int(drops[0]), int(drops[1]))
	var mult := float(elite.get("shards_mult", 1.0))
	return CombatMath.shard_amount(int(round(float(base) * mult)), Settings.difficulty)


func _drop_shards() -> void:
	var host := get_parent()
	if host == null:
		return
	var total := shard_drop_amount()
	for i in mini(total, 3):
		var shard := DreamShard.new()
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-26.0, -12.0))
		shard.position = position + offset
		host.call_deferred("add_child", shard)


func _draw() -> void:
	var size: Array = data.get("size", [28, 40])
	var body := Vector2(float(size[0]), float(size[1]))
	var base_color: Color = _data_color()
	if hurt_flash > 0.0:
		base_color = base_color.lerp(Color.WHITE, 0.65)
	if elite.has("color_tint"):
		var tint: Array = elite["color_tint"]
		base_color = base_color.lerp(Color(float(tint[0]), float(tint[1]), float(tint[2])), 0.45)
	var rect := Rect2(Vector2(-body.x / 2.0, -body.y), body)
	draw_rect(rect, base_color)
	# eyes look toward the player
	var eye_dir := facing
	var eye_y := -body.y * 0.72
	draw_circle(Vector2(eye_dir * 6.0 - 3.0, eye_y), 2.6, Color(1.0, 0.95, 0.7))
	draw_circle(Vector2(eye_dir * 6.0 + 3.0, eye_y), 2.6, Color(1.0, 0.95, 0.7))
	if shield_hp > 0.0:
		draw_rect(Rect2(Vector2(eye_dir * body.x * 0.55, -body.y), Vector2(4, body.y)),
				Color(0.7, 0.8, 0.95, 0.9))
	if revives_left > 0:
		draw_circle(Vector2(0, -body.y - 8.0), 3.0, Color(0.7, 1.0, 0.6, 0.9))
	if hp < max_hp:
		var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-body.x / 2.0, -body.y - 6.0), Vector2(body.x, 3.0)),
				Color(0.15, 0.15, 0.2, 0.8))
		draw_rect(Rect2(Vector2(-body.x / 2.0, -body.y - 6.0), Vector2(body.x * ratio, 3.0)),
				Color(0.9, 0.35, 0.4))


func _data_color() -> Color:
	var c: Array = data.get("color", [0.4, 0.35, 0.55])
	return Color(float(c[0]), float(c[1]), float(c[2]))
