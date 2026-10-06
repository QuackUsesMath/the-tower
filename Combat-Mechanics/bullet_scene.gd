extends Area2D
## Scene: Area2D (this script, scene ROOT) > CollisionShape2D (small circle) + Line2D "Trail".
## Trail must be a direct child of the Area2D, not nested under the CollisionShape2D.

@export var speed := 700.0
@export var max_length := 28.0
@export var grow_time := 0.06      # dot -> line animation time (player overrides this)
@export var lifetime := 1.2
@export var trail_width := 2.0
@export var trail_color := Color(1.0, 0.9, 0.3)

var direction := Vector2.RIGHT
var damage := 10.0
var _age := 0.0

@onready var trail: Line2D = $Trail


func _ready() -> void:
	rotation = direction.angle()
	trail.width = trail_width
	trail.default_color = trail_color
	trail.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])   # starts as a dot
	if grow_time > 0.0:
		create_tween().tween_method(_set_length, 0.0, max_length, grow_time)
	else:
		_set_length(max_length)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _set_length(length: float) -> void:
	trail.set_point_position(0, Vector2(-length, 0.0))   # tail grows backwards from the tip


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
		Fx.hitstop(0.04)
		Fx.shake(2.0)
	queue_free()
