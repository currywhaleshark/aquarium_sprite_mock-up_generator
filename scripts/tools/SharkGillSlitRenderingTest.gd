extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	var shark := SharkRigScript.new()
	add_child(shark)
	var parameters := {
		"creature_type": "shark",
		"body_length": 5.8,
		"body_height": 0.42,
		"body_width": 0.28,
		"head_size": 0.42,
		"head_offset": -0.78,
		"head_shape": "pointed",
		"snout_length": 0.22,
		"forehead_slope": 0.2,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_gill_slit_length": 0.22,
		"shark_gill_slit_spacing": 0.055,
		"shark_gill_slit_angle": -8.0,
		"shark_gill_slit_depth": 0.65,
		"shark_gill_slit_position_x": -0.28,
		"shark_gill_slit_position_y": 0.08,
		"gill_mark": "operculum",
		"operculum_size": 1.0
	}
	shark.set_parameters(parameters)
	await get_tree().process_frame
	var root := shark.get_node_or_null("BodyPivot/SharkGillSlits")
	assert(root != null)
	# One slit per gill on EACH flank -> 2x the gill count.
	assert(_slit_nodes(root).size() == 10)
	assert(_slit_nodes_side(root, "L").size() == 5)
	assert(_slit_nodes_side(root, "R").size() == 5)
	assert(shark.get_node_or_null("BodyPivot/GillMark_operculum") == null)
	for slit in _slit_nodes(root):
		assert(slit is MeshInstance3D)
		assert(String(slit.name).begins_with("SharkGillSlit"))
	_assert_slits_hug_shell_surface(shark, root)

	parameters["shark_gill_slit_count"] = 7
	parameters["shark_gill_slit_angle"] = -18.0
	parameters["shark_gill_slit_position_x"] = -0.18
	shark.set_parameters(parameters)
	await get_tree().process_frame
	root = shark.get_node_or_null("BodyPivot/SharkGillSlits")
	assert(_slit_nodes(root).size() == 14)
	var left := _slit_nodes_side(root, "L")
	assert(left.size() == 7)
	assert(abs((left[0] as Node3D).rotation_degrees.z - -18.0) < 0.01)
	# centre gill of the cluster sits at position_x on each flank
	assert(abs((left[left.size() / 2] as Node3D).position.x - -0.18) < 0.001)
	_assert_slits_hug_shell_surface(shark, root)

	await _assert_unified_slits_follow_body_surface(parameters)

	parameters["shark_gill_slit_enabled"] = false
	shark.set_parameters(parameters)
	await get_tree().process_frame
	root = shark.get_node_or_null("BodyPivot/SharkGillSlits")
	assert(root != null)
	assert(not (root as Node3D).visible)
	assert(_slit_nodes(root).is_empty())
	print("SHARK_GILL_SLIT_RENDERING_TEST_OK")
	get_tree().quit(0)

func _slit_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	for child in root.get_children():
		if String(child.name).begins_with("SharkGillSlit"):
			result.append(child)
	return result

func _slit_nodes_side(root: Node, suffix: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in _slit_nodes(root):
		if String(child.name).ends_with(suffix):
			result.append(child)
	return result

func _assert_slits_hug_shell_surface(shark: Node, root: Node) -> void:
	var shell := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	assert(shell != null)
	# Check each flank independently: x marches forward within a side, and the slit hugs that
	# flank's surface (|z| ~ surface_z), on whichever side it sits.
	for suffix in ["L", "R"]:
		var previous_x := -INF
		for child in _slit_nodes_side(root, suffix):
			var slit := child as MeshInstance3D
			if not _require(slit != null, "slit is not a MeshInstance3D"):
				return
			if not _require(slit.position.x > previous_x + 0.001, "slits should be separated along x"):
				return
			previous_x = slit.position.x
			var side_sign := 1.0 if suffix == "L" else -1.0
			if not _require(side_sign * slit.position.z > 0.0, "slit %s must sit on the %s flank" % [slit.name, suffix]):
				return
			var surface_z := _positive_shell_surface_z(shell, slit.position.x, slit.position.y)
			var z_abs := absf(slit.position.z)
			if not _require(z_abs >= surface_z - 0.004, "slit is buried below shell surface"):
				return
			if not _require(z_abs <= surface_z + 0.025, "slit floats above shell surface"):
				return
			if not _require(_mesh_y_span(slit) <= 0.12, "slit visual length is too tall for the shark body"):
				return

# The gills ride the body surface (not the rigid head), so through a turn pose the cluster must
# stay glued to the shell at its x rather than peeling off as the body bends.
func _assert_unified_slits_follow_body_surface(parameters: Dictionary) -> void:
	var shark := SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false
	var pose_parameters := parameters.duplicate(true)
	pose_parameters["unified_surface_enabled"] = 1.0
	pose_parameters["turn_amount"] = 1.0
	pose_parameters["turn_phase"] = 0.48
	pose_parameters["turn_direction"] = 1.0
	pose_parameters["turn_curve_bias"] = 1.0
	shark.set_parameters(pose_parameters)
	await get_tree().process_frame
	var root := shark.get_node_or_null("BodyPivot/SharkGillSlits")
	var slits := _slit_nodes(root)
	if not _require(slits.size() > 0, "unified shark gill slits must exist"):
		return
	var center_slit := _slit_nodes_side(root, "L")[2] as Node3D
	if not _require(_slit_surface_gap(shark, center_slit) < 0.06, "gill slit must hug the body surface in a turn pose"):
		return
	shark.apply_pose(0.33)
	await get_tree().process_frame
	if not _require(_slit_surface_gap(shark, center_slit) < 0.06, "gill slit must stay on the body surface through the pose (no detachment)"):
		return
	shark.queue_free()

# Smallest distance from the slit to any OuterShell vertex (global space) - how far it floats
# off the body.
func _slit_surface_gap(shark: Node, slit: Node3D) -> float:
	var shell := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return INF
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var slit_pos := slit.global_position
	var best := INF
	for vertex in verts:
		best = minf(best, slit_pos.distance_to(shell.to_global(vertex)))
	return best

func _positive_shell_surface_z(shell: MeshInstance3D, local_x: float, local_y: float) -> float:
	var arrays := shell.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var best_distance := INF
	var best_z := 0.0
	for vertex in verts:
		if vertex.z < 0.0:
			continue
		var dx := vertex.x - local_x
		var dy := vertex.y - local_y
		var distance := dx * dx + dy * dy
		if distance < best_distance:
			best_distance = distance
			best_z = vertex.z
	return best_z

func _mesh_y_span(node: MeshInstance3D) -> float:
	if node.mesh == null:
		return 0.0
	return node.mesh.get_aabb().size.y * node.scale.y

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
