extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

var _failed := false

func _ready() -> void:
	await _test_fish_presets_default_to_unified_surface()
	if _failed:
		return
	await _test_unified_surface_reframes_head_ring_handles()
	if _failed:
		return
	await _test_unified_surface_omits_closed_head_rear_cap_from_weld()
	if _failed:
		return
	await _test_unified_surface_replaces_visible_head_mesh_with_outer_shell_geometry()
	if _failed:
		return
	await _test_unified_surface_preserves_cephalofoil_head_width()
	if _failed:
		return
	await _test_unified_surface_skips_legacy_neck_crutches()
	if _failed:
		return
	await _test_unified_head_ring_handles_sculpt_independently()
	if _failed:
		return
	print("UNIFIED_FISH_RIG_SURFACE_TEST_OK")
	get_tree().quit(0)

# Regression: in unified mode the head ring's top/bottom handles sculpt the head dorsal and
# ventral INDEPENDENTLY. Before, the drag fed the body-ring upper/lower_height, which only
# scaled the head's symmetric average depth - so dragging the top dragged the bottom with it
# (and barely moved). Each edge must now move on its own and stay put when the other is dragged.
func _test_unified_head_ring_handles_sculpt_independently() -> void:
	var params := {
		"shell_enabled": 1.0, "unified_surface_enabled": 1.0, "head_shape": "rounded",
		"head_size": 0.48, "head_length": 0.52, "body_height": 0.58, "body_width": 0.34,
	}
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters(params.duplicate(true))
	await get_tree().process_frame
	var before := _head_handle_edges(fish, "head")
	fish.drag_ring_handle("head", "top", Vector3(0.0, 0.12, 0.0))
	await get_tree().process_frame
	var after := _head_handle_edges(fish, "head")
	_require(after["top"] - before["top"] > 0.03, "head top drag must raise the head top edge (Δ=%.4f)" % (after["top"] - before["top"]))
	_require(absf(after["bot"] - before["bot"]) < 0.012, "head top drag must leave the head bottom edge ~unchanged (Δ=%.4f)" % (after["bot"] - before["bot"]))
	if _failed:
		return
	fish.set_parameters(params.duplicate(true))
	await get_tree().process_frame
	before = _head_handle_edges(fish, "head")
	fish.drag_ring_handle("head", "bottom", Vector3(0.0, -0.12, 0.0))
	await get_tree().process_frame
	after = _head_handle_edges(fish, "head")
	_require(after["bot"] - before["bot"] < -0.03, "head bottom drag must lower the head bottom edge (Δ=%.4f)" % (after["bot"] - before["bot"]))
	_require(absf(after["top"] - before["top"]) < 0.012, "head bottom drag must leave the head top edge ~unchanged (Δ=%.4f)" % (after["top"] - before["top"]))
	if _failed:
		return
	# The snout ring handle resizes the snout's top/bottom independently too (thin snout, so it
	# uses snout_top_curve/snout_belly_curve, a direct offset rather than the girth-faded head
	# curves). Previously the snout just translated / did nothing.
	fish.set_parameters(params.duplicate(true))
	await get_tree().process_frame
	before = _head_handle_edges(fish, "snout")
	fish.drag_ring_handle("snout", "top", Vector3(0.0, 0.12, 0.0))
	await get_tree().process_frame
	after = _head_handle_edges(fish, "snout")
	_require(after["top"] - before["top"] > 0.03, "snout top drag must raise the snout top edge (Δ=%.4f)" % (after["top"] - before["top"]))
	_require(absf(after["bot"] - before["bot"]) < 0.012, "snout top drag must leave the snout bottom edge ~unchanged (Δ=%.4f)" % (after["bot"] - before["bot"]))
	if _failed:
		return
	fish.set_parameters(params.duplicate(true))
	await get_tree().process_frame
	before = _head_handle_edges(fish, "snout")
	fish.drag_ring_handle("snout", "bottom", Vector3(0.0, -0.12, 0.0))
	await get_tree().process_frame
	after = _head_handle_edges(fish, "snout")
	_require(after["bot"] - before["bot"] < -0.03, "snout bottom drag must lower the snout bottom edge (Δ=%.4f)" % (after["bot"] - before["bot"]))
	_require(absf(after["top"] - before["top"]) < 0.012, "snout bottom drag must leave the snout top edge ~unchanged (Δ=%.4f)" % (after["top"] - before["top"]))
	fish.queue_free()

