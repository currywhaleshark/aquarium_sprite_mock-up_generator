extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

const INTERIOR_DARK_NODES := ["MouthCavity", "MouthUpperInterior", "MouthSideAperture"]
const MAX_AHEAD := 0.022

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

func _closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	var v := vb * denom
	var w := vc * denom
	return a + ab * v + ac * w

func _mesh_triangles(mesh: ArrayMesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var triangles := []
	if indices.is_empty():
		for i in range(0, verts.size() - 2, 3):
			triangles.append([verts[i], verts[i + 1], verts[i + 2]])
	else:
		for i in range(0, indices.size() - 2, 3):
			triangles.append([verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]]])
	return triangles

func _closest_mesh_point(point: Vector3, triangles: Array) -> Vector3:
	var best: Vector3 = triangles[0][0]
	var best_dist := INF
	for tri in triangles:
		var closest := _closest_point_on_triangle(point, tri[0], tri[1], tri[2])
		var d := point.distance_squared_to(closest)
		if d < best_dist:
			best_dist = d
			best = closest
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

func _assert_interior_contained(fish: FishRig, label: String) -> bool:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head == null or head.mesh == null:
		return _fail("%s: BodyPivot/Head mesh is missing" % label)
	var head_triangles := _mesh_triangles(head.mesh as ArrayMesh)
	if head_triangles.is_empty():
		return _fail("%s: Head mesh has no vertices" % label)

	var found_any := false
	for node_name in INTERIOR_DARK_NODES:
		var node := fish.get_node_or_null("BodyPivot/Head/%s" % node_name) as MeshInstance3D
		if node == null:
			continue
		if node.mesh == null:
			return _fail("%s: %s has no mesh" % [label, node_name])
		found_any = true
		var verts := _mesh_vertices_in_parent_space(node)
		if verts.is_empty():
			return _fail("%s: %s has no vertices" % [label, node_name])
		var worst_ahead := 0.0
		for v in verts:
			var nearest := _closest_mesh_point(v, head_triangles)
			worst_ahead = maxf(worst_ahead, nearest.x - v.x)
		if worst_ahead >= MAX_AHEAD:
			return _fail("%s: %s protrudes ahead of Head: worst_ahead=%.5f" % [label, node_name, worst_ahead])

	if not found_any:
		return _fail("%s: no interior dark mouth nodes found" % label)
	return true

func _assert_closed_interior_absent(fish: FishRig, label: String) -> bool:
	for node_name in INTERIOR_DARK_NODES:
		if fish.get_node_or_null("BodyPivot/Head/%s" % node_name) != null:
			return _fail("%s: %s exists when mouth_open is 0.0" % [label, node_name])
	return true

func _mouth_cavity_y_extent(fish: FishRig) -> float:
	var cavity := fish.get_node_or_null("BodyPivot/Head/MouthCavity") as MeshInstance3D
	assert(cavity != null and cavity.mesh != null)
	if cavity.mesh.get_surface_count() == 0:
		return 0.0
	var verts := _mesh_vertices_in_parent_space(cavity)
	assert(not verts.is_empty())
	var min_y := INF
	var max_y := -INF
	for v in verts:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	return max_y - min_y

func _assert_cavity_responds_to_gape(fish: FishRig, base_params: Dictionary) -> bool:
	var extents := {}
	for gape in [0.05, 0.3, 1.0]:
		var params := base_params.duplicate(true)
		params["mouth_open"] = gape
		fish.set_parameters(params)
		await get_tree().process_frame
		await get_tree().process_frame
		extents[gape] = _mouth_cavity_y_extent(fish)

	var near_closed := float(extents[0.05])
	var partial := float(extents[0.3])
	var full := float(extents[1.0])
	if near_closed >= full * 0.35:
		return _fail("MouthCavity y extent does not shrink near closed: g005=%.5f full=%.5f" % [near_closed, full])
	if partial >= full * 0.9:
		return _fail("MouthCavity y extent barely responds to gape: g030=%.5f full=%.5f" % [partial, full])
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
			if not _assert_interior_contained(fish, "%s gape %.1f" % [scenario_label, gape]):
				return

		var closed_params := base_params.duplicate(true)
		closed_params["mouth_open"] = 0.0
		fish.set_parameters(closed_params)
		await get_tree().process_frame
		await get_tree().process_frame
		if not _assert_closed_interior_absent(fish, scenario_label):
			return

		if scenario_label == "pale":
			if not await _assert_cavity_responds_to_gape(fish, base_params):
				return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/mouth_interior_containment.ok", FileAccess.WRITE)
	file.store_string("mouth interior dark meshes remain inside the head silhouette")
	file.close()
	print("MOUTH_INTERIOR_CONTAINMENT_TEST_OK")
	get_tree().quit(0)
