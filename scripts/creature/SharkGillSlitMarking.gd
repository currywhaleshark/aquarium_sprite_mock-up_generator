class_name SharkGillSlitMarking
extends RefCounted

static func rebuild(parent: Node3D, parameters: Dictionary) -> Node3D:
	var root := parent.get_node_or_null("SharkGillSlits") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "SharkGillSlits"
		parent.add_child(root)
	for child in root.get_children():
		child.free()

	var count := clampi(int(round(float(parameters.get("shark_gill_slit_count", 5)))), 1, 7)
	var length := maxf(float(parameters.get("shark_gill_slit_length", 0.22)), 0.01)
	var spacing := maxf(float(parameters.get("shark_gill_slit_spacing", 0.055)), 0.0)
	var angle := float(parameters.get("shark_gill_slit_angle", -8.0))
	var depth := clampf(float(parameters.get("shark_gill_slit_depth", 0.65)), 0.0, 1.0)
	var position_x := float(parameters.get("shark_gill_slit_position_x", -0.28))
	var position_y := float(parameters.get("shark_gill_slit_position_y", 0.08))
	var body_width := maxf(float(parameters.get("body_width", 0.42)), 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.025, 0.03, depth)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var center_offset := float(count - 1) * 0.5
	for index in range(count):
		var slit := MeshInstance3D.new()
		slit.name = "SharkGillSlit%d" % [index + 1]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.012, length, 0.018)
		slit.mesh = mesh
		slit.material_override = mat
		slit.position = Vector3(position_x, position_y + (float(index) - center_offset) * spacing, body_width * 0.52)
		slit.rotation_degrees.z = angle
		root.add_child(slit)
	return root
