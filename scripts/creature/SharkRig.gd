class_name SharkRig
extends FishRig

const SharkGillSlitMarkingScript := preload("res://scripts/creature/SharkGillSlitMarking.gd")

func set_parameters(new_parameters: Dictionary) -> void:
	var shark_parameters := new_parameters.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	for key in shark_parameters.keys():
		var text_key := String(key)
		if text_key == "gill_mark" or text_key.begins_with("operculum_"):
			shark_parameters.erase(key)
	super.set_parameters(shark_parameters)
	if body_pivot != null:
		SharkGillSlitMarkingScript.rebuild(body_pivot, shark_parameters)
