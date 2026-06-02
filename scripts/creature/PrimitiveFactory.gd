class_name PrimitiveFactory
extends RefCounted

# Longitudinal UV span the head mesh occupies, snout(0) -> neck(HEAD_U_SPAN).
# The body shell (build_fish_outer_shell_mesh) maps U uniformly over [0, 1] of the
# whole fish length, so this MUST match the head's physical length as a fraction of
# total length for the stripe density / pattern to stay continuous across the neck
# seam. Both meshes read this single constant so the two never drift apart.
const HEAD_U_SPAN := 0.25

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

static func deformed_head_mesh(shape: String, snout_length: float, forehead_slope: float, rings: int = 18, segments: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var grid := []
	for i in range(rings + 1):
		var phi := PI * float(i) / float(rings)
		var ring_vertices := []
		for j in range(segments + 1):
			var theta := TAU * float(j) / float(segments)
			
			var x := -0.5 * cos(phi)
			var y := 0.5 * sin(phi) * sin(theta)
			var z := 0.5 * sin(phi) * cos(theta)
			
			var u := x + 0.5 # 0.0 (front) to 1.0 (back)
			
			# 1. Cephalofoil (Hammerhead)
			if shape == "cephalofoil":
				var z_stretch := sin(phi) * 2.2
				z *= (1.0 + z_stretch)
				y *= 0.42
				x += abs(z) * 0.18 # sweep wings back
			
			# 2. Snout stretch & taper (for non-cephalofoil snouts)
			if shape != "cephalofoil" and x < 0.0:
				var stretch_t := 1.0 - (u / 0.5)
				x -= snout_length * stretch_t * stretch_t
				
				if shape == "pointed" or shape == "tapered":
					var taper_factor := lerpf(0.12, 1.0, u / 0.5)
					y *= taper_factor
					z *= taper_factor
				elif shape == "blunt":
					var taper_factor := lerpf(0.68, 1.0, pow(u / 0.5, 0.4))
					y *= taper_factor
					z *= taper_factor
			
			# 3. Nuchal Hump / Steep Forehead
			if shape != "cephalofoil" and y > 0.0 and x < 0.1:
				var hump_weight := sin(phi) * (1.0 - u)
				var hump_height := 0.16 + forehead_slope * 0.15
				if shape == "hump":
					y += hump_weight * hump_height
				elif shape == "steep_forehead":
					y += hump_weight * hump_height * 0.72
					x -= hump_weight * hump_height * 0.35
			
			# 4. Flattened head
			if shape == "flattened" and y < 0.0:
				y *= 0.65
				
			ring_vertices.append(Vector3(x, y, z))
		grid.append(ring_vertices)
		
	# Add triangles. U runs 0.0 (snout) to HEAD_U_SPAN (neck) so pattern density on
	# the head matches the body shell, where the head occupies roughly the front
	# quarter of the fish length. V wraps the circumference for seamless patterns.
	for i in rings:
		for j in segments:
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j+1]
			var p10: Vector3 = grid[i+1][j]
			var p11: Vector3 = grid[i+1][j+1]
			var u0 := float(i) / float(rings) * HEAD_U_SPAN
			var u1 := float(i + 1) / float(rings) * HEAD_U_SPAN
			var v0 := float(j) / float(segments)
			var v1 := float(j + 1) / float(segments)

			# Triangle 1
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p01)

			# Triangle 2
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p01)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p11)

	st.generate_normals()
	return st.commit()

