extends Node

# Median + caudal fins are flat sheets thin along local z, so in the head-on N/S export
# views of the settled death pose they sit edge-on and vanish. The death pose now bows
# their free margin slightly out of plane (local z) so they keep a silhouette from every
# direction. This guards that bow -- especially for *stiff* fins, which used to early-out
# of the death settle and stay perfectly planar.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var flat := await _max_abs_fin_z(0.0)
	var bowed := await _max_abs_fin_z(0.15)
	for fin_name in ["TailFin", "DorsalFin1", "AnalFin"]:
		var flat_z := float(flat.get(fin_name, INF))
		var bowed_z := float(bowed.get(fin_name, 0.0))
		if not _require(flat_z < 0.01, "%s should be ~planar in death pose without bow (z=%f)" % [fin_name, flat_z]):
			return
		if not _require(bowed_z > flat_z + 0.01, "%s should bow out of plane in death pose (flat=%f bowed=%f)" % [fin_name, flat_z, bowed_z]):
			return
	print("DEATH_FIN_LATERAL_BOW_TEST_OK")
	get_tree().quit(0)

func _max_abs_fin_z(bow: float) -> Dictionary:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var parameters := _base_parameters()
	parameters["death_fin_lateral_bow"] = bow
	fish.set_parameters(parameters)
	await get_tree().process_frame
	fish.apply_pose(0.25)
	var result := {}
	for fin_name in ["TailFin", "DorsalFin1", "AnalFin"]:
		result[fin_name] = _max_abs_mesh_z(fish.find_child(fin_name, true, false) as MeshInstance3D)
	fish.queue_free()
	await get_tree().process_frame
	return result

func _max_abs_mesh_z(node: MeshInstance3D) -> float:
	if node == null or node.mesh == null:
		return INF
	var max_z := 0.0
	for surface_index in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			max_z = maxf(max_z, absf(vertex.z))
	return max_z

# Rigid fins (softness 0, rigidity 1): the death settle has no droop to apply, so the
# only out-of-plane z can come from the lateral bow -- the case that used to render the
# fins invisible from N/S.
func _base_parameters() -> Dictionary:
	return {
		"death_pose_enabled": true,
		"shell_enabled": 1.0,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"fin_color": "#7edfe5",
		"fin_softness": 0.0,
		"fin_rigidity": 1.0,
		"caudal_softness": 0.0,
		"caudal_rigidity": 1.0,
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
		"caudal_shape": "halfmoon",
		"tail_fin_size": 0.72,
		"caudal_height_scale": 1.25,
		"global_sway_amount": 0.0,
		"tail_sway_multiplier": 0.0
	}

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
