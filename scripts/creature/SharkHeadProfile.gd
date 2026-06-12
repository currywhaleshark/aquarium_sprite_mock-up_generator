class_name SharkHeadProfile
extends RefCounted

const HEAD_U_SPAN := 0.25
const ROSTRUM_FRONT_X := -0.72
const NECK_X := 0.50
const DEFAULT_THETA_SEGMENTS := 32
const BASE_U_RINGS := 24
const MOUTH_EDGE_HALF_WIDTH_U := 0.055
const MOUTH_CREASE_EPSILON_U := 0.012

static func build_head(name: String, parameters: Dictionary, head_scale: Vector3, snout_length: float, forehead_slope: float, material: Material, sculpt: Dictionary = {}) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var samples := u_samples(parameters)
	node.mesh = _build_head_mesh(parameters, samples, snout_length, forehead_slope, sculpt)
	node.scale = head_scale
	node.material_override = material
	node.set_meta("head_profile_type", "shark")
	node.set_meta("shark_u_samples", samples)
	node.set_meta("shark_mouth_u", _mouth_u(parameters))
	node.set_meta("shark_mouth_center_y", _mouth_center_y(parameters))
	return node

static func u_samples(parameters: Dictionary) -> PackedFloat32Array:
	var values := []
	for i in range(BASE_U_RINGS + 1):
		values.append(float(i) / float(BASE_U_RINGS))
	values.append(0.015)
	values.append(0.985)
	var mouth_u := _mouth_u(parameters)
	for sample in [
		mouth_u - MOUTH_EDGE_HALF_WIDTH_U,
		mouth_u - MOUTH_CREASE_EPSILON_U,
		mouth_u,
		mouth_u + MOUTH_CREASE_EPSILON_U,
		mouth_u + MOUTH_EDGE_HALF_WIDTH_U
	]:
		values.append(clampf(float(sample), 0.0, 1.0))
	values.sort()
	var result := PackedFloat32Array()
	var previous := -INF
	for value in values:
		var clamped := clampf(float(value), 0.0, 1.0)
		if result.size() == 0 or absf(clamped - previous) > 0.0005:
			result.append(clamped)
			previous = clamped
	return result

static func point_at(parameters: Dictionary, u: float, theta: float, snout_length: float = 0.0, forehead_slope: float = 0.35, sculpt: Dictionary = {}) -> Vector3:
	var point := _base_point(parameters, u, theta, snout_length, forehead_slope, sculpt)
	var mouth_y := _mouth_center_y(parameters)
	var mouth := mouth_weight(parameters, u, point.y, point.z)
	if mouth <= 0.0:
		return point
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var drop := clampf(float(parameters.get("shark_lower_jaw_drop", 0.28)), 0.0, 0.4)
	var drop_norm := drop / 0.4
	var projection := clampf(float(parameters.get("shark_jaw_projection", 0.08)), 0.0, 0.4)
	point.x += mouth * (0.018 + 0.055 * gape + 0.035 * projection)
	point.z *= 1.0 - mouth * (0.22 + 0.18 * gape)
	if point.y < mouth_y:
		point.y -= mouth * (0.020 + 0.090 * gape * drop_norm)
	else:
		point.y += mouth * (0.006 + 0.018 * gape)
	return point

static func surface_z_at(parameters: Dictionary, u: float, y: float, side: float = 1.0) -> float:
	var radii := _base_radii(parameters, u, float(parameters.get("snout_length", 0.0)), float(parameters.get("forehead_slope", 0.35)), {})
	var radius_y := maxf(radii.x, 0.001)
	var radius_z := maxf(radii.y, 0.001)
	var normalized_y := clampf(y / radius_y, -0.98, 0.98)
	var z := radius_z * sqrt(maxf(1.0 - normalized_y * normalized_y, 0.0)) * signf(side)
	var mouth := mouth_weight(parameters, u, y, z)
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	z *= 1.0 - mouth * (0.22 + 0.18 * gape)
	return z

static func mouth_weight(parameters: Dictionary, u: float, y: float, z: float) -> float:
	var mouth_u := _mouth_u(parameters)
	var mouth_y := _mouth_center_y(parameters)
	var width := clampf(float(parameters.get("shark_mouth_width", 0.18)), 0.02, 0.5)
	var curve := clampf(float(parameters.get("shark_mouth_curve", 0.58)), 0.0, 1.0)
	var half_u := clampf(width * 0.42, 0.035, 0.13)
	var half_y := lerpf(0.06, 0.14, curve)
	var u_w := 1.0 - clampf(absf(u - mouth_u) / half_u, 0.0, 1.0)
	var y_w := 1.0 - clampf(absf(y - mouth_y) / half_y, 0.0, 1.0)
	var side_w := smoothstep(0.02, 0.12, absf(z))
	return clampf(u_w * y_w * side_w, 0.0, 1.0)

