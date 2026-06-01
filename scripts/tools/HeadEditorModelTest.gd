extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
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
	var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	assert(head != null)
	assert(mouth != null)
	assert(head.scale.x > head.scale.y)
	assert(mouth.position.y < -0.05)
	var initial_head_scale_x := head.scale.x
	var initial_shell_profile: Array = fish.shell_profile
	var initial_front_radius_y := float(initial_shell_profile[1].y)
	var initial_shell_start_x := float(initial_shell_profile[0].x)

	fish.set_head_shape("pointed")
	fish.set_mouth_type("superior")
	var adjusted_parameters: Dictionary = fish.parameters.duplicate(true)
	adjusted_parameters["snout_length"] = 0.28
	adjusted_parameters["head_flattening"] = 0.55
	adjusted_parameters["snout_appendage"] = "swordfish_bill"
	adjusted_parameters["snout_appendage_length"] = 0.35
	fish.set_parameters(adjusted_parameters)
	await get_tree().process_frame
	await get_tree().process_frame
	var head_after := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var mouth_after := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	var socket_after := fish.get_node_or_null("BodyPivot/Head/SnoutSocket") as Node3D
	var appendage_after := fish.get_node_or_null("BodyPivot/Head/SnoutSocket/SnoutAppendage") as Node3D
	var pointed_shell_profile: Array = fish.shell_profile
	assert(head_after.scale.x > initial_head_scale_x)
	assert(mouth_after.position.y > 0.0)
	assert(socket_after != null)
	assert(appendage_after != null)
	assert(abs(socket_after.position.x - (-0.5 - 0.28)) < 0.001)
	assert(abs(socket_after.scale.x - (1.0 / head_after.scale.x)) < 0.001)
	assert(float(pointed_shell_profile[1].y) < initial_front_radius_y * 0.8)
	assert(float(pointed_shell_profile[0].x) > head_after.position.x - head_after.scale.x * 0.35)
	assert(float(pointed_shell_profile[0].x) < head_after.position.x - head_after.scale.x * 0.05)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_model.ok", FileAccess.WRITE)
	file.store_string("head editor model applied")
	file.close()
	print("HEAD_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)
