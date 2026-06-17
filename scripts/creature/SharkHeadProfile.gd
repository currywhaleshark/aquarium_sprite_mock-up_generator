class_name SharkHeadProfile
extends RefCounted

const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")

const HEAD_U_SPAN := 0.25
# The shark head spans a longer x range than the fish's unit-sphere head, so the same
# head_top_curve/head_belly_curve/head_bump value spreads over more length and reads as a
# shallower slope. Scale the profile offsets up so the controls feel as strong as the fish
# editor's (the user's reference) rather than a gentle nudge.
const HEAD_PROFILE_GAIN := 1.5
const ROSTRUM_FRONT_X := -0.72
const NECK_X := 0.50
const DEFAULT_THETA_SEGMENTS := 32
const BASE_U_RINGS := 24
const MOUTH_EDGE_HALF_WIDTH_U := 0.055
const MOUTH_CREASE_EPSILON_U := 0.012
# Head-local outward offset so mouth markings sit proud of the head surface and
# are not occluded by it. head.scale.z (~0.20) maps this to ~0.006 world units,
# matching the gill-slit clearance (surface_z + 0.006) that renders correctly.
const MOUTH_SURFACE_CLEARANCE := 0.030
const TOOTH_SURFACE_CLEARANCE := 0.044
# The mouth is a ventral arc wrapping the lower-front of the snout. theta = -PI/2
# is the underside (bottom) of each cross-section; the arc spans +/- half-angle
# around it so the seam runs continuously from one flank, under the snout, to the
# other flank (readable head-on, not two disconnected flank patches).
const MOUTH_DEFAULT_Y := -0.13
const MOUTH_PATH_SEGMENTS := 20

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
	var mouth := mouth_weight(parameters, u, point.y, point.z)
	if mouth <= 0.0:
		return point
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var drop_norm := clampf(float(parameters.get("shark_lower_jaw_drop", 0.10)), 0.0, 0.4) / 0.4
	var projection := clampf(float(parameters.get("shark_jaw_projection", 0.08)), 0.0, 0.4)
	# How far onto the throat (lower-jaw) side of the seam this vertex sits.
	var lower_side := clampf((u - _mouth_u(parameters)) / maxf(_mouth_half_u(parameters), 0.001), 0.0, 1.0)
	# Carve a recessed seam (groove) around the lower-front so the mouth reads as
	# real 3-D form from every angle, deepening as the mouth opens.
	var groove := mouth * (0.07 + 0.10 * gape)
	point.z *= 1.0 - groove
	point.y *= 1.0 - groove * 0.30
	# Snout overhangs the mouth; jaw projection pushes the upper jaw forward.
	point.x += mouth * (0.012 + 0.030 * projection)
	# Lower jaw (throat side of the seam) swings open and down with gape/jaw-drop.
	point.y -= mouth * lower_side * (0.020 + gape * (0.12 + 0.18 * drop_norm))
	return point

static func surface_z_at(parameters: Dictionary, u: float, y: float, side: float = 1.0) -> float:
	var snout_length := float(parameters.get("snout_length", 0.0))
	var radii := _base_radii(parameters, u, snout_length, float(parameters.get("forehead_slope", 0.35)), {})
	var radius_y := maxf(radii.x, 0.001)
	var radius_z := maxf(radii.y, 0.001)
	var center_y := _snout_curve_y_shift(parameters, u, snout_length, {})
	var normalized_y := clampf((y - center_y) / radius_y, -0.98, 0.98)
	var z := radius_z * sqrt(maxf(1.0 - normalized_y * normalized_y, 0.0)) * signf(side)
	var mouth := mouth_weight(parameters, u, y, z)
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	z *= 1.0 - mouth * (0.07 + 0.10 * gape)
	return z

static func mouth_weight(parameters: Dictionary, u: float, y: float, z: float) -> float:
	# Longitudinal lip window (front-to-back thickness of the closed seam).
	var u_w := 1.0 - clampf(absf(u - _mouth_u(parameters)) / _mouth_half_u(parameters), 0.0, 1.0)
	if u_w <= 0.0:
		return 0.0
	# Angular wrap around the lower cross-section (bottom = -PI/2). position_y
	# translates the band vertically so the slider keeps affecting geometry.
	var radii := _base_radii(parameters, u, float(parameters.get("snout_length", 0.0)), float(parameters.get("forehead_slope", 0.35)), {})
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y + _snout_curve_y_shift(parameters, u, float(parameters.get("snout_length", 0.0)), {})
	var theta := atan2((y - y_shift) / maxf(radii.x, 0.001), z / maxf(radii.y, 0.001))
	var ang_w := 1.0 - clampf(absf(theta + PI * 0.5) / _mouth_half_ang(parameters), 0.0, 1.0)
	return clampf(smoothstep(0.0, 1.0, u_w) * smoothstep(0.0, 1.0, ang_w), 0.0, 1.0)

