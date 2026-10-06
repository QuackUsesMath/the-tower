extends CanvasLayer
## Add a CanvasLayer to your level and attach this script. It builds its own UI, no scene setup.
## Light bar reads left to right: hope | humanity | physical.
## Spending goes physical -> humanity -> hope, so the bar drains right to left.

@export var px_per_light := 3.0
@export var bar_height := 14.0

const COLORS := {
	"hope": Color("fff2a8"),
	"humanity": Color("e8a23a"),
	"physical": Color("8a4f1d"),
}

var _player: Node
var _light: LightPool
var _hp_bar: ProgressBar
var _heal_label: Label
var _bars := {}


func _ready() -> void:
	layer = 10
	_build()
	await get_tree().process_frame      # let the player register in its group
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("HUD: no node in group 'player'")
		return
	_light = _player.light


func _process(_delta: float) -> void:
	if _player == null:
		return
	_hp_bar.max_value = _player.max_hp
	_hp_bar.value = _player.hp
	for pool in _bars:
		var bar: ProgressBar = _bars[pool]
		bar.max_value = _light.get(pool + "_max")
		bar.value = _light.get(pool)
		bar.custom_minimum_size.x = bar.max_value * px_per_light
	_heal_label.text = "Heal x%d  (RMB)" % _player.heal_charges


func _build() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(16, 16)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_hp_bar = _make_bar(Color("d94a4a"))
	_hp_bar.custom_minimum_size = Vector2(200, bar_height)
	root.add_child(_hp_bar)

	var light_row := HBoxContainer.new()
	light_row.add_theme_constant_override("separation", 2)
	root.add_child(light_row)
	for pool in COLORS:
		var bar := _make_bar(COLORS[pool])
		light_row.add_child(bar)
		_bars[pool] = bar

	_heal_label = Label.new()
	root.add_child(_heal_label)

	# HUD must never eat mouse clicks (the player ignores shots over UI controls)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in root.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = bar_height
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar
