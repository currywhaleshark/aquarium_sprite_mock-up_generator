class_name PrimitiveFactory
extends RefCounted

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")

# Longitudinal UV span the head mesh occupies, snout(0) -> neck(HEAD_U_SPAN).
# The body shell (build_fish_outer_shell_mesh) maps U uniformly over [0, 1] of the
# whole fish length, so this MUST match the head's physical length as a fraction of
# total length for the stripe density / pattern to stay continuous across the neck
# seam. Both meshes read this single constant so the two never drift apart.
const HEAD_U_SPAN := 0.25

# Upper-jaw carve: the head's lower-front is PERMANENTLY cut into an upper-jaw biting
# plane (the head IS the upper jaw). Sizes are in head-LOCAL units (head radius 0.5).
# mouth_size also scales the carve moderately so larger mouths reshape the upper-jaw
# rim instead of only widening the dark interior decal.
const UPPER_JAW_CARVE_DEPTH := 0.22       # how far below the bite line the cut reaches
const UPPER_JAW_CARVE_BACK := 0.20        # max rearward (+x) push of the carved surface
const UPPER_JAW_CARVE_UP := 0.13          # max upward (+y) push of the carved surface
const UPPER_JAW_CARVE_LENGTH := 0.50      # how far back along the snout (u) the cut spans
const UPPER_JAW_CARVE_HALF_WIDTH := 0.24  # z half-span of the cut

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

static func _head_point_before_flatness(shape: String, phi: float, theta: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Vector3:
	var snout_base := float(sculpt.get("snout_base", HeadProfile.SNOUT_BLEND_HALF))
	var snout_thickness := float(sculpt.get("snout_thickness", 1.0))
	var snout_taper := float(sculpt.get("snout_taper", 0.0))
	var snout_shift := float(sculpt.get("snout_y_shift", 0.0))
	var snout_curve := float(sculpt.get("snout_curve", 0.0))
	var top_curve := float(sculpt.get("head_top_curve", 0.0))
	var top_peak := float(sculpt.get("head_top_peak", 0.35))
	var belly_curve := float(sculpt.get("head_belly_curve", 0.0))
	var bump_height := float(sculpt.get("head_bump_height", 0.0))
	var bump_pos := float(sculpt.get("head_bump_pos", -0.2))
	var bump_width := float(sculpt.get("head_bump_width", 0.18))
	var bump_round := float(sculpt.get("head_bump_round", 0.6))
	var bump_rad := deg_to_rad(float(sculpt.get("head_bump_angle", 35.0)))
	var bump_up := cos(bump_rad)
	var bump_fwd := sin(bump_rad)

	var x := -0.5 * cos(phi)
	var y := 0.5 * sin(phi) * sin(theta)
	var z := 0.5 * sin(phi) * cos(theta)
	var u := x + 0.5

	if shape == "cephalofoil":
		var z_stretch := sin(phi) * HeadProfile.CEPHALOFOIL_Z_GAIN
		z *= (1.0 + z_stretch)
		y *= HeadProfile.CEPHALOFOIL_Y_SCALE
		x += abs(z) * HeadProfile.CEPHALOFOIL_SWEEP

	if shape != "cephalofoil" and x < 0.0:
		x -= HeadProfile.snout_forward_x_shift(snout_length, u, snout_base)
		var taper := HeadProfile.taper_factor(shape, u)
		var snout_r := HeadProfile.snout_radial_scale(snout_length, u, snout_base, snout_thickness, snout_taper)
		y *= taper * snout_r
		z *= taper * snout_r

	if shape != "cephalofoil" and y > 0.0 and x < 0.1:
		var hump_weight := sin(phi) * (1.0 - u)
		var hump_height := HeadProfile.hump_height(forehead_slope)
		if shape == "hump":
			y += hump_weight * hump_height
		elif shape == "steep_forehead":
			y += hump_weight * hump_height * HeadProfile.STEEP_FOREHEAD_SCALE
			x -= hump_weight * hump_height * HeadProfile.STEEP_FOREHEAD_X_SHIFT

	if shape == "flattened" and y < 0.0:
		y *= HeadProfile.FLATTEN_MESH_FACTOR

	if shape != "cephalofoil":
		var theta_w := absf(sin(theta))
		if y > 0.0:
			y += HeadProfile.dorsal_offset(u, sin(phi), top_curve, top_peak) * theta_w
		elif y < 0.0:
			y -= HeadProfile.ventral_offset(u, sin(phi), belly_curve, 0.45) * theta_w

	if shape != "cephalofoil" and bump_height != 0.0:
		var bump_amt := bump_height * HeadProfile.head_bump_falloff(x, theta, bump_pos, bump_width, bump_round)
		y += bump_amt * bump_up
		x -= bump_amt * bump_fwd

	if shape != "cephalofoil":
		y += HeadProfile.snout_y_shift(snout_shift, u, snout_base, snout_curve)

	return Vector3(x, y, z)

static func _head_mesh_precompute(shape: String, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Dictionary:
	var mouth_size_scale := clampf(float(sculpt.get("mouth_size", 0.08)) / 0.08, 0.65, 2.2)
	var jaw_gape := clampf(float(sculpt.get("mouth_open", 0.0)), 0.0, 1.0)
	var jaw_lm := HeadProfile.jaw_landmarks(sculpt, jaw_gape)
	return {
		"mouth_carve_enabled": bool(sculpt.get("mouth_carve_enabled", true)),
		"snout_base": float(sculpt.get("snout_base", HeadProfile.SNOUT_BLEND_HALF)),
		"snout_thickness": float(sculpt.get("snout_thickness", 1.0)),
		"snout_taper": float(sculpt.get("snout_taper", 0.0)),
		"snout_shift": float(sculpt.get("snout_y_shift", 0.0)),
		"snout_curve": float(sculpt.get("snout_curve", 0.0)),
		"top_curve": float(sculpt.get("head_top_curve", 0.0)),
		"top_peak": float(sculpt.get("head_top_peak", 0.35)),
		"belly_curve": float(sculpt.get("head_belly_curve", 0.0)),
		"head_top_flatness": clampf(float(sculpt.get("head_top_flatness", 0.0)), 0.0, 1.0),
		"head_bottom_flatness": clampf(float(sculpt.get("head_bottom_flatness", 0.0)), 0.0, 1.0),
		"head_left_flatness": clampf(float(sculpt.get("head_left_flatness", 0.0)), 0.0, 1.0),
		"head_right_flatness": clampf(float(sculpt.get("head_right_flatness", 0.0)), 0.0, 1.0),
		"bump_height": float(sculpt.get("head_bump_height", 0.0)),
		"bump_pos": float(sculpt.get("head_bump_pos", -0.2)),
		"bump_width": float(sculpt.get("head_bump_width", 0.18)),
		"bump_round": float(sculpt.get("head_bump_round", 0.6)),
		"bump_up": cos(deg_to_rad(float(sculpt.get("head_bump_angle", 35.0)))),
		"bump_fwd": sin(deg_to_rad(float(sculpt.get("head_bump_angle", 35.0)))),
		"mouth_center_y": float(sculpt.get("mouth_center_y", 0.0)),
		"lower_jaw_scale": clampf(float(sculpt.get("lower_jaw_scale", 1.0)), 0.45, 1.8),
		"mouth_size_scale": mouth_size_scale,
		"upper_carve_size_scale": lerpf(0.75, 1.35, clampf((mouth_size_scale - 0.65) / 1.55, 0.0, 1.0)),
		"jaw_gape": jaw_gape,
		"jaw_lm": jaw_lm,
		"premax_fwd": HeadProfile.JAW_SNOUT_FRONT_X - (jaw_lm["upper_tip"] as Vector2).x,
	}

# Returns {"point": Vector3, "pit_weight": float, "pit_inset_x": float} for one
# (phi, theta) grid sample. pit_weight is the HeadProfile.mouth_pit_weight used in
# block 6c and pit_inset_x is the actual +x dent applied there.
static func _head_final_point(shape: String, phi: float, theta: float, snout_length: float, forehead_slope: float, sculpt: Dictionary, precomputed: Dictionary) -> Dictionary:
	var snout_base := float(precomputed["snout_base"])
	var snout_thickness := float(precomputed["snout_thickness"])
	var snout_taper := float(precomputed["snout_taper"])
	var snout_shift := float(precomputed["snout_shift"])
	var snout_curve := float(precomputed["snout_curve"])
	var top_curve := float(precomputed["top_curve"])
	var top_peak := float(precomputed["top_peak"])
	var belly_curve := float(precomputed["belly_curve"])
	var head_top_flatness := float(precomputed["head_top_flatness"])
	var head_bottom_flatness := float(precomputed["head_bottom_flatness"])
	var head_left_flatness := float(precomputed["head_left_flatness"])
	var head_right_flatness := float(precomputed["head_right_flatness"])
	var bump_height := float(precomputed["bump_height"])
	var bump_pos := float(precomputed["bump_pos"])
	var bump_width := float(precomputed["bump_width"])
	var bump_round := float(precomputed["bump_round"])
	var bump_up := float(precomputed["bump_up"])
	var bump_fwd := float(precomputed["bump_fwd"])
	var mouth_center_y := float(precomputed["mouth_center_y"])
	var lower_jaw_scale := float(precomputed["lower_jaw_scale"])
	var mouth_size_scale := float(precomputed["mouth_size_scale"])
	var upper_carve_size_scale := float(precomputed["upper_carve_size_scale"])
	var jaw_gape := float(precomputed["jaw_gape"])
	var jaw_lm: Dictionary = precomputed["jaw_lm"]
	var premax_fwd := float(precomputed["premax_fwd"])
	var mouth_carve_enabled := bool(precomputed.get("mouth_carve_enabled", true))

	var x := -0.5 * cos(phi)
	var y := 0.5 * sin(phi) * sin(theta)
	var z := 0.5 * sin(phi) * cos(theta)

	var u := x + 0.5 # 0.0 (front) to 1.0 (back)

	# 1. Cephalofoil (Hammerhead)
	if shape == "cephalofoil":
		var z_stretch := sin(phi) * HeadProfile.CEPHALOFOIL_Z_GAIN
		z *= (1.0 + z_stretch)
		y *= HeadProfile.CEPHALOFOIL_Y_SCALE
		x += abs(z) * HeadProfile.CEPHALOFOIL_SWEEP # sweep wings back

	# 2. Snout stretch & taper (for non-cephalofoil snouts)
	if shape != "cephalofoil" and x < 0.0:
		x -= HeadProfile.snout_forward_x_shift(snout_length, u, snout_base)
		var taper := HeadProfile.taper_factor(shape, u)
		var snout_r := HeadProfile.snout_radial_scale(snout_length, u, snout_base, snout_thickness, snout_taper)
		y *= taper * snout_r
		z *= taper * snout_r

	# 3. Nuchal Hump / Steep Forehead
	if shape != "cephalofoil" and y > 0.0 and x < 0.1:
		var hump_weight := sin(phi) * (1.0 - u)
		var hump_height := HeadProfile.hump_height(forehead_slope)
		if shape == "hump":
			y += hump_weight * hump_height
		elif shape == "steep_forehead":
			y += hump_weight * hump_height * HeadProfile.STEEP_FOREHEAD_SCALE
			x -= hump_weight * hump_height * HeadProfile.STEEP_FOREHEAD_X_SHIFT

	# 4. Flattened head
	if shape == "flattened" and y < 0.0:
		y *= HeadProfile.FLATTEN_MESH_FACTOR

	# 4b. Continuous dorsal/ventral profile (forehead hump, flat top, flat belly).
	# Weight by |sin(theta)| so the offset is full at the crown/keel (theta = 90/270)
	# and fades to zero at the flanks (theta = 0/180). Without this the whole upper
	# (or lower) hemisphere shifts uniformly, dragging the side vertices out past the
	# body shell's silhouette-based envelope and tearing the head/shell seam. The
	# shell contour samples theta = 90, which still gets the full offset, so the two
	# stay matched.
	if shape != "cephalofoil":
		var theta_w := absf(sin(theta))
		if y > 0.0:
			y += HeadProfile.dorsal_offset(u, sin(phi), top_curve, top_peak) * theta_w
		elif y < 0.0:
			y -= HeadProfile.ventral_offset(u, sin(phi), belly_curve, 0.45) * theta_w

	# 4c. Localized crown bump protruding at head_bump_angle (up .. forward).
	if shape != "cephalofoil" and bump_height != 0.0:
		var bump_amt := bump_height * HeadProfile.head_bump_falloff(x, theta, bump_pos, bump_width, bump_round)
		y += bump_amt * bump_up
		x -= bump_amt * bump_fwd

	# 5. Jaw shear + snout curve: the snout tip follows the mouth and can curl
	# up/down, while the snout base (where it meets the head) stays fixed, so the
	# head body itself does not move.
	if shape != "cephalofoil":
		y += HeadProfile.snout_y_shift(snout_shift, u, snout_base, snout_curve)

	if shape != "cephalofoil" and sin(phi) > 0.001:
		var top_target := _head_point_before_flatness(shape, phi, PI * 0.5, snout_length, forehead_slope, sculpt).y
		var bottom_target := _head_point_before_flatness(shape, phi, PI * 1.5, snout_length, forehead_slope, sculpt).y
		var left_target := _head_point_before_flatness(shape, phi, PI, snout_length, forehead_slope, sculpt).z
		var right_target := _head_point_before_flatness(shape, phi, 0.0, snout_length, forehead_slope, sculpt).z
		y = HeadProfile.flat_cap_value(y, top_target, 1.0, head_top_flatness)
		y = HeadProfile.flat_cap_value(y, bottom_target, -1.0, head_bottom_flatness)
		z = HeadProfile.flat_cap_value(z, left_target, -1.0, head_left_flatness)
		z = HeadProfile.flat_cap_value(z, right_target, 1.0, head_right_flatness)

	var carve_back_x := 0.0
	var carve_up_y := 0.0

	# 6. Upper-jaw silhouette: the head mesh ITSELF is the upper jaw, and its
	# underside is carved into a defined biting plane ALWAYS - not only when the
	# mouth opens. This is the base shape (the teardrop "head+upper jaw" of the
	# sketch). The gape comes entirely from the separate lower-jaw mesh swinging
	# down below this plane; mouth_open only widens the carve slightly so the
	# upper lip lifts a touch as the jaw drops. The lower jaw fills this carved
	# region when closed (mouth_open = 0) so the head still reads as whole.
	# front_w stretches the cut back along the snout (jaw plane length); center_w
	# widens it across the mouth's z so it spans the mouth width, not a notch.
	if mouth_carve_enabled and shape != "cephalofoil" and x < 0.04:
		var front_w := smoothstep(UPPER_JAW_CARVE_LENGTH, 0.0, u)
		var carve_depth := UPPER_JAW_CARVE_DEPTH * lower_jaw_scale * upper_carve_size_scale
		var carve_half_width := UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.82, 1.12, clampf((lower_jaw_scale - 0.45) / 1.35, 0.0, 1.0)) * upper_carve_size_scale
		var lower_edge := mouth_center_y - carve_depth
		var lower_w := smoothstep(mouth_center_y + 0.04, lower_edge, y)
		var center_w := 1.0 - clampf(absf(z) / carve_half_width, 0.0, 1.0)
		var carve_w := front_w * lower_w * center_w
		carve_back_x = UPPER_JAW_CARVE_BACK * lower_jaw_scale * upper_carve_size_scale * carve_w
		carve_up_y = UPPER_JAW_CARVE_UP * lower_jaw_scale * upper_carve_size_scale * carve_w
		x += carve_back_x
		y += carve_up_y

	# 6b. Premaxilla protrusion: as the mouth opens, the upper jaw is thrown
	# forward (the teleost protrusible-jaw tube). Pushes the snout-front region
	# (-x) weighted by how close it is to the tip; no-op when jaw_protrusion = 0.
	if mouth_carve_enabled and shape != "cephalofoil" and premax_fwd > 0.0 and x < 0.1:
		x -= premax_fwd * smoothstep(UPPER_JAW_CARVE_LENGTH, 0.0, u)

	var pit_weight := 0.0
	var pit_inset_x := 0.0

	# 6c. Real mouth pit: as the mouth opens the lower-front shell is dented INWARD into
	# a concave socket (a true silhouette concavity visible from the side). The socket
	# grows taller/wider with gape; 0 when closed so the resting head is untouched. The
	# dark socket lining (FishRig) uses the same HeadProfile.mouth_pit math to stay flush.
	if mouth_carve_enabled and shape != "cephalofoil" and jaw_gape > 0.0 and x < 0.1:
		var mouth_width_scale := mouth_size_scale
		var mouth_depth_scale := lerpf(0.85, 1.25, clampf((mouth_width_scale - 0.65) / 1.55, 0.0, 1.0))

		var buffer_y: float = 0.03 * lower_jaw_scale * sqrt(mouth_width_scale)
		var pit_top: float = (jaw_lm["upper_tip"] as Vector2).y + buffer_y
		var pit_bottom: float = (jaw_lm["lower_tip"] as Vector2).y - buffer_y
		var pit_h: float = pit_top - pit_bottom
		var pit_half_h: float = pit_h * 0.5
		var pit_center_y: float = (pit_top + pit_bottom) * 0.5
		var lower_jaw_half_w := UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.72, 1.12, clampf((lower_jaw_scale - 0.45) / 1.35, 0.0, 1.0)) * mouth_width_scale
		var pit_half_w := lower_jaw_half_w * 0.84
		var pit_depth := UPPER_JAW_CARVE_DEPTH * 0.5 * lower_jaw_scale * mouth_depth_scale
		pit_weight = HeadProfile.mouth_pit_weight(u, y, z, pit_center_y, pit_half_h, pit_half_w)
		var pit := HeadProfile.mouth_pit_offset(u, y, z, pit_center_y, pit_half_h, pit_half_w, pit_depth, jaw_gape)
		pit_inset_x = maxf(pit.x, 0.0)
		x += pit.x
		y += pit.y
		z += pit.z

	return {
		"point": Vector3(x, y, z),
		"pit_weight": pit_weight,
		"pit_inset_x": pit_inset_x,
		"carve_back_x": carve_back_x,
		"carve_up_y": carve_up_y,
	}