static func mouth_path_frame(parameters: Dictionary, s: float) -> Dictionary:
	var pos := _mouth_seam_point(parameters, s)
	var ds := 0.02
	var ahead := _mouth_seam_point(parameters, clampf(s + ds, 0.0, 1.0))
	var behind := _mouth_seam_point(parameters, clampf(s - ds, 0.0, 1.0))
	var tangent := (ahead - behind)
	if tangent.length() < 1e-5:
		tangent = Vector3(0.0, 0.0, 1.0)
	tangent = tangent.normalized()
	# Outward normal in the cross-section (y,z) plane from the base ellipse.
	var u := _mouth_seam_u(parameters, s)
	var radii := _base_radii(parameters, u, float(parameters.get("snout_length", 0.0)), float(parameters.get("forehead_slope", 0.35)), {})
	var theta := _mouth_seam_theta(parameters, s)
	var normal := Vector3(0.0, sin(theta) / maxf(radii.x, 1e-4), cos(theta) / maxf(radii.y, 1e-4)).normalized()
	return {"pos": pos, "normal": normal, "tangent": tangent}

static func _mouth_seam_point(parameters: Dictionary, s: float) -> Vector3:
	var snout := float(parameters.get("snout_length", 0.0))
	var u := _mouth_seam_u(parameters, s)
	var theta := _mouth_seam_theta(parameters, s)
	var forehead_slope := float(parameters.get("forehead_slope", 0.35))
	# Ride the same deformed surface the head mesh uses (dorsal/ventral profile, bump,
	# snout curve) so the mouth seam stays flush on the head no matter how it is sculpted.
	var surface := _shaped_point(parameters, u, theta, snout, forehead_slope, {})
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y
	var y := surface.y + y_shift
	var ang_w := 1.0 - clampf(absf(theta + PI * 0.5) / _mouth_half_ang(parameters), 0.0, 1.0)
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var groove := ang_w * (0.07 + 0.10 * gape)
	var z := surface.z * (1.0 - groove)
	y *= 1.0 - groove * 0.30
	return Vector3(surface.x, y, z)

static func _mouth_seam_theta(parameters: Dictionary, s: float) -> float:
	var half_ang := _mouth_half_ang(parameters)
	return lerpf(-PI * 0.5 - half_ang, -PI * 0.5 + half_ang, clampf(s, 0.0, 1.0))

static func _mouth_seam_u(parameters: Dictionary, s: float) -> float:
	# The arc centre bows slightly forward (toward the rostrum) like a real jaw.
	return clampf(_mouth_u(parameters) - sin(clampf(s, 0.0, 1.0) * PI) * 0.03, 0.02, 0.95)

static func _mouth_half_u(parameters: Dictionary) -> float:
	var width := clampf(float(parameters.get("shark_mouth_width", 0.18)), 0.02, 0.5)
	return clampf(0.030 + width * 0.20, 0.035, 0.11)

static func _mouth_half_ang(parameters: Dictionary) -> float:
	var width := clampf(float(parameters.get("shark_mouth_width", 0.18)), 0.02, 0.5)
	var curve := clampf(float(parameters.get("shark_mouth_curve", 0.58)), 0.0, 1.0)
	return lerpf(0.85, 1.45, clampf(width / 0.4, 0.0, 1.0)) * lerpf(0.92, 1.10, curve)

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
	var p := _shaped_point(parameters, u, theta, snout_length, forehead_slope, sculpt)
	# Flat-cap the silhouette (flat top/belly/cheeks) exactly like the fish head editor:
	# pull each axis toward the cross-section's own extreme at this u. Mirrors
	# PrimitiveFactory's flatness block so the shark gains the same controls.
	var top_flat := _snout_sculpt_value(parameters, sculpt, "head_top_flatness", 0.0)
	var bottom_flat := _snout_sculpt_value(parameters, sculpt, "head_bottom_flatness", 0.0)
	var left_flat := _snout_sculpt_value(parameters, sculpt, "head_left_flatness", 0.0)
	var right_flat := _snout_sculpt_value(parameters, sculpt, "head_right_flatness", 0.0)
	if top_flat == 0.0 and bottom_flat == 0.0 and left_flat == 0.0 and right_flat == 0.0:
		return p
	var top_target := _shaped_point(parameters, u, PI * 0.5, snout_length, forehead_slope, sculpt).y
	var bottom_target := _shaped_point(parameters, u, PI * 1.5, snout_length, forehead_slope, sculpt).y
	var left_target := _shaped_point(parameters, u, PI, snout_length, forehead_slope, sculpt).z
	var right_target := _shaped_point(parameters, u, 0.0, snout_length, forehead_slope, sculpt).z
	p.y = HeadProfile.flat_cap_value(p.y, top_target, 1.0, top_flat)
	p.y = HeadProfile.flat_cap_value(p.y, bottom_target, -1.0, bottom_flat)
	p.z = HeadProfile.flat_cap_value(p.z, left_target, -1.0, left_flat)
	p.z = HeadProfile.flat_cap_value(p.z, right_target, 1.0, right_flat)
	return p

