extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

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

func _assert_cavity_fits_head(fish: FishRig) -> bool:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head == null or head.mesh == null:
		return _fail("BodyPivot/Head mesh is missing")
	var cavity := fish.get_node_or_null("BodyPivot/Head/MouthCavity") as MeshInstance3D
	if cavity == null or cavity.mesh == null:
		return _fail("BodyPivot/Head/MouthCavity mesh is missing")

	var head_arrays := head.mesh.surface_get_arrays(0)
	var head_verts: PackedVector3Array = head_arrays[Mesh.ARRAY_VERTEX]
	var cavity_verts := _mesh_vertices_in_parent_space(cavity)
	if head_verts.is_empty() or cavity_verts.is_empty():
		return _fail("head or cavity mesh has no vertices")

	var worst_fit := 0.0
	var worst_ahead := 0.0
	for v in cavity_verts:
		var nearest := _nearest_vertex(v, head_verts)
		worst_fit = maxf(worst_fit, v.distance_to(nearest))
		worst_ahead = maxf(worst_ahead, nearest.x - v.x)

	if worst_fit >= 0.02:
		return _fail("MouthCavity is not flush with Head: worst_fit=%.5f" % worst_fit)
	if worst_ahead >= 0.006:
		return _fail("MouthCavity protrudes ahead of Head: worst_ahead=%.5f" % worst_ahead)
	return true

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var params := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"snout_length": 0.45,
		"snout_taper": 0.7,
		"snout_thickness": 0.6,
		"head_belly_curve": -0.7,
		"head_bottom_flatness": 0.8,
		"head_bump_height": 0.3,
		"mouth_open": 1.0,
		"mouth_size": 0.14,
	}
	fish.set_parameters(params)
	await get_tree().process_frame
	if not _assert_cavity_fits_head(fish):
		return

	var closed_params := params.duplicate(true)
	closed_params["mouth_open"] = 0.0
	fish.set_parameters(closed_params)
	await get_tree().process_frame
	if fish.get_node_or_null("BodyPivot/Head/MouthCavity") != null:
		_fail("MouthCavity exists when mouth_open is 0.0")
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/mouth_cavity_fit.ok", FileAccess.WRITE)
	file.store_string("mouth cavity follows the carved head pit")
	file.close()
	print("MOUTH_CAVITY_FIT_TEST_OK")
	get_tree().quit(0)