static func mouth_anchor(parameters: Dictionary, side: float = 1.0) -> Vector3:
	var u := _mouth_u(parameters)
	var y := _mouth_center_y(parameters)
	return Vector3(_x_at_u(u, float(parameters.get("snout_length", 0.0))), y, surface_z_at(parameters, u, y, side))

static func mouth_corners(parameters: Dictionary, side: float = 1.0) -> Array[Vector3]:
	var mouth_u := _mouth_u(parameters)
	var width := clampf(float(parameters.get("shark_mouth_width", 0.18)), 0.02, 0.5)
	var half_u := clampf(width * 0.42, 0.035, 0.13)
	var y := _mouth_center_y(parameters)
	var front_u := clampf(mouth_u - half_u, 0.03, 0.97)
	var rear_u := clampf(mouth_u + half_u, 0.03, 0.97)
	return [
		Vector3(_x_at_u(front_u, float(parameters.get("snout_length", 0.0))), y, surface_z_at(parameters, front_u, y, side)),
		Vector3(_x_at_u(rear_u, float(parameters.get("snout_length", 0.0))), y, surface_z_at(parameters, rear_u, y, side))
	]

static func build_mouth_interior_shadow(parameters: Dictionary, material: Material = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "MouthInteriorShadow"
	node.mesh = _mouth_shadow_mesh(parameters)
	node.material_override = material if material != null else _shadow_material()
	return node

static func contour_radius_at_x(parameters: Dictionary, local_x: float, snout_length: float = 0.0, forehead_slope: float = 0.35, sculpt: Dictionary = {}) -> Vector2:
	var front_x := _front_x(snout_length)
	var u := clampf((local_x - front_x) / (NECK_X - front_x), 0.0, 1.0)
	var radii := _base_radii(parameters, u, snout_length, forehead_slope, sculpt)
	return Vector2(maxf(radii.x + 0.035, 0.02), maxf(radii.y + 0.018, 0.02))

static func _build_head_mesh(parameters: Dictionary, samples: PackedFloat32Array, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for u in samples:
		var ring := []
		for j in range(DEFAULT_THETA_SEGMENTS + 1):
			var theta := TAU * float(j) / float(DEFAULT_THETA_SEGMENTS)
			ring.append(point_at(parameters, float(u), theta, snout_length, forehead_slope, sculpt))
		grid.append(ring)
	for i in range(samples.size() - 1):
		for j in range(DEFAULT_THETA_SEGMENTS):
			_add_quad(st, grid, samples, i, j)
	_add_rear_cap(st, grid[grid.size() - 1], float(samples[samples.size() - 1]))
	st.generate_normals()
	return st.commit()

static func _add_quad(st: SurfaceTool, grid: Array, samples: PackedFloat32Array, i: int, j: int) -> void:
	var p00: Vector3 = grid[i][j]
	var p01: Vector3 = grid[i][j + 1]
	var p10: Vector3 = grid[i + 1][j]
	var p11: Vector3 = grid[i + 1][j + 1]
	var u0 := float(samples[i]) * HEAD_U_SPAN
	var u1 := float(samples[i + 1]) * HEAD_U_SPAN
	var v0 := float(j) / float(DEFAULT_THETA_SEGMENTS)
	var v1 := float(j + 1) / float(DEFAULT_THETA_SEGMENTS)
	_add_vertex(st, Vector2(u0, v1), p01)
	_add_vertex(st, Vector2(u1, v0), p10)
	_add_vertex(st, Vector2(u0, v0), p00)
	_add_vertex(st, Vector2(u1, v1), p11)
	_add_vertex(st, Vector2(u1, v0), p10)
	_add_vertex(st, Vector2(u0, v1), p01)

static func _add_rear_cap(st: SurfaceTool, ring: Array, u: float) -> void:
	var center := Vector3(NECK_X + 0.003, 0.0, 0.0)
	for j in range(DEFAULT_THETA_SEGMENTS):
		var p0: Vector3 = ring[j]
		var p1: Vector3 = ring[j + 1]
		_add_vertex(st, Vector2(u * HEAD_U_SPAN, 0.5), center)
		_add_vertex(st, Vector2(u * HEAD_U_SPAN, float(j + 1) / float(DEFAULT_THETA_SEGMENTS)), p1)
		_add_vertex(st, Vector2(u * HEAD_U_SPAN, float(j) / float(DEFAULT_THETA_SEGMENTS)), p0)

static func _add_vertex(st: SurfaceTool, uv: Vector2, point: Vector3) -> void:
	st.set_uv(uv)
	st.set_uv2(uv)
	st.add_vertex(point)

static func _base_point(parameters: Dictionary, u: float, theta: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Vector3:
	var x := _x_at_u(u, snout_length)
	var radii := _base_radii(parameters, u, snout_length, forehead_slope, sculpt)
	var y := radii.x * sin(theta)
	var z := radii.y * cos(theta)
	if y > 0.0:
		y += _dorsal_bias(u, forehead_slope)
	elif y < 0.0:
		y -= _ventral_bias(u)
	return Vector3(x, y, z)

static func _base_radii(parameters: Dictionary, u: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Vector2:
	var rostrum := smoothstep(0.0, 0.22, u)
	var neck_fill := smoothstep(0.42, 1.0, u)
	var base := clampf(lerpf(0.08, 0.50, rostrum) * lerpf(0.86, 1.0, neck_fill), 0.0, 0.52)
	if u <= 0.001:
		base = 0.0
	var snout_narrow := 1.0 - clampf(snout_length, 0.0, 0.6) * 0.16 * (1.0 - u)
	var radius_y := base * snout_narrow
	var radius_z := base * lerpf(0.56, 0.86, smoothstep(0.18, 1.0, u)) * snout_narrow
	radius_y *= 1.0 + clampf(forehead_slope - 0.35, -0.35, 0.65) * 0.08 * (1.0 - u)
	return Vector2(radius_y, radius_z)

static func _mouth_shadow_mesh(parameters: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := false
	var segments := 12
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var side_value := float(side)
		var corners := mouth_corners(parameters, side_value)
		var front: Vector3 = corners[0]
		var rear: Vector3 = corners[1]
		var previous_top := Vector3.ZERO
		var previous_bottom := Vector3.ZERO
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var u := lerpf(_u_for_x(front.x, float(parameters.get("snout_length", 0.0))), _u_for_x(rear.x, float(parameters.get("snout_length", 0.0))), t)
			var curve := sin(t * PI)
			var y_center := lerpf(front.y, rear.y, t) - curve * (0.010 + gape * 0.020)
			var z_surface := surface_z_at(parameters, u, y_center, side_value)
			var inset := -side_value * (0.006 + gape * 0.010)
			var top := Vector3(_x_at_u(u, float(parameters.get("snout_length", 0.0))), y_center + 0.006, z_surface + inset)
			var bottom := Vector3(top.x + 0.006 + gape * 0.018, y_center - 0.018 - gape * 0.020, z_surface + inset * 1.3)
			if i > 0:
				st.add_vertex(previous_top)
				st.add_vertex(previous_bottom)
				st.add_vertex(top)
				st.add_vertex(top)
				st.add_vertex(previous_bottom)
				st.add_vertex(bottom)
				emitted = true
			previous_top = top
			previous_bottom = bottom
	if not emitted:
		return ArrayMesh.new()
	st.generate_normals()
	return st.commit()

static func _front_x(snout_length: float) -> float:
	return ROSTRUM_FRONT_X - clampf(snout_length, 0.0, 0.6) * 0.35

static func _x_at_u(u: float, snout_length: float) -> float:
	return lerpf(_front_x(snout_length), NECK_X, clampf(u, 0.0, 1.0))

static func _u_for_x(x: float, snout_length: float) -> float:
	var front_x := _front_x(snout_length)
	return clampf((x - front_x) / (NECK_X - front_x), 0.0, 1.0)

static func _mouth_u(parameters: Dictionary) -> float:
	var raw := clampf(float(parameters.get("shark_mouth_position_x", -0.96)), -1.5, 0.2)
	return clampf((raw + 1.5) / 1.7, 0.08, 0.82)

static func _mouth_center_y(parameters: Dictionary) -> float:
	return clampf(float(parameters.get("shark_mouth_position_y", -0.13)), -0.42, 0.24)

static func _dorsal_bias(u: float, forehead_slope: float) -> float:
	return smoothstep(0.08, 0.48, u) * (1.0 - smoothstep(0.65, 1.0, u)) * lerpf(0.008, 0.042, clampf(forehead_slope, 0.0, 1.0))

static func _ventral_bias(u: float) -> float:
	return smoothstep(0.04, 0.34, u) * (1.0 - smoothstep(0.72, 1.0, u)) * 0.018

static func _shadow_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.005, 0.006, 0.008, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
