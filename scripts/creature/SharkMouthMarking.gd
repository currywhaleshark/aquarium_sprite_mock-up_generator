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
		_place_tooth_row(lower_teeth, parameters, head, tooth_count, tooth_size, false, gape, jaw_drop, tooth_angle, tooth_mat)
	var upper_count := clampi(int(round(float(tooth_count) * maxf(0.6, projection_signal))), 0, tooth_count)
	_place_tooth_row(upper_teeth, parameters, head, upper_count, tooth_size * 0.85, true, gape, jaw_drop, -tooth_angle, tooth_mat)

	if furrow_length > 0.001:
		# Labial furrows extend the mouth line outward past each corner.
		_add_furrow(socket, parameters, head, 0.94, furrow_length, dark_mat, "LabialFurrowRight")
		_add_furrow(socket, parameters, head, 0.06, furrow_length, dark_mat, "LabialFurrowLeft")

	return root

static func _place_tooth_row(parent: Node3D, parameters: Dictionary, head: MeshInstance3D, count: int, size: float, upper: bool, gape: float, jaw_drop: float, tooth_angle: float, material: Material) -> void:
	if count <= 0:
		return
	# Lower teeth ride the dropped jaw; upper teeth ride the seam (palate).
	var drop := 0.0 if upper else (0.012 + gape * (0.05 + jaw_drop * 0.18))
	for index in range(count):
		var s := 0.5 if count == 1 else lerpf(0.10, 0.90, float(index) / float(count - 1))
		var frame := SharkHeadProfile.mouth_path_frame(parameters, s)
		var pos: Vector3 = frame["pos"]
		var normal: Vector3 = frame["normal"]
		var tangent: Vector3 = frame["tangent"]
		var bite := normal.cross(tangent).normalized()
		if bite.y < 0.0:
			bite = -bite
		var anchor := pos + normal * SharkHeadProfile.TOOTH_SURFACE_CLEARANCE - bite * drop
		# Lean each tooth about its outward normal so the row rakes consistently.
		var basis := (Basis(tangent, bite, normal) * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(tooth_angle))).orthonormalized()
		var tooth := MeshInstance3D.new()
		tooth.name = "Tooth%d" % [index + 1]
		tooth.mesh = _tooth_mesh(size, upper)
		tooth.material_override = material
		tooth.transform = Transform3D(basis, _socket_position_for_head_anchor(anchor, head))
		parent.add_child(tooth)

static func _add_furrow(socket: Node3D, parameters: Dictionary, head: MeshInstance3D, s: float, length: float, material: Material, name: String) -> void:
	var frame := SharkHeadProfile.mouth_path_frame(parameters, s)
	var pos: Vector3 = frame["pos"]
	var normal: Vector3 = frame["normal"]
	# A small crease angling back and down from the mouth corner along the
	# surface (a real labial furrow), kept subtle so it reads as a corner tick.
	var back := Vector3(1.0, -0.55, 0.0)
	back = (back - normal * back.dot(normal)).normalized()
	var up := normal.cross(back).normalized()
	var furrow := _box(name, Vector3(length * 0.5, 0.005, 0.007), material)
	var anchor := pos + normal * (SharkHeadProfile.MOUTH_SURFACE_CLEARANCE * 0.5)
	var basis := Basis(back, up, normal).orthonormalized()
	furrow.transform = Transform3D(basis, _socket_position_for_head_anchor(anchor, head))
	socket.add_child(furrow)

static func _socket_position_for_head_anchor(anchor: Vector3, head: MeshInstance3D) -> Vector3:
	if head == null:
		return anchor
	return Vector3(anchor.x * head.scale.x, anchor.y * head.scale.y, anchor.z * head.scale.z)

static func _box(name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	return node

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
