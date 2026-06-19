extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

var _failed := false

func _ready() -> void:
	await _test_unified_surface_replaces_visible_head_mesh_with_outer_shell_geometry()
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

func _assert_unified_surface_geometry(fish: FishRig, label: String) -> void:
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
	_require(boundary_count == fish.shell_segments + 1, "%s unified outer shell must share the shell-front boundary ring exactly once" % label)

func _require(condition: bool, message: String) -> void:
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)