extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

var _failed := false

func _ready() -> void:
	await _test_shark_presets_default_to_unified_surface()
	if _failed:
		return
	await _test_unified_shark_reframes_head_ring_handles()
	if _failed:
		return
	await _test_unified_surface_uses_shark_head_sampler_without_duplicate_head_mesh()
	if _failed:
		return
	_test_unified_shark_sampler_skips_legacy_neck_tuck()
	if _failed:
		return
	await _test_unified_shark_neck_has_no_step()
	if _failed:
		return
	print("UNIFIED_SHARK_RIG_SURFACE_TEST_OK")
	get_tree().quit(0)

func _test_shark_presets_default_to_unified_surface() -> void:
	var preset := PresetStoreScript.find_default_for_mode("shark")
	_require(not preset.is_empty(), "default shark preset must load")
	if _failed:
		return
	var parameters: Dictionary = preset.get("parameters", {})
	_require(float(parameters.get("unified_surface_enabled", 0.0)) > 0.5, "default shark preset must enable unified surface")

func _test_unified_shark_reframes_head_ring_handles() -> void:
	var shark: SharkRig = SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false
	shark.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_size": 0.46,
		"head_length": 0.55,
		"snout_length": 0.32,
		"forehead_slope": 0.34,
		"body_height": 0.52,
		"body_width": 0.32,
		"shell_expand": 0.07,
	})
	await get_tree().process_frame
	var boundary_index := shark._unified_surface_body_start_index(String(shark.parameters.get("head_shape", "rounded")), shark.eye_head_scale)
	_require(boundary_index > 0, "unified shark weld boundary must not reuse the logical snout shell ring")
	if _failed:
		return
	var boundary_id := String(shark.shell_ring_ids[boundary_index])
	_require(boundary_id == "front_body", "unified shark weld boundary must use the editable front_body ring, not hidden support ring %s" % boundary_id)
	if _failed:
		return
	var boundary_x := shark.shell_profile[boundary_index].x
	var handles := shark.get_body_ring_handles()
	_require(handles.has("snout") and handles.has("head") and handles.has("front_body"), "unified shark handles must expose snout, head, and front_body")
	if _failed:
		return
	var snout_handle: Dictionary = handles["snout"]
	var head_handle: Dictionary = handles["head"]
	var front_body_handle: Dictionary = handles["front_body"]
	var snout_center: Vector3 = shark.body_pivot.to_local(snout_handle["center"])
	var head_center: Vector3 = shark.body_pivot.to_local(head_handle["center"])
	var front_body_center: Vector3 = shark.body_pivot.to_local(front_body_handle["center"])
	_require(snout_center.x < head_center.x - 0.02, "unified shark snout handle must sit ahead of the head handle")
	_require(head_center.x < boundary_x - 0.005, "unified shark head handle must sit ahead of the generated weld boundary")
	_require(absf(front_body_center.x - boundary_x) <= 0.005, "unified shark front_body handle must sit on the editable weld boundary")
	_require(absf(snout_center.x - shark.shell_profile[0].x) > 0.03, "unified shark snout handle must not stay on the old shell-front support ring")
	if _failed:
		return
	var before_head_x := head_center.x
	shark.drag_ring_handle("head", "center", Vector3(0.08, 0.0, 0.0))
	await get_tree().process_frame
	var moved_handles := shark.get_body_ring_handles()
	var moved_head_handle: Dictionary = moved_handles["head"]
	var moved_head_center: Vector3 = shark.body_pivot.to_local(moved_head_handle["center"])
	_require(moved_head_center.x > before_head_x + 0.005, "unified shark head center drag must move the sampled head handle")
	shark.queue_free()

func _test_unified_surface_uses_shark_head_sampler_without_duplicate_head_mesh() -> void:
	var shark: SharkRig = SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false
	shark.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_size": 0.46,
		"head_length": 0.55,
		"snout_length": 0.32,
		"forehead_slope": 0.34,
		"body_height": 0.52,
		"body_width": 0.32,
		"shell_expand": 0.07,
	})
	await get_tree().process_frame
	_assert_unified_surface_geometry(shark, "rest pose")
	if _failed:
		return
	_assert_unified_boundary_ring(shark, "rest pose")
	if _failed:
		return
	shark.apply_pose(0.31)
	await get_tree().process_frame
	_assert_unified_surface_geometry(shark, "animated pose")
	if _failed:
		return
	_assert_unified_boundary_ring(shark, "animated pose", true)
	shark.queue_free()

func _test_unified_shark_sampler_skips_legacy_neck_tuck() -> void:
	var legacy := {
		"unified_surface_enabled": 0.0,
		"snout_length": 0.32,
		"forehead_slope": 0.34,
		"snout_thickness": 1.0,
		"snout_taper": 0.0,
	}
	var unified := legacy.duplicate(true)
	unified["unified_surface_enabled"] = 1.0
	var u := 0.95
	var theta := PI * 0.5
	var legacy_y := SharkHeadProfile.point_at(legacy, u, theta, 0.32, 0.34, {}).y
	var unified_y := SharkHeadProfile.point_at(unified, u, theta, 0.32, 0.34, {}).y
	_require(unified_y > legacy_y * 1.25, "unified shark sampler must bypass legacy neck tuck: legacy=%.5f unified=%.5f" % [legacy_y, unified_y])

