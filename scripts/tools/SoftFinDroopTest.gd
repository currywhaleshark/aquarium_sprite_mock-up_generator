extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false

	var rigid_parameters := _base_parameters()
	rigid_parameters["fin_softness"] = 0.0
	rigid_parameters["fin_rigidity"] = 1.0
	rigid_parameters["caudal_softness"] = 0.0
	rigid_parameters["caudal_rigidity"] = 1.0
	rigid_parameters["pectoral_softness"] = 0.0
	rigid_parameters["pectoral_rigidity"] = 1.0
	fish.set_parameters(rigid_parameters)
	await get_tree().process_frame
	fish.apply_pose(0.25)
	var rigid_tail_min_y := _mesh_min_global_y(_tail_fin(fish))
	var rigid_pectoral_min_y := _mesh_min_global_y(_pectoral_fin(fish))

	var soft_parameters := rigid_parameters.duplicate(true)
	soft_parameters["fin_softness"] = 1.0
	soft_parameters["fin_rigidity"] = 0.0
	soft_parameters["caudal_softness"] = 1.0
	soft_parameters["caudal_rigidity"] = 0.0
	soft_parameters["pectoral_softness"] = 1.0
	soft_parameters["pectoral_rigidity"] = 0.0
	fish.set_parameters(soft_parameters)
	await get_tree().process_frame
	fish.apply_pose(0.25)
	var soft_tail := _tail_fin(fish)
	var soft_pectoral := _pectoral_fin(fish)
	var soft_tail_min_y := _mesh_min_global_y(soft_tail)
	var soft_pectoral_min_y := _mesh_min_global_y(soft_pectoral)

	if not _require(soft_tail_min_y < rigid_tail_min_y - 0.025, "soft caudal fin must hang lower in death pose"):
		return
	if not _require(soft_pectoral_min_y < rigid_pectoral_min_y - 0.01, "soft pectoral fin must hang lower in death pose"):
		return

	print("SOFT_FIN_DROOP_TEST_OK")
	get_tree().quit(0)

func _base_parameters() -> Dictionary:
	return {
		"death_pose_enabled": true,
		"shell_enabled": 1.0,
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
		"caudal_shape": "halfmoon",
		"tail_fin_size": 0.72,
		"caudal_height_scale": 1.25,
		"pectoral_shape": "triangle",
		"pectoral_fin_size": 0.42,
		"global_sway_amount": 0.0,
		"tail_sway_multiplier": 0.0
	}

func _tail_fin(fish: FishRig) -> MeshInstance3D:
	var fin := fish.get_node_or_null("BodyPivot/TailPivot1/TailPivot2/TailFinPivot/TailFin") as MeshInstance3D
	if not _require(fin != null, "tail fin must exist"):
		return null
	return fin

func _pectoral_fin(fish: FishRig) -> MeshInstance3D:
	var fin := fish.get_node_or_null("BodyPivot/PectoralFinL") as MeshInstance3D
	if not _require(fin != null, "pectoral fin must exist"):
		return null
	return fin

func _mesh_min_global_y(node: MeshInstance3D) -> float:
	if node == null or node.mesh == null:
		return INF
	var min_y := INF
	for surface_index in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			min_y = minf(min_y, (node.global_transform * vertex).y)
	return min_y

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
