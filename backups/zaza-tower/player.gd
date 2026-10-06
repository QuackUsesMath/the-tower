extends CharacterBody2D
## Root: CharacterBody2D (Motion Mode = Floating). Expected children:
##   LightPool (light_pool.gd), RayCast2D "BeamRay", Line2D "BeamLine", Node2D "Barrier",
##   plus your sprite and CollisionShape2D.
## Beam visuals, barrier visuals and beam audio are all built in code.

signal hp_changed(hp: float, max_hp: float)
signal died

const BEAM_TICK := 0.1

@export_group("Movement")
@export var speed := 180.0

@export_group("Aiming")
@export var muzzle_distance := 14.0
@export var use_aim_arc := false
@export_range(10, 180) var aim_arc_degrees := 70.0

@export_group("Photon Bullet (LMB tap)")
@export var bullet_scene: PackedScene
@export var bullet_damage := 10.0
@export var bullet_cost := 3.0
@export var bullet_windup := 0.05             # anticipation (keep <= 0.1)
@export var bullet_recovery := 0.14           # recovery before next shot
@export var bullet_grow_time := 0.06          # dot -> line animation time

@export_group("Photon Beam (LMB hold)")
@export var beam_hold_time := 0.3
@export var beam_length := 10000.0            # effectively infinite
@export var beam_dps := 25.0
@export var beam_drains_light := false        # false = beam lasts as long as LMB is held
@export var beam_cost_per_sec := 12.0         # only used when beam_drains_light is true
@export var beam_move_multiplier := 0.4
@export var beam_turn_speed := 400.0      # deg/sec the beam turns toward the cursor, 0 = snap instantly
@export var beam_width := 8.0
@export var beam_color := Color(1.0, 0.85, 0.2, 0.55)
@export var beam_sound_stream: AudioStream    # drag your .ogg here

@export_group("Survival")
@export var max_hp := 100.0
@export var barrier_radius := 22.0
@export var barrier_cost_per_sec := 8.0
@export var barrier_damage_taken := 0.15      # 0.15 = barrier blocks 85%
@export var heal_charges := 3
@export var heal_amount := 35.0

@export_group("Dev")
@export var takes_damage := true
@export var free_bullets := false

@onready var light: LightPool = $LightPool
@onready var beam_ray: RayCast2D = $BeamRay
@onready var beam_line: Line2D = $BeamLine
@onready var barrier_visual: Node2D = $Barrier

var hp := 0.0
var facing_dir := Vector2.DOWN     # primary direction (4-way)
var aim_dir := Vector2.DOWN        # specific direction (toward mouse)

var _can_shoot := true
var _hold_time := 0.0
var _beam_active := false
var _beam_exhausted := false
var _beam_dir := Vector2.ZERO
var _beam_tick := 0.0
var _barrier_active := false
var _beam_core: Line2D
var _beam_sound: AudioStreamPlayer
var _sound_tween: Tween


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	beam_ray.enabled = false
	beam_ray.add_exception(self)
	_build_beam_visuals()
	_build_barrier_visuals()
	_build_beam_sound()
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	_update_aim()
	_handle_barrier(delta)
	_handle_shooting(delta)
	if Input.is_action_just_pressed("heal"):
		_heal()
	_move()


# ---------- Visual / audio setup ----------

func _build_beam_visuals() -> void:
	beam_line.visible = false
	beam_line.width = beam_width
	beam_line.default_color = beam_color
	beam_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_core = Line2D.new()
	_beam_core.width = beam_width * 0.4
	_beam_core.default_color = Color(1.0, 1.0, 0.9)
	_beam_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_line.add_child(_beam_core)


func _build_barrier_visuals() -> void:
	barrier_visual.visible = false
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * barrier_radius)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(1.0, 0.9, 0.4, 0.18)
	barrier_visual.add_child(fill)
	var ring := Line2D.new()
	ring.points = pts
	ring.closed = true
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.9, 0.4, 0.9)
	barrier_visual.add_child(ring)


func _build_beam_sound() -> void:
	_beam_sound = AudioStreamPlayer.new()
	_beam_sound.stream = beam_sound_stream
	add_child(_beam_sound)
	if beam_sound_stream is AudioStreamOggVorbis:
		(beam_sound_stream as AudioStreamOggVorbis).loop = true
	_beam_sound.finished.connect(_on_beam_sound_finished)   # fallback loop for other formats


func _on_beam_sound_finished() -> void:
	if _beam_active:
		_beam_sound.play()


# ---------- Movement & aiming ----------

func _move() -> void:
	var dir := Input.get_vector("left", "right", "up", "down")
	var mult := beam_move_multiplier if _beam_active else 1.0
	velocity = dir * speed * mult
	if dir != Vector2.ZERO:
		facing_dir = _snap_primary(dir)
	move_and_slide()


