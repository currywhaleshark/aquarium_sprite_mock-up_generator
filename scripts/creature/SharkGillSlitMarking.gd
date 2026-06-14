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
	root.visible = bool(parameters.get("shark_gill_slit_enabled", true))
	if not root.visible:
		return root

	var count := clampi(int(round(float(parameters.get("shark_gill_slit_count", 5)))), 1, 7)
	var length := maxf(float(parameters.get("shark_gill_slit_length", 0.09)), 0.01)
	var spacing := maxf(float(parameters.get("shark_gill_slit_spacing", 0.045)), 0.0)
	var angle := float(parameters.get("shark_gill_slit_angle", -8.0))
	var depth := clampf(float(parameters.get("shark_gill_slit_depth", 0.65)), 0.0, 1.0)
	var position_x := float(parameters.get("shark_gill_slit_position_x", -0.28))
	var position_y := float(parameters.get("shark_gill_slit_position_y", 0.08))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.025, 0.03, depth)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var center_offset := float(count - 1) * 0.5
	for index in range(count):
		var slit_x := position_x + (float(index) - center_offset) * spacing
		var bounds := _shell_y_bounds_at_x(parent, slit_x)
		var max_length := maxf((bounds.y - bounds.x) * 0.24, 0.035)
		var visual_length := clampf(length, 0.01, max_length)
		var slit_y := clampf(position_y, bounds.x + visual_length * 0.55, bounds.y - visual_length * 0.55)
		var surface_z := _positive_shell_surface_z(parent, slit_x, slit_y)
		var slit := MeshInstance3D.new()
		slit.name = "SharkGillSlit%d" % [index + 1]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.010, visual_length, 0.006)
		slit.mesh = mesh
		slit.material_override = mat
		slit.position = Vector3(slit_x, slit_y, surface_z + 0.006)
		slit.rotation_degrees.z = angle
		root.add_child(slit)
	return root

static func _positive_shell_surface_z(parent: Node3D, local_x: float, local_y: float) -> float:
	var shell := parent.get_node_or_null("OuterShell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return 0.04
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

static func _shell_y_bounds_at_x(parent: Node3D, local_x: float) -> Vector2:
	var shell := parent.get_node_or_null("OuterShell") as MeshInstance3D
	if shell == null or shell.mesh == null:
		return Vector2(-0.18, 0.18)
	var arrays := shell.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var closest_dx := INF
	for vertex in verts:
		closest_dx = minf(closest_dx, absf(vertex.x - local_x))
	var min_y := INF
	var max_y := -INF
	for vertex in verts:
		if absf(vertex.x - local_x) > closest_dx + 0.012:
			continue
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	if min_y == INF:
		return Vector2(-0.18, 0.18)
	return Vector2(min_y, max_y)
