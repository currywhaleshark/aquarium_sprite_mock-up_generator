class_name SharkMouthMarking
extends RefCounted

const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

static func rebuild(parent: Node3D, parameters: Dictionary) -> Node3D:
	var head := parent.get_node_or_null("Head") as MeshInstance3D
	var root_parent := head if head != null else parent
	var root := root_parent.get_node_or_null("SharkMouth") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "SharkMouth"
		root_parent.add_child(root)
	for child in root.get_children():
		child.free()

	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var projection := clampf(float(parameters.get("shark_jaw_projection", 0.08)), 0.0, 0.4)
	var projection_signal := maxf(gape, projection * 2.0)
	var jaw_drop := clampf(float(parameters.get("shark_lower_jaw_drop", 0.10)), 0.0, 0.4)
	var tooth_count := clampi(int(round(float(parameters.get("shark_tooth_visible_count", 11)))), 0, 24)
	var tooth_size := clampf(float(parameters.get("shark_tooth_size", 0.018)), 0.004, 0.06)
	var tooth_angle := float(parameters.get("shark_tooth_angle", -8.0))
	var furrow_length := clampf(float(parameters.get("shark_labial_furrow_length", 0.04)), 0.0, 0.2)
	var dark_mat := _flat_material(Color(0.015, 0.018, 0.022, 0.92))
	var tooth_mat := _flat_material(Color(0.92, 0.9, 0.78, 0.95))

	var shadow := SharkHeadProfile.build_mouth_interior_shadow(parameters, dark_mat)
	root.add_child(shadow)

	var socket := Node3D.new()
	socket.name = "AttachmentSocket"
	if head != null:
		socket.scale = Vector3(
			1.0 / maxf(absf(head.scale.x), 0.001),
			1.0 / maxf(absf(head.scale.y), 0.001),
			1.0 / maxf(absf(head.scale.z), 0.001)
		)
	root.add_child(socket)

	var lower_teeth := Node3D.new()
	lower_teeth.name = "LowerTeeth"
	socket.add_child(lower_teeth)
	var upper_teeth := Node3D.new()
	upper_teeth.name = "UpperTeeth"
	socket.add_child(upper_teeth)

	if bool(parameters.get("shark_lower_teeth_visible", true)):
		for side in [-1.0, 1.0]:
			var anchor := SharkHeadProfile.mouth_anchor(parameters, float(side))
			anchor.y -= 0.018 + jaw_drop * 0.12 + gape * 0.035
			anchor = _proud(anchor, float(side))
			_add_teeth(lower_teeth, tooth_count, _mouth_width_for_side(parameters, head, float(side)) * 0.72, tooth_size, tooth_angle, _socket_position_for_head_anchor(anchor, head), tooth_mat, false)
	var upper_count := clampi(int(round(float(tooth_count) * maxf(0.35, projection_signal))), 0, tooth_count)
	for side in [-1.0, 1.0]:
		var anchor := SharkHeadProfile.mouth_anchor(parameters, float(side))
		anchor.x -= projection * 0.08
		anchor.y += 0.014 + gape * 0.018
		anchor = _proud(anchor, float(side))
		_add_teeth(upper_teeth, upper_count, _mouth_width_for_side(parameters, head, float(side)) * 0.58, tooth_size * 0.82, -tooth_angle, _socket_position_for_head_anchor(anchor, head), tooth_mat, true)

	if furrow_length > 0.001:
		var right_corners := SharkHeadProfile.mouth_corners(parameters, 1.0)
		var left := _box("LabialFurrowLeft", Vector3(_scaled_x(furrow_length, head), 0.006, 0.01), dark_mat)
		left.position = _socket_position_for_head_anchor(_proud(right_corners[0], 1.0), head)
		left.rotation_degrees.z = -24.0
		socket.add_child(left)
		var right := _box("LabialFurrowRight", Vector3(_scaled_x(furrow_length, head), 0.006, 0.01), dark_mat)
		right.position = _socket_position_for_head_anchor(_proud(right_corners[1], 1.0), head)
		right.rotation_degrees.z = 24.0
		socket.add_child(right)
		for side in [-1.0]:
			var mirror_corners := SharkHeadProfile.mouth_corners(parameters, float(side))
			var mirror_left := _box("LabialFurrowLeftMirror", Vector3(_scaled_x(furrow_length, head), 0.006, 0.01), dark_mat)
			mirror_left.position = _socket_position_for_head_anchor(_proud(mirror_corners[0], float(side)), head)
			mirror_left.rotation_degrees.z = -24.0
			socket.add_child(mirror_left)
			var mirror_right := _box("LabialFurrowRightMirror", Vector3(_scaled_x(furrow_length, head), 0.006, 0.01), dark_mat)
			mirror_right.position = _socket_position_for_head_anchor(_proud(mirror_corners[1], float(side)), head)
			mirror_right.rotation_degrees.z = 24.0
			socket.add_child(mirror_right)

	return root

static func _proud(anchor: Vector3, side: float) -> Vector3:
	# Offset a head-surface anchor outward so the attachment sits proud of the
	# head and is not occluded by it (mirrors the gill-slit surface_z + clearance).
	anchor.z += side * SharkHeadProfile.TOOTH_SURFACE_CLEARANCE
	return anchor

static func _socket_position_for_head_anchor(anchor: Vector3, head: MeshInstance3D) -> Vector3:
	if head == null:
		return anchor
	return Vector3(anchor.x * head.scale.x, anchor.y * head.scale.y, anchor.z * head.scale.z)

static func _mouth_width_for_side(parameters: Dictionary, head: MeshInstance3D, side: float) -> float:
	var corners := SharkHeadProfile.mouth_corners(parameters, side)
	var local_width := absf((corners[1] as Vector3).x - (corners[0] as Vector3).x)
	return _scaled_x(local_width, head)

static func _scaled_x(value: float, head: MeshInstance3D) -> float:
	if head == null:
		return value
	return value * maxf(absf(head.scale.x), 0.001)

static func _box(name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	return node

static func _add_teeth(parent: Node3D, count: int, width: float, size: float, angle: float, center: Vector3, material: Material, upper: bool) -> void:
	if count <= 0:
		return
	var center_offset := float(count - 1) * 0.5
	var spacing := width / maxf(float(maxi(count - 1, 1)), 1.0)
	for index in range(count):
		var tooth := MeshInstance3D.new()
		tooth.name = "Tooth%d" % [index + 1]
		tooth.mesh = _tooth_mesh(size, upper)
		tooth.material_override = material
		tooth.position = center + Vector3((float(index) - center_offset) * spacing, 0.0, 0.0)
		tooth.rotation_degrees.z = angle
		parent.add_child(tooth)

static func _tooth_mesh(size: float, upper: bool) -> ArrayMesh:
	var tip_y := -size if upper else size
	var verts := PackedVector3Array([
		Vector3(-size * 0.36, 0.0, 0.0),
		Vector3(size * 0.36, 0.0, 0.0),
		Vector3(0.0, tip_y, 0.0)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