func _snap_primary(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


func _update_aim() -> void:
	var raw := (get_global_mouse_position() - global_position).normalized()
	if raw == Vector2.ZERO:
		raw = facing_dir
	aim_dir = _clamp_to_arc(raw) if use_aim_arc else raw


func _clamp_to_arc(raw: Vector2) -> Vector2:
	var center := facing_dir.angle()
	var limit := deg_to_rad(aim_arc_degrees)
	var diff := clampf(wrapf(raw.angle() - center, -PI, PI), -limit, limit)
	return Vector2.from_angle(center + diff)


# ---------- Shooting ----------

func _handle_shooting(delta: float) -> void:
	# Clicks on HUD / dev panel controls shouldn't shoot
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var pressed := Input.is_action_just_pressed("shoot") and not over_ui
	var held := Input.is_action_pressed("shoot") and not over_ui

	if _barrier_active:
		_stop_beam()
		_hold_time = 0.0
		return

	if pressed:
		_hold_time = 0.0
		_fire_bullet()

	if held:
		_hold_time += delta
		if _hold_time >= beam_hold_time and not _beam_active and not _beam_exhausted:
			_start_beam()
	else:
		_hold_time = 0.0
		_beam_exhausted = false
		_stop_beam()

	if _beam_active:
		_update_beam(delta)


func _fire_bullet() -> void:
	if not _can_shoot or _beam_active or bullet_scene == null:
		return
	_can_shoot = false
	await get_tree().create_timer(bullet_windup).timeout        # anticipation
	var mult := 1.0 if free_bullets else light.spend(bullet_cost)
	if mult > 0.0:
		var b = bullet_scene.instantiate()
		b.direction = aim_dir
		b.damage = bullet_damage * mult
		b.grow_time = bullet_grow_time
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + aim_dir * muzzle_distance
	await get_tree().create_timer(bullet_recovery).timeout      # recovery
	_can_shoot = true


func _start_beam() -> void:
	_beam_active = true
	_beam_dir = aim_dir
	_beam_tick = 0.0
	beam_line.visible = true
	if beam_sound_stream:
		if _sound_tween:
			_sound_tween.kill()
		_beam_sound.volume_db = 0.0
		_beam_sound.play()


func _stop_beam() -> void:
	if not _beam_active:
		return
	_beam_active = false
	beam_line.visible = false
	if _beam_sound.playing:
		_sound_tween = create_tween()
		_sound_tween.tween_property(_beam_sound, "volume_db", -40.0, 0.08)
		_sound_tween.tween_callback(_beam_sound.stop)


func _update_beam(delta: float) -> void:
	var mult := 1.0
	if beam_drains_light:
		mult = light.spend(beam_cost_per_sec * delta)
		if mult < 0.0:
			_beam_exhausted = true       # must release LMB before the beam can restart
			_stop_beam()
			return

	# Beam sweeps toward the cursor at a limited turn rate (0 = snap instantly)
	if beam_turn_speed > 0.0:
		var diff := wrapf(aim_dir.angle() - _beam_dir.angle(), -PI, PI)
		var step := deg_to_rad(beam_turn_speed) * delta
		_beam_dir = _beam_dir.rotated(clampf(diff, -step, step)).normalized()
	else:
		_beam_dir = aim_dir

	var origin := _beam_dir * muzzle_distance
	beam_ray.position = origin
	beam_ray.target_position = _beam_dir * beam_length
	beam_ray.force_raycast_update()
	var end := origin + _beam_dir * beam_length
	if beam_ray.is_colliding():
		end = to_local(beam_ray.get_collision_point())
	var pts := PackedVector2Array([origin, end])
	beam_line.points = pts
	_beam_core.points = pts

	var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.05)
	beam_line.width = beam_width * pulse
	_beam_core.width = beam_width * 0.4 * pulse

	_beam_tick += delta
	if _beam_tick >= BEAM_TICK:
		_beam_tick = 0.0
		var target := beam_ray.get_collider()
		if target and target.has_method("take_damage"):
			target.take_damage(beam_dps * BEAM_TICK * mult, _beam_dir)


# ---------- Barrier, heal, damage ----------

func _handle_barrier(delta: float) -> void:
	var want := Input.is_action_pressed("barrier")
	if want and light.spend(barrier_cost_per_sec * delta) < 0.0:
		want = false
	_barrier_active = want
	barrier_visual.visible = want


func _heal() -> void:
	if heal_charges <= 0 or hp >= max_hp:
		return
	heal_charges -= 1
	hp = minf(hp + heal_amount, max_hp)
	hp_changed.emit(hp, max_hp)


func take_damage(amount: float, _from_dir := Vector2.ZERO) -> void:
	if not takes_damage:
		return
	if _barrier_active:
		amount *= barrier_damage_taken
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	modulate = Color.RED
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	Fx.shake(1.5 if _barrier_active else 3.0)
	if hp <= 0.0:
		died.emit()