func _head_handle_edges(fish: FishRig, ring_id: String) -> Dictionary:
	var handles := fish.get_body_ring_handles()
	if not handles.has(ring_id):
		return {"top": NAN, "bot": NAN}
	var d: Dictionary = handles[ring_id]
	return {
		"top": fish.body_pivot.to_local(d["top"]).y,
		"bot": fish.body_pivot.to_local(d["bottom"]).y,
	}

func _test_fish_presets_default_to_unified_surface() -> void:
	var preset := PresetStoreScript.find_default_for_mode("fish")
	_require(not preset.is_empty(), "default fish preset must load")
	if _failed:
		return
	var parameters: Dictionary = preset.get("parameters", {})
	_require(float(parameters.get("unified_surface_enabled", 0.0)) > 0.5, "default fish preset must enable unified surface")

func _test_unified_surface_reframes_head_ring_handles() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.48,
		"head_length": 0.52,
		"body_height": 0.58,
		"body_width": 0.34,
		"shell_expand": 0.08,
	})
	await get_tree().process_frame
	var boundary_index := fish._unified_surface_body_start_index("rounded", fish.eye_head_scale)
	_require(boundary_index > 0, "unified fish weld boundary must not reuse the logical snout shell ring")
	if _failed:
		return
	var boundary_id := String(fish.shell_ring_ids[boundary_index])
	_require(boundary_id == "front_body", "unified fish weld boundary must use the editable front_body ring, not hidden support ring %s" % boundary_id)
	if _failed:
		return
	var boundary_x := fish.shell_profile[boundary_index].x
	var handles := fish.get_body_ring_handles()
	_require(handles.has("snout") and handles.has("head") and handles.has("front_body"), "unified fish handles must expose snout, head, and front_body")
	if _failed:
		return
	var snout_handle: Dictionary = handles["snout"]
	var head_handle: Dictionary = handles["head"]
	var front_body_handle: Dictionary = handles["front_body"]
	var snout_center: Vector3 = fish.body_pivot.to_local(snout_handle["center"])
	var head_center: Vector3 = fish.body_pivot.to_local(head_handle["center"])
	var front_body_center: Vector3 = fish.body_pivot.to_local(front_body_handle["center"])
	_require(snout_center.x < head_center.x - 0.02, "unified fish snout handle must sit ahead of the head handle")
	_require(head_center.x < boundary_x - 0.005, "unified fish head handle must sit ahead of the generated weld boundary")
	_require(absf(front_body_center.x - boundary_x) <= 0.005, "unified fish front_body handle must sit on the editable weld boundary")
	_require(absf(snout_center.x - fish.shell_profile[0].x) > 0.03, "unified fish snout handle must not stay on the old shell-front support ring")
	if _failed:
		return
	# Center drag moves the snout along the body via snout_length (it no longer slides the handle
	# off the mesh by changing the vestigial body-ring x). Dragging forward extends the snout and
	# the fixed-sample handle tracks the extended tip.
	var before_snout_x := snout_center.x
	var before_snout_length := float(fish.parameters.get("snout_length", 0.0))
	fish.drag_ring_handle("snout", "center", Vector3(-0.12, 0.0, 0.0))
	await get_tree().process_frame
	var moved_handles := fish.get_body_ring_handles()
	var moved_snout_handle: Dictionary = moved_handles["snout"]
	var moved_snout_center: Vector3 = fish.body_pivot.to_local(moved_snout_handle["center"])
	_require(float(fish.parameters.get("snout_length", 0.0)) > before_snout_length + 0.01, "unified fish snout center drag must lengthen the snout, not slide the handle off it")
	_require(moved_snout_center.x < before_snout_x - 0.005, "unified fish snout center drag must carry the snout handle forward with the extended snout")
	fish.queue_free()

