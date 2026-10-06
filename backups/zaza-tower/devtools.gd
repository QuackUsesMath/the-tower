extends CanvasLayer
## Add a CanvasLayer to your level and attach this script. Press F1 to show/hide.
## Sliders change the Player's exported values live. They reset when you stop the game,
## so copy values you like back into the Inspector.

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")

# [property, min, max, step]
const SLIDERS := [
	["speed", 50.0, 400.0, 1.0],
	["bullet_damage", 1.0, 50.0, 1.0],
	["bullet_windup", 0.0, 0.2, 0.005],
	["bullet_recovery", 0.02, 0.5, 0.005],
	["bullet_grow_time", 0.0, 0.2, 0.005],
	["beam_hold_time", 0.05, 0.8, 0.01],
	["beam_turn_speed", 0.0, 1080.0, 10.0],
	["beam_dps", 5.0, 100.0, 1.0],
	["beam_cost_per_sec", 0.0, 40.0, 0.5],
	["beam_move_multiplier", 0.0, 1.0, 0.05],
]
const TOGGLES := ["beam_drains_light", "use_aim_arc", "takes_damage", "free_bullets"]

var _player: Node
var _panel: PanelContainer


func _ready() -> void:
	layer = 20
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("DevTools: no node in group 'player'")
		return
	_build()
	_panel.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and _panel:
			_panel.visible = not _panel.visible
		elif event.keycode == KEY_B and enemy_scene and _player:
			_spawn_enemy()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 110)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 440)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = "DEV TOOLS (F1)"
	box.add_child(title)

	for prop in TOGGLES:
		var check := CheckBox.new()
		check.text = prop
		check.button_pressed = _player.get(prop)
		check.toggled.connect(_on_toggle.bind(prop))
		box.add_child(check)

	for s in SLIDERS:
		box.add_child(_make_slider_row(s[0], s[1], s[2], s[3]))

	_add_button(box, "Refill light", _refill_light)
	_add_button(box, "Full heal + 3 charges", _full_heal)
	_add_button(box, "Take 20 damage", _hurt_player)
	if enemy_scene:
		_add_button(box, "Spawn enemy near player (B)", _spawn_enemy)
		_add_button(box, "Spawn wave (5 enemies)", _spawn_wave)


func _make_slider_row(prop: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = prop
	name_label.custom_minimum_size.x = 150
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 140
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = _player.get(prop)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48
	value_label.text = str(snappedf(slider.value, 0.001))
	slider.value_changed.connect(_on_slider.bind(prop, value_label))
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _on_slider(value: float, prop: String, label: Label) -> void:
	_player.set(prop, value)
	label.text = str(snappedf(value, 0.001))


func _on_toggle(on: bool, prop: String) -> void:
	_player.set(prop, on)


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)


func _refill_light() -> void:
	var l: LightPool = _player.light
	l.hope = l.hope_max
	l.humanity = l.humanity_max
	l.physical = l.physical_max
	l.changed.emit()


func _full_heal() -> void:
	_player.hp = _player.max_hp
	_player.heal_charges = 3
	_player.hp_changed.emit(_player.hp, _player.max_hp)


func _hurt_player() -> void:
	_player.hp = maxf(_player.hp - 20.0, 0.0)
	_player.hp_changed.emit(_player.hp, _player.max_hp)


func _spawn_enemy() -> void:
	if _player == null:
		return
	var e := enemy_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(e)
	e.global_position = _player.global_position + Vector2(140.0, 0.0).rotated(randf() * TAU)


func _spawn_wave() -> void:
	for i in 5:
		_spawn_enemy()
