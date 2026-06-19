extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

var _failed := false

func _ready() -> void:
	await _test_unified_surface_uses_shark_head_sampler_without_duplicate_head_mesh()
	if _failed:
		return
	_test_unified_shark_sampler_skips_legacy_neck_tuck()
	if _failed:
		return
	print("UNIFIED_SHARK_RIG_SURFACE_TEST_OK")
	get_tree().quit(0)

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
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		if absf(vertex.x - shell_front_x) <= 0.0005:
			boundary_count += 1
	_require(min_x < shell_front_x - 0.05, "%s unified shark mesh must include rostrum vertices ahead of the old shell front" % label)
	if label == "rest pose":
		_require(boundary_count == shark.shell_segments + 1, "%s unified shark mesh must share the shell-front boundary ring exactly once" % label)

func _assert_unified_boundary_ring(shark: SharkRig, label: String, animated: bool = false) -> void:
	var outer := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	_require(outer != null and outer.mesh != null, "%s unified shark mesh must exist" % label)
	if _failed:
		return
	var expected_ring: PackedVector3Array = shark._unified_body_boundary_ring(0, shark.animated_shell_centers, shark.animated_shell_yaws) if animated else shark._unified_body_boundary_ring(0)
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