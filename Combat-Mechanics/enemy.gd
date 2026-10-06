extends CharacterBody2D
## Test dummy that chases the player. Needs a visual child named "Visual" (Sprite2D/AnimatedSprite2D),
## a CollisionShape2D, and flash_shader assigned in the inspector.

@export var flash_shader: Shader
@export var max_hp := 30.0
@export var speed := 55.0
@export var contact_damage := 8.0
@export var contact_cooldown := 0.8
@export var enemy_color := Color(1.0, 0.35, 0.35)

@onready var visual: CanvasItem = ($Visual if has_node("Visual") else $visual) as CanvasItem

var hp := 0.0
var _player: Node2D
var _knockback := Vector2.ZERO
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	if visual:
		visual.modulate = enemy_color
		if flash_shader:
			var mat := ShaderMaterial.new()
			mat.shader = flash_shader
			visual.material = mat


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	var to_player := _player.global_position - global_position
	velocity = to_player.normalized() * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()

	_cooldown -= delta
	if to_player.length() < 16.0 and _cooldown <= 0.0:
		_cooldown = contact_cooldown
		_player.take_damage(contact_damage, to_player.normalized())


func take_damage(amount: float, from_dir := Vector2.ZERO) -> void:
	hp -= amount
	_knockback = from_dir * 120.0
	if visual:
		var mat := visual.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", 1.0)
			create_tween().tween_method(func(v: float): mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.1)
	if hp <= 0.0:
		queue_free()