# Regression for the shark dorsal notch / unfilled-cone seam: before the neck loft the shark
# head rings welded straight onto front_body across a large x gap with no rings between,
# leaving a stretched cone with a step. The weld grid must now march forward and grow in
# radius without a step from the head's widest collar through the neck to the body boundary.
func _test_unified_shark_neck_has_no_step() -> void:
	var shark: SharkRig = SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false
	shark.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_size": 0.46,
		"head_length": 0.55,
		"snout_length": 0.32,
		"forehead_slope": 0.34,
		"body_height": 0.52,
		"body_width": 0.32,
		"shell_expand": 0.07,
	})
	await get_tree().process_frame
	var head_shape := String(shark.parameters.get("head_shape", "rounded"))
	var boundary_index := shark._unified_surface_body_start_index(head_shape, shark.eye_head_scale)
	var boundary_x: float = shark.shell_profile[boundary_index].x
	var grid := shark._head_grid_for_unified_surface(
		head_shape, shark.eye_head_scale,
		float(shark.parameters.get("snout_length", 0.0)),
		float(shark.parameters.get("forehead_slope", 0.34)),
		shark._head_sculpt_params(), boundary_x, boundary_index)
	_require(grid.size() >= 6, "unified shark weld must loft neck rings between the head and the body boundary")
	if _failed:
		return
	var collar_index := 0
	var collar_radius := -1.0
	for i in grid.size():
		var r := _ring_yz_radius(grid[i])
		if r >= collar_radius:
			collar_radius = r
			collar_index = i
	var prev_x := _ring_average_x(grid[0])
	for i in range(1, grid.size()):
		var ring: PackedVector3Array = grid[i]
		var x := _ring_average_x(ring)
		_require(x > prev_x - 0.0001, "unified shark weld rings must march forward: x=%.5f after %.5f" % [x, prev_x])
		if i > collar_index:
			var prev_radius := _ring_yz_radius(grid[i - 1])
			var radius := _ring_yz_radius(ring)
			_require(radius >= prev_radius - 0.001, "unified shark neck must not pinch between collar and boundary: radius=%.5f after %.5f" % [radius, prev_radius])
			var slope := absf(radius - prev_radius) / maxf(absf(x - prev_x), 0.0001)
			_require(slope < 1.5, "unified shark neck must not step in radius (단차): slope=%.3f at x=%.5f" % [slope, x])
		prev_x = x
	shark.queue_free()

func _ring_average_x(ring: PackedVector3Array) -> float:
	if ring.is_empty():
		return 0.0
	var total := 0.0
	for point in ring:
		total += point.x
	return total / float(ring.size())

func _ring_yz_radius(ring: PackedVector3Array) -> float:
	if ring.is_empty():
		return 0.0
	var center_y := 0.0
	var center_z := 0.0
	for point in ring:
		center_y += point.y
		center_z += point.z
	center_y /= float(ring.size())
	center_z /= float(ring.size())
	var radius := 0.0
	for point in ring:
		var dy := point.y - center_y
		var dz := point.z - center_z
		radius = maxf(radius, sqrt(dy * dy + dz * dz))
	return radius

func _assert_unified_surface_geometry(shark: SharkRig, label: String) -> void:
	var outer := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	_require(outer != null, "%s unified shark must still expose BodyPivot/OuterShell" % label)
	_require(head != null, "%s unified shark must keep BodyPivot/Head as an attachment anchor" % label)
	_require(head.mesh == null or head.mesh.get_surface_count() == 0, "%s unified shark head anchor must not render a duplicate head mesh" % label)
	_require(outer.mesh != null and outer.mesh.get_surface_count() == 1, "%s unified shark outer shell must render one combined mesh surface" % label)
	if _failed:
		return
	var arrays := outer.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_require(normals.size() == vertices.size(), "%s unified shark mesh must carry normals for the whole surface" % label)
	var min_x := INF
	var boundary_count := 0
	var shell_front_x := shark.shell_profile[0].x
	var boundary_index := shark._unified_surface_body_start_index(String(shark.parameters.get("head_shape", "rounded")), shark.eye_head_scale)
	var boundary_x := shark.shell_profile[boundary_index].x
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		if absf(vertex.x - boundary_x) <= 0.0005:
			boundary_count += 1
	_require(min_x < shell_front_x - 0.05, "%s unified shark mesh must include rostrum vertices ahead of the old shell front" % label)
	if label == "rest pose":
		_require(boundary_count == shark.shell_segments + 1, "%s unified shark mesh must share the editable boundary ring exactly once" % label)

func _assert_unified_boundary_ring(shark: SharkRig, label: String, animated: bool = false) -> void:
	var outer := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	_require(outer != null and outer.mesh != null, "%s unified shark mesh must exist" % label)
	if _failed:
		return
	var boundary_index := shark._unified_surface_body_start_index(String(shark.parameters.get("head_shape", "rounded")), shark.eye_head_scale)
	var expected_ring: PackedVector3Array = shark._unified_body_boundary_ring(boundary_index, shark.animated_shell_centers, shark.animated_shell_yaws) if animated else shark._unified_body_boundary_ring(boundary_index)
	var vertices: PackedVector3Array = outer.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var matching_vertices := 0
	var max_boundary_distance := 0.0
	for vertex in vertices:
		for expected in expected_ring:
			if vertex.distance_to(expected) <= 0.0005:
				matching_vertices += 1
				break
	for expected in expected_ring:
		var best := INF
		for vertex in vertices:
			best = minf(best, vertex.distance_to(expected))
		max_boundary_distance = maxf(max_boundary_distance, best)
	_require(matching_vertices == shark.shell_segments + 1, "%s unified shark boundary ring must appear exactly once: count=%d expected=%d" % [label, matching_vertices, shark.shell_segments + 1])
	_require(max_boundary_distance <= 0.0005, "%s unified shark boundary ring must match the selected body ring: distance=%.6f" % [label, max_boundary_distance])

func _require(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