func _test_unified_surface_omits_closed_head_rear_cap_from_weld() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.48,
		"head_length": 0.52,
		"body_height": 0.58,
		"body_width": 0.34,
		"shell_expand": 0.08,
	})
	await get_tree().process_frame
	var boundary_index := fish._unified_surface_body_start_index("rounded", fish.eye_head_scale)
	var boundary_x := fish.shell_profile[boundary_index].x
	var head_grid := fish._head_grid_for_unified_surface(
		"rounded",
		fish.eye_head_scale,
		float(fish.parameters.get("snout_length", 0.0)),
		float(fish.parameters.get("forehead_slope", 0.35)),
		fish._head_sculpt_params(),
		boundary_x,
		boundary_index
	)
	_require(head_grid.size() >= 3, "unified fish head grid must include head rings before the boundary")
	if _failed:
		return
	# The weld must be a single smooth tube: ring centers march strictly forward and, from
	# the head's widest "collar" cross-section to the body boundary, the radius grows without
	# a step. This is the regression for the dorsal 단차 - before the neck loft, the last head
	# ring jumped straight to the (much larger) body ring over a near-zero x gap.
	var collar_grid_index := 0
	var collar_grid_radius := -1.0
	for i in head_grid.size():
		var r := _ring_yz_radius(head_grid[i])
		if r >= collar_grid_radius:
			collar_grid_radius = r
			collar_grid_index = i
	var prev_x := _ring_average_x(head_grid[0])
	for i in range(1, head_grid.size()):
		var ring: PackedVector3Array = head_grid[i]
		var x := _ring_average_x(ring)
		_require(x > prev_x - 0.0001, "unified fish weld rings must march forward (no folded neck): x=%.5f after %.5f" % [x, prev_x])
		if i > collar_grid_index:
			var prev_radius := _ring_yz_radius(head_grid[i - 1])
			var radius := _ring_yz_radius(ring)
			# The tangent-continuous (C1) neck loft lets the girth crown a hair above the boundary
			# near the shoulder and settle back, which is smoother than a forced-monotone ramp, so a
			# sub-percent dip is expected. A real pinch/step is large and is caught by the slope guard.
			_require(radius >= prev_radius - maxf(0.01, prev_radius * 0.03), "unified fish neck must not pinch between collar and boundary: radius=%.5f after %.5f" % [radius, prev_radius])
			var slope := absf(radius - prev_radius) / maxf(absf(x - prev_x), 0.0001)
			_require(slope < 1.5, "unified fish neck must not step in radius (단차): slope=%.3f at x=%.5f" % [slope, x])
		prev_x = x
	if _failed:
		return
	var last_head_ring: PackedVector3Array = head_grid[head_grid.size() - 2]
	var boundary_ring: PackedVector3Array = head_grid[head_grid.size() - 1]
	var radius := _ring_yz_radius(last_head_ring)
	var boundary_radius := _ring_yz_radius(boundary_ring)
	_require(radius > 0.015, "unified fish weld must not include the closed rear head cap before the body boundary: radius=%.6f" % radius)
	_require(radius >= boundary_radius * 0.7, "unified fish neck loft must meet the body boundary smoothly: neck_radius=%.6f boundary_radius=%.6f" % [radius, boundary_radius])
	fish.queue_free()

func _test_unified_surface_replaces_visible_head_mesh_with_outer_shell_geometry() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.48,
		"head_length": 0.52,
		"body_height": 0.58,
		"body_width": 0.34,
		"shell_expand": 0.08,
	})
	await get_tree().process_frame
	_assert_unified_surface_geometry(fish, "rest pose")
	if _failed:
		return
	fish.apply_pose(0.31)
	await get_tree().process_frame
	_assert_unified_surface_geometry(fish, "animated pose")
	fish.queue_free()


func _test_unified_surface_preserves_cephalofoil_head_width() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_shape": "cephalofoil",
		"head_size": 0.42,
		"head_length": 0.44,
		"body_height": 0.48,
		"body_width": 0.28,
		"shell_expand": 0.06,
	})
	await get_tree().process_frame
	_assert_unified_surface_geometry(fish, "cephalofoil rest pose", false)
	if _failed:
		return
	_assert_cephalofoil_width_in_unified_mesh(fish, "cephalofoil rest pose")
	if _failed:
		return
	_assert_cephalofoil_boundary_ring_in_unified_mesh(fish, "cephalofoil rest pose")
	if _failed:
		return
	fish.apply_pose(0.31)
	await get_tree().process_frame
	_assert_unified_surface_geometry(fish, "cephalofoil animated pose", false)
	if _failed:
		return
	_assert_cephalofoil_width_in_unified_mesh(fish, "cephalofoil animated pose")
	if _failed:
		return
	_assert_cephalofoil_boundary_ring_in_unified_mesh(fish, "cephalofoil animated pose", true)
	fish.queue_free()

