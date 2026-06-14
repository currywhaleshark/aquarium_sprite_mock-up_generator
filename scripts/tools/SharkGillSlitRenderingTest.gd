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
	assert(_slit_nodes(root).size() == 5)
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
	var slits := _slit_nodes(root)
	assert(slits.size() == 7)
	var first := slits[0] as Node3D
	assert(abs(first.rotation_degrees.z - -18.0) < 0.01)
	assert(abs((slits[slits.size() / 2] as Node3D).position.x - -0.18) < 0.001)
	_assert_slits_hug_shell_surface(shark, root)

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

func _assert_slits_hug_shell_surface(shark: Node, root: Node) -> void:
	var shell := shark.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	assert(shell != null)
	var slits := _slit_nodes(root)
	var previous_x := -INF
	for child in slits:
		var slit := child as MeshInstance3D
		if not _require(slit != null, "slit is not a MeshInstance3D"):
			return
		if not _require(slit.position.x > previous_x + 0.001, "slits should be separated along x"):
			return
		previous_x = slit.position.x
		var surface_z := _positive_shell_surface_z(shell, slit.position.x, slit.position.y)
		if not _require(slit.position.z >= surface_z - 0.004, "slit is buried below shell surface"):
			return
		if not _require(slit.position.z <= surface_z + 0.025, "slit floats above shell surface"):
			return
		if not _require(_mesh_y_span(slit) <= 0.12, "slit visual length is too tall for the shark body"):
			return

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
