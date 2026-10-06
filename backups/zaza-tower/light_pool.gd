class_name LightPool
extends Node
## The three-tier "light" resource. Spends weakest pool first (physical -> humanity -> hope).

signal changed

@export var hope_max := 20.0          # player's hope: fixed, strongest, never regenerates
@export var humanity_max := 40.0      # humanity's hope: max can change, never regenerates
@export var physical_max := 60.0      # physical light: weakest, regenerates
@export var physical_regen := 8.0     # per second
@export var regen_delay := 0.6        # seconds after last spend before regen starts

# Damage multiplier per pool (hope hits hardest)
const POWER := {"physical": 1.0, "humanity": 1.6, "hope": 2.5}
const SPEND_ORDER := ["physical", "humanity", "hope"]

var hope := 0.0
var humanity := 0.0
var physical := 0.0
var _since_spend := 0.0


func _ready() -> void:
	hope = hope_max
	humanity = humanity_max
	physical = physical_max


func _process(delta: float) -> void:
	_since_spend += delta
	if _since_spend >= regen_delay and physical < physical_max:
		physical = minf(physical + physical_regen * delta, physical_max)
		changed.emit()


func total() -> float:
	return hope + humanity + physical


## Returns the damage multiplier for this spend, or -1.0 if it can't be afforded.
func spend(amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	if total() < amount:
		return -1.0
	var remaining := amount
	var weighted := 0.0
	for pool in SPEND_ORDER:
		var have: float = get(pool)
		var take := minf(have, remaining)
		set(pool, have - take)
		weighted += take * POWER[pool]
		remaining -= take
		if remaining <= 0.0:
			break
	_since_spend = 0.0
	changed.emit()
	return weighted / amount


## Call this from quests/achievements to grow or shrink humanity's hope.
func set_humanity_max(value: float) -> void:
	humanity_max = value
	humanity = minf(humanity, humanity_max)
	changed.emit()
