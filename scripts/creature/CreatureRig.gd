class_name CreatureRig
extends Node3D

var parameters: Dictionary = {}
var auto_animate := true
var time_seconds := 0.0

func set_parameters(new_parameters: Dictionary) -> void:
	parameters = new_parameters.duplicate(true)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		child.queue_free()

func apply_pose(_loop_phase: float) -> void:
	pass

func _process(delta: float) -> void:
	if not auto_animate:
		return
	time_seconds += delta
	var speed := float(parameters.get("swim_speed", parameters.get("flap_speed", 1.0)))
	apply_pose(fposmod(time_seconds * speed, 1.0))

func param_float(key: String, fallback: float) -> float:
	return float(parameters.get(key, fallback))

func param_color(key: String, fallback: String) -> Color:
	var value: Variant = parameters.get(key, fallback)
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(value)
	return Color.html(fallback)