static func deformed_head(name: String, shape: String, head_scale: Vector3, snout_length: float, forehead_slope: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = deformed_head_mesh(shape, snout_length, forehead_slope)
	node.scale = head_scale
	node.material_override = material
	return node

static func snout_appendage(type: String, bill_length: float, head_scale: Vector3, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "SnoutAppendage"
	
	match type:
		"swordfish_bill":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.003
			mesh.bottom_radius = 0.015
			mesh.height = bill_length
			mesh.radial_segments = 8
			var node := MeshInstance3D.new()
			node.name = "SwordfishBill"
			node.mesh = mesh
			node.material_override = material
			node.rotation_degrees.z = 90.0
			node.position.x = -bill_length * 0.5
			root.add_child(node)
			
		"sawfish_saw":
			var length := bill_length
			var blade := BoxMesh.new()
			blade.size = Vector3(length, 0.008, 0.024)
			var node := MeshInstance3D.new()
			node.name = "SawBlade"
			node.mesh = blade
			node.material_override = material
			node.position.x = -length * 0.5
			root.add_child(node)
			
			# Add teeth along the sides
			var tooth_count := 6
			for i in range(tooth_count):
				var ratio := float(i) / float(tooth_count - 1)
				var offset_x := -length * (0.1 + 0.8 * ratio)
				var tooth_size := 0.006 * (1.0 - ratio * 0.4)
				
				for side in [-1.0, 1.0]:
					var tooth := MeshInstance3D.new()
					var t_mesh := BoxMesh.new()
					t_mesh.size = Vector3(tooth_size, 0.002, tooth_size * 2.0)
					tooth.mesh = t_mesh
					tooth.material_override = material
					tooth.position = Vector3(offset_x, 0.0, side * (0.012 + tooth_size))
					root.add_child(tooth)
					
		"barbels":
			var b_length := bill_length * 0.8
			# 4 barbels
			var barbel_positions := [
				Vector3(0.0, -0.01, -0.015),
				Vector3(0.0, -0.01, 0.015),
				Vector3(0.0, -0.005, -0.005),
				Vector3(0.0, -0.005, 0.005)
			]
			var barbel_rotations := [
				Vector3(0.0, 30.0, -35.0),
				Vector3(0.0, -30.0, -35.0),
				Vector3(0.0, 15.0, -50.0),
				Vector3(0.0, -15.0, -50.0)
			]
			for i in range(4):
				var b_root := Node3D.new()
				b_root.position = barbel_positions[i]
				b_root.rotation_degrees = barbel_rotations[i]
				root.add_child(b_root)
				
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.001
				mesh.bottom_radius = 0.004
				mesh.height = b_length
				mesh.radial_segments = 6
				
				var node := MeshInstance3D.new()
				node.mesh = mesh
				node.material_override = material
				node.rotation_degrees.z = 90.0
				node.position.x = -b_length * 0.5
				b_root.add_child(node)
				
	return root

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
	return polygon_fin(name, caudal_fin_points(shape, length, height), material)

static func caudal_fin_points(shape: String, length: float, height: float) -> PackedVector3Array:
	return _caudal_shape_points(shape, length, height)

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
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	uvs.append(_fin_uv_for_point(center, min_x, max_x, min_y, max_y))
	for point in points:
		vertices.append(point)
		normals.append(Vector3.BACK)
		uvs.append(_fin_uv_for_point(point, min_x, max_x, min_y, max_y))
	for i in points.size():
		indices.append_array(PackedInt32Array([0, i + 1, (i + 1) % points.size() + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _fin_uv_for_point(point: Vector3, min_x: float, max_x: float, min_y: float, max_y: float) -> Vector2:
	var width := maxf(max_x - min_x, 0.001)
	var height := maxf(max_y - min_y, 0.001)
	return Vector2((point.x - min_x) / width, (point.y - min_y) / height)

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
		"fan":
			return PackedVector3Array([
				Vector3(0.0, height * 0.44, 0.0),
				Vector3(length * 0.88, height * 0.98, 0.0),
				Vector3(length, 0.0, 0.0),
				Vector3(length * 0.88, -height * 0.98, 0.0),
				Vector3(0.0, -height * 0.44, 0.0)
			])
		"double_fan":
			return PackedVector3Array([
				Vector3(0.0, height * 0.26, 0.0),
				Vector3(length * 0.78, height, 0.0),
				Vector3(length * 0.92, height * 0.18, 0.0),
				Vector3(length * 0.52, 0.0, 0.0),
				Vector3(length * 0.92, -height * 0.18, 0.0),
				Vector3(length * 0.78, -height, 0.0),
				Vector3(0.0, -height * 0.26, 0.0)
			])
		"halfmoon":
			return PackedVector3Array([
				Vector3(0.0, height * 0.54, 0.0),
				Vector3(length * 0.46, height * 1.08, 0.0),
				Vector3(length, height * 0.52, 0.0),
				Vector3(length, -height * 0.52, 0.0),
				Vector3(length * 0.46, -height * 1.08, 0.0),
				Vector3(0.0, -height * 0.54, 0.0)
			])
		"veil":
			return PackedVector3Array([
				Vector3(0.0, height * 0.34, 0.0),
				Vector3(length * 0.55, height * 0.82, 0.0),
				Vector3(length * 1.08, height * 0.20, 0.0),
				Vector3(length * 0.94, -height * 0.84, 0.0),
				Vector3(length * 0.25, -height * 0.52, 0.0),
				Vector3(0.0, -height * 0.24, 0.0)
			])
		"crowntail":
			return PackedVector3Array([
				Vector3(0.0, height * 0.42, 0.0),
				Vector3(length * 0.72, height, 0.0),
				Vector3(length * 0.50, height * 0.42, 0.0),
				Vector3(length, height * 0.56, 0.0),
				Vector3(length * 0.52, 0.0, 0.0),
				Vector3(length, -height * 0.56, 0.0),
				Vector3(length * 0.50, -height * 0.42, 0.0),
				Vector3(length * 0.72, -height, 0.0),
				Vector3(0.0, -height * 0.42, 0.0)
			])
		"spade":
			return PackedVector3Array([
				Vector3(0.0, height * 0.34, 0.0),
				Vector3(length * 0.72, height * 0.78, 0.0),
				Vector3(length, 0.0, 0.0),
				Vector3(length * 0.72, -height * 0.78, 0.0),
				Vector3(0.0, -height * 0.34, 0.0)
			])
		"lyre":
			return PackedVector3Array([
				Vector3(0.0, height * 0.24, 0.0),
				Vector3(length * 1.05, height * 1.05, 0.0),
				Vector3(length * 0.58, height * 0.18, 0.0),
				Vector3(length * 0.38, 0.0, 0.0),
				Vector3(length * 0.58, -height * 0.18, 0.0),
				Vector3(length * 1.05, -height * 1.05, 0.0),
				Vector3(0.0, -height * 0.24, 0.0)
			])
		"top_sword":
			return PackedVector3Array([
				Vector3(0.0, height * 0.22, 0.0),
				Vector3(length * 1.2, height * 1.0, 0.0),
				Vector3(length * 0.62, height * 0.08, 0.0),
				Vector3(length * 0.78, -height * 0.46, 0.0),
				Vector3(0.0, -height * 0.18, 0.0)
			])
		"bottom_sword":
			return PackedVector3Array([
				Vector3(0.0, height * 0.18, 0.0),
				Vector3(length * 0.78, height * 0.46, 0.0),
				Vector3(length * 0.62, -height * 0.08, 0.0),
				Vector3(length * 1.2, -height * 1.0, 0.0),
				Vector3(0.0, -height * 0.22, 0.0)
			])
		"double_sword":
			return PackedVector3Array([
				Vector3(0.0, height * 0.20, 0.0),
				Vector3(length * 1.18, height * 0.92, 0.0),
				Vector3(length * 0.62, height * 0.12, 0.0),
				Vector3(length * 0.42, 0.0, 0.0),
				Vector3(length * 0.62, -height * 0.12, 0.0),
				Vector3(length * 1.18, -height * 0.92, 0.0),
				Vector3(0.0, -height * 0.20, 0.0)
			])
		"butterfly":
			return PackedVector3Array([
				Vector3(0.0, height * 0.38, 0.0),
				Vector3(length * 0.72, height * 0.95, 0.0),
				Vector3(length * 0.92, height * 0.18, 0.0),
				Vector3(length * 0.62, 0.0, 0.0),
				Vector3(length * 0.92, -height * 0.18, 0.0),
				Vector3(length * 0.72, -height * 0.95, 0.0),
				Vector3(0.0, -height * 0.38, 0.0)
			])
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
	var vertices := PackedVector3Array([Vector3(radius_x, 0.0, 0.0)])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var point := Vector3(cos(angle) * radius_x + radius_x, sin(angle) * radius_y, 0.0)
		vertices.append(point)
		uvs.append(Vector2(
			clampf(point.x / maxf(radius_x * 2.0, 0.001), 0.0, 1.0),
			clampf((point.y + radius_y) / maxf(radius_y * 2.0, 0.001), 0.0, 1.0)
		))
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node

# Outline points of an oval fin, matching oval_fin()'s ring layout (base near the
# local origin, tip extending to +x). Used to rebuild the fin through
# build_polygon_fin_mesh() when a soft-membrane deform is active.
static func oval_fin_points(radius_x: float, radius_y: float, segments: int = 18) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector3(cos(angle) * radius_x + radius_x, sin(angle) * radius_y, 0.0))
	return points

# Densifies a coarse fin outline by linearly interpolating extra vertices along each
# edge of the closed loop. Used only on the soft-membrane path so a travelling ripple
# renders as smooth flowing cloth instead of a few coarse folds.
static func subdivide_fin_outline(points: PackedVector3Array, segments_per_edge: int) -> PackedVector3Array:
	var count := points.size()
	if count < 3 or segments_per_edge <= 1:
		return points
	var dense := PackedVector3Array()
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		for s in segments_per_edge:
			dense.append(a.lerp(b, float(s) / float(segments_per_edge)))
	return dense

static func bezier_fin_points(length: float, height: float, p1: Vector2, p2: Vector2, segments: int = 8) -> PackedVector3Array:
	var points := PackedVector3Array()
	var p0 := Vector2(-length * 0.5, 0.0)
	var p3 := Vector2(length * 0.5, 0.0)
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var omt := 1.0 - t
		var omt2 := omt * omt
		var omt3 := omt2 * omt
		var t2 := t * t
		var t3 := t2 * t
		var pos := omt3 * p0 + 3.0 * omt2 * t * p1 + 3.0 * omt * t2 * p2 + t3 * p3
		points.append(Vector3(pos.x, pos.y, 0.0))
	return points

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
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# A duplicate seam column (segment == segments) carries V == 1.0 so cylindrical
	# patterns wrap continuously instead of snapping back to V == 0.0 on the last face.
	var verts_per_ring := segments + 1
	var last_ring := maxi(profile.size() - 1, 1)
	for ring_index in profile.size():
		var point := profile[ring_index]
		var z_offset := z_offsets[ring_index] if ring_index < z_offsets.size() else 0.0
		var center := centers[ring_index] if ring_index < centers.size() else Vector3(point.x, 0.0, z_offset)
		center.y += center_y_offsets[ring_index] if ring_index < center_y_offsets.size() else 0.0
		var ring_yaw := deg_to_rad(yaw_degrees[ring_index] if ring_index < yaw_degrees.size() else 0.0)
		var ring_basis := Basis(Vector3.UP, ring_yaw)
		var u := float(ring_index) / float(last_ring)
		for segment in range(verts_per_ring):
			var angle := TAU * float(segment) / float(segments)
			var y := sin(angle) * point.y
			var z := cos(angle) * point.z
			var local_vertex := Vector3(0.0, y, z)
			vertices.append(center + ring_basis * local_vertex)
			var local_normal := Vector3(0.0, y / maxf(point.y, 0.001), z / maxf(point.z, 0.001)).normalized()
			normals.append((ring_basis * local_normal).normalized())
			uvs.append(Vector2(u, float(segment) / float(segments)))
	for ring_index in profile.size() - 1:
		for segment in segments:
			var a := ring_index * verts_per_ring + segment
			var b := ring_index * verts_per_ring + segment + 1
			var c := (ring_index + 1) * verts_per_ring + segment
			var d := (ring_index + 1) * verts_per_ring + segment + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
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
