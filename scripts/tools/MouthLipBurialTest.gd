extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

const MAX_LIP_BURIAL := 0.002

func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false

func _mesh_vertices_in_parent_space(node: MeshInstance3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var arrays := node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for v in verts:
		result.append(node.transform * v)
	return result

func _nearest_vertex(point: Vector3, candidates: PackedVector3Array) -> Vector3:
	var best := candidates[0]
	var best_dist := point.distance_squared_to(best)
	for i in range(1, candidates.size()):
		var d := point.distance_squared_to(candidates[i])
		if d < best_dist:
			best_dist = d
			best = candidates[i]
	return best

func _scenario_params() -> Array[Dictionary]:
	return [
		{
			"label": "pale",
			"parameters": {
				"shell_enabled": 1.0,
				"mouth_type": "terminal",
				"mouth_open": 1.0,
				"mouth_size": 0.2,
			},
		},
		{
			"label": "sculpted",
			"parameters": {
				"shell_enabled": 1.0,
				"mouth_type": "terminal",
				"head_shape": "rounded",
				"snout_length": 0.45,
				"snout_taper": 0.7,
				"snout_thickness": 0.6,
				"head_belly_curve": -0.7,
				"head_bottom_flatness": 0.8,
				"head_bump_height": 0.3,
				"mouth_open": 1.0,
				"mouth_size": 0.14,
			},
		},
	]

func _assert_lip_not_buried(fish: FishRig, label: String) -> bool:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head == null or head.mesh == null:
		return _fail("%s: BodyPivot/Head mesh is missing" % label)
	var lip := fish.get_node_or_null("BodyPivot/Head/MouthLipUpper") as MeshInstance3D
	if lip == null or lip.mesh == null:
		return _fail("%s: MouthLipUpper mesh is missing" % label)

	var head_arrays := head.mesh.surface_get_arrays(0)
	var head_verts: PackedVector3Array = head_arrays[Mesh.ARRAY_VERTEX]
	var lip_verts := _mesh_vertices_in_parent_space(lip)
	if head_verts.is_empty() or lip_verts.is_empty():
		return _fail("%s: Head or MouthLipUpper mesh has no vertices" % label)

	var worst_burial := 0.0
	for v in lip_verts:
		var nearest := _nearest_vertex(v, head_verts)
		worst_burial = maxf(worst_burial, v.x - nearest.x)
	if worst_burial >= MAX_LIP_BURIAL:
		return _fail("%s: MouthLipUpper is buried behind Head: worst_burial=%.5f" % [label, worst_burial])
	return true

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false

	for scenario in _scenario_params():
		var scenario_label := String(scenario["label"])
		var base_params: Dictionary = (scenario["parameters"] as Dictionary).duplicate(true)
		for gape in [0.3, 1.0]:
			var open_params := base_params.duplicate(true)
			open_params["mouth_open"] = gape
			fish.set_parameters(open_params)
			await get_tree().process_frame
			await get_tree().process_frame
			if not _assert_lip_not_buried(fish, "%s gape %.1f" % [scenario_label, gape]):
				return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/mouth_lip_burial.ok", FileAccess.WRITE)
	file.store_string("upper mouth lip remains proud of the head surface")
	file.close()
	print("MOUTH_LIP_BURIAL_TEST_OK")
	get_tree().quit(0)