static func deformed_head_mesh(shape: String, snout_length: float, forehead_slope: float, rings: int = 18, segments: int = 24, sculpt: Dictionary = {}) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var precomputed := _head_mesh_precompute(shape, snout_length, forehead_slope, sculpt)
	var grid := []
	for i in range(rings + 1):
		var phi := PI * float(i) / float(rings)
		var ring_vertices := []
		for j in range(segments + 1):
			var theta := TAU * float(j) / float(segments)
			var sample := _head_final_point(shape, phi, theta, snout_length, forehead_slope, sculpt, precomputed)
			ring_vertices.append(sample["point"] as Vector3)
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
			st.set_uv2(Vector2(u0, v0))
			st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0))
			st.set_uv2(Vector2(u1, v0))
			st.add_vertex(p10)
			st.set_uv(Vector2(u0, v1))
			st.set_uv2(Vector2(u0, v1))
			st.add_vertex(p01)

			# Triangle 2
			st.set_uv(Vector2(u0, v1))
			st.set_uv2(Vector2(u0, v1))
			st.add_vertex(p01)
			st.set_uv(Vector2(u1, v0))
			st.set_uv2(Vector2(u1, v0))
			st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1))
			st.set_uv2(Vector2(u1, v1))
			st.add_vertex(p11)

	st.generate_normals()
	return st.commit()

