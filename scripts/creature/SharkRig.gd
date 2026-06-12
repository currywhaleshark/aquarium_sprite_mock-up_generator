class_name SharkRig
extends FishRig

const SharkGillSlitMarkingScript := preload("res://scripts/creature/SharkGillSlitMarking.gd")
const SharkMouthMarkingScript := preload("res://scripts/creature/SharkMouthMarking.gd")

func set_parameters(new_parameters: Dictionary) -> void:
	super.set_parameters(_shark_parameters(new_parameters))

func rebuild() -> void:
	super.rebuild()
	if body_pivot == null:
		return
	_remove_fish_mouth_nodes()
	SharkGillSlitMarkingScript.rebuild(body_pivot, parameters)
	SharkMouthMarkingScript.rebuild(body_pivot, parameters)

func _shark_parameters(source: Dictionary) -> Dictionary:
	var shark_parameters := source.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	shark_parameters["mouth_carve_enabled"] = false
	shark_parameters["mouth_open"] = 0.0
	shark_parameters["mouth_size"] = 0.0
	shark_parameters["mouth_detail"] = "none"
	for key in shark_parameters.keys():
		var text_key := String(key)
		if text_key == "gill_mark" or text_key.begins_with("operculum_"):
			shark_parameters.erase(key)
	return shark_parameters

func _remove_fish_mouth_nodes() -> void:
	var head := body_pivot.get_node_or_null("Head")
	if head == null:
		return
	for child in head.get_children():
		var child_name := String(child.name)
		if child_name in ["Mouth", "MouthLowerJaw", "MouthCavity", "MouthFloor", "MouthLipUpper"] or child_name.begins_with("MouthDetail_"):
			head.remove_child(child)
			child.free()
