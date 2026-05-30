extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
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
