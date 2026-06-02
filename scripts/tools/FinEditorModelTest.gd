extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.1,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"fin_color": "#7edfe5",
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.02, "upper_height": 0.22, "lower_height": 0.18, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.02, "upper_height": 0.30, "lower_height": 0.28, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.70, "lower_height": 0.46, "width": 0.42, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": 0.0, "upper_height": 0.34, "lower_height": 0.36, "width": 0.36, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": 0.0, "upper_height": 0.22, "lower_height": 0.24, "width": 0.22, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": 0.0, "upper_height": 0.12, "lower_height": 0.12, "width": 0.07, "roundness": 0.7, "sway_weight": 1.0}
			]
		},
		"dorsal_1_attach_t": 0.32,
		"dorsal_1_shape": "spiny",
		"dorsal_2_enabled": 1.0,
		"dorsal_2_attach_t": 0.72,
		"dorsal_2_shape": "trailing",
		"pelvic_enabled": 1.0,
		"pelvic_attach_t": 0.36,
		"anal_attach_t": 0.7,
		"caudal_shape": "shark_heterocercal"
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var dorsal_1 := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	var dorsal_2 := fish.get_node_or_null("BodyPivot/DorsalFin2") as MeshInstance3D
	var pelvic_l := fish.get_node_or_null("BodyPivot/PelvicFinL") as MeshInstance3D
	var pelvic_r := fish.get_node_or_null("BodyPivot/PelvicFinR") as MeshInstance3D
	var anal := fish.get_node_or_null("BodyPivot/AnalFin") as MeshInstance3D
	var caudal := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot/TailFin") as MeshInstance3D

	assert(dorsal_1 != null)
	assert(dorsal_2 != null)
	assert(pelvic_l != null)
	assert(pelvic_r != null)
	assert(anal != null)
	assert(caudal != null)
	assert(dorsal_1.position.x < dorsal_2.position.x)
	assert(dorsal_1.position.y > 0.0)
	assert(anal.position.y < 0.0)
	assert(abs(pelvic_l.position.z + pelvic_r.position.z) < 0.001)
	assert(abs(dorsal_1.rotation_degrees.z) > 1.0)
	assert(abs(anal.rotation_degrees.z) > 1.0)
	assert(abs(pelvic_l.rotation_degrees.z) > 1.0)

	var dorsal_1_y_before := dorsal_1.position.y
	var dorsal_1_z_before := dorsal_1.rotation_degrees.z
	fish.set_fin_attach("dorsal_1", 0.76)
	assert(dorsal_1.position.x > dorsal_2.position.x - 0.2)
	assert(abs(dorsal_1.position.y - dorsal_1_y_before) > 0.001)
	assert(abs(dorsal_1.rotation_degrees.z - dorsal_1_z_before) > 1.0)

	var caudal_bounds := _mesh_bounds(caudal)
	assert(caudal_bounds["max_y"] > abs(float(caudal_bounds["min_y"])) * 1.25)

	var tail_fin_pivot := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
	assert(tail_fin_pivot != null)
	var low_wave_parameters: Dictionary = fish.parameters.duplicate(true)
	low_wave_parameters["global_sway_amount"] = 18.0
	low_wave_parameters["body_wave_amount"] = 0.05
	fish.set_parameters(low_wave_parameters)
	await get_tree().process_frame
	var low_wave_dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	fish.apply_pose(0.25)
	var low_ripple := _mesh_max_abs_z(low_wave_dorsal)

	var high_wave_parameters: Dictionary = fish.parameters.duplicate(true)
	high_wave_parameters["body_wave_amount"] = 0.95
	high_wave_parameters["dorsal_1_length"] = 0.82
	fish.set_parameters(high_wave_parameters)
	await get_tree().process_frame
	var high_wave_dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	var high_wave_tail := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
	fish.apply_pose(0.25)
	# Median fins move with the body by rippling their mesh in z; the free edge
	# undulates more as the body wave grows, and the rigid yaw rotation is gone.
	var high_ripple := _mesh_max_abs_z(high_wave_dorsal)
	assert(absf(high_wave_dorsal.rotation_degrees.y) < 0.001)
	assert(high_ripple > 0.01)
	assert(high_ripple < 0.09)
	assert(high_ripple > low_ripple + 0.005)
	assert(_dorsal_base_surface_error(fish, high_wave_dorsal, 0.035) < 0.02)

	var high_wave_anal := fish.get_node_or_null("BodyPivot/AnalFin") as MeshInstance3D
	var high_wave_pelvic_l := fish.get_node_or_null("BodyPivot/PelvicFinL") as MeshInstance3D
	assert(high_wave_anal != null)
	assert(high_wave_pelvic_l != null)
	var shell_yaw := fish._sample_animated_shell_yaw(float(fish.parameters.get("dorsal_1_attach_t", 0.45)), fish.animated_shell_yaws)
	var pelvic_shell_yaw := fish._sample_animated_shell_yaw(float(fish.parameters.get("pelvic_attach_t", 0.36)), fish.animated_shell_yaws)
	assert(absf(shell_yaw) > 1.0)
	assert(_mesh_max_abs_z(high_wave_anal) > 0.005)
	assert(absf(high_wave_pelvic_l.rotation_degrees.y - 12.0) < absf(pelvic_shell_yaw) * 0.35)
	fish.apply_pose(0.5)
	assert(absf(high_wave_tail.rotation_degrees.y) < 12.0)

	var rigid_tail_parameters: Dictionary = fish.parameters.duplicate(true)
	rigid_tail_parameters["caudal_shape"] = "halfmoon"
	rigid_tail_parameters["tail_fin_size"] = 0.86
	rigid_tail_parameters["caudal_height_scale"] = 1.2
	rigid_tail_parameters["global_sway_amount"] = 18.0
	rigid_tail_parameters["tail_sway_multiplier"] = 1.2
	rigid_tail_parameters["tail_fin_extra_swing"] = 0.55
	rigid_tail_parameters["fin_softness"] = 0.0
	rigid_tail_parameters["caudal_softness"] = 0.0
	rigid_tail_parameters["fin_rigidity"] = 1.0
	fish.set_parameters(rigid_tail_parameters)
	await get_tree().process_frame
	var rigid_caudal := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot/TailFin") as MeshInstance3D
	fish.apply_pose(0.25)
	var rigid_tail_z := _mesh_max_abs_z(rigid_caudal)
	assert(rigid_tail_z < 0.001)

	var soft_tail_parameters: Dictionary = rigid_tail_parameters.duplicate(true)
	soft_tail_parameters["fin_softness"] = 0.85
	soft_tail_parameters["caudal_softness"] = 1.0
	soft_tail_parameters["fin_rigidity"] = 0.0
	fish.set_parameters(soft_tail_parameters)
	await get_tree().process_frame
	var soft_caudal := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot/TailFin") as MeshInstance3D
	fish.apply_pose(0.25)
	var soft_tail_z := _mesh_max_abs_z(soft_caudal)
	assert(soft_tail_z > rigid_tail_z + 0.025)
	assert(soft_tail_z < 0.28)

	var eel_fin_parameters: Dictionary = fish.parameters.duplicate(true)
	eel_fin_parameters["body_wave_amount"] = 50000.0
	fish.set_parameters(eel_fin_parameters)
	await get_tree().process_frame
	var eel_dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	fish.apply_pose(0.0)
	var previous_ripple_z := _mesh_average_z(eel_dorsal)
	var max_ripple_step := 0.0
	for sample in range(1, 49):
		fish.apply_pose(float(sample) / 48.0)
		var current_ripple_z := _mesh_average_z(eel_dorsal)
		max_ripple_step = maxf(max_ripple_step, absf(current_ripple_z - previous_ripple_z))
		previous_ripple_z = current_ripple_z
	assert(max_ripple_step < 0.08)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_editor_model.ok", FileAccess.WRITE)
	file.store_string("fin editor model slots applied")
	file.close()
	print("FIN_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)

func _mesh_bounds(mesh_instance: MeshInstance3D) -> Dictionary:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	return {"min_y": min_y, "max_y": max_y}

func _mesh_max_abs_z(mesh_instance: MeshInstance3D) -> float:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_abs_z := 0.0
	for vertex in vertices:
		max_abs_z = maxf(max_abs_z, absf(vertex.z))
	return max_abs_z

func _mesh_average_z(mesh_instance: MeshInstance3D) -> float:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var total_z := 0.0
	for vertex in vertices:
		total_z += vertex.z
	return total_z / maxf(float(vertices.size()), 1.0)

func _dorsal_base_surface_error(fish: FishRig, mesh_instance: MeshInstance3D, margin: float) -> float:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var attach_t := float(fish.parameters.get("dorsal_1_attach_t", 0.45))
	var length := float(fish.parameters.get("dorsal_1_length", 0.42))
	var x_span := maxf(fish.shell_profile[fish.shell_profile.size() - 1].x - fish.shell_profile[0].x, 0.001)
	var local_xs := PackedFloat32Array([-length * 0.5, length * 0.5])
	var vertex_indices := PackedInt32Array([1, vertices.size() - 1])
	var max_error := 0.0
	for i in local_xs.size():
		var t_prime := clampf(attach_t + local_xs[i] / x_span, 0.0, 1.0)
		var actual := mesh_instance.transform * vertices[vertex_indices[i]]
		var expected := fish._animated_surface_position("dorsal", t_prime, margin, 0.0, 0.0, fish.animated_shell_centers, fish.animated_shell_yaws)
		max_error = maxf(max_error, actual.distance_to(expected))
	return max_error
