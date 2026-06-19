extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

var _failed := false

func _ready() -> void:
	await _test_unified_surface_replaces_visible_head_mesh_with_outer_shell_geometry()
	if _failed:
		return
	await _test_unified_surface_preserves_cephalofoil_head_width()
	if _failed:
		return
	print("UNIFIED_FISH_RIG_SURFACE_TEST_OK")
	get_tree().quit(0)

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
	fish.queue_free()

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

func _assert_cephalofoil_boundary_ring_in_unified_mesh(fish: FishRig, label: String) -> void:
	var outer := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	_require(outer != null and outer.mesh != null, "%s cephalofoil unified mesh must exist" % label)
	if _failed:
		return
	var boundary_index: int = fish._unified_surface_body_start_index("cephalofoil", fish.eye_head_scale)
	_require(boundary_index > 0, "%s cephalofoil unified surface must use a later body boundary ring" % label)
	if _failed:
		return
	var expected_ring: PackedVector3Array = fish._unified_body_boundary_ring(boundary_index)
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
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		if absf(vertex.x - shell_front_x) <= 0.0005:
			boundary_count += 1
	_require(min_x < shell_front_x - 0.05, "%s unified outer shell must include head vertices ahead of the old shell front" % label)
	if require_front_boundary:
		_require(boundary_count == fish.shell_segments + 1, "%s unified outer shell must share the shell-front boundary ring exactly once" % label)

func _require(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
