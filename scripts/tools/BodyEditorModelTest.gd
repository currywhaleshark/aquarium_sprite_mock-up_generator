extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
		"shell_enabled": 1.0,
		"body_length": 1.45,
		"body_height": 0.58,
		"body_width": 0.34,
		"tail_length": 0.78,
		"tail_height": 0.24,
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.16, "upper_height": 0.24, "lower_height": 0.18, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.12, "upper_height": 0.36, "lower_height": 0.30, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": -0.04, "upper_height": 0.72, "lower_height": 0.68, "width": 0.42, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": -0.12, "upper_height": 0.84, "lower_height": 0.72, "width": 0.36, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": -0.17, "upper_height": 0.26, "lower_height": 0.24, "width": 0.22, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": -0.18, "upper_height": 0.12, "lower_height": 0.12, "width": 0.07, "roundness": 0.7, "sway_weight": 1.0}
			]
		},
		"global_sway_amount": 12.0,
		"tail_sway_multiplier": 1.5,
		"phase_delay": 0.62
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var profile: Array = fish.shell_profile
	assert(profile.size() == 6)
	assert(profile[0].y < profile[2].y)
	assert(profile[3].y > 0.42)
	assert(profile[2].z < 0.2)
	assert(profile[5].y < profile[3].y * 0.45)
	assert(float(profile[5].x) <= 1.45 * 0.55)
	var center_y_offsets: Array = fish.shell_center_y_offsets
	assert(center_y_offsets.size() == 6)
	assert(float(center_y_offsets[0]) > 0.08)
	assert(float(center_y_offsets[3]) < -0.03)
	assert(float(center_y_offsets[5]) < -0.09)
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var body := fish.get_node_or_null("BodyPivot/Body") as MeshInstance3D
	var tail_pivot_1 := fish.get_node_or_null("BodyPivot/TailPivot1") as Node3D
	var tail_pivot_2 := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2") as Node3D
	var tail_fin_pivot := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
	assert(head != null)
	assert(body == null)
	assert(tail_pivot_1 != null)
	assert(tail_pivot_2 != null)
	assert(tail_fin_pivot != null)
	assert(fish.get_node_or_null("BodyPivot/TailPivot1/Tail1") == null)
	assert(fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/Tail2") == null)
	assert(head.position.y > 0.06)
	assert(tail_pivot_1.position.y < -0.09)
	assert(abs(tail_pivot_2.position.y) > 0.01)
	assert(abs(tail_fin_pivot.position.x) < 0.001)
	var eye := fish.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	assert(eye != null)
	assert(eye.position.y > 0.1)

	var before_tail_yaw := tail_pivot_2.rotation_degrees.y
	fish.apply_pose(0.25)
	await get_tree().process_frame
	assert(abs(tail_pivot_2.rotation_degrees.y - before_tail_yaw) > 0.01)

	var low_sway_parameters: Dictionary = fish.parameters.duplicate(true)
	low_sway_parameters["global_sway_amount"] = 2.0
	fish.set_parameters(low_sway_parameters)
	await get_tree().process_frame
	tail_pivot_2 = fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2") as Node3D
	fish.apply_pose(0.25)
	var low_tail_yaw := absf(tail_pivot_2.rotation_degrees.y)
	var high_sway_parameters: Dictionary = fish.parameters.duplicate(true)
	high_sway_parameters["global_sway_amount"] = 18.0
	fish.set_parameters(high_sway_parameters)
	await get_tree().process_frame
	tail_pivot_2 = fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2") as Node3D
	fish.apply_pose(0.25)
	var high_tail_yaw := absf(tail_pivot_2.rotation_degrees.y)
	assert(high_tail_yaw > low_tail_yaw * 3.0)

	var low_body_wave_parameters: Dictionary = fish.parameters.duplicate(true)
	low_body_wave_parameters["global_sway_amount"] = 12.0
	low_body_wave_parameters["body_wave_amount"] = 0.1
	fish.set_parameters(low_body_wave_parameters)
	await get_tree().process_frame
	var low_shell := fish.get_node("BodyPivot/OuterShell") as MeshInstance3D
	var low_shell_before := _ring_vertex(low_shell, 3, 0, 28)
	fish.apply_pose(0.25)
	var low_shell_after := _ring_vertex(low_shell, 3, 0, 28)
	var low_shell_delta := low_shell_before.distance_to(low_shell_after)
	assert(absf((fish.get_node("BodyPivot") as Node3D).rotation_degrees.y) < 0.001)
	var high_body_wave_parameters: Dictionary = fish.parameters.duplicate(true)
	high_body_wave_parameters["body_wave_amount"] = 0.9
	fish.set_parameters(high_body_wave_parameters)
	await get_tree().process_frame
	var high_shell := fish.get_node("BodyPivot/OuterShell") as MeshInstance3D
	var high_shell_before := _ring_vertex(high_shell, 3, 0, 28)
	fish.apply_pose(0.25)
	var high_shell_after := _ring_vertex(high_shell, 3, 0, 28)
	var high_shell_delta := high_shell_before.distance_to(high_shell_after)
	assert(absf((fish.get_node("BodyPivot") as Node3D).rotation_degrees.y) < 0.001)
	assert(high_shell_delta > low_shell_delta * 5.0)

	fish.set_selected_body_ring("front_body")
	var ring_points: Dictionary = fish.get_body_ring_global_points()
	assert(ring_points.has("front_body"))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_editor_model.ok", FileAccess.WRITE)
	file.store_string("body ring model applied")
	file.close()
	print("BODY_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)

func _ring_vertex(mesh_instance: MeshInstance3D, ring_index: int, segment_index: int, segments: int) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices[ring_index * segments + segment_index]
