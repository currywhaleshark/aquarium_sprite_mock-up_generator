class_name PrimitiveFactory
extends RefCounted

static func ellipsoid(name: String, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.scale = scale_value
	node.material_override = material
	return node

static func cylinder(name: String, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node

static func tapered_segment(name: String, length: float, height: float, width: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 10
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.scale = Vector3(length, height, width)
	node.material_override = material
	return node

static func fin_triangle(name: String, points: PackedVector3Array, material: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node

static func fin_shape(name: String, shape: String, length: float, height: float, material: Material, invert_y: bool = false) -> MeshInstance3D:
	var points := _fin_shape_points(shape, length, height)
	if invert_y:
		for i in points.size():
			points[i].y *= -1.0
	return polygon_fin(name, points, material)

static func caudal_fin_shape(name: String, shape: String, length: float, height: float, material: Material) -> MeshInstance3D:
	return polygon_fin(name, _caudal_shape_points(shape, length, height), material)

static func polygon_fin(name: String, points: PackedVector3Array, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_polygon_fin_mesh(points)
	node.material_override = material
	return node

static func build_polygon_fin_mesh(points: PackedVector3Array) -> ArrayMesh:
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var vertices := PackedVector3Array([center])
	var normals := PackedVector3Array([Vector3.BACK])
	var indices := PackedInt32Array()
	for point in points:
		vertices.append(point)
		normals.append(Vector3.BACK)
	for i in points.size():
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % points.size() + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _fin_shape_points(shape: String, length: float, height: float) -> PackedVector3Array:
	match shape:
		"spiny":
			return PackedVector3Array([
				Vector3(-length * 0.5, 0.0, 0.0),
				Vector3(-length * 0.34, height * 0.82, 0.0),
				Vector3(-length * 0.22, height * 0.34, 0.0),
				Vector3(-length * 0.06, height, 0.0),
				Vector3(length * 0.08, height * 0.42, 0.0),
				Vector3(length * 0.24, height * 0.72, 0.0),
				Vector3(length * 0.5, 0.0, 0.0)
			])
		"split":
			return PackedVector3Array([
				Vector3(-length * 0.5, 0.0, 0.0),
				Vector3(-length * 0.3, height * 0.78, 0.0),
				Vector3(-length * 0.05, height * 0.28, 0.0),
				Vector3(length * 0.26, height * 0.74, 0.0),
				Vector3(length * 0.5, 0.0, 0.0)
			])
		"trailing":
			return PackedVector3Array([
				Vector3(-length * 0.56, 0.0, 0.0),
				Vector3(-length * 0.28, height * 0.8, 0.0),
				Vector3(length * 0.08, height * 0.62, 0.0),
				Vector3(length * 0.68, height * 0.18, 0.0),
				Vector3(length * 0.5, 0.0, 0.0)
			])
		"trigger":
			return PackedVector3Array([
				Vector3(-length * 0.42, 0.0, 0.0),
				Vector3(-length * 0.18, height, 0.0),
				Vector3(length * 0.12, height * 0.64, 0.0),
				Vector3(length * 0.46, 0.0, 0.0)
			])
		"long":
			return PackedVector3Array([
				Vector3(-length * 0.55, 0.0, 0.0),
				Vector3(-length * 0.28, height * 0.54, 0.0),
				Vector3(length * 0.44, height * 0.4, 0.0),
				Vector3(length * 0.56, 0.0, 0.0)
			])
		"rounded":
			return PackedVector3Array([
				Vector3(-length * 0.5, 0.0, 0.0),
				Vector3(-length * 0.28, height * 0.55, 0.0),
				Vector3(0.0, height * 0.68, 0.0),
				Vector3(length * 0.32, height * 0.48, 0.0),
				Vector3(length * 0.5, 0.0, 0.0)
			])
		_:
			return PackedVector3Array([
				Vector3(-length * 0.5, 0.0, 0.0),
				Vector3(0.0, height, 0.0),
				Vector3(length * 0.5, 0.0, 0.0)
			])

static func _caudal_shape_points(shape: String, length: float, height: float) -> PackedVector3Array:
	match shape:
		"forked_deep":
			return PackedVector3Array([
				Vector3(0.0, height * 0.22, 0.0),
				Vector3(length, height, 0.0),
				Vector3(length * 0.58, 0.0, 0.0),
				Vector3(length, -height, 0.0),
				Vector3(0.0, -height * 0.22, 0.0)
			])
		"truncate":
			return PackedVector3Array([
				Vector3(0.0, height * 0.52, 0.0),
				Vector3(length * 0.82, height * 0.78, 0.0),
				Vector3(length * 0.82, -height * 0.78, 0.0),
				Vector3(0.0, -height * 0.52, 0.0)
			])
		"rounded":
			return PackedVector3Array([
				Vector3(0.0, height * 0.42, 0.0),
				Vector3(length * 0.55, height * 0.82, 0.0),
				Vector3(length, 0.0, 0.0),
				Vector3(length * 0.55, -height * 0.82, 0.0),
				Vector3(0.0, -height * 0.42, 0.0)
			])
		"pointed":
			return PackedVector3Array([
				Vector3(0.0, height * 0.22, 0.0),
				Vector3(length, 0.0, 0.0),
				Vector3(0.0, -height * 0.22, 0.0)
			])
		"lunate":
			return PackedVector3Array([
				Vector3(0.0, height * 0.18, 0.0),
				Vector3(length * 1.08, height * 1.05, 0.0),
				Vector3(length * 0.5, 0.0, 0.0),
				Vector3(length * 1.08, -height * 1.05, 0.0),
				Vector3(0.0, -height * 0.18, 0.0)
			])
		"shark_heterocercal":
			return PackedVector3Array([
				Vector3(0.0, height * 0.24, 0.0),
				Vector3(length * 1.18, height * 1.28, 0.0),
				Vector3(length * 0.62, height * 0.05, 0.0),
				Vector3(length * 0.92, -height * 0.68, 0.0),
				Vector3(0.0, -height * 0.18, 0.0)
			])
		"thresher":
			return PackedVector3Array([
				Vector3(0.0, height * 0.18, 0.0),
				Vector3(length * 1.72, height * 1.55, 0.0),
				Vector3(length * 0.5, height * 0.02, 0.0),
				Vector3(length * 0.86, -height * 0.48, 0.0),
				Vector3(0.0, -height * 0.14, 0.0)
			])
		"forked_shallow":
			return PackedVector3Array([
				Vector3(0.0, height * 0.32, 0.0),
				Vector3(length * 0.9, height * 0.84, 0.0),
				Vector3(length * 0.72, 0.0, 0.0),
				Vector3(length * 0.9, -height * 0.84, 0.0),
				Vector3(0.0, -height * 0.32, 0.0)
			])
		_:
			return PackedVector3Array([
				Vector3(0.0, height * 0.25, 0.0),
				Vector3(length, height * 0.72, 0.0),
				Vector3(length, -height * 0.72, 0.0),
				Vector3(0.0, -height * 0.25, 0.0)
			])

static func oval_fin(name: String, radius_x: float, radius_y: float, material: Material, segments: int = 18) -> MeshInstance3D:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var indices := PackedInt32Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		vertices.append(Vector3(cos(angle) * radius_x, sin(angle) * radius_y, 0.0))
	for i in segments:
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % segments + 1)
	var normals := PackedVector3Array()
	for i in vertices.size():
		normals.append(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node

static func ray_wing(name: String, side: float, length: float, width: float, curve: float, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	vertices.append(Vector3(0.0, 0.0, 0.0))
	vertices.append(Vector3(-length * 0.38, curve, side * width * 0.38))
	vertices.append(Vector3(length * 0.12, -curve * 0.3, side * width))
	vertices.append(Vector3(length * 0.48, curve * 0.5, side * width * 0.32))
	var normals := PackedVector3Array()
	for i in vertices.size():
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node

static func fish_outer_shell(name: String, profile: Array[Vector3], material: Material, segments: int = 28, center_y_offsets: PackedFloat32Array = PackedFloat32Array()) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, PackedVector3Array(), PackedFloat32Array(), center_y_offsets)
	node.material_override = material
	return node

static func update_fish_outer_shell(node: MeshInstance3D, profile: Array[Vector3], z_offsets: PackedFloat32Array, segments: int = 28) -> void:
	node.mesh = build_fish_outer_shell_mesh(profile, z_offsets, segments)

static func update_fish_outer_shell_bent(node: MeshInstance3D, profile: Array[Vector3], centers: PackedVector3Array, yaw_degrees: PackedFloat32Array, segments: int = 28, center_y_offsets: PackedFloat32Array = PackedFloat32Array()) -> void:
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, centers, yaw_degrees, center_y_offsets)

static func build_fish_outer_shell_mesh(
	profile: Array[Vector3],
	z_offsets: PackedFloat32Array = PackedFloat32Array(),
	segments: int = 28,
	centers: PackedVector3Array = PackedVector3Array(),
	yaw_degrees: PackedFloat32Array = PackedFloat32Array(),
	center_y_offsets: PackedFloat32Array = PackedFloat32Array()
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring_index in profile.size():
		var point := profile[ring_index]
		var z_offset := z_offsets[ring_index] if ring_index < z_offsets.size() else 0.0
		var center := centers[ring_index] if ring_index < centers.size() else Vector3(point.x, 0.0, z_offset)
		center.y += center_y_offsets[ring_index] if ring_index < center_y_offsets.size() else 0.0
		var ring_yaw := deg_to_rad(yaw_degrees[ring_index] if ring_index < yaw_degrees.size() else 0.0)
		var ring_basis := Basis(Vector3.UP, ring_yaw)
		for segment in segments:
			var angle := TAU * float(segment) / float(segments)
			var y := sin(angle) * point.y
			var z := cos(angle) * point.z
			var local_vertex := Vector3(0.0, y, z)
			vertices.append(center + ring_basis * local_vertex)
			var local_normal := Vector3(0.0, y / maxf(point.y, 0.001), z / maxf(point.z, 0.001)).normalized()
			normals.append((ring_basis * local_normal).normalized())
	for ring_index in profile.size() - 1:
		for segment in segments:
			var a := ring_index * segments + segment
			var b := ring_index * segments + (segment + 1) % segments
			var c := (ring_index + 1) * segments + segment
			var d := (ring_index + 1) * segments + (segment + 1) % segments
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func ray_mantle_shell(name: String, radius_x: float, radius_z: float, crown_height: float, material: Material, segments: int = 48) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_ray_mantle_shell_mesh(radius_x, radius_z, crown_height, 0.0, segments)
	node.material_override = material
	return node

static func update_ray_mantle_shell(node: MeshInstance3D, radius_x: float, radius_z: float, crown_height: float, flap_lift: float, segments: int = 48) -> void:
	node.mesh = build_ray_mantle_shell_mesh(radius_x, radius_z, crown_height, flap_lift, segments)

static func build_ray_mantle_shell_mesh(radius_x: float, radius_z: float, crown_height: float, flap_lift: float = 0.0, segments: int = 48) -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3(0.0, crown_height, 0.0)])
	var normals := PackedVector3Array([Vector3.UP])
	var indices := PackedInt32Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var x := cos(angle) * radius_x
		var z := sin(angle) * radius_z
		var wing_weight: float = abs(z) / maxf(radius_z, 0.001)
		var edge_lift: float = crown_height * 0.18 * (1.0 + cos(angle)) + flap_lift * wing_weight
		vertices.append(Vector3(x, edge_lift, z))
		normals.append(Vector3.UP)
	for i in segments:
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % segments + 1]))
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