# Cells whose dent is shallower than this (in head-local units) are skipped: there the
# lining would sit nearly coplanar with the shell and depth-fight (jagged black/teal
# triangles). The skipped rim ring is sub-pixel shallow, so the dark edge still reads as
# the pit boundary.
const MOUTH_LINING_MIN_INSET := 0.006
const MOUTH_LINING_MIN_CARVE := 0.012
const MOUTH_LINING_REVEAL_GAPE := 1.5

static func mouth_interior_lining_mesh(shape: String, snout_length: float, forehead_slope: float, rings: int, segments: int, sculpt: Dictionary, proud: float = 0.02) -> ArrayMesh:
	var precomputed := _head_mesh_precompute(shape, snout_length, forehead_slope, sculpt)
	var reveal := smoothstep(0.0, MOUTH_LINING_REVEAL_GAPE, float(precomputed["jaw_gape"]))
	var grid := []
	for i in range(rings + 1):
		var phi := PI * float(i) / float(rings)
		var ring_samples := []
		for j in range(segments + 1):
			var theta := TAU * float(j) / float(segments)
			ring_samples.append(_head_final_point(shape, phi, theta, snout_length, forehead_slope, sculpt, precomputed))
		grid.append(ring_samples)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := false
	for i in rings:
		for j in segments:
			var s00: Dictionary = grid[i][j]
			var s01: Dictionary = grid[i][j + 1]
			var s10: Dictionary = grid[i + 1][j]
			var s11: Dictionary = grid[i + 1][j + 1]
			var f00 := _mouth_lining_field(s00, reveal)
			var f01 := _mouth_lining_field(s01, reveal)
			var f10 := _mouth_lining_field(s10, reveal)
			var f11 := _mouth_lining_field(s11, reveal)
			if f00 < 0.0 and f01 < 0.0 and f10 < 0.0 and f11 < 0.0:
				continue
			if f00 >= 0.0 and f01 >= 0.0 and f10 >= 0.0 and f11 >= 0.0:
				var p00 := _mouth_lining_vertex(s00, proud)
				var p01 := _mouth_lining_vertex(s01, proud)
				var p10 := _mouth_lining_vertex(s10, proud)
				var p11 := _mouth_lining_vertex(s11, proud)
				st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
				st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
				emitted = true
				continue
			var polygon := _mouth_lining_cell_polygon([s00, s10, s11, s01], reveal)
			if polygon.size() < 3:
				continue
			var p0 := _mouth_lining_vertex(polygon[0], proud)
			for k in range(1, polygon.size() - 1):
				st.add_vertex(p0)
				st.add_vertex(_mouth_lining_vertex(polygon[k], proud))
				st.add_vertex(_mouth_lining_vertex(polygon[k + 1], proud))
			emitted = true
	if not emitted:
		return ArrayMesh.new()
	st.generate_normals()
	return st.commit()