# The full deformed head surface point at (u, theta), minus flatness. Honors the same
# continuous head-shape controls as the fish head (PrimitiveFactory.deformed_head_mesh):
# dorsal/ventral profile curves and a localized crown bump, so editing a shark head feels
# like editing a fish head. Shared by the mesh, the mouth seam and the flatness targets.
static func _shaped_point(parameters: Dictionary, u: float, theta: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Vector3:
	var x := _x_at_u(u, snout_length, parameters, sculpt)
	var radii := _base_radii(parameters, u, snout_length, forehead_slope, sculpt)
	var y := radii.x * sin(theta)
	var z := radii.y * cos(theta)
	y += _snout_curve_y_shift(parameters, u, snout_length, sculpt)
	# Girth fade (1 at mid-head, 0 at the rostrum tip and neck), the analogue of the fish
	# head's sin(phi), so profile offsets vanish toward the ends just as they do for fish.
	var sin_phi := 2.0 * sqrt(clampf(u * (1.0 - u), 0.0, 0.25))
	var theta_w := absf(sin(theta))
	var top_curve := _snout_sculpt_value(parameters, sculpt, "head_top_curve", 0.0)
	var top_peak := _snout_sculpt_value(parameters, sculpt, "head_top_peak", 0.35)
	var belly_curve := _snout_sculpt_value(parameters, sculpt, "head_belly_curve", 0.0)
	if y > 0.0:
		y += _dorsal_bias(u, forehead_slope)
		y += HeadProfile.dorsal_offset(u, sin_phi, top_curve, top_peak) * theta_w * HEAD_PROFILE_GAIN
	elif y < 0.0:
		y -= _ventral_bias(u)
		y -= HeadProfile.ventral_offset(u, sin_phi, belly_curve, 0.45) * theta_w * HEAD_PROFILE_GAIN
	var bump_height := _snout_sculpt_value(parameters, sculpt, "head_bump_height", 0.0)
	if bump_height != 0.0:
		var bump_pos := _snout_sculpt_value(parameters, sculpt, "head_bump_pos", -0.2)
		var bump_width := _snout_sculpt_value(parameters, sculpt, "head_bump_width", 0.18)
		var bump_round := _snout_sculpt_value(parameters, sculpt, "head_bump_round", 0.6)
		var bump_angle := deg_to_rad(_snout_sculpt_value(parameters, sculpt, "head_bump_angle", 35.0))
		var bump_amt := bump_height * HeadProfile.head_bump_falloff(x, theta, bump_pos, bump_width, bump_round) * HEAD_PROFILE_GAIN
		y += bump_amt * cos(bump_angle)
		x -= bump_amt * sin(bump_angle)
	return Vector3(x, y, z)

static func _base_radii(parameters: Dictionary, u: float, _snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Vector2:
	var snout_base := _snout_base(parameters, sculpt)
	var snout_thickness := clampf(_snout_sculpt_value(parameters, sculpt, "snout_thickness", 1.0), 0.15, 1.0)
	var snout_taper := clampf(_snout_sculpt_value(parameters, sculpt, "snout_taper", 0.0), 0.0, 1.0)
	# Girth "shoulder": the u where the head has swollen to full body girth. Driven by
	# snout_base and mapped well PAST the snout itself, because a real shark keeps widening
	# back toward the gill region (a great white peaks at u~0.65-0.8) - the head is not a
	# short cone that flares to full width instantly. Decoupled from snout_length, which now
	# only governs how far the rostrum tip projects forward (see _front_x), so a SHORT blunt
	# snout can still sit on a head that fills out gradually.
	var shoulder := lerpf(0.30, 0.62, clampf((snout_base - 0.12) / 0.38, 0.0, 1.0))
	var ramp_t := clampf(u / shoulder, 0.0, 1.0)
	# Taper bows the ramp: < 0.5 = blunt, bulbous nose that fills FAST (convex, exponent
	# below 1 - the real great-white rostrum); 0.5 = even cone; > 0.5 = sharp needle
	# (goblin/mako). The old range only spanned linear..sharp, so a blunt nose was
	# unreachable and every shark looked like a ballpoint pen.
	var ramp_exp := lerpf(0.5, 3.0, snout_taper)
	var ramp := smoothstep(0.0, 1.0, pow(ramp_t, ramp_exp))
	# Girth floor at the very tip: a thick snout keeps a blunt, rounded nose; a thin one
	# tapers toward a point. (u <= 0.001 is still forced to a closed point below.)
	var tip_floor := lerpf(0.02, 0.18, snout_thickness)
	var neck_fill := smoothstep(0.42, 1.0, u)
	var base := clampf(lerpf(tip_floor, 0.50, ramp) * lerpf(0.86, 1.0, neck_fill), 0.0, 0.52)
	if u <= 0.001:
		base = 0.0
	var radius_y := base
	# Cross-section width: a shark head is nearly as wide as tall at the gills, only
	# narrowing toward the snout. A fuller front floor (0.72 vs the old 0.56) lets the
	# rostrum read as a broad blunt cone instead of a thin blade, rounding to ~0.97 by the
	# gill region so the head-on view is a thick ellipse, not a knife.
	var radius_z := base * lerpf(0.72, 0.98, smoothstep(0.12, 0.62, u))
	radius_y *= 1.0 + clampf(forehead_slope - 0.35, -0.35, 0.65) * 0.08 * (1.0 - u)
	return Vector2(radius_y, radius_z)

static func _mouth_shadow_mesh(parameters: Dictionary) -> ArrayMesh:
	# Dark cavity ribbon following the wrapped ventral arc. The upper edge rides
	# the seam (lip) just proud of the head; the lower edge recedes inward and
	# drops with gape so the opening reads as a real 3-D maw from every angle.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := false
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var drop_norm := clampf(float(parameters.get("shark_lower_jaw_drop", 0.10)), 0.0, 0.4) / 0.4
	var open := 0.018 + gape * (0.085 + 0.05 * drop_norm)
	var previous_top := Vector3.ZERO
	var previous_bottom := Vector3.ZERO
	for i in range(MOUTH_PATH_SEGMENTS + 1):
		var s := float(i) / float(MOUTH_PATH_SEGMENTS)
		var frame := mouth_path_frame(parameters, s)
		var pos: Vector3 = frame["pos"]
		var normal: Vector3 = frame["normal"]
		# Slightly proud upper lip edge keeps the dark line visible side-on.
		var top := pos + normal * 0.006
		# Lower edge sinks into the head (-normal) and drops to expose the cavity.
		var bottom := pos - normal * (0.006 + open * 0.6) + Vector3(0.0, -open, 0.0)
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

static func _x_at_u(u: float, snout_length: float, parameters: Dictionary = {}, sculpt: Dictionary = {}) -> float:
	var clamped_u := clampf(u, 0.0, 1.0)
	var x := lerpf(_front_x(snout_length), NECK_X, clamped_u)
	var snout_base := _snout_base(parameters, sculpt)
	var base_delta := snout_base - HeadProfile.SNOUT_BLEND_HALF
	if snout_length > 0.0 and absf(base_delta) > 0.001 and clamped_u < snout_base:
		var t := 1.0 - clamped_u / maxf(snout_base, 0.001)
		x += base_delta * snout_length * 0.42 * t * (1.0 - t)
	return x

static func _mouth_u(parameters: Dictionary) -> float:
	var raw := clampf(float(parameters.get("shark_mouth_position_x", -0.96)), -1.5, 0.2)
	return clampf((raw + 1.5) / 1.7, 0.08, 0.82)

static func _mouth_center_y(parameters: Dictionary) -> float:
	return clampf(float(parameters.get("shark_mouth_position_y", -0.13)), -0.42, 0.24)

static func _snout_base(parameters: Dictionary, sculpt: Dictionary) -> float:
	return clampf(_snout_sculpt_value(parameters, sculpt, "snout_base", HeadProfile.SNOUT_BLEND_HALF), 0.12, 0.5)

static func _snout_curve_y_shift(parameters: Dictionary, u: float, snout_length: float, sculpt: Dictionary) -> float:
	var snout_base := _snout_base(parameters, sculpt)
	if snout_length <= 0.0 or u >= snout_base:
		return 0.0
	var tip_lock := smoothstep(0.025, 0.18, clampf(u, 0.0, 1.0))
	var curve := clampf(_snout_sculpt_value(parameters, sculpt, "snout_curve", 0.0), -1.0, 1.0)
	return HeadProfile.snout_y_shift(0.0, u, snout_base, curve) * 0.35 * tip_lock

static func _snout_sculpt_value(parameters: Dictionary, sculpt: Dictionary, key: String, default_value: float) -> float:
	if sculpt.has(key):
		return float(sculpt.get(key, default_value))
	return float(parameters.get(key, default_value))

# Small legacy forehead/keel nudge from forehead_slope. The primary dorsal/ventral
# shaping now comes from the continuous head_top_curve/head_belly_curve controls (same
# as the fish head editor); this just preserves the original mild shark default.
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
