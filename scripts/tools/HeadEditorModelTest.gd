extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.call("set_parameters", {
		"shell_enabled": 1.0,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"head_shape": "hump",
		"mouth_type": "inferior",
		"snout_length": 0.18,
		"forehead_slope": 0.65,
		"jaw_offset": -0.09,
		"mouth_size": 0.12,
		"head_flattening": 0.1
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var hump := fish.get_node_or_null("BodyPivot/Head/NuchalHump") as MeshInstance3D
	var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	assert(head != null)
	assert(hump != null)
	assert(mouth != null)
	assert(head.scale.x > head.scale.y)
	assert(hump.position.y > 0.0)
	assert(mouth.position.y < -0.05)
	var initial_head_scale_x := head.scale.x

	fish.call("set_head_shape", "pointed")
	fish.call("set_mouth_type", "superior")
	await get_tree().process_frame
	await get_tree().process_frame
	var head_after := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var mouth_after := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	assert(head_after.scale.x > initial_head_scale_x)
	assert(mouth_after.position.y > 0.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_model.ok", FileAccess.WRITE)
	file.store_string("head editor model applied")
	file.close()
	print("HEAD_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)
