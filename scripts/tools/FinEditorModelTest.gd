extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.call("set_parameters", {
		"shell_enabled": 1.0,
		"shell_expand": 0.1,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"fin_color": "#7edfe5",
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

	var dorsal_1_y_before := dorsal_1.position.y
	fish.call("set_fin_attach", "dorsal_1", 0.76)
	assert(dorsal_1.position.x > dorsal_2.position.x - 0.2)
	assert(abs(dorsal_1.position.y - dorsal_1_y_before) > 0.001)

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
