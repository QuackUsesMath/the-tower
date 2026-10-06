extends Node2D
## Spawns enemies periodically around the player.

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var auto_spawn := true
@export var spawn_interval := 3.0
@export var max_enemies := 8
@export var spawn_distance_min := 100.0
@export var spawn_distance_max := 220.0
@export var initial_enemies := 3

var _timer := 0.0
var _player: Node2D


func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if auto_spawn and _player != null:
		for i in initial_enemies:
			spawn_enemy()


func _physics_process(delta: float) -> void:
	if not auto_spawn:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		var current_count := get_tree().get_nodes_in_group("enemy").size()
		if current_count < max_enemies:
			spawn_enemy()


func spawn_enemy() -> Node2D:
	if enemy_scene == null:
		return null
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return null

	var e := enemy_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(e)
	var offset := Vector2(randf_range(spawn_distance_min, spawn_distance_max), 0.0).rotated(randf() * TAU)
	e.global_position = _player.global_position + offset
	return e