static func _mouth_lining_cell_polygon(samples: Array, reveal: float) -> Array:
	var polygon := []
	for sample in samples:
		polygon.append({
			"sample": sample,
			"field": _mouth_lining_field(sample, reveal),
		})
	var clipped := []
	for i in range(polygon.size()):
		var current: Dictionary = polygon[i]
		var next: Dictionary = polygon[(i + 1) % polygon.size()]
		var current_inside := float(current["field"]) >= 0.0
		var next_inside := float(next["field"]) >= 0.0
		if current_inside and next_inside:
			clipped.append(next["sample"])
		elif current_inside and not next_inside:
			clipped.append(_mouth_lining_lerp_sample(current, next))
		elif not current_inside and next_inside:
			clipped.append(_mouth_lining_lerp_sample(current, next))
			clipped.append(next["sample"])
	return clipped

static func _mouth_lining_field(sample: Dictionary, reveal: float) -> float:
	var pit_field := float(sample["pit_inset_x"]) / MOUTH_LINING_MIN_INSET
	var carve_field := float(sample["carve_back_x"]) * reveal / MOUTH_LINING_MIN_CARVE
	return maxf(pit_field, carve_field) - 1.0

static func _mouth_lining_lerp_sample(a: Dictionary, b: Dictionary) -> Dictionary:
	var af := float(a["field"])
	var bf := float(b["field"])
	var denom := af - bf
	var t := 0.5 if absf(denom) < 0.000001 else clampf(af / denom, 0.0, 1.0)
	var sa: Dictionary = a["sample"]
	var sb: Dictionary = b["sample"]
	return {
		"point": (sa["point"] as Vector3).lerp(sb["point"] as Vector3, t),
		"pit_weight": lerpf(float(sa["pit_weight"]), float(sb["pit_weight"]), t),
		"pit_inset_x": lerpf(float(sa["pit_inset_x"]), float(sb["pit_inset_x"]), t),
		"carve_back_x": lerpf(float(sa["carve_back_x"]), float(sb["carve_back_x"]), t),
		"carve_up_y": lerpf(float(sa["carve_up_y"]), float(sb["carve_up_y"]), t),
	}

static func _mouth_lining_vertex(sample: Dictionary, proud: float) -> Vector3:
	var point := sample["point"] as Vector3
	# Float at half the local dent/carve vector (capped at `proud`): enough to win the
	# depth test cleanly while staying inside the original, uncarved head surface.
	var back := Vector3(
		-(float(sample["pit_inset_x"]) + float(sample["carve_back_x"])) * 0.5,
		-float(sample["carve_up_y"]) * 0.5,
		0.0
	)
	if back.length() > proud:
		back = back.normalized() * proud
	return point + back

static func deformed_head(name: String, shape: String, head_scale: Vector3, snout_length: float, forehead_slope: float, material: Material, sculpt: Dictionary = {}) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = deformed_head_mesh(shape, snout_length, forehead_slope, 18, 24, sculpt)
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

static func tapered_cylinder(name: String, bottom_radius: float, top_radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
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

static func build_polygon_fin_mesh(points: PackedVector3Array, uv_reference_points: PackedVector3Array = PackedVector3Array()) -> ArrayMesh:
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	
	var vertices := PackedVector3Array([center])
	var normals := PackedVector3Array([Vector3.BACK])
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	# Determine UV bounds using reference points if provided (so UVs remain constant during deformation)
	var ref_points := uv_reference_points if not uv_reference_points.is_empty() else points
	var ref_center := Vector3.ZERO
	for p in ref_points:
		ref_center += p
	ref_center /= float(ref_points.size())
	
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for p in ref_points:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		
	uvs.append(_fin_uv_for_point(ref_center, min_x, max_x, min_y, max_y))
	for i in points.size():
		var point := points[i]
		var ref_point := ref_points[i]
		vertices.append(point)
		normals.append(Vector3.BACK)
		uvs.append(_fin_uv_for_point(ref_point, min_x, max_x, min_y, max_y))
		
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
		"nub":
			return PackedVector3Array([
				Vector3(-length * 0.45, 0.0, 0.0),
				Vector3(-length * 0.10, height, 0.0),
				Vector3(length * 0.45, height * 0.25, 0.0),
				Vector3(length * 0.40, 0.0, 0.0)
			])
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

static func fish_outer_shell(name: String, profile: Array[Vector3], material: Material, segments: int = 28, center_y_offsets: PackedFloat32Array = PackedFloat32Array(), radius_half_diffs: PackedFloat32Array = PackedFloat32Array(), radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(), flatness_profiles: Array[Vector4] = []) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, PackedVector3Array(), PackedFloat32Array(), center_y_offsets, radius_half_diffs, radius_z_half_diffs, flatness_profiles)
	node.material_override = material
	return node

static func update_fish_outer_shell(node: MeshInstance3D, profile: Array[Vector3], z_offsets: PackedFloat32Array, segments: int = 28) -> void:
	node.mesh = build_fish_outer_shell_mesh(profile, z_offsets, segments)

static func update_fish_outer_shell_bent(node: MeshInstance3D, profile: Array[Vector3], centers: PackedVector3Array, yaw_degrees: PackedFloat32Array, segments: int = 28, center_y_offsets: PackedFloat32Array = PackedFloat32Array(), radius_half_diffs: PackedFloat32Array = PackedFloat32Array(), radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(), flatness_profiles: Array[Vector4] = []) -> void:
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, centers, yaw_degrees, center_y_offsets, radius_half_diffs, radius_z_half_diffs, flatness_profiles)