func _test_unified_surface_skips_legacy_neck_crutches() -> void:
	var parameters := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.48,
		"head_length": 0.52,
		"body_height": 0.58,
		"body_width": 0.34,
		"shell_expand": 0.08,
		"head_top_curve": 0.22,
		"head_belly_curve": -0.12,
	}
	var legacy: FishRig = FishRigScript.new()
	add_child(legacy)
	legacy.auto_animate = false
	legacy.set_parameters(parameters.duplicate(true))
	await get_tree().process_frame
	var legacy_floor := maxf(_max_abs(legacy.shell_head_floor_y), _max_abs(legacy.shell_head_floor_z))
	legacy.queue_free()
	_require(legacy_floor > 0.0001, "non-unified shell must retain legacy neck floor coverage for comparison")
	if _failed:
		return
	var unified_parameters := parameters.duplicate(true)
	unified_parameters["unified_surface_enabled"] = 1.0
	var unified: FishRig = FishRigScript.new()
	add_child(unified)
	unified.auto_animate = false
	unified.set_parameters(unified_parameters)
	await get_tree().process_frame
	var unified_floor := maxf(_max_abs(unified.shell_head_floor_y), _max_abs(unified.shell_head_floor_z))
	unified.queue_free()
	_require(unified_floor <= 0.0001, "unified surface must bypass legacy neck floor crutches: floor=%.6f" % unified_floor)

func _assert_cephalofoil_width_in_unified_mesh(fish: FishRig, label: String) -> void:
	var outer := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	_require(outer != null and outer.mesh != null, "%s cephalofoil unified mesh must exist" % label)
	if _failed:
		return
	var vertices: PackedVector3Array = outer.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mesh_max_z := 0.0
	for vertex in vertices:
		mesh_max_z = maxf(mesh_max_z, absf(vertex.z))
	var body_max_z := 0.0
	for shell_ring in fish.shell_profile:
		body_max_z = maxf(body_max_z, absf(shell_ring.z))
	_require(mesh_max_z > body_max_z * 1.18, "%s unified cephalofoil head must be visibly wider than the body: mesh_z=%.4f body_z=%.4f" % [label, mesh_max_z, body_max_z])

func _assert_cephalofoil_boundary_ring_in_unified_mesh(fish: FishRig, label: String, animated: bool = false) -> void:
	var outer := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	_require(outer != null and outer.mesh != null, "%s cephalofoil unified mesh must exist" % label)
	if _failed:
		return
	var boundary_index: int = fish._unified_surface_body_start_index("cephalofoil", fish.eye_head_scale)
	_require(boundary_index > 0, "%s cephalofoil unified surface must use a later body boundary ring" % label)
	if _failed:
		return
	var expected_ring: PackedVector3Array = fish._unified_body_boundary_ring(boundary_index, fish.animated_shell_centers, fish.animated_shell_yaws) if animated else fish._unified_body_boundary_ring(boundary_index)
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
	_require(matching_vertices == fish.shell_segments + 1, "%s cephalofoil boundary ring must appear exactly once: count=%d expected=%d" % [label, matching_vertices, fish.shell_segments + 1])
	_require(max_boundary_distance <= 0.0005, "%s cephalofoil boundary ring must match the selected body ring: distance=%.6f" % [label, max_boundary_distance])

func _assert_unified_surface_geometry(fish: FishRig, label: String, require_front_boundary: bool = true) -> void:
	var outer := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	_require(outer != null, "%s unified rig must still expose BodyPivot/OuterShell" % label)
	_require(head != null, "%s unified rig must keep BodyPivot/Head as an attachment anchor" % label)
	_require(head.mesh == null or head.mesh.get_surface_count() == 0, "%s unified rig head anchor must not render a duplicate head mesh" % label)
	_require(outer.mesh != null and outer.mesh.get_surface_count() == 1, "%s unified outer shell must render one combined mesh surface" % label)
	if _failed:
		return
	var arrays := outer.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_require(normals.size() == vertices.size(), "%s unified outer shell must carry normals for the whole surface" % label)
	var min_x := INF
	var boundary_count := 0
	var shell_front_x := fish.shell_profile[0].x
	var head_shape := String(fish.parameters.get("head_shape", "rounded"))
	var boundary_index := fish._unified_surface_body_start_index(head_shape, fish.eye_head_scale)
	var expected_boundary: PackedVector3Array = fish._unified_body_boundary_ring(boundary_index, fish.animated_shell_centers, fish.animated_shell_yaws) if not fish.animated_shell_centers.is_empty() else fish._unified_body_boundary_ring(boundary_index)
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		for expected in expected_boundary:
			if vertex.distance_to(expected) <= 0.0005:
				boundary_count += 1
				break
	_require(min_x < shell_front_x - 0.05, "%s unified outer shell must include head vertices ahead of the old shell front" % label)
	if require_front_boundary:
		_require(boundary_count == fish.shell_segments + 1, "%s unified outer shell must share the editable boundary ring exactly once" % label)

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

func _max_abs(values: Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, absf(float(value)))
	return result

func _require(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
