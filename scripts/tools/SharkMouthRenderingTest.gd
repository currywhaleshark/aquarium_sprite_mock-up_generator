extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

var _failed := false

func _ready() -> void:
	var shark := SharkRigScript.new()
	add_child(shark)
	var parameters := _base_parameters()
	shark.set_parameters(parameters)
	await get_tree().process_frame

	_assert_shark_mouth_attachment_contract(shark)
	if _failed:
		return
	_assert_no_fish_mouth_nodes(shark)
	if _failed:
		return
	_assert_attachments_near_head_mesh(shark)
	if _failed:
		return

	parameters["shark_mouth_gape"] = 0.32
	parameters["shark_jaw_projection"] = 0.16
	shark.set_parameters(parameters)
	await get_tree().process_frame
	_assert_shark_mouth_attachment_contract(shark)
	if _failed:
		return
	_assert_attachments_near_head_mesh(shark)
	if _failed:
		return

	parameters["mouth_open"] = 0.0
	parameters["shark_mouth_gape"] = 0.0
	parameters["shark_jaw_projection"] = 0.0
	shark.set_parameters(parameters)
	await get_tree().process_frame
	_assert_no_fish_mouth_nodes(shark)
	if _failed:
		return

	shark.rebuild()
	await get_tree().process_frame
	if not _require(shark.get_node_or_null("BodyPivot/Head/SharkMouth/AttachmentSocket") != null, "shark mouth socket must survive rebuild"):
		return
	if not _require(shark.get_node_or_null("BodyPivot/SharkGillSlits") != null, "shark gills must survive rebuild"):
		return
	_assert_no_fish_mouth_nodes(shark)
	if _failed:
		return

	print("SHARK_MOUTH_RENDERING_TEST_OK")
	get_tree().quit(0)

func _base_parameters() -> Dictionary:
	return {
		"creature_type": "shark",
		"body_length": 5.8,
		"body_height": 0.42,
		"body_width": 0.28,
		"head_shape": "pointed",
		"head_size": 0.42,
		"head_offset": -0.78,
		"snout_length": 0.22,
		"forehead_slope": 0.2,
		"mouth_type": "terminal",
		"mouth_detail": "lip",
		"mouth_open": 0.32,
		"mouth_size": 0.16,
		"jaw_offset": 0.4,
		"lower_jaw_length": 0.4,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_position_x": -0.96,
		"shark_mouth_position_y": -0.13,
		"shark_mouth_width": 0.18,
		"shark_mouth_curve": 0.58,
		"shark_mouth_gape": 0.16,
		"shark_jaw_projection": 0.08,
		"shark_lower_jaw_drop": 0.10,
		"shark_lower_teeth_visible": true,
		"shark_tooth_visible_count": 11,
		"shark_tooth_size": 0.018,
		"shark_tooth_angle": -8.0,
		"shark_labial_furrow_length": 0.04
	}

func _assert_shark_mouth_attachment_contract(shark: Node) -> void:
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if not _require(head != null, "shark head must exist"):
		return
	var root := head.get_node_or_null("SharkMouth") as Node3D
	if not _require(root != null, "SharkMouth root must be under Head"):
		return
	if not _require(root.get_parent() == head, "SharkMouth root must be a Head child"):
		return
	var socket := root.get_node_or_null("AttachmentSocket") as Node3D
	if not _require(socket != null, "inverse-scale attachment socket must exist"):
		return
	if not _require(_near(socket.scale.x, 1.0 / maxf(absf(head.scale.x), 0.001)), "socket x scale must cancel head scale"):
		return
	if not _require(_near(socket.scale.y, 1.0 / maxf(absf(head.scale.y), 0.001)), "socket y scale must cancel head scale"):
		return
	if not _require(_near(socket.scale.z, 1.0 / maxf(absf(head.scale.z), 0.001)), "socket z scale must cancel head scale"):
		return
	if not _require(socket.get_node_or_null("LowerTeeth") != null, "LowerTeeth must be under AttachmentSocket"):
		return
	if not _require(socket.get_node_or_null("UpperTeeth") != null, "UpperTeeth must be under AttachmentSocket"):
		return
	if not _require(socket.get_node_or_null("LabialFurrowLeft") != null, "LabialFurrowLeft must be under AttachmentSocket"):
		return
	if not _require(socket.get_node_or_null("LabialFurrowRight") != null, "LabialFurrowRight must be under AttachmentSocket"):
		return
	if not _require(root.get_node_or_null("MouthInteriorShadow") != null, "MouthInteriorShadow must exist under the head-scaled root"):
		return
	if not _require(socket.get_node_or_null("MouthInteriorShadow") == null, "MouthInteriorShadow must not be inverse-scaled"):
		return
	for old_name in ["MouthCrescent", "LowerJaw", "ProjectedUpperJaw"]:
		if not _require(root.find_child(old_name, true, false) == null, "old overlay node must be absent: %s" % old_name):
			return

func _assert_no_fish_mouth_nodes(shark: Node) -> void:
	var body := shark.get_node_or_null("BodyPivot")
	var head := shark.get_node_or_null("BodyPivot/Head")
	if not _require(body != null and head != null, "body/head must exist"):
		return
	for node_name in ["Mouth", "MouthLowerJaw", "MouthCavity", "MouthFloor", "MouthLipUpper", "MouthDetail_lip"]:
		if not _require(body.get_node_or_null(node_name) == null, "fish mouth node must not be under BodyPivot: %s" % node_name):
			return
		if not _require(head.get_node_or_null(node_name) == null, "fish mouth node must not be under Head: %s" % node_name):
			return
		if not _require(shark.find_child(node_name, true, false) == null, "fish mouth descendant must be absent: %s" % node_name):
			return

func _assert_attachments_near_head_mesh(shark: Node) -> void:
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var socket := shark.get_node_or_null("BodyPivot/Head/SharkMouth/AttachmentSocket") as Node3D
	if not _require(head != null and socket != null, "head/socket must exist for attachment distance checks"):
		return
	var checked := 0
	for node in _mesh_descendants(socket):
		var mesh_node := node as MeshInstance3D
		var local := head.to_local(mesh_node.global_position)
		if not _require(_nearest_vertex_distance(head, local) <= 0.11, "attachment floats too far from head mesh: %s" % mesh_node.name):
			return
		checked += 1
	if not _require(checked > 0, "attachment distance check must inspect mesh descendants"):
		return

func _mesh_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_mesh_descendants(child))
	return result

func _nearest_vertex_distance(head: MeshInstance3D, local_position: Vector3) -> float:
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var best := INF
	for vertex in verts:
		best = minf(best, vertex.distance_to(local_position))
	return best

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false