static func _apply_flat_cap(value: float, radius: float, side_sign: float, amount: float) -> float:
	return HeadProfile.flat_cap_value(value, side_sign * radius, side_sign, amount)

static func build_fish_outer_shell_mesh(
	profile: Array[Vector3],
	z_offsets: PackedFloat32Array = PackedFloat32Array(),
	segments: int = 28,
	centers: PackedVector3Array = PackedVector3Array(),
	yaw_degrees: PackedFloat32Array = PackedFloat32Array(),
	center_y_offsets: PackedFloat32Array = PackedFloat32Array(),
	radius_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	flatness_profiles: Array[Vector4] = []
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array()
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
		# Egg cross-section: the upper half uses radius (point.y + hd), the lower half
		# (point.y - hd), about the true centerline (center.y - hd). This keeps the top and
		# bottom extremes at center.y +/- point.y exactly as a symmetric ring, so samplers
		# and fin anchors are untouched, while letting the two heights curve independently.
		# hd is clamped so the thinner side never collapses through the centerline.
		var hd := radius_half_diffs[ring_index] if ring_index < radius_half_diffs.size() else 0.0
		hd = clampf(hd, -point.y * 0.9, point.y * 0.9)
		var r_up := point.y + hd
		var r_lo := point.y - hd
		var center_true_y := center.y - hd
		var zd := radius_z_half_diffs[ring_index] if ring_index < radius_z_half_diffs.size() else 0.0
		zd = clampf(zd, -point.z * 0.9, point.z * 0.9)
		var r_z_top := maxf(point.z + zd, 0.001)
		var r_z_bottom := maxf(point.z - zd, 0.001)
		var flat := flatness_profiles[ring_index] if ring_index < flatness_profiles.size() else Vector4.ZERO
		for segment in range(verts_per_ring):
			var angle := TAU * float(segment) / float(segments)
			var sin_a := sin(angle)
			var cos_a := cos(angle)
			var upper_half := sin_a >= 0.0
			var r_y := r_up if upper_half else r_lo
			var z_radius := lerpf(r_z_bottom, r_z_top, HeadProfile.vertical_half_blend(sin_a))
			var y := (center_true_y - center.y) + sin_a * r_y
			var z := cos_a * z_radius
			y = _apply_flat_cap(y, point.y, 1.0, flat.x)
			y = _apply_flat_cap(y, point.y, -1.0, flat.y)
			z = _apply_flat_cap(z, z_radius, -1.0, flat.z)
			z = _apply_flat_cap(z, z_radius, 1.0, flat.w)
			var local_vertex := Vector3(0.0, y, z)
			vertices.append(center + ring_basis * local_vertex)
			var local_normal := Vector3(0.0, sin_a / maxf(r_y, 0.001), z / maxf(z_radius, 0.001)).normalized()
			normals.append((ring_basis * local_normal).normalized())
			uvs.append(Vector2(u, float(segment) / float(segments)))
			var circumference := TAU * (point.y + point.z) * 0.5
			var physical_v := (float(segment) / float(segments)) * circumference
			uvs2.append(Vector2(point.x, physical_v))
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
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func ray_mantle_shell(name: String, radius_x: float, radius_z: float, crown_height: float, material: Material, segments: int = 48, roundness: float = 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_ray_mantle_shell_mesh(radius_x, radius_z, crown_height, 0.0, segments, roundness)
	node.material_override = material
	return node

static func update_ray_mantle_shell(node: MeshInstance3D, radius_x: float, radius_z: float, crown_height: float, flap_lift: float, segments: int = 48, roundness: float = 1.0) -> void:
	node.mesh = build_ray_mantle_shell_mesh(radius_x, radius_z, crown_height, flap_lift, segments, roundness)

static func build_ray_mantle_shell_mesh(radius_x: float, radius_z: float, crown_height: float, flap_lift: float = 0.0, segments: int = 48, roundness: float = 1.0) -> ArrayMesh:
	var num_rings := 6
	var vertices := PackedVector3Array([Vector3(0.0, crown_height, 0.0)])
	var normals := PackedVector3Array([Vector3.UP])
	var indices := PackedInt32Array()
	
	var wingtip_x: float = radius_x * 0.1
	var P_back := Vector3(radius_x, 0.0, 0.0)
	var P_left := Vector3(wingtip_x, 0.0, radius_z)
	var P_front := Vector3(-radius_x, 0.0, 0.0)
	var P_right := Vector3(wingtip_x, 0.0, -radius_z)
	
	var theta_left: float = atan2(P_left.z, P_left.x)
	var theta_right: float = fposmod(atan2(P_right.z, P_right.x), TAU)
	
	for r in range(1, num_rings):
		var t := float(r) / float(num_rings - 1)
		for s in segments:
			var angle := TAU * float(s) / float(segments)
			var angle_norm := fposmod(angle, TAU)
			
			var boundary_pt := Vector3.ZERO
			if angle_norm < theta_left:
				var t_seg: float = angle_norm / theta_left
				boundary_pt = P_back.lerp(P_left, t_seg)
			elif angle_norm < PI:
				var t_seg: float = (angle_norm - theta_left) / (PI - theta_left)
				boundary_pt = P_left.lerp(P_front, t_seg)
			elif angle_norm < theta_right:
				var t_seg: float = (angle_norm - PI) / (theta_right - PI)
				boundary_pt = P_front.lerp(P_right, t_seg)
			else:
				var t_seg: float = (angle_norm - theta_right) / (TAU - theta_right)
				boundary_pt = P_right.lerp(P_back, t_seg)
			
			var x_el: float = cos(angle) * radius_x
			var z_el: float = sin(angle) * radius_z
			var P_ellipse := Vector3(x_el, 0.0, z_el)
			
			var P_blended := boundary_pt.lerp(P_ellipse, roundness)
			
			var x: float = P_blended.x * t
			var z: float = P_blended.z * t
			
			var wing_weight: float = absf(P_blended.z) / maxf(radius_z, 0.001)
			var edge_lift: float = crown_height * 0.18 * (1.0 + cos(angle)) + flap_lift * wing_weight
			var y: float = lerp(crown_height, edge_lift, t * t)
			
			vertices.append(Vector3(x, y, z))
			
			var dir := Vector3(x, 0.0, z).normalized()
			var normal := (Vector3.UP + dir * t * 0.45).normalized()
			normals.append(normal)
			
	for s in segments:
		var B := 1 + s
		var C := 1 + (s + 1) % segments
		indices.append_array(PackedInt32Array([0, B, C]))
		
	for r in range(1, num_rings - 1):
		for s in segments:
			var s_next := (s + 1) % segments
			var A := 1 + (r - 1) * segments + s
			var B := 1 + (r - 1) * segments + s_next
			var C := 1 + r * segments + s
			var D := 1 + r * segments + s_next
			indices.append_array(PackedInt32Array([A, C, B, B, C, D]))
			
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func build_ray_grid_mesh(radius_x: float, radius_z: float, crown_height: float, roundness: float = 1.0, is_double_sided: bool = true, rings: Array = [], head_shape: String = "manta", snout_length: float = 0.3, wing_width: float = 1.0, wing_curve: float = 0.0) -> ArrayMesh:
	var cols: int = 17
	var rows: int = 17
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	var wingtip_x: float = radius_x * 0.1
	var P_back: Vector3 = Vector3(radius_x, 0.0, 0.0)
	var P_left: Vector3 = Vector3(wingtip_x, 0.0, radius_z)
	var P_front: Vector3 = Vector3(-radius_x, 0.0, 0.0)
	var P_right: Vector3 = Vector3(wingtip_x, 0.0, -radius_z)
	
	var theta_left: float = atan2(P_left.z, P_left.x)
	var theta_right: float = fposmod(atan2(P_right.z, P_right.x), TAU)
	
	var get_boundary := func(angle: float) -> Vector3:
		var angle_norm: float = fposmod(angle, TAU)
		var boundary_pt: Vector3 = Vector3.ZERO
		if angle_norm < theta_left:
			var t_seg: float = angle_norm / theta_left
			boundary_pt = P_back.lerp(P_left, t_seg)
		elif angle_norm < PI:
			var t_seg: float = (angle_norm - theta_left) / (PI - theta_left)
			boundary_pt = P_left.lerp(P_front, t_seg)
		elif angle_norm < theta_right:
			var t_seg: float = (angle_norm - PI) / (theta_right - PI)
			boundary_pt = P_front.lerp(P_right, t_seg)
		else:
			var t_seg: float = (angle_norm - theta_right) / (TAU - theta_right)
			boundary_pt = P_right.lerp(P_back, t_seg)
			
		var x_el: float = cos(angle) * radius_x
		var z_el: float = sin(angle) * radius_z
		var P_ellipse: Vector3 = Vector3(x_el, 0.0, z_el)
		var pt := boundary_pt.lerp(P_ellipse, roundness)
		
		# Snout shape deformation in head region
		if angle_norm > theta_left and angle_norm < theta_right:
			var angle_from_front := absf(angle_norm - PI)
			var head_span := PI - theta_left
			var spade := cos(angle_from_front * (PI / 2.0 / head_span))
			var snout_scale := snout_length / 0.3
			
			if head_shape == "eagle":
				var disp := -radius_x * 0.28 * pow(spade, 2.0) * snout_scale
				pt.x += disp
			elif head_shape == "cownose":
				var lobe_freq := 4.5
				var groove := (0.14 * (1.0 - cos(angle_from_front * lobe_freq)) - 0.08) * pow(spade, 1.5)
				pt.x += -radius_x * groove * snout_scale
			elif head_shape == "manta":
				var flat := -radius_x * 0.06 * (1.0 - pow(1.0 - spade, 2.0))
				pt.x += flat
				
		return pt
		
	for c in range(cols):
		var u: float = float(c) / float(cols - 1)
		var x: float = -radius_x + 2.0 * radius_x * u
		var theta: float = PI - u * PI
		
		var sampled := BodyProfileScript.sample_rings(rings, u)
		var width_scale := float(sampled.get("width", 0.5)) / 0.45
		
		var pt_left: Vector3 = get_boundary.call(theta)
		pt_left.z *= width_scale
		var pt_right: Vector3 = get_boundary.call(-theta)
		pt_right.z *= width_scale
		
		for r in range(rows):
			var v: float = float(r) / float(rows - 1)
			var pt_boundary: Vector3 = pt_right.lerp(pt_left, v)
			var z: float = pt_boundary.z
			var W: float = maxf(absf(pt_left.z), 0.001)
			var t_z: float = absf(z) / W
			var t_x: float = x / radius_x
			var edge_weight := pow(t_z, 1.35)
			var boundary_x := pt_boundary.x
			var x_contoured := lerpf(x, boundary_x, edge_weight)
			var x_shaped := lerpf(x_contoured, x_contoured * maxf(wing_width, 0.05), edge_weight)
			var thick_profile: float = (1.0 - t_z * t_z) * (1.0 - t_x * t_x)
			var half_thick: float = crown_height * maxf(thick_profile, 0.0)
			
			var edge_curve_y := wing_curve * edge_weight
			var y_top := half_thick * (float(sampled.get("upper_height", 0.3)) / 0.42) + float(sampled.get("y_offset", 0.0)) + edge_curve_y
			vertices.append(Vector3(x_shaped, y_top, z))
			var dir: Vector3 = Vector3(x_shaped, 0.0, z).normalized()
			var normal: Vector3 = (Vector3.UP + dir * t_z * 0.3).normalized()
			normals.append(normal)
			uvs.append(Vector2(u, v))
			
	for c in range(cols - 1):
		for r in range(rows - 1):
			var a: int = c * rows + r
			var b: int = c * rows + r + 1
			var d: int = (c + 1) * rows + r
			var e: int = (c + 1) * rows + r + 1
			indices.append_array(PackedInt32Array([a, b, d, b, e, d]))
			
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if is_double_sided:
		var b_vertices: PackedVector3Array = PackedVector3Array()
		var b_normals: PackedVector3Array = PackedVector3Array()
		var b_uvs: PackedVector2Array = PackedVector2Array()
		var b_indices: PackedInt32Array = PackedInt32Array()
		
		for c in range(cols):
			var u: float = float(c) / float(cols - 1)
			var x: float = -radius_x + 2.0 * radius_x * u
			var theta: float = PI - u * PI
			
			var sampled := BodyProfileScript.sample_rings(rings, u)
			var width_scale := float(sampled.get("width", 0.5)) / 0.45
			
			var pt_left: Vector3 = get_boundary.call(theta)
			pt_left.z *= width_scale
			var pt_right: Vector3 = get_boundary.call(-theta)
			pt_right.z *= width_scale
			
			for r in range(rows):
				var v: float = float(r) / float(rows - 1)
				var pt_boundary: Vector3 = pt_right.lerp(pt_left, v)
				var z: float = pt_boundary.z
				var W: float = maxf(absf(pt_left.z), 0.001)
				var t_z: float = absf(z) / W
				var t_x: float = x / radius_x
				var edge_weight := pow(t_z, 1.35)
				var boundary_x := pt_boundary.x
				var x_contoured := lerpf(x, boundary_x, edge_weight)
				var x_shaped := lerpf(x_contoured, x_contoured * maxf(wing_width, 0.05), edge_weight)
				var thick_profile: float = (1.0 - t_z * t_z) * (1.0 - t_x * t_x)
				var half_thick: float = crown_height * maxf(thick_profile, 0.0)
				
				var edge_curve_y := wing_curve * edge_weight
				var y_bottom := -half_thick * (float(sampled.get("lower_height", 0.3)) / 0.36) + float(sampled.get("y_offset", 0.0)) + edge_curve_y
				b_vertices.append(Vector3(x_shaped, y_bottom, z))
				var dir: Vector3 = Vector3(x_shaped, 0.0, z).normalized()
				var normal: Vector3 = (Vector3.DOWN + dir * t_z * 0.3).normalized()
				b_normals.append(normal)
				b_uvs.append(Vector2(u, v))
				
		for c in range(cols - 1):
			for r in range(rows - 1):
				var a: int = c * rows + r
				var b: int = c * rows + r + 1
				var d: int = (c + 1) * rows + r
				var e: int = (c + 1) * rows + r + 1
				b_indices.append_array(PackedInt32Array([a, d, b, b, d, e]))
				
		var b_arrays := []
		b_arrays.resize(Mesh.ARRAY_MAX)
		b_arrays[Mesh.ARRAY_VERTEX] = b_vertices
		b_arrays[Mesh.ARRAY_NORMAL] = b_normals
		b_arrays[Mesh.ARRAY_TEX_UV] = b_uvs
		b_arrays[Mesh.ARRAY_INDEX] = b_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b_arrays)
		
	return mesh

static func ray_cephalic_lobe(name: String, style: String, length: float, thickness: float, material: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	if style == "rolled":
		var cols: int = 8
		var rows: int = 8
		for c in range(cols):
			var u: float = float(c) / float(cols - 1)
			var x: float = -length * u
			var rad: float = thickness * 1.5 * (1.0 - u * 0.3)
			for r in range(rows):
				var v: float = float(r) / float(rows - 1)
				var phi: float = (v - 0.5) * TAU * 0.85
				var y: float = sin(phi) * rad
				var z: float = cos(phi) * rad
				vertices.append(Vector3(x, y, z))
				normals.append(Vector3(0.0, sin(phi), cos(phi)).normalized())
				
		for c in range(cols - 1):
			for r in range(rows - 1):
				var a: int = c * rows + r
				var b: int = c * rows + r + 1
				var d: int = (c + 1) * rows + r
				var e: int = (c + 1) * rows + r + 1
				indices.append_array(PackedInt32Array([a, b, d, b, e, d]))
	else:
		var cols: int = 6
		var rows: int = 5
		for c in range(cols):
			var u: float = float(c) / float(cols - 1)
			var x: float = -length * u
			var w: float = thickness * 3.0 * (1.0 - u)
			for r in range(rows):
				var v: float = float(r) / float(rows - 1)
				var z: float = -w * 0.5 + w * v
				var y: float = thickness * 0.2 * sin(v * PI) - u * 0.05
				vertices.append(Vector3(x, y, z))
				normals.append(Vector3.UP)
				
		for c in range(cols - 1):
			for r in range(rows - 1):
				var a: int = c * rows + r
				var b: int = c * rows + r + 1
				var d: int = (c + 1) * rows + r
				var e: int = (c + 1) * rows + r + 1
				indices.append_array(PackedInt32Array([a, b, d, b, e, d]))
				
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	return node
