class_name SharkMouthMarking
extends RefCounted

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

	var position_x := _head_local_x(head, float(parameters.get("shark_mouth_position_x", -0.96)))
	var position_y := _head_local_y(head, float(parameters.get("shark_mouth_position_y", -0.13)))
	var width := maxf(float(parameters.get("shark_mouth_width", 0.18)), 0.02)
	var curve := clampf(float(parameters.get("shark_mouth_curve", 0.58)), 0.0, 1.0)
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var projection := clampf(float(parameters.get("shark_jaw_projection", 0.08)), 0.0, 0.4)
	var jaw_drop := clampf(float(parameters.get("shark_lower_jaw_drop", 0.10)), 0.0, 0.4)
	var tooth_count := clampi(int(round(float(parameters.get("shark_tooth_visible_count", 11)))), 0, 24)
	var tooth_size := clampf(float(parameters.get("shark_tooth_size", 0.018)), 0.004, 0.06)
	var tooth_angle := float(parameters.get("shark_tooth_angle", -8.0))
	var furrow_length := clampf(float(parameters.get("shark_labial_furrow_length", 0.04)), 0.0, 0.2)
	var z_outset := _head_local_outset(head, 0.004)
	var mouth_position := _head_surface_point(head, position_x, position_y, z_outset)
	var dark_mat := _flat_material(Color(0.015, 0.018, 0.022, 0.92))
	var tooth_mat := _flat_material(Color(0.92, 0.9, 0.78, 0.95))

	var mouth := _box("MouthCrescent", Vector3(width, 0.012 + curve * 0.018, 0.014), dark_mat)
	mouth.position = mouth_position
	mouth.rotation_degrees.z = -8.0 + curve * 16.0
	root.add_child(mouth)

	var lower_jaw := _box("LowerJaw", Vector3(width * 0.86, 0.01 + jaw_drop * 0.045, 0.012), dark_mat)
	lower_jaw.position = _head_surface_point(head, position_x + projection * 0.10, position_y - jaw_drop * 0.30 - gape * 0.04, z_outset + 0.012)
	lower_jaw.rotation_degrees.z = 4.0 + jaw_drop * 18.0
	root.add_child(lower_jaw)

	var projection_signal := maxf(gape, projection * 2.0)
	if projection_signal >= 0.24:
		var upper := _box("ProjectedUpperJaw", Vector3(width * 0.58, 0.012, 0.012), dark_mat)
		upper.position = _head_surface_point(head, position_x - projection * 0.18, position_y + 0.025 + gape * 0.02, z_outset + 0.014)
		upper.rotation_degrees.z = -6.0
		root.add_child(upper)

	var lower_teeth := Node3D.new()
	lower_teeth.name = "LowerTeeth"
	root.add_child(lower_teeth)
	if bool(parameters.get("shark_lower_teeth_visible", true)):
		_add_teeth(lower_teeth, tooth_count, width * 0.72, tooth_size, tooth_angle, _head_surface_point(head, position_x, position_y - 0.018 - jaw_drop * 0.12, z_outset + 0.024), tooth_mat, false)

	var upper_teeth := Node3D.new()
	upper_teeth.name = "UpperTeeth"
	root.add_child(upper_teeth)
	var upper_count := clampi(int(round(float(tooth_count) * maxf(0.35, projection_signal))), 0, tooth_count)
	_add_teeth(upper_teeth, upper_count, width * 0.58, tooth_size * 0.82, -tooth_angle, _head_surface_point(head, position_x - projection * 0.08, position_y + 0.014 + gape * 0.018, z_outset + 0.026), tooth_mat, true)

	if furrow_length > 0.001:
		var left := _box("LabialFurrowLeft", Vector3(furrow_length, 0.006, 0.01), dark_mat)
		left.position = _head_surface_point(head, position_x + width * 0.48, position_y - 0.01, z_outset + 0.014)
		left.rotation_degrees.z = -24.0
		root.add_child(left)
		var right := _box("LabialFurrowRight", Vector3(furrow_length, 0.006, 0.01), dark_mat)
		right.position = _head_surface_point(head, position_x - width * 0.48, position_y - 0.01, z_outset + 0.014)
		right.rotation_degrees.z = 24.0
		root.add_child(right)

	return root

static func _head_local_x(head: MeshInstance3D, value: float) -> float:
	var bounds := _mesh_bounds(head)
	return clampf(value * 0.5, bounds.position.x + 0.025, bounds.position.x + bounds.size.x - 0.025)

static func _head_local_y(head: MeshInstance3D, value: float) -> float:
	var bounds := _mesh_bounds(head)
	return clampf(value, bounds.position.y + 0.025, bounds.position.y + bounds.size.y - 0.025)

static func _head_surface_point(head: MeshInstance3D, local_x: float, local_y: float, local_outset: float) -> Vector3:
	var bounds := _mesh_bounds(head)
	var x := clampf(local_x, bounds.position.x + 0.015, bounds.position.x + bounds.size.x - 0.015)
	var y := clampf(local_y, bounds.position.y + 0.015, bounds.position.y + bounds.size.y - 0.015)
	return Vector3(x, y, _positive_head_surface_z(head, x, y) + local_outset)

static func _positive_head_surface_z(head: MeshInstance3D, local_x: float, local_y: float) -> float:
	if head == null or head.mesh == null:
		return 0.0
	var arrays := head.mesh.surface_get_arrays(0)
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

static func _head_local_outset(head: MeshInstance3D, world_outset: float) -> float:
	if head == null:
		return world_outset
	return clampf(world_outset / maxf(absf(head.scale.z), 0.001), 0.018, 0.05)

static func _mesh_bounds(head: MeshInstance3D) -> AABB:
	if head == null or head.mesh == null:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	return head.mesh.get_aabb()

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
