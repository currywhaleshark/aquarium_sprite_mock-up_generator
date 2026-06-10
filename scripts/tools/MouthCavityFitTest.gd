extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")
const PF := preload("res://scripts/creature/PrimitiveFactory.gd")

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
	var min_ahead := INF
	for v in cavity_verts:
		var nearest := _nearest_vertex(v, head_verts)
		worst_fit = maxf(worst_fit, v.distance_to(nearest))
		worst_ahead = maxf(worst_ahead, nearest.x - v.x)
		min_ahead = minf(min_ahead, nearest.x - v.x)

	if worst_fit >= 0.03:
		return _fail("MouthCavity is not flush with Head: worst_fit=%.5f" % worst_fit)
	if worst_ahead >= 0.022:
		return _fail("MouthCavity protrudes ahead of Head: worst_ahead=%.5f" % worst_ahead)
	# The lining must keep a real gap from the dented shell everywhere; coplanar vertices
	# z-fight and render as jagged black/teal triangles (the "star" regression).
	if min_ahead <= 0.002:
		return _fail("MouthCavity sits coplanar with Head (depth-fight risk): min_ahead=%.5f" % min_ahead)
	return true

func _pit_metrics(params: Dictionary, gape: float) -> Dictionary:
	var lower_jaw_scale := clampf(float(params.get("lower_jaw_scale", 1.0)), 0.45, 1.8)
	var mouth_width_scale := clampf(float(params.get("mouth_size", 0.08)) / 0.08, 0.65, 2.2)
	var jaw_lm := HeadProfile.jaw_landmarks(params, gape)
	var lower_jaw_half_w := PF.UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.72, 1.12, clampf((lower_jaw_scale - 0.45) / 1.35, 0.0, 1.0)) * mouth_width_scale
	return {
		"buffer_y": 0.03 * lower_jaw_scale * sqrt(mouth_width_scale),
		"pit_half_w": lower_jaw_half_w * 0.84,
		"upper_tip": jaw_lm["upper_tip"],
		"lower_tip": jaw_lm["lower_tip"],
	}

func _assert_floor_overlaps_cavity(fish: FishRig, params: Dictionary, gape: float) -> bool:
	var cavity := fish.get_node_or_null("BodyPivot/Head/MouthCavity") as MeshInstance3D
	if cavity == null or cavity.mesh == null:
		return _fail("MouthCavity is missing for overlap check at gape %.2f" % gape)
	var floor := fish.get_node_or_null("BodyPivot/Head/MouthFloor") as MeshInstance3D
	if floor == null or floor.mesh == null:
		return _fail("MouthFloor is missing for overlap check at gape %.2f" % gape)

	var cavity_verts := _mesh_vertices_in_parent_space(cavity)
	var floor_verts := _mesh_vertices_in_parent_space(floor)
	var metrics := _pit_metrics(params, gape)
	var pit_half_w := float(metrics["pit_half_w"])
	var buffer_y := float(metrics["buffer_y"])
	var slice_width := maxf(pit_half_w * 0.2, 0.001)
	for frac in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		var z_center := float(frac) * pit_half_w
		var min_cavity_y := INF
		var max_floor_y := -INF
		var found_cavity := false
		var found_floor := false
		for v in cavity_verts:
			if absf(v.z - z_center) <= slice_width:
				min_cavity_y = minf(min_cavity_y, v.y)
				found_cavity = true
		for v in floor_verts:
			if absf(v.z - z_center) <= slice_width:
				max_floor_y = maxf(max_floor_y, v.y)
				found_floor = true
		if not found_cavity or not found_floor:
			return _fail("Missing overlap slice vertices at gape %.2f z=%.4f" % [gape, z_center])
		var required_y := min_cavity_y + buffer_y * 0.5
		if max_floor_y < required_y:
			return _fail("MouthFloor does not overlap MouthCavity at gape %.2f z=%.4f: floor_y=%.5f required=%.5f" % [gape, z_center, max_floor_y, required_y])
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

	for gape in [0.3, 0.6, 1.0]:
		var open_params := params.duplicate(true)
		open_params["mouth_open"] = gape
		fish.set_parameters(open_params)
		await get_tree().process_frame
		if not _assert_floor_overlaps_cavity(fish, open_params, gape):
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
