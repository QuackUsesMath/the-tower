extends Node
## Autoload this as "Fx" (Project Settings > Globals > Autoload).


func hitstop(duration := 0.05, slow_scale := 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = slow_scale
	# 4th arg = ignore_time_scale, otherwise this timer would be slowed too
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func shake(strength := 4.0, duration := 0.12) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var steps := 6
	var tween := create_tween()
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tween.tween_property(cam, "offset", off, duration / steps)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.02)