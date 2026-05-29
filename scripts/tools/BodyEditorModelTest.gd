extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.call("set_parameters", {
		"shell_enabled": 1.0,
		"body_length": 1.45,
		"body_height": 0.58,
		"body_width": 0.34,
		"tail_length": 0.78,
		"tail_height": 0.24,
		"body_profile_shape": "deep_compressed",
		"head_depth_scale": 0.72,
		"shoulder_depth_scale": 1.32,
		"midbody_depth_scale": 1.58,
		"tail_base_depth_scale": 0.82,
		"caudal_peduncle_depth_scale": 0.42,
		"body_width_scale": 0.82,
		"lateral_compression": 0.48,
		"body_depth_bias": -1.0,
		"head_vertical_offset": 0.16,
		"tail_vertical_offset": -0.18
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var profile: Array = fish.get("shell_profile")
	assert(profile.size() == 7)
	assert(profile[0].y < profile[2].y)
	assert(profile[3].y > 0.5)
	assert(profile[2].z < 0.2)
	assert(profile[5].y < profile[3].y * 0.45)
	var center_y_offsets: Array = fish.get("shell_center_y_offsets")
	assert(center_y_offsets.size() == 7)
	assert(float(center_y_offsets[0]) > 0.14)
	assert(float(center_y_offsets[3]) < -0.12)
	assert(float(center_y_offsets[6]) < -0.12)
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var tail_pivot_1 := fish.get_node_or_null("BodyPivot/TailPivot1") as Node3D
	var tail_pivot_2 := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2") as Node3D
	assert(head != null)
	assert(tail_pivot_1 != null)
	assert(tail_pivot_2 != null)
	assert(head.position.y > 0.18)
	assert(tail_pivot_1.position.y < -0.18)
	assert(abs(tail_pivot_2.position.y) > 0.01)
	var eye := fish.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	assert(eye != null)
	assert(eye.position.y > 0.22)

	fish.call("set_body_profile_shape", "broad_head")
	await get_tree().process_frame
	await get_tree().process_frame
	var broad_profile: Array = fish.get("shell_profile")
	assert(broad_profile[0].y > profile[0].y)
	assert(broad_profile[1].z > profile[1].z)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_editor_model.ok", FileAccess.WRITE)
	file.store_string("body editor model applied")
	file.close()
	print("BODY_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)
