class_name FishRig
extends "res://scripts/creature/CreatureRig.gd"

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")
const TMF := preload("res://scripts/materials/ToonMaterialFactory.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")

# How far median/pelvic fin bases sink into the body so they look rooted
# instead of floating above the surface. Larger embeds the base deeper.
const FIN_BASE_EMBED := 0.05

# Single jaw hinge location, as a fraction of mouth_size BEHIND the mouth node. The
# upper/lower lip bands and the split lower-jaw mesh all pivot about this same x so
# they meet at one corner of the mouth instead of two slightly offset hinges.
const MOUTH_HINGE_FRAC := 0.56

# The lower jaw's max depression (degrees at mouth_open = 1) now lives in the shared jaw
# linkage as HeadProfile.JAW_MAX_GAPE_DEG, so the carve, lower jaw, lower lip and cheeks
# all rotate by one gape value. See HeadProfile.jaw_landmarks.

# TEMP (Phase 2 iteration): the old surface-mouth decoration (dark aperture band, interior
# cavity, upper/lower lip bands) is hidden while the carved upper jaw + filling lower jaw
# are shaped, because it overlays and occludes them. Set true to restore the old mouth.
const MOUTH_DECOR_ENABLED := true

var body_pivot: Node3D
var tail_pivot_1: Node3D
var tail_pivot_2: Node3D
var tail_fin_pivot: Node3D
var tail_fin: MeshInstance3D
var tail_fin_base_points := PackedVector3Array()
var outer_shell: MeshInstance3D
var shell_profile: Array[Vector3] = []
var shell_center_y_offsets: Array[float] = []
# Per-ring (upper_height - lower_height) * 0.5 * body_height. shell_profile.y stays the
# AVERAGE radius and shell_center_y_offsets stays the shifted center, so every sampler and
# the ring extremes are unchanged; the mesh builder uses this to give each ring an
# independent upper/lower radius (egg cross-section) so editing one height no longer
# reshapes the opposite side.
var shell_radius_half_diff: Array[float] = []
var shell_ring_ids: Array[String] = []
var animated_shell_centers := PackedVector3Array()
var animated_shell_yaws := PackedFloat32Array()
var body_ring_world_points: Dictionary = {}
var shell_segments := 28
var shell_tail_pivot_1_x := 0.0
var shell_tail_pivot_2_x := 0.0
var dorsal_fin: MeshInstance3D
var dorsal_2_fin: MeshInstance3D
var anal_fin: MeshInstance3D
var pelvic_l: MeshInstance3D
var pelvic_r: MeshInstance3D
var pectoral_l: Node3D
var pectoral_r: Node3D
# Undeformed outline points for the paired side fins, captured at build time so the
# soft-membrane flutter can re-deform their mesh each frame (shared L/R per pair).
var pectoral_base_points := PackedVector3Array()
var pelvic_base_points := PackedVector3Array()
var dorsal_base_position := Vector3.ZERO
var dorsal_2_base_position := Vector3.ZERO
var anal_base_position := Vector3.ZERO
var pelvic_l_base_position := Vector3.ZERO
var pelvic_r_base_position := Vector3.ZERO
var pectoral_l_base_position := Vector3.ZERO
var pectoral_r_base_position := Vector3.ZERO
var pectoral_l_base_rotation := Vector3.ZERO
var pectoral_r_base_rotation := Vector3.ZERO
var head_node: MeshInstance3D
# Lower-jaw pivot (quadrate-articular joint) in head-LOCAL space, exposed so the editor
# can mark where the hinge sits while the jaw_hinge_x/_y sliders are adjusted.
var jaw_hinge_local := Vector3.ZERO
var jaw_hinge_valid := false
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
var eye_stalk_l: MeshInstance3D
var eye_stalk_r: MeshInstance3D
var eye_head_center := Vector3.ZERO
var eye_head_scale := Vector3.ONE
var eye_radius := 0.055
var ring_editor_enabled := false
var selected_body_ring_id := ""

func rebuild() -> void:
	super.rebuild()
	outer_shell = null
	shell_profile = []
	shell_center_y_offsets = []
	animated_shell_centers = PackedVector3Array()
	animated_shell_yaws = PackedFloat32Array()
	dorsal_fin = null
	dorsal_2_fin = null
	anal_fin = null
	pelvic_l = null
	pelvic_r = null
	pectoral_l = null
	pectoral_r = null
	pectoral_base_points = PackedVector3Array()
	pelvic_base_points = PackedVector3Array()
	tail_fin = null
	tail_fin_base_points = PackedVector3Array()
	head_node = null
	jaw_hinge_valid = false
	eye_l = null
	eye_r = null
	eye_stalk_l = null
	eye_stalk_r = null
	# Opaque toon material shared by the body shell and head so countershading and
	# patterns flow continuously across the neck. secondary_color now serves only as
	# the head-appendage / eye-stalk accent.
	var body_mat := TMF.make_body_material(parameters)
	var secondary_mat := TMF.make_surface(param_color("secondary_color", "#d8fbff"), 0.2, 0.5)
	var fin_mat := TMF.make_fin_material(parameters)
	var eye_mat := TMF.make_dark("#10161a")

	var body_length := param_float("body_length", 1.45)
	var body_height := param_float("body_height", 0.58)
	var body_width := param_float("body_width", 0.34)
	var body_profile := BodyProfileScript.ensure_body_profile(parameters)
	parameters["body_profile"] = body_profile
	selected_body_ring_id = String(parameters.get("selected_body_ring_id", selected_body_ring_id))
	var rings: Array = body_profile.get("rings", [])
	var mid_ring := _ring_by_id(rings, "mid_body", 3)
	var head_ring := _ring_by_id(rings, "head", 1)
	var midbody_depth_scale := maxf((float(mid_ring.get("upper_height", 0.46)) + float(mid_ring.get("lower_height", 0.42))) * 0.5 / 0.46, 0.1)
	var head_depth_scale := maxf((float(head_ring.get("upper_height", 0.42)) + float(head_ring.get("lower_height", 0.36))) * 0.5 / 0.42, 0.1)
	var body_z_scale := maxf(float(mid_ring.get("width", 0.38)) / 0.38, 0.1)
	var head_width_boost := maxf(float(head_ring.get("width", 0.34)) / 0.34, 0.35)
	var head_size := param_float("head_size", 0.44)
	var head_offset := param_float("head_offset", -0.58)
	var tail_length := param_float("tail_length", 0.78)
	var tail_fin_size := param_float("tail_fin_size", 0.46)
	var eye_size := param_float("eye_size", 0.055)
	var shell_expand := param_float("shell_expand", 0.08)

	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	_build_shell_profile_from_rings(rings, body_length, body_height, body_width, body_z_scale, head_offset, head_size, tail_length, shell_expand)

	if param_float("shell_enabled", 1.0) > 0.5:
		outer_shell = PF.fish_outer_shell("OuterShell", shell_profile, body_mat, shell_segments, PackedFloat32Array(shell_center_y_offsets), PackedFloat32Array(shell_radius_half_diff))
		body_pivot.add_child(outer_shell)

	var head_scale := _head_scale_for_shape(String(parameters.get("head_shape", "rounded")), head_size, body_height * head_depth_scale, body_width * body_z_scale * head_width_boost)
	var head_shape := String(parameters.get("head_shape", "rounded"))
	var snout_len := param_float("snout_length", 0.0)
	var forehead_slope := param_float("forehead_slope", 0.35)
	
	var head_mat := body_mat.duplicate() as ShaderMaterial
	head_mat.set_shader_parameter("is_head", true)
	
	head_node = PF.deformed_head("Head", head_shape, head_scale, snout_len, forehead_slope, head_mat, _head_sculpt_params())
	head_node.position = Vector3(head_offset, _sample_shell_center_y_at_x(head_offset), 0.0)
	body_pivot.add_child(head_node)
	_add_head_features(head_node, secondary_mat)

	dorsal_fin = _build_median_fin(
		"DorsalFin1",
		"dorsal",
		String(parameters.get("dorsal_1_shape", "single")),
		param_float("dorsal_1_length", 0.42),
		param_float("dorsal_1_height", param_float("dorsal_fin_size", 0.28)),
		param_float("dorsal_1_attach_t", 0.45),
		0.035,
		fin_mat
	)
	dorsal_base_position = _surface_position("dorsal", param_float("dorsal_1_attach_t", 0.45), 0.035)
	dorsal_fin.position = dorsal_base_position
	dorsal_fin.rotation_degrees.z = _surface_tangent_angle_degrees("dorsal", param_float("dorsal_1_attach_t", 0.45))
	body_pivot.add_child(dorsal_fin)

	if param_float("dorsal_2_enabled", 0.0) > 0.5:
		dorsal_2_fin = _build_median_fin(
			"DorsalFin2",
			"dorsal",
			String(parameters.get("dorsal_2_shape", "single")),
			param_float("dorsal_2_length", 0.34),
			param_float("dorsal_2_height", 0.18),
			param_float("dorsal_2_attach_t", 0.68),
			0.028,
			fin_mat
		)
		dorsal_2_base_position = _surface_position("dorsal", param_float("dorsal_2_attach_t", 0.68), 0.028)
		dorsal_2_fin.position = dorsal_2_base_position
		dorsal_2_fin.rotation_degrees.z = _surface_tangent_angle_degrees("dorsal", param_float("dorsal_2_attach_t", 0.68))
		body_pivot.add_child(dorsal_2_fin)

	anal_fin = _build_median_fin(
		"AnalFin",
		"ventral",
		String(parameters.get("anal_shape", "long")),
		param_float("anal_length", 0.36),
		param_float("anal_height", param_float("anal_fin_size", 0.2)),
		param_float("anal_attach_t", 0.64),
		0.03,
		fin_mat
	)
	anal_base_position = _surface_position("ventral", param_float("anal_attach_t", 0.64), 0.03)
	anal_fin.position = anal_base_position
	anal_fin.rotation_degrees.z = _surface_tangent_angle_degrees("ventral", param_float("anal_attach_t", 0.64))
	body_pivot.add_child(anal_fin)

	if param_float("pelvic_enabled", 0.0) > 0.5:
		var pelvic_shape := String(parameters.get("pelvic_shape", "triangle"))
		var pelvic_length := param_float("pelvic_length", 0.22)
		var pelvic_height := param_float("pelvic_height", 0.14)
		if pelvic_shape == "oval":
			pelvic_base_points = PF.oval_fin_points(pelvic_length, pelvic_height)
			pelvic_l = PF.oval_fin("PelvicFinL", pelvic_length, pelvic_height, fin_mat)
			pelvic_r = PF.oval_fin("PelvicFinR", pelvic_length, pelvic_height, fin_mat)
		else:
			var points_l := _get_fin_points("PelvicFinL", pelvic_shape, pelvic_length, pelvic_height)
			var points_r := _get_fin_points("PelvicFinR", pelvic_shape, pelvic_length, pelvic_height)
			var inverted_l := PackedVector3Array()
			for p in points_l:
				inverted_l.append(Vector3(p.x, -p.y, p.z))
			var inverted_r := PackedVector3Array()
			for p in points_r:
				inverted_r.append(Vector3(p.x, -p.y, p.z))
			pelvic_base_points = inverted_l
			pelvic_l = PF.polygon_fin("PelvicFinL", inverted_l, fin_mat)
			pelvic_r = PF.polygon_fin("PelvicFinR", inverted_r, fin_mat)
		var pelvic_attach_t := param_float("pelvic_attach_t", 0.36)
		var pelvic_center := _surface_position("ventral", pelvic_attach_t, 0.02)
		var pelvic_z := _surface_radius_z(pelvic_attach_t) * 0.32
		pelvic_l_base_position = pelvic_center + Vector3(0.0, 0.0, -pelvic_z)
		pelvic_r_base_position = pelvic_center + Vector3(0.0, 0.0, pelvic_z)
		pelvic_l.position = pelvic_l_base_position
		pelvic_r.position = pelvic_r_base_position
		var pelvic_surface_angle := _surface_tangent_angle_degrees("ventral", pelvic_attach_t)
		pelvic_l.rotation_degrees = Vector3(0.0, 12.0, pelvic_surface_angle)
		pelvic_r.rotation_degrees = Vector3(0.0, -12.0, pelvic_surface_angle)
		body_pivot.add_child(pelvic_l)
		body_pivot.add_child(pelvic_r)

	var pectoral_size := param_float("pectoral_fin_size", 0.16)
	var pectoral_shape := String(parameters.get("pectoral_shape", "oval"))
	if pectoral_shape == "oval":
		pectoral_base_points = PF.oval_fin_points(pectoral_size, pectoral_size * 0.5)
		pectoral_l = PF.oval_fin("PectoralFinL", pectoral_size, pectoral_size * 0.5, fin_mat)
	else:
		var points_l := _get_fin_points("PectoralFinL", pectoral_shape, pectoral_size, pectoral_size * 0.5)
		pectoral_base_points = points_l
		pectoral_l = PF.polygon_fin("PectoralFinL", points_l, fin_mat)
	var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
	var pectoral_center := _surface_position("side", pectoral_attach_t, 0.0)
	pectoral_l_base_position = Vector3(pectoral_center.x, -0.02, -_surface_radius_z(pectoral_attach_t) - shell_expand * 0.18)
	pectoral_l.position = pectoral_l_base_position
	var pectoral_surface_angle := _surface_tangent_angle_degrees("center", pectoral_attach_t)
	pectoral_l_base_rotation = Vector3(0.0, 25.0, -28.0 + pectoral_surface_angle)
	pectoral_l.rotation_degrees = pectoral_l_base_rotation
	body_pivot.add_child(pectoral_l)

	if pectoral_shape == "oval":
		pectoral_r = PF.oval_fin("PectoralFinR", pectoral_size, pectoral_size * 0.5, fin_mat)
	else:
		var points_r := _get_fin_points("PectoralFinR", pectoral_shape, pectoral_size, pectoral_size * 0.5)
		pectoral_r = PF.polygon_fin("PectoralFinR", points_r, fin_mat)
	pectoral_r_base_position = Vector3(pectoral_center.x, -0.02, _surface_radius_z(pectoral_attach_t) + shell_expand * 0.18)
	pectoral_r.position = pectoral_r_base_position
	pectoral_r_base_rotation = Vector3(0.0, -25.0, -28.0 + pectoral_surface_angle)
	pectoral_r.rotation_degrees = pectoral_r_base_rotation
	body_pivot.add_child(pectoral_r)
	_apply_fin_offsets()

	_add_eyes(eye_mat, secondary_mat, head_node.position, head_scale, eye_size)

	tail_pivot_1 = Node3D.new()
	tail_pivot_1.name = "TailPivot1"
	var tail_pivot_1_y := _sample_shell_center_y_at_x(shell_tail_pivot_1_x)
	tail_pivot_1.position = Vector3(shell_tail_pivot_1_x, tail_pivot_1_y, 0.0)
	body_pivot.add_child(tail_pivot_1)

	tail_pivot_2 = Node3D.new()
	tail_pivot_2.name = "TailPivot2"
	var tail_pivot_2_y := _sample_shell_center_y_at_x(shell_tail_pivot_2_x)
	tail_pivot_2.position = Vector3(shell_tail_pivot_2_x - shell_tail_pivot_1_x, tail_pivot_2_y - tail_pivot_1_y, 0.0)
	tail_pivot_1.add_child(tail_pivot_2)

	tail_fin_pivot = Node3D.new()
	tail_fin_pivot.name = "TailFinPivot"
	tail_fin_pivot.position = Vector3.ZERO
	tail_pivot_2.add_child(tail_fin_pivot)

	tail_fin_base_points = _get_caudal_fin_points(String(parameters.get("caudal_shape", "forked_shallow")), tail_fin_size, tail_fin_size * param_float("caudal_height_scale", 0.72))
	
	# Align caudal fin root vertices (x == 0.0) with the tail stem vertical radius of the body
	var stem_radius_y := 0.04
	if not shell_profile.is_empty():
		stem_radius_y = shell_profile.back().y
	var adjusted_points := PackedVector3Array()
	for p in tail_fin_base_points:
		var new_p := p
		if is_zero_approx(p.x):
			if p.y > 0.0:
				new_p.y = stem_radius_y
			elif p.y < 0.0:
				new_p.y = -stem_radius_y
		adjusted_points.append(new_p)
	tail_fin_base_points = adjusted_points

	tail_fin = PF.polygon_fin("TailFin", tail_fin_base_points, fin_mat)
	tail_fin_pivot.add_child(tail_fin)
	_update_body_ring_world_points()
	if ring_editor_enabled or param_float("show_ring_guides", 0.0) > 0.5:
		_add_ring_guides()

func set_ring_editor_enabled(enabled: bool) -> void:
	ring_editor_enabled = enabled
	rebuild()

func set_selected_body_ring(ring_id: String) -> void:
	selected_body_ring_id = ring_id
	parameters["selected_body_ring_id"] = ring_id
	rebuild()

func get_body_ring_global_points() -> Dictionary:
	_update_body_ring_world_points()
	return body_ring_world_points.duplicate(true)

func _build_shell_profile_from_rings(rings: Array, body_length: float, body_height: float, body_width: float, body_z_scale: float, head_offset: float, head_size: float, tail_length: float, shell_expand: float) -> void:
	shell_profile = []
	shell_center_y_offsets = []
	shell_radius_half_diff = []
	shell_ring_ids = []
	if rings.is_empty():
		rings = BodyProfileScript.default_fish_rings()
	var head_shell := _head_shell_metrics(rings, body_height, body_width, body_z_scale, head_offset, head_size, shell_expand)
	var start_x := float(head_shell["start_x"])
	var end_x := body_length * 0.48
	head_shell["end_x"] = end_x
	for i in rings.size():
		var ring: Dictionary = BodyProfileScript.normalize_ring(rings[i], i)
		var radius_y := body_height * (float(ring["upper_height"]) + float(ring["lower_height"])) * 0.5 + shell_expand * lerpf(1.0, 0.22, float(ring["x"]))
		var center_y := body_height * (float(ring["y_offset"]) + (float(ring["upper_height"]) - float(ring["lower_height"])) * 0.5)
		var ring_id := String(ring.get("id", ""))
		if ring_id == "snout" or ring_id == "head":
			center_y += 0.02
		var radius_z := body_width * body_z_scale * float(ring["width"]) * lerpf(0.62, 1.0, float(ring["roundness"])) + shell_expand * lerpf(1.0, 0.18, float(ring["x"]))
		var adjusted := _apply_head_shell_metrics(ring, radius_y, radius_z, head_shell)
		radius_y = float(adjusted["radius_y"])
		radius_z = float(adjusted["radius_z"])
		center_y += float(adjusted.get("center_y_delta", 0.0))
		shell_profile.append(Vector3(lerpf(start_x, end_x, float(ring["x"])), radius_y, radius_z))
		shell_center_y_offsets.append(center_y)
		# Asymmetry magnitude for the egg cross-section. center_y already carries the same
		# (upper-lower)/2 shift, so the mesh recovers the true centerline as center_y - this.
		shell_radius_half_diff.append(body_height * (float(ring["upper_height"]) - float(ring["lower_height"])) * 0.5)
		shell_ring_ids.append(String(ring.get("id", "ring_%d" % i)))
	shell_tail_pivot_1_x = _ring_x_by_id("rear_body", body_length * 0.48)
	shell_tail_pivot_2_x = _ring_x_by_id("tail_stem", shell_tail_pivot_1_x + tail_length * 0.5)

func _head_shell_metrics(rings: Array, body_height: float, body_width: float, body_z_scale: float, head_offset: float, head_size: float, shell_expand: float) -> Dictionary:
	var head_ring := _ring_by_id(rings, "head", mini(1, rings.size() - 1))
	var head_depth_scale := maxf((float(head_ring.get("upper_height", 0.42)) + float(head_ring.get("lower_height", 0.36))) * 0.5 / 0.42, 0.1)
	var head_width_boost := maxf(float(head_ring.get("width", 0.34)) / 0.34, 0.35)
	var shape := String(parameters.get("head_shape", "rounded"))
	var head_scale := _head_scale_for_shape(shape, head_size, body_height * head_depth_scale, body_width * body_z_scale * head_width_boost)
	var start_x := head_offset - head_scale.x * 0.22
	var sculpt := _head_sculpt_params()
	return {
		"shape": shape,
		"head_scale": head_scale,
		"head_offset": head_offset,
		"forehead_slope": param_float("forehead_slope", 0.35),
		"snout_length": param_float("snout_length", 0.0),
		"snout_base": float(sculpt["snout_base"]),
		"snout_thickness": float(sculpt["snout_thickness"]),
		"snout_taper": float(sculpt["snout_taper"]),
		"head_top_curve": float(sculpt["head_top_curve"]),
		"head_top_peak": float(sculpt["head_top_peak"]),
		"head_belly_curve": float(sculpt["head_belly_curve"]),
		"head_bump_height": float(sculpt["head_bump_height"]),
		"head_bump_pos": float(sculpt["head_bump_pos"]),
		"head_bump_width": float(sculpt["head_bump_width"]),
		"head_bump_round": float(sculpt["head_bump_round"]),
		"head_bump_angle": float(sculpt["head_bump_angle"]),
		"shell_expand": shell_expand,
		"start_x": start_x,
		"radius_y": maxf(head_scale.y * 0.5 + shell_expand * 0.72, 0.04),
		"radius_z": maxf(head_scale.z * 0.5 + shell_expand * 0.72, 0.035),
	}

func _get_head_contour_radius(x_local_unscaled: float, shape: String, forehead_slope: float, snout_length: float, snout_base: float = HeadProfile.SNOUT_BLEND_HALF, snout_thickness: float = 1.0, snout_taper: float = 0.0) -> Vector2:
	var x := clampf(x_local_unscaled, -0.499 - snout_length, 0.499)
	var x_base := x
	if shape != "cephalofoil":
		x_base = HeadProfile.snout_base_x(snout_length, x, snout_base)

	x_base = clampf(x_base, -0.499, 0.499)
	var sin_phi := sqrt(1.0 - 4.0 * x_base * x_base)
	var y_deformed := 0.5 * sin_phi
	var z_deformed := 0.5 * sin_phi

	if shape == "cephalofoil":
		z_deformed *= (1.0 + sin_phi * HeadProfile.CEPHALOFOIL_Z_GAIN)
		y_deformed *= HeadProfile.CEPHALOFOIL_Y_SCALE
	else:
		var u := x_base + 0.5
		if x_base < 0.0:
			var taper := HeadProfile.taper_factor(shape, u)
			var snout_r := HeadProfile.snout_radial_scale(snout_length, u, snout_base, snout_thickness, snout_taper)
			y_deformed *= taper * snout_r
			z_deformed *= taper * snout_r

		if x_base < 0.1:
			var hump_weight := sin_phi * (1.0 - u)
			var hump_height := HeadProfile.hump_height(forehead_slope)
			if shape == "hump":
				y_deformed += 0.5 * hump_weight * hump_height
			elif shape == "steep_forehead":
				y_deformed += 0.5 * hump_weight * hump_height * HeadProfile.STEEP_FOREHEAD_SCALE

		if shape == "flattened":
			y_deformed *= HeadProfile.FLATTEN_CONTOUR_FACTOR

	return Vector2(y_deformed, z_deformed)

func _apply_head_shell_metrics(ring: Dictionary, radius_y: float, radius_z: float, metrics: Dictionary) -> Dictionary:
	var shape := String(metrics.get("shape", "rounded"))
	var head_scale: Vector3 = metrics.get("head_scale", Vector3.ONE)
	var head_offset: float = float(metrics.get("head_offset", 0.0))
	var forehead_slope: float = float(metrics.get("forehead_slope", 0.35))
	var snout_length: float = float(metrics.get("snout_length", 0.0))
	var shell_expand: float = float(metrics.get("shell_expand", 0.08))
	var start_x: float = float(metrics.get("start_x", 0.0))
	var end_x: float = float(metrics.get("end_x", 0.0))
	
	var ring_x := float(ring["x"])
	var ring_x_world := lerpf(start_x, end_x, ring_x)
	var x_local_unscaled := (ring_x_world - head_offset) / head_scale.x
	
	if x_local_unscaled >= 0.5:
		return {"radius_y": radius_y, "radius_z": radius_z, "center_y_delta": 0.0}

	var snout_base: float = float(metrics.get("snout_base", HeadProfile.SNOUT_BLEND_HALF))
	var contour := _get_head_contour_radius(x_local_unscaled, shape, forehead_slope, snout_length, snout_base, float(metrics.get("snout_thickness", 1.0)), float(metrics.get("snout_taper", 0.0)))

	var r_head_y := head_scale.y * contour.x
	var r_head_z := head_scale.z * contour.y

	var blend_factor := clampf((x_local_unscaled - (-0.22)) / (0.5 - (-0.22)), 0.0, 1.0)

	var exp_offset_y := lerpf(shell_expand * 0.15, shell_expand * lerpf(1.0, 0.22, ring_x), blend_factor)
	var exp_offset_z := lerpf(shell_expand * 0.15, shell_expand * lerpf(1.0, 0.18, ring_x), blend_factor)

	var target_y := lerpf(r_head_y, radius_y - shell_expand * lerpf(1.0, 0.22, ring_x), blend_factor) + exp_offset_y
	var target_z := lerpf(r_head_z, radius_z - shell_expand * lerpf(1.0, 0.18, ring_x), blend_factor) + exp_offset_z

	# Grow the shell asymmetrically so it encloses the continuous dorsal/ventral
	# profile and the crown bump near the head (the shell is a symmetric tube, so a
	# top-only bulge becomes a radius increase plus an upward center shift). Fades
	# into the body via head_weight so the trunk is untouched.
	var center_y_delta := 0.0
	if shape != "cephalofoil":
		var sx := clampf(HeadProfile.snout_base_x(snout_length, clampf(x_local_unscaled, -0.499 - snout_length, 0.499), snout_base), -0.499, 0.499)
		var s_sin := sqrt(maxf(1.0 - 4.0 * sx * sx, 0.0))
		var s_u := sx + 0.5
		var top_extra := head_scale.y * HeadProfile.dorsal_offset(s_u, s_sin, float(metrics.get("head_top_curve", 0.0)), float(metrics.get("head_top_peak", 0.35)))
		var bottom_extra := head_scale.y * HeadProfile.ventral_offset(s_u, s_sin, float(metrics.get("head_belly_curve", 0.0)), 0.45)
		var bump_v := head_scale.y * float(metrics.get("head_bump_height", 0.0)) * cos(deg_to_rad(float(metrics.get("head_bump_angle", 35.0)))) * HeadProfile.head_bump_falloff(sx, PI * 0.5, float(metrics.get("head_bump_pos", -0.2)), float(metrics.get("head_bump_width", 0.18)), float(metrics.get("head_bump_round", 0.6)))
		top_extra += maxf(bump_v, 0.0)
		var head_weight := 1.0 - blend_factor
		top_extra *= head_weight
		bottom_extra *= head_weight
		target_y += 0.5 * (top_extra + bottom_extra)
		center_y_delta = 0.5 * (top_extra - bottom_extra)
		# A concave profile (e.g. arowana's lowered top) shrinks target_y symmetrically,
		# but the head mesh only lowers its top - its bottom keeps the base radius and so
		# pokes through the now-too-thin shell ("head splits / inside shows" seam). Stop the
		# shell from shrinking below the un-profiled head contour so it still encloses the
		# rigid head. This is a floor (never grows past the head's natural size) so it does
		# NOT fatten the head or create a head/body step; it only cancels the over-shrink.
		target_y = maxf(target_y, r_head_y + exp_offset_y)

	return {
		"radius_y": maxf(target_y, 0.035),
		"radius_z": maxf(target_z, 0.03),
		"center_y_delta": center_y_delta
	}

func _add_ring_guides() -> void:
	var guide_root := Node3D.new()
	guide_root.name = "BodyRingGuides"
	body_pivot.add_child(guide_root)
	var guide_mat := TMF.make_surface(Color.html("#f6d365"), 0.2, 0.65)
	var selected_mat := TMF.make_surface(Color.html("#ff4d6d"), 0.18, 0.75)
	var endpoint_mat := TMF.make_surface(Color.html("#f8f9fa"), 0.12, 0.55)
	for i in shell_profile.size():
		var ring_id := shell_ring_ids[i] if i < shell_ring_ids.size() else ""
		var selected := ring_id == selected_body_ring_id
		var center_y := shell_center_y_offsets[i] if i < shell_center_y_offsets.size() else 0.0
		var point := shell_profile[i]
		var center := PF.ellipsoid("RingCenter_%s" % ring_id, Vector3(0.035, 0.035, 0.035), selected_mat if selected else guide_mat)
		center.position = Vector3(point.x, center_y, -point.z - 0.03)
		guide_root.add_child(center)
		var top := PF.ellipsoid("RingTop_%s" % ring_id, Vector3(0.02, 0.02, 0.02), selected_mat if selected else endpoint_mat)
		top.position = Vector3(point.x, center_y + point.y, -point.z - 0.03)
		guide_root.add_child(top)
		var bottom := PF.ellipsoid("RingBottom_%s" % ring_id, Vector3(0.02, 0.02, 0.02), selected_mat if selected else endpoint_mat)
		bottom.position = Vector3(point.x, center_y - point.y, -point.z - 0.03)
		guide_root.add_child(bottom)
		var label := Label3D.new()
		label.name = "RingLabel_%s" % ring_id
		label.text = _ring_label_by_id(ring_id, "Ring")
		label.font_size = 18
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(point.x, center_y + point.y + 0.08, -point.z - 0.04)
		guide_root.add_child(label)

func _update_body_ring_world_points() -> void:
	body_ring_world_points.clear()
	if body_pivot == null:
		return
	for i in shell_profile.size():
		var ring_id := shell_ring_ids[i] if i < shell_ring_ids.size() else "ring_%d" % i
		var center_y := shell_center_y_offsets[i] if i < shell_center_y_offsets.size() else 0.0
		body_ring_world_points[ring_id] = body_pivot.to_global(Vector3(shell_profile[i].x, center_y, 0.0))

func _ring_by_id(rings: Array, ring_id: String, fallback_index: int) -> Dictionary:
	for ring in rings:
		if String(ring.get("id", "")) == ring_id:
			return ring
	if rings.is_empty():
		return BodyProfileScript.default_fish_rings()[0]
	return rings[clampi(fallback_index, 0, rings.size() - 1)]

func _ring_label_by_id(ring_id: String, fallback: String) -> String:
	for ring in BodyProfileScript.ensure_body_profile(parameters).get("rings", []):
		if String(ring.get("id", "")) == ring_id:
			return String(ring.get("label", fallback))
	return fallback

func _ring_x_by_id(ring_id: String, fallback: float) -> float:
	for i in shell_ring_ids.size():
		if shell_ring_ids[i] == ring_id:
			return shell_profile[i].x
	return fallback

func _ring_sway_weight(ring_id: String, fallback: float) -> float:
	for ring in BodyProfileScript.ensure_body_profile(parameters).get("rings", []):
		if String(ring.get("id", "")) == ring_id:
			return float(ring.get("sway_weight", fallback))
	return fallback

func apply_pose(loop_phase: float) -> void:
	var wave := sin(loop_phase * TAU)
	var delayed := sin(loop_phase * TAU - param_float("phase_delay", 0.65))
	position.y = wave * param_float("idle_bob_amount", 0.035)
	var global_sway := param_float("global_sway_amount", param_float("body_sway_amount", 3.0))
	var tail_multiplier := param_float("tail_sway_multiplier", 1.0)
	var tail_stem_weight := _ring_sway_weight("tail_stem", 1.0)
	
	var turn_amount := clampf(param_float("turn_amount", 0.0), 0.0, 1.0)
	var turn_phase := clampf(param_float("turn_phase", 0.0), 0.0, 1.0)
	var roll_turn := turn_amount
	if turn_amount > 0.001 and turn_phase > 0.001:
		roll_turn = sin(PI * pow(turn_phase, 0.33))
		
	var turn_direction := _turn_direction()
	var roll_angle := turn_direction * roll_turn * param_float("turn_bank_roll", 10.0)
	
	if body_pivot:
		body_pivot.rotation_degrees = Vector3(roll_angle, 0.0, 0.0)
	if tail_pivot_1:
		tail_pivot_1.rotation_degrees.y = delayed * global_sway * tail_multiplier * _ring_sway_weight("rear_body", 0.65)
	if tail_pivot_2:
		tail_pivot_2.rotation_degrees.y = sin(loop_phase * TAU - param_float("phase_delay", 0.65) * 1.8) * global_sway * tail_multiplier * tail_stem_weight
	if tail_fin_pivot:
		var direct_tail_yaw := sin(loop_phase * TAU - param_float("phase_delay", 0.65) * 2.4) * global_sway * tail_multiplier * tail_stem_weight * 1.25
		tail_fin_pivot.rotation_degrees.y = direct_tail_yaw
		# When the body shell drives the rig, _apply_animated_tail re-poses the caudal
		# fin below; only deform here in the shell-less fallback to avoid doing it twice.
		if outer_shell == null or shell_profile.is_empty():
			_animate_caudal_fin(loop_phase, direct_tail_yaw)
	if pectoral_l:
		pectoral_l.rotation_degrees = pectoral_l_base_rotation
	if pectoral_r:
		pectoral_r.rotation_degrees = pectoral_r_base_rotation
	_deform_shell(loop_phase)

func _deform_shell(loop_phase: float) -> void:
	if outer_shell == null or shell_profile.is_empty():
		return
	var phase_delay := param_float("phase_delay", 0.65)
	var global_sway := param_float("global_sway_amount", param_float("body_sway_amount", 3.0))
	var body_wave_amount := param_float("body_wave_amount", 0.35)
	var effective_body_wave_amount := _response_limited_amount(body_wave_amount, param_float("body_wave_response_scale", 100.0))
	var body_wave_yaw_limit := param_float("body_wave_yaw_limit", 55.0)
	var body_wave_start := clampf(param_float("body_wave_start", 0.16), 0.0, 1.0)
	var body_wave_falloff := maxf(param_float("body_wave_falloff", 0.75), 0.05)
	var tail_multiplier := param_float("tail_sway_multiplier", 1.0)
	var tail_1_yaw := sin(loop_phase * TAU - phase_delay) * global_sway * tail_multiplier * _ring_sway_weight("rear_body", 0.65)
	var tail_2_yaw := sin(loop_phase * TAU - phase_delay * 1.8) * global_sway * tail_multiplier * _ring_sway_weight("tail_stem", 1.0)
	var turn_amount := clampf(param_float("turn_amount", 0.0), 0.0, 1.0)
	var turn_direction := _turn_direction()
	var turn_tail_lag := clampf(param_float("turn_tail_lag", 0.65), 0.0, 1.5)
	
	var yaws_only_turn := PackedFloat32Array()
	for ring_index in shell_profile.size():
		var t := float(ring_index) / maxf(float(shell_profile.size() - 1), 1.0)
		yaws_only_turn.append(_turn_ring_yaw(t, turn_amount, turn_direction, turn_tail_lag))
		
	var turn_offsets := PackedFloat32Array()
	turn_offsets.resize(shell_profile.size())
	turn_offsets[0] = 0.0
	for i in range(1, shell_profile.size()):
		var prev_x := shell_profile[i-1].x
		var curr_x := shell_profile[i].x
		var segment_len := curr_x - prev_x
		var avg_yaw := (yaws_only_turn[i-1] + yaws_only_turn[i]) * 0.5
		turn_offsets[i] = turn_offsets[i-1] - sin(deg_to_rad(avg_yaw)) * segment_len
		
	var centers := PackedVector3Array()
	var yaws := PackedFloat32Array()
	for ring_index in shell_profile.size():
		var t := float(ring_index) / maxf(float(shell_profile.size() - 1), 1.0)
		var point := shell_profile[ring_index]
		var bend := _tail_bent_center_and_yaw(point.x, tail_1_yaw, tail_2_yaw)
		var center: Vector3 = bend["center"]
		var ring_id := shell_ring_ids[ring_index] if ring_index < shell_ring_ids.size() else ""
		var ring_weight := _ring_sway_weight(ring_id, t)
		var body_distribution := _body_wave_distribution(t, body_wave_start, body_wave_falloff)
		var raw_ring_yaw := sin(loop_phase * TAU - float(ring_index) * phase_delay) * global_sway * ring_weight * effective_body_wave_amount * body_distribution
		var ring_yaw := _soft_limit_yaw(raw_ring_yaw, body_wave_yaw_limit)
		var turn_yaw := yaws_only_turn[ring_index]
		var yaw: float = bend["yaw"] + ring_yaw + turn_yaw
		center.z += sin(loop_phase * TAU - float(ring_index) * phase_delay) * 0.012 * effective_body_wave_amount * body_distribution
		center.z += turn_offsets[ring_index]
		centers.append(center)
		yaws.append(yaw)

	# Align snout and head rings of the body shell to rotate and translate exactly with the head node's kinematic system
	var head_offset := param_float("head_offset", -0.58)
	var attach_t := _shell_attach_t_for_x(head_offset)
	var yaw_head := _sample_animated_shell_yaw(attach_t, yaws)
	var head_center := _sample_animated_shell_center(attach_t, centers)
	var basis_head := Basis(Vector3.UP, deg_to_rad(yaw_head))
	for i in range(2):
		if i < centers.size():
			# head_center already includes the interpolated shell_center_y_offset, but the
			# per-ring offset is re-added downstream (mesh builder + _animated_ring_center).
			# Preserve each ring's raw y so the vertical offset is applied exactly once;
			# only the yaw rotation and x/z translation follow the head kinematics.
			var raw_y := centers[i].y
			var dx := shell_profile[i].x - head_offset
			centers[i] = head_center + basis_head * Vector3(dx, 0.0, 0.0)
			centers[i].y = raw_y
			yaws[i] = yaw_head

	PF.update_fish_outer_shell_bent(outer_shell, shell_profile, centers, yaws, shell_segments, PackedFloat32Array(shell_center_y_offsets), PackedFloat32Array(shell_radius_half_diff))
	animated_shell_centers = centers
	animated_shell_yaws = yaws
	_apply_animated_attachments(loop_phase, centers, yaws)
	_update_body_ring_world_points()

func _body_wave_distribution(t: float, start: float, falloff: float) -> float:
	if t <= start:
		return 0.0
	var normalized := clampf((t - start) / maxf(1.0 - start, 0.001), 0.0, 1.0)
	return pow(normalized, falloff)

func _turn_direction() -> float:
	var direction := param_float("turn_direction", 1.0)
	return -1.0 if direction < 0.0 else 1.0

func _turn_ring_yaw(t: float, turn_amount: float, turn_direction: float, tail_lag: float) -> float:
	if turn_amount <= 0.0:
		return 0.0
	var turn_phase := clampf(param_float("turn_phase", 0.0), 0.0, 1.0)
	var head_amount := turn_amount
	var tail_amount := turn_amount
	if turn_amount > 0.001 and turn_phase > 0.001:
		head_amount = turn_amount * sin(PI * pow(turn_phase, 0.4))
		tail_amount = turn_amount * sin(PI * pow(turn_phase, 1.4))
	var curve_bias := clampf(param_float("turn_curve_bias", 0.5), 0.0, 1.0)
	var head_yaw_limit := 24.0
	var tail_yaw_limit := -38.0
	var t_clamped := clampf(t, 0.0, 1.0)
	var head_factor := (1.0 - t_clamped) * (1.0 - t_clamped) * (1.0 + curve_bias)
	var tail_factor := t_clamped * t_clamped * tail_lag
	return turn_direction * (head_yaw_limit * head_factor * head_amount + tail_yaw_limit * tail_factor * tail_amount)

func _turn_ring_offset(_x: float, _turn_yaw: float) -> Vector3:
	return Vector3.ZERO

func _tail_bent_center_and_yaw(x: float, tail_1_yaw: float, tail_2_yaw: float) -> Dictionary:
	var pivot_1 := Vector3(shell_tail_pivot_1_x, 0.0, 0.0)
	if x <= shell_tail_pivot_1_x:
		return {"center": Vector3(x, 0.0, 0.0), "yaw": 0.0}
	var basis_1 := Basis(Vector3.UP, deg_to_rad(tail_1_yaw))
	if x <= shell_tail_pivot_2_x:
		return {
			"center": pivot_1 + basis_1 * Vector3(x - shell_tail_pivot_1_x, 0.0, 0.0),
			"yaw": tail_1_yaw
		}
	var pivot_2 := pivot_1 + basis_1 * Vector3(shell_tail_pivot_2_x - shell_tail_pivot_1_x, 0.0, 0.0)
	var basis_2 := Basis(Vector3.UP, deg_to_rad(tail_1_yaw + tail_2_yaw))
	return {
		"center": pivot_2 + basis_2 * Vector3(x - shell_tail_pivot_2_x, 0.0, 0.0),
		"yaw": tail_1_yaw + tail_2_yaw
	}

func _apply_animated_attachments(loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	_apply_animated_head(centers, yaws)
	_apply_animated_fins(loop_phase, centers, yaws)
	_apply_animated_tail(loop_phase, centers, yaws)

func _apply_animated_head(centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	if head_node == null:
		return
	var head_offset := param_float("head_offset", -0.58)
	var attach_t := _shell_attach_t_for_x(head_offset)
	var yaw := _sample_animated_shell_yaw(attach_t, yaws)
	var center := _sample_animated_shell_center(attach_t, centers)
	head_node.position = center
	head_node.rotation_degrees = Vector3(0.0, yaw, 0.0)
	_apply_animated_eyes(yaw)

func _apply_animated_eyes(yaw: float) -> void:
	if eye_l == null or eye_r == null:
		return
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var layout := _eye_layout()
	var anchor: Vector3 = layout["anchor"]
	var eye_center_z := float(layout["eye_center_z"])
	var stalk_inner := float(layout["stalk_inner"])
	var stalk_length := float(layout["stalk_length"])
	var eye_style := String(parameters.get("eye_style", "bead"))
	
	var theta := 0.0
	if eye_style == "celestial":
		theta = deg_to_rad(55.0)
		
	var dynamic_head_center := head_node.position
	var local_anchor := anchor - eye_head_center
	
	for side in [-1.0, 1.0]:
		var eye := eye_l if side < 0.0 else eye_r
		var v: Vector3 = Vector3(0.0, sin(theta), side * cos(theta))
		var rot_x: float = side * (90.0 - rad_to_deg(theta))
		
		var local_offset := local_anchor + v * eye_center_z
		eye.position = dynamic_head_center + basis * local_offset
		eye.rotation_degrees = Vector3(rot_x, yaw, 0.0)
		
	for stalk_side in [eye_stalk_l, eye_stalk_r]:
		if stalk_side == null:
			continue
		var side := -1.0 if stalk_side == eye_stalk_l else 1.0
		var v: Vector3 = Vector3(0.0, sin(theta), side * cos(theta))
		var rot_x: float = side * (90.0 - rad_to_deg(theta))
		
		var stalk_mesh := stalk_side.mesh as CylinderMesh
		if stalk_mesh:
			stalk_mesh.height = stalk_length
			var is_thick_stalk := eye_style == "telescope" or eye_style == "celestial"
			var r_bottom := eye_radius * 0.6 if is_thick_stalk else eye_radius * 0.34
			var r_top := eye_radius * 0.8 if is_thick_stalk else eye_radius * 0.34
			stalk_mesh.bottom_radius = r_bottom
			stalk_mesh.top_radius = r_top
			
		var local_offset := local_anchor + v * (stalk_inner + stalk_length * 0.5)
		stalk_side.position = dynamic_head_center + basis * local_offset
		stalk_side.rotation_degrees = Vector3(rot_x, yaw, 0.0)

func _apply_animated_fins(loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	if dorsal_fin:
		var dorsal_attach_t := param_float("dorsal_1_attach_t", 0.45)
		dorsal_fin.position = _animated_surface_position("dorsal", dorsal_attach_t, 0.035, 0.0, float(parameters.get("dorsal_fin_offset_x", 0.0)), centers, yaws)
		dorsal_fin.rotation_degrees = Vector3(_median_fin_flap(loop_phase), 0.0, _surface_tangent_angle_degrees("dorsal", dorsal_attach_t))
		_animate_median_fin(dorsal_fin, "dorsal", String(parameters.get("dorsal_1_shape", "single")), param_float("dorsal_1_length", 0.42), param_float("dorsal_1_height", param_float("dorsal_fin_size", 0.28)), dorsal_attach_t, 0.035, loop_phase, centers, yaws)
	if dorsal_2_fin:
		var dorsal_2_attach_t := param_float("dorsal_2_attach_t", 0.68)
		dorsal_2_fin.position = _animated_surface_position("dorsal", dorsal_2_attach_t, 0.028, 0.0, 0.0, centers, yaws)
		dorsal_2_fin.rotation_degrees = Vector3(_median_fin_flap(loop_phase, 0.12), 0.0, _surface_tangent_angle_degrees("dorsal", dorsal_2_attach_t))
		_animate_median_fin(dorsal_2_fin, "dorsal", String(parameters.get("dorsal_2_shape", "single")), param_float("dorsal_2_length", 0.34), param_float("dorsal_2_height", 0.18), dorsal_2_attach_t, 0.028, loop_phase, centers, yaws)
	if anal_fin:
		var anal_attach_t := param_float("anal_attach_t", 0.64)
		anal_fin.position = _animated_surface_position("ventral", anal_attach_t, 0.03, 0.0, float(parameters.get("anal_fin_offset_x", 0.0)), centers, yaws)
		anal_fin.rotation_degrees = Vector3(-_median_fin_flap(loop_phase, 0.5), 0.0, _surface_tangent_angle_degrees("ventral", anal_attach_t))
		_animate_median_fin(anal_fin, "ventral", String(parameters.get("anal_shape", "long")), param_float("anal_length", 0.36), param_float("anal_height", param_float("anal_fin_size", 0.2)), anal_attach_t, 0.03, loop_phase, centers, yaws)
	if pelvic_l and pelvic_r:
		var pelvic_attach_t := param_float("pelvic_attach_t", 0.36)
		var pelvic_z := _surface_radius_z(pelvic_attach_t) * 0.32
		var pelvic_yaw := _fin_follow_yaw(pelvic_attach_t, yaws)
		var pelvic_surface_angle := _surface_tangent_angle_degrees("ventral", pelvic_attach_t)
		pelvic_l.position = _animated_surface_position("ventral", pelvic_attach_t, 0.02, -pelvic_z, 0.0, centers, yaws)
		pelvic_r.position = _animated_surface_position("ventral", pelvic_attach_t, 0.02, pelvic_z, 0.0, centers, yaws)
		pelvic_l.rotation_degrees = Vector3(0.0, pelvic_yaw + 12.0, pelvic_surface_angle)
		pelvic_r.rotation_degrees = Vector3(0.0, pelvic_yaw - 12.0, pelvic_surface_angle)
		_animate_blade_fin(pelvic_l, pelvic_base_points, loop_phase, 0.0)
		_animate_blade_fin(pelvic_r, pelvic_base_points, loop_phase, PI)
	var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
	var pectoral_z := _surface_radius_z(pectoral_attach_t) + param_float("shell_expand", 0.08) * 0.18
	var pectoral_yaw := _fin_follow_yaw(pectoral_attach_t, yaws)
	var pectoral_surface_angle := _surface_tangent_angle_degrees("center", pectoral_attach_t)
	var p_sync := String(parameters.get("pectoral_flap_sync", "alternating"))
	# Fish pectoral fins are mirrored in transform space. A PI phase offset makes the
	# left/right fins read as visually synchronous; zero offset reads as alternating.
	# Ray wing sync uses a different surface-wave basis, so do not mirror this blindly.
	var right_phase_offset := PI if p_sync == "synchronous" else 0.0

	var pectoral_flap_l := sin(loop_phase * TAU * 2.0) * param_float("fin_flap_amount", param_float("pectoral_flap_amount", 10.0))
	var pectoral_flap_r := sin(loop_phase * TAU * 2.0 + right_phase_offset) * param_float("fin_flap_amount", param_float("pectoral_flap_amount", 10.0))
	var turn_amount := clampf(param_float("turn_amount", 0.0), 0.0, 1.0)
	var turn_phase := clampf(param_float("turn_phase", 0.0), 0.0, 1.0)
	var pectoral_turn := turn_amount
	if turn_amount > 0.001 and turn_phase > 0.001:
		pectoral_turn = sin(PI * pow(turn_phase, 0.33))
		
	var turn_direction := _turn_direction()
	var inside_fold := clampf(param_float("inside_pectoral_fold", 0.75), 0.0, 1.5) * pectoral_turn
	var outside_brace := clampf(param_float("outside_pectoral_brace", 0.5), 0.0, 1.5) * pectoral_turn
	
	var left_turn_bias := -inside_fold if turn_direction > 0.0 else outside_brace
	var right_turn_bias := outside_brace if turn_direction > 0.0 else -inside_fold
	
	var left_flap_scale := clampf(1.0 - (inside_fold if turn_direction > 0.0 else outside_brace), 0.0, 1.0)
	var right_flap_scale := clampf(1.0 - (outside_brace if turn_direction > 0.0 else inside_fold), 0.0, 1.0)
	
	var left_pectoral_flap := pectoral_flap_l * left_flap_scale
	var right_pectoral_flap := pectoral_flap_r * right_flap_scale
	
	var pectoral_offset := float(parameters.get("pectoral_fin_offset_x", 0.0))
	var pectoral_offset_y := param_float("pectoral_offset_y", 0.0)
	var p_yaw := param_float("pectoral_fin_yaw", 25.0)
	var p_pitch := param_float("pectoral_fin_pitch", 0.0)
	var p_roll := param_float("pectoral_fin_roll", -28.0)
	if pectoral_l:
		pectoral_l.position = _animated_side_position(pectoral_attach_t, -0.02 + pectoral_offset_y, -pectoral_z, pectoral_offset, centers, yaws)
		pectoral_l_base_rotation = Vector3(p_pitch, pectoral_yaw + p_yaw, p_roll + pectoral_surface_angle)
		pectoral_l.rotation_degrees = pectoral_l_base_rotation + Vector3(left_pectoral_flap + left_turn_bias * 24.0, left_turn_bias * 16.0, left_turn_bias * 20.0)
	if pectoral_r:
		pectoral_r.position = _animated_side_position(pectoral_attach_t, -0.02 + pectoral_offset_y, pectoral_z, pectoral_offset, centers, yaws)
		pectoral_r_base_rotation = Vector3(-p_pitch, pectoral_yaw - p_yaw, p_roll + pectoral_surface_angle)
		pectoral_r.rotation_degrees = pectoral_r_base_rotation + Vector3(right_pectoral_flap + right_turn_bias * 24.0, right_turn_bias * 16.0, right_turn_bias * 20.0)
	_animate_blade_fin(pectoral_l as MeshInstance3D, pectoral_base_points, loop_phase, 0.0)
	_animate_blade_fin(pectoral_r as MeshInstance3D, pectoral_base_points, loop_phase, right_phase_offset)

func _apply_animated_tail(loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	if tail_pivot_1 == null or tail_pivot_2 == null or tail_fin_pivot == null:
		return
	var rear_index := _ring_index_by_id("rear_body", maxi(shell_profile.size() - 2, 0))
	var stem_index := _ring_index_by_id("tail_stem", maxi(shell_profile.size() - 1, 0))
	var rear_center := _animated_ring_center(rear_index, centers)
	var stem_center := _animated_ring_center(stem_index, centers)
	var rear_yaw := _animated_ring_yaw(rear_index, yaws)
	var stem_yaw := _animated_ring_yaw(stem_index, yaws)
	var tail_body_wave_follow := clampf(param_float("tail_body_wave_follow", 0.45), 0.0, 1.0)
	var tail_root_yaw_limit := param_float("tail_root_yaw_limit", 70.0)
	var tail_joint_yaw_limit := param_float("tail_joint_yaw_limit", 55.0)
	var tail_fin_yaw_limit := param_float("tail_fin_yaw_limit", 42.0)
	tail_pivot_1.position = rear_center
	var limited_rear_yaw := _soft_limit_yaw(rear_yaw * tail_body_wave_follow, tail_root_yaw_limit)
	tail_pivot_1.rotation_degrees = Vector3(0.0, limited_rear_yaw, 0.0)
	tail_pivot_2.position = Basis(Vector3.UP, deg_to_rad(-limited_rear_yaw)) * (stem_center - rear_center)
	tail_pivot_2.rotation_degrees = Vector3(0.0, _soft_limit_yaw((stem_yaw - rear_yaw) * tail_body_wave_follow, tail_joint_yaw_limit), 0.0)
	var phase_delay := param_float("phase_delay", 0.65)
	var global_sway := param_float("global_sway_amount", param_float("body_sway_amount", 3.0))
	var tail_multiplier := param_float("tail_sway_multiplier", 1.0)
	var tail_stem_weight := _ring_sway_weight("tail_stem", 1.0)
	var tail_extra_swing := param_float("tail_fin_extra_swing", 0.45)
	var tail_fin_yaw := sin(loop_phase * TAU - phase_delay * 2.4) * global_sway * tail_multiplier * tail_stem_weight * tail_extra_swing
	tail_fin_pivot.position = Vector3.ZERO
	tail_fin_pivot.rotation_degrees = Vector3(0.0, _soft_limit_yaw(tail_fin_yaw, tail_fin_yaw_limit), 0.0)
	_animate_caudal_fin(loop_phase, tail_fin_yaw)

func _animate_caudal_fin(loop_phase: float, _tail_fin_yaw: float) -> void:
	if tail_fin == null or tail_fin_base_points.is_empty():
		return
	var softness := _effective_caudal_softness()
	# Rigid: leave the flat base mesh built in rebuild() untouched. Any parameter
	# change re-runs rebuild(), so the mesh can never be stuck in a deformed state.
	if softness <= 0.001:
		return
	var tail_size := maxf(param_float("tail_fin_size", 0.46), 0.001)
	# Lock the membrane to the tail's own swing phase so it trails the swing instead
	# of wriggling on its own clock.
	var drive_phase := loop_phase * TAU - param_float("phase_delay", 0.65) * 2.4
	var down_local := tail_fin.global_transform.basis.inverse() * Vector3.DOWN
	var res := _membrane_deformed_points(tail_fin_base_points, softness, drive_phase, _swim_drive_strength(), 0.0, tail_size, down_local)
	tail_fin.mesh = PF.build_polygon_fin_mesh(res.deformed, res.reference)

# Re-deforms a paired side fin (pectoral/pelvic) into a soft trailing membrane.
# Skips work entirely when the fin reads as rigid, preserving the original mesh.
func _animate_blade_fin(fin_node: MeshInstance3D, base_points: PackedVector3Array, loop_phase: float, phase_offset: float) -> void:
	if fin_node == null or base_points.is_empty():
		return
	var softness := _effective_fin_softness(_fin_name_to_slot(fin_node.name))
	if softness <= 0.001:
		return
	var max_x := -INF
	var min_x := INF
	for point in base_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	var size_ref := maxf(max_x - min_x, 0.001)
	# Paired fins scull at roughly double the body cadence; lock to that beat.
	var drive_phase := loop_phase * TAU * 2.0 + phase_offset
	var down_local := fin_node.global_transform.basis.inverse() * Vector3.DOWN
	var res := _membrane_deformed_points(base_points, softness, drive_phase, _swim_drive_strength(), 0.0, size_ref, down_local)
	fin_node.mesh = PF.build_polygon_fin_mesh(res.deformed, res.reference)

# How far the soft membrane trails, as a fraction of the fin's span, at full drive.
# Higher reads as a looser, more flowing fin (betta-tail style); 0 is a stiff blade.
const FIN_SOFT_AMPLITUDE := 0.58

# Static gravity sag (fraction of span) pulled toward world-down at the free tip, so a
# soft fin also hangs/droops a little, more as softness rises.
const FIN_SOFT_DROOP := 0.65

# Net strength of the swimming motion the fins should flow with. Near 0 when the fish
# is holding still (so fins settle), rising as it sways/swims harder. A small floor
# keeps a gentle drift for hovering fish like bettas.
func _swim_drive_strength() -> float:
	var global_sway := param_float("global_sway_amount", param_float("body_sway_amount", 3.0))
	var tail_multiplier := param_float("tail_sway_multiplier", 1.0)
	return clampf(0.12 + absf(global_sway * tail_multiplier) / 14.0, 0.0, 1.3)

# Trailing membrane bend: the tip lags the base by tip_t * lag, so the membrane curves
# from the difference between the rigid swing and the lagged tip — strongest as the
# motion crosses through center (fastest), easing at the swing extremes. This is what
# makes the fin look dragged through water rather than self-animated.
func _membrane_trail(drive_phase: float, tip_t: float, lag: float) -> float:
	return sin(drive_phase) - sin(drive_phase - tip_t * lag)

# Shared free-edge membrane deform. Subdivides the coarse outline so the trailing wave
# renders as smooth cloth, then displaces z with amplitude growing toward the trailing
# tip (+x) and free margin (|y|), scaled by how hard the fish is actually moving.
func _membrane_deformed_points(base_points: PackedVector3Array, softness: float, drive_phase: float, drive_strength: float, phase_offset: float, size_ref: float, down_local: Vector3) -> Dictionary:
	var outline := PF.subdivide_fin_outline(base_points, 8)
	var min_x := INF
	var max_x := -INF
	var max_abs_y := 0.001
	for point in outline:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		max_abs_y = maxf(max_abs_y, absf(point.y))
	var x_span := maxf(max_x - min_x, 0.001)
	var lag := 0.6 + softness * 5.2
	var deformed := PackedVector3Array()
	for point in outline:
		var tip_t := clampf((point.x - min_x) / x_span, 0.0, 1.0)
		var edge_norm := clampf(point.y / max_abs_y, -1.0, 1.0)
		var membrane_weight := 0.4 + 0.6 * absf(edge_norm)
		var trail := _membrane_trail(drive_phase + phase_offset, tip_t, lag)
		var z := FIN_SOFT_AMPLITUDE * drive_strength * trail * size_ref * softness * pow(tip_t, 1.05) * membrane_weight
		var sag := FIN_SOFT_DROOP * softness * pow(tip_t, 1.1) * size_ref
		var sag_offset := Vector3(0.0, down_local.y, down_local.z) * sag
		
		# Keep physical length strictly conserved relative to root (origin)
		var r := point.length()
		if r > 0.0001:
			var v_dir := Vector3(point.x, point.y + sag_offset.y, point.z + z + sag_offset.z)
			deformed.append(v_dir.normalized() * r)
		else:
			deformed.append(point)
			
	return {"deformed": deformed, "reference": outline}

func _effective_caudal_softness() -> float:
	return _effective_fin_softness("caudal")

# Per-fin softness, with the global fin_softness/fin_rigidity acting as the default
# when a slot has no explicit override. Returns the net softness after rigidity damping.
func _effective_fin_softness(slot: String) -> float:
	var base_softness := clampf(param_float("fin_softness", 0.0), 0.0, 1.0)
	var base_rigidity := clampf(param_float("fin_rigidity", 0.0), 0.0, 1.0)
	var softness := clampf(float(parameters.get("%s_softness" % slot, base_softness)), 0.0, 1.0)
	var rigidity := clampf(float(parameters.get("%s_rigidity" % slot, base_rigidity)), 0.0, 1.0)
	return softness * (1.0 - rigidity)

func _fin_follow_yaw(attach_t: float, yaws: PackedFloat32Array) -> float:
	return _sample_animated_shell_yaw(attach_t, yaws) * param_float("fin_yaw_follow_strength", 0.25)

func _soft_limit_yaw(value: float, limit: float) -> float:
	var safe_limit := maxf(absf(limit), 0.001)
	return tanh(value / safe_limit) * safe_limit

func _response_limited_amount(value: float, response_scale: float) -> float:
	var safe_scale := maxf(absf(response_scale), 0.001)
	var direction := -1.0 if value < 0.0 else 1.0
	return direction * safe_scale * log(1.0 + absf(value) / safe_scale)

func _median_fin_wave_tilt_amount() -> float:
	var body_wave := _response_limited_amount(param_float("body_wave_amount", 0.35), param_float("median_fin_wave_response_scale", 4.0))
	var raw_tilt := param_float("median_fin_wave_amount", 0.3) * body_wave
	return _soft_limit_yaw(raw_tilt, param_float("median_fin_wave_tilt_limit", 0.24))

# Median fins (dorsal/anal) move with the body by re-deforming their mesh each
# frame: the base stays embedded on the contour and the free edge ripples with
# the body wave, instead of the whole blade rigidly rotating about its root.
func _animate_median_fin(fin_node: MeshInstance3D, side: String, shape: String, length: float, height: float, attach_t: float, margin: float, loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	var points := _get_fin_points(fin_node.name, shape, length, height)
	var follow := clampf(param_float("fin_curve_follow", 1.0), 0.0, 1.0)
	fin_node.mesh = PF.build_polygon_fin_mesh(_animated_curved_fin_points(fin_node, side, attach_t, margin, points, follow, loop_phase, centers, yaws))

func _median_fin_flap(loop_phase: float, phase_offset: float = 0.0) -> float:
	var flap_amount := param_float("median_fin_flap_amount", 1.5)
	var flap_phase := param_float("median_fin_flap_phase", 0.5)
	return sin(loop_phase * TAU * 2.0 - (flap_phase + phase_offset) * TAU) * flap_amount

func _animated_surface_position(side: String, attach_t: float, margin: float, local_z: float, offset_x: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> Vector3:
	var sample := _sample_shell_profile(attach_t)
	var local_y := 0.0
	match side:
		"dorsal":
			local_y = sample.y + margin - FIN_BASE_EMBED
		"ventral":
			local_y = -sample.y - margin + FIN_BASE_EMBED
	var center := _sample_animated_shell_center(attach_t, centers)
	var yaw := _sample_animated_shell_yaw(attach_t, yaws)
	return center + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(offset_x, local_y, local_z)

func _animated_side_position(attach_t: float, local_y: float, local_z: float, offset_x: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> Vector3:
	var center := _sample_animated_shell_center(attach_t, centers)
	var yaw := _sample_animated_shell_yaw(attach_t, yaws)
	return center + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(offset_x, local_y, local_z)

func _sample_animated_shell_center(attach_t: float, centers: PackedVector3Array) -> Vector3:
	if centers.is_empty():
		var sample := _sample_shell_profile(attach_t)
		return Vector3(sample.x, _sample_shell_center_y(attach_t), 0.0)
	var scaled := clampf(attach_t, 0.0, 1.0) * float(centers.size() - 1)
	var index := int(floor(scaled))
	var next_index := mini(index + 1, centers.size() - 1)
	var local_t := scaled - float(index)
	return _animated_ring_center(index, centers).lerp(_animated_ring_center(next_index, centers), local_t)

func _sample_animated_shell_yaw(attach_t: float, yaws: PackedFloat32Array) -> float:
	if yaws.is_empty():
		return 0.0
	var scaled := clampf(attach_t, 0.0, 1.0) * float(yaws.size() - 1)
	var index := int(floor(scaled))
	var next_index := mini(index + 1, yaws.size() - 1)
	var local_t := scaled - float(index)
	return lerpf(float(yaws[index]), float(yaws[next_index]), local_t)

func _shell_attach_t_for_x(x: float) -> float:
	if shell_profile.size() <= 1:
		return 0.0
	if x <= shell_profile[0].x:
		return 0.0
	for i in range(1, shell_profile.size()):
		var prev_x := shell_profile[i - 1].x
		var curr_x := shell_profile[i].x
		if x <= curr_x:
			var segment_t := clampf((x - prev_x) / maxf(curr_x - prev_x, 0.001), 0.0, 1.0)
			return (float(i - 1) + segment_t) / float(shell_profile.size() - 1)
	return 1.0

func _animated_ring_center(ring_index: int, centers: PackedVector3Array) -> Vector3:
	var index := clampi(ring_index, 0, maxi(centers.size() - 1, 0))
	var center := centers[index] if index < centers.size() else Vector3.ZERO
	center.y += shell_center_y_offsets[index] if index < shell_center_y_offsets.size() else 0.0
	return center

func _animated_ring_yaw(ring_index: int, yaws: PackedFloat32Array) -> float:
	var index := clampi(ring_index, 0, maxi(yaws.size() - 1, 0))
	return float(yaws[index]) if index < yaws.size() else 0.0

func _ring_index_by_id(ring_id: String, fallback_index: int) -> int:
	for i in shell_ring_ids.size():
		if shell_ring_ids[i] == ring_id:
			return i
	return clampi(fallback_index, 0, maxi(shell_ring_ids.size() - 1, 0))

func set_fin_offset(fin_id: String, offset_x: float) -> void:
	var clamped := clampf(offset_x, -0.55, 0.55)
	match fin_id:
		"dorsal":
			parameters["dorsal_fin_offset_x"] = clamped
		"dorsal_1":
			parameters["dorsal_fin_offset_x"] = clamped
		"anal":
			parameters["anal_fin_offset_x"] = clamped
		"pectoral":
			parameters["pectoral_fin_offset_x"] = clamped
	_apply_fin_offsets()

func set_fin_attach(fin_id: String, attach_t: float) -> void:
	var clamped := clampf(attach_t, 0.02, 0.98)
	match fin_id:
		"dorsal", "dorsal_1":
			parameters["dorsal_1_attach_t"] = clamped
		"dorsal_2":
			parameters["dorsal_2_attach_t"] = clamped
		"anal":
			parameters["anal_attach_t"] = clamped
		"pelvic":
			parameters["pelvic_attach_t"] = clamped
		"pectoral":
			parameters["pectoral_attach_t"] = clamped
	_apply_fin_offsets()

func move_fin_offset(fin_id: String, delta_x: float) -> void:
	var key := _fin_offset_key(fin_id)
	if key == "":
		return
	set_fin_offset(fin_id, float(parameters.get(key, 0.0)) + delta_x)

func move_fin_attach(fin_id: String, delta_t: float) -> void:
	var key := _fin_attach_key(fin_id)
	if key == "":
		return
	set_fin_attach(fin_id, float(parameters.get(key, _default_attach_t(fin_id))) + delta_t)

func get_fin_drag_points() -> Dictionary:
	var points := {}
	if dorsal_fin:
		points["dorsal"] = dorsal_fin.global_position
		points["dorsal_1"] = dorsal_fin.global_position
	if dorsal_2_fin:
		points["dorsal_2"] = dorsal_2_fin.global_position
	if anal_fin:
		points["anal"] = anal_fin.global_position
	if pelvic_l and pelvic_r:
		points["pelvic"] = (pelvic_l.global_position + pelvic_r.global_position) * 0.5
	if pectoral_l and pectoral_r:
		points["pectoral"] = (pectoral_l.global_position + pectoral_r.global_position) * 0.5
	return points

func get_drag_handles() -> Dictionary:
	var handles := get_fin_drag_points()
	if eye_l:
		handles["eye_l"] = eye_l.global_position
	if eye_r:
		handles["eye_r"] = eye_r.global_position
	return handles

func get_vector_edit_marker_world(slot: String, norm_position: Vector2) -> Vector3:
	match slot:
		"dorsal", "dorsal_1":
			return _single_local_point_to_world(dorsal_fin, _curved_fin_points(
				"dorsal",
				param_float("dorsal_1_attach_t", 0.45),
				0.035,
				PackedVector3Array([Vector3(norm_position.x * param_float("dorsal_1_length", 0.42), norm_position.y * param_float("dorsal_1_height", param_float("dorsal_fin_size", 0.28)), 0.0)]),
				clampf(param_float("fin_curve_follow", 1.0), 0.0, 1.0)
			)[0])
		"dorsal_2":
			return _single_local_point_to_world(dorsal_2_fin, _curved_fin_points(
				"dorsal",
				param_float("dorsal_2_attach_t", 0.68),
				0.028,
				PackedVector3Array([Vector3(norm_position.x * param_float("dorsal_2_length", 0.34), norm_position.y * param_float("dorsal_2_height", 0.18), 0.0)]),
				clampf(param_float("fin_curve_follow", 1.0), 0.0, 1.0)
			)[0])
		"anal":
			return _single_local_point_to_world(anal_fin, _curved_fin_points(
				"ventral",
				param_float("anal_attach_t", 0.64),
				0.03,
				PackedVector3Array([Vector3(norm_position.x * param_float("anal_length", 0.36), norm_position.y * param_float("anal_height", param_float("anal_fin_size", 0.2)), 0.0)]),
				clampf(param_float("fin_curve_follow", 1.0), 0.0, 1.0)
			)[0])
		"pectoral":
			var pectoral_size := param_float("pectoral_fin_size", 0.16)
			return _single_local_point_to_world(pectoral_l, Vector3((norm_position.x + 0.5) * pectoral_size, norm_position.y * pectoral_size * 0.5, 0.0))
		"pelvic":
			return _single_local_point_to_world(pelvic_l, Vector3((norm_position.x + 0.5) * param_float("pelvic_length", 0.22), -norm_position.y * param_float("pelvic_height", 0.14), 0.0))
		"caudal":
			return _single_local_point_to_world(tail_fin, Vector3(norm_position.x * param_float("tail_fin_size", 0.46), norm_position.y * param_float("tail_fin_size", 0.46) * param_float("caudal_height_scale", 0.72), 0.0))
		"operculum":
			return _operculum_edit_marker_world(norm_position)
	return Vector3.INF

func _single_local_point_to_world(node: Node3D, local_point: Vector3) -> Vector3:
	if node == null:
		return Vector3.INF
	return node.global_transform * local_point

func _operculum_edit_marker_world(norm_position: Vector2) -> Vector3:
	if body_pivot == null:
		return Vector3.INF
	var op_len := clampf(float(parameters.get("operculum_size", 1.0)), 0.5, 1.5)
	var op_h := clampf(float(parameters.get("operculum_height", 1.0)), 0.5, 1.5)
	var op_open := clampf(float(parameters.get("operculum_open", 0.0)), 0.0, 1.0)
	var lift := 0.012 + 0.03 * op_open
	var center_t := 0.19
	var half_t := 0.05 * op_len
	var t_front := maxf(center_t - half_t, 0.02)
	var t_rear := center_t + half_t
	var vfrac_max := 0.62 * op_h
	var u := clampf(norm_position.x, 0.0, 1.0)
	var f := clampf(norm_position.y * vfrac_max, -0.985, 0.985)
	var out := 0.002 + (0.012 + lift) * smoothstep(0.05, 1.0, u)
	return body_pivot.global_transform * _op_shell_point(u, f, t_front, t_rear, 1.0, out)

# Lower-jaw pivot in head-local space. Shared by _mouth_lower_jaw_mesh (which rotates the
# jaw about it) and the editor hinge marker so the drawn point is the ACTUAL pivot.
func _lower_jaw_hinge_local(origin: Vector3, jaw_scale: float, hinge_x_off: float, hinge_y_off: float) -> Vector3:
	var scale := clampf(jaw_scale, 0.45, 1.8)
	var depth := PF.UPPER_JAW_CARVE_DEPTH * scale * 1.2
	return Vector3(maxf(0.18, origin.x + 0.42) + hinge_x_off, origin.y + depth * 0.06 + hinge_y_off, 0.0)

# World position of the lower-jaw hinge, or Vector3.INF when there is no jaw (ray heads,
# or before the first build). Used by DragHandlesOverlay to mark the hinge.
func get_jaw_hinge_world() -> Vector3:
	if not jaw_hinge_valid or head_node == null:
		return Vector3.INF
	return head_node.global_transform * jaw_hinge_local

func move_eye(delta_x: float, delta_y: float) -> void:
	parameters["eye_position_x"] = clampf(float(parameters.get("eye_position_x", -0.78)) + delta_x, -1.5, 0.2)
	parameters["eye_position_y"] = clampf(float(parameters.get("eye_position_y", 0.12)) + delta_y, -0.5, 0.6)
	_reposition_eyes()

func move_pectoral(delta_x: float, delta_y: float) -> void:
	parameters["pectoral_attach_t"] = clampf(float(parameters.get("pectoral_attach_t", 0.32)) + delta_x, 0.02, 0.98)
	parameters["pectoral_offset_y"] = clampf(float(parameters.get("pectoral_offset_y", 0.0)) + delta_y, -0.5, 0.5)
	_apply_fin_offsets()

func _apply_fin_offsets() -> void:
	if dorsal_fin:
		var dorsal_attach_t := param_float("dorsal_1_attach_t", 0.45)
		dorsal_base_position = _surface_position("dorsal", dorsal_attach_t, 0.035)
		dorsal_fin.position = dorsal_base_position + Vector3(float(parameters.get("dorsal_fin_offset_x", 0.0)), 0.0, 0.0)
		dorsal_fin.rotation_degrees.z = _surface_tangent_angle_degrees("dorsal", dorsal_attach_t)
	if dorsal_2_fin:
		var dorsal_2_attach_t := param_float("dorsal_2_attach_t", 0.68)
		dorsal_2_base_position = _surface_position("dorsal", dorsal_2_attach_t, 0.028)
		dorsal_2_fin.position = dorsal_2_base_position
		dorsal_2_fin.rotation_degrees.z = _surface_tangent_angle_degrees("dorsal", dorsal_2_attach_t)
	if anal_fin:
		var anal_attach_t := param_float("anal_attach_t", 0.64)
		anal_base_position = _surface_position("ventral", anal_attach_t, 0.03)
		anal_fin.position = anal_base_position + Vector3(float(parameters.get("anal_fin_offset_x", 0.0)), 0.0, 0.0)
		anal_fin.rotation_degrees.z = _surface_tangent_angle_degrees("ventral", anal_attach_t)
	if pelvic_l and pelvic_r:
		var pelvic_attach_t := param_float("pelvic_attach_t", 0.36)
		var pelvic_center := _surface_position("ventral", pelvic_attach_t, 0.02)
		var pelvic_z := _surface_radius_z(pelvic_attach_t) * 0.32
		pelvic_l_base_position = pelvic_center + Vector3(0.0, 0.0, -pelvic_z)
		pelvic_r_base_position = pelvic_center + Vector3(0.0, 0.0, pelvic_z)
		pelvic_l.position = pelvic_l_base_position
		pelvic_r.position = pelvic_r_base_position
		var pelvic_surface_angle := _surface_tangent_angle_degrees("ventral", pelvic_attach_t)
		pelvic_l.rotation_degrees = Vector3(0.0, 12.0, pelvic_surface_angle)
		pelvic_r.rotation_degrees = Vector3(0.0, -12.0, pelvic_surface_angle)
	var pectoral_offset := float(parameters.get("pectoral_fin_offset_x", 0.0))
	var pectoral_offset_y := param_float("pectoral_offset_y", 0.0)
	var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
	var pectoral_center := _surface_position("side", pectoral_attach_t, 0.0)
	var pectoral_z := _surface_radius_z(pectoral_attach_t) + param_float("shell_expand", 0.08) * 0.18
	var pectoral_surface_angle := _surface_tangent_angle_degrees("center", pectoral_attach_t)
	var p_yaw := param_float("pectoral_fin_yaw", 25.0)
	var p_pitch := param_float("pectoral_fin_pitch", 0.0)
	var p_roll := param_float("pectoral_fin_roll", -28.0)
	if pectoral_l:
		pectoral_l_base_position = Vector3(pectoral_center.x, -0.02 + pectoral_center.y + pectoral_offset_y, -pectoral_z)
		pectoral_l.position = pectoral_l_base_position + Vector3(pectoral_offset, 0.0, 0.0)
		pectoral_l_base_rotation = Vector3(p_pitch, p_yaw, p_roll + pectoral_surface_angle)
		pectoral_l.rotation_degrees = pectoral_l_base_rotation
	if pectoral_r:
		pectoral_r_base_position = Vector3(pectoral_center.x, -0.02 + pectoral_center.y + pectoral_offset_y, pectoral_z)
		pectoral_r.position = pectoral_r_base_position + Vector3(pectoral_offset, 0.0, 0.0)
		pectoral_r_base_rotation = Vector3(-p_pitch, -p_yaw, p_roll + pectoral_surface_angle)
		pectoral_r.rotation_degrees = pectoral_r_base_rotation

func _fin_offset_key(fin_id: String) -> String:
	match fin_id:
		"dorsal":
			return "dorsal_fin_offset_x"
		"anal":
			return "anal_fin_offset_x"
		"pectoral":
			return "pectoral_fin_offset_x"
	return ""

func _fin_attach_key(fin_id: String) -> String:
	match fin_id:
		"dorsal", "dorsal_1":
			return "dorsal_1_attach_t"
		"dorsal_2":
			return "dorsal_2_attach_t"
		"anal":
			return "anal_attach_t"
		"pelvic":
			return "pelvic_attach_t"
		"pectoral":
			return "pectoral_attach_t"
	return ""

func _default_attach_t(fin_id: String) -> float:
	match fin_id:
		"dorsal", "dorsal_1":
			return 0.45
		"dorsal_2":
			return 0.68
		"anal":
			return 0.64
		"pelvic":
			return 0.36
		"pectoral":
			return 0.32
	return 0.5

func _surface_position(side: String, attach_t: float, margin: float) -> Vector3:
	var sample := _sample_shell_profile(attach_t)
	var center_y := _sample_shell_center_y(attach_t)
	match side:
		"dorsal":
			return Vector3(sample.x, center_y + sample.y + margin - FIN_BASE_EMBED, 0.0)
		"ventral":
			return Vector3(sample.x, center_y - sample.y - margin + FIN_BASE_EMBED, 0.0)
		"side":
			return Vector3(sample.x, center_y, 0.0)
	return Vector3(sample.x, center_y + sample.y, 0.0)

func _surface_radius_z(attach_t: float) -> float:
	return _sample_shell_profile(attach_t).z

func _surface_tangent_angle_degrees(side: String, attach_t: float) -> float:
	if shell_profile.size() < 2:
		return 0.0
	var delta := 1.0 / maxf(float(shell_profile.size() - 1), 1.0)
	var from_t := clampf(attach_t - delta, 0.0, 1.0)
	var to_t := clampf(attach_t + delta, 0.0, 1.0)
	if is_equal_approx(from_t, to_t):
		return 0.0
	var from_point := _surface_contour_point(side, from_t)
	var to_point := _surface_contour_point(side, to_t)
	var dx := to_point.x - from_point.x
	if absf(dx) < 0.0001:
		return 0.0
	return clampf(rad_to_deg(atan2(to_point.y - from_point.y, dx)), -40.0, 40.0)

func _surface_contour_point(side: String, attach_t: float) -> Vector2:
	var sample := _sample_shell_profile(attach_t)
	var center_y := _sample_shell_center_y(attach_t)
	match side:
		"dorsal":
			return Vector2(sample.x, center_y + sample.y)
		"ventral":
			return Vector2(sample.x, center_y - sample.y)
	return Vector2(sample.x, center_y)

func _contour_outward_normal(side: String, attach_t: float) -> Vector2:
	var delta := 1.0 / maxf(float(shell_profile.size() - 1), 1.0)
	var before := _surface_contour_point(side, clampf(attach_t - delta, 0.0, 1.0))
	var after := _surface_contour_point(side, clampf(attach_t + delta, 0.0, 1.0))
	var tangent := after - before
	if tangent.length() < 0.00001:
		tangent = Vector2(1.0, 0.0)
	tangent = tangent.normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	if side == "ventral":
		if normal.y > 0.0:
			normal = -normal
	elif normal.y < 0.0:
		normal = -normal
	return normal

# Builds a median fin (dorsal/ventral) whose base hugs the body contour and
# whose membrane bends along the body curve. `fin_curve_follow` blends between
# the original flat fin (0) and the fully contour-following shape (1).
func _build_median_fin(fin_name: String, side: String, shape: String, length: float, height: float, attach_t: float, margin: float, material: Material) -> MeshInstance3D:
	var points := _get_fin_points(fin_name, shape, length, height)
	var follow := clampf(param_float("fin_curve_follow", 1.0), 0.0, 1.0)
	return PF.polygon_fin(fin_name, _curved_fin_points(side, attach_t, margin, points, follow), material)

func _get_fin_points(fin_name: String, shape: String, length: float, height: float) -> PackedVector3Array:
	var pts: PackedVector3Array
	var slot := _fin_name_to_slot(fin_name)
	if shape == "custom":
		var default_pts := [-0.5, 0.0, -0.25, 0.6, 0.0, 0.8, 0.25, 0.6, 0.5, 0.0]
		if slot == "pectoral" or slot == "pelvic":
			default_pts = [-0.5, 0.2, 0.0, 0.5, 0.5, 0.0, 0.0, -0.5, -0.5, -0.2]
		var raw_pts: Array = parameters.get(slot + "_custom_points", default_pts)
		pts = PackedVector3Array()
		for i in range(0, raw_pts.size(), 2):
			if i + 1 < raw_pts.size():
				pts.append(Vector3(raw_pts[i] * length, raw_pts[i+1] * height, 0.0))
	elif shape == "bezier":
		var prefix := slot + "_bezier_"
		var p1_x := param_float(prefix + "p1_x", -0.25)
		var p1_y := param_float(prefix + "p1_y", 1.0)
		var p2_x := param_float(prefix + "p2_x", 0.25)
		var p2_y := param_float(prefix + "p2_y", 1.0)
		var p1 := Vector2(length * p1_x, height * p1_y)
		var p2 := Vector2(length * p2_x, height * p2_y)
		pts = PF.bezier_fin_points(length, height, p1, p2)
	else:
		pts = PF._fin_shape_points(shape, length, height)
		
	if slot == "pectoral" or slot == "pelvic":
		var shifted := PackedVector3Array()
		for p in pts:
			shifted.append(p + Vector3(length * 0.5, 0.0, 0.0))
		pts = shifted
	return pts

func _get_caudal_fin_points(shape: String, length: float, height: float) -> PackedVector3Array:
	if shape == "custom":
		var default_pts := [0.0, 0.44, 0.88, 0.98, 1.0, 0.0, 0.88, -0.98, 0.0, -0.44]
		var raw_pts: Array = parameters.get("caudal_custom_points", default_pts)
		var pts := PackedVector3Array()
		for i in range(0, raw_pts.size(), 2):
			if i + 1 < raw_pts.size():
				pts.append(Vector3(raw_pts[i] * length, raw_pts[i+1] * height, 0.0))
		return pts
	return PF.caudal_fin_points(shape, length, height)

func _fin_name_to_slot(fin_name: String) -> String:
	if fin_name.begins_with("DorsalFin1"):
		return "dorsal_1"
	elif fin_name.begins_with("DorsalFin2"):
		return "dorsal_2"
	elif fin_name.begins_with("AnalFin"):
		return "anal"
	elif fin_name.begins_with("PelvicFin"):
		return "pelvic"
	elif fin_name.begins_with("PectoralFin"):
		return "pectoral"
	return "dorsal_1"

func _curved_fin_points(side: String, attach_t: float, margin: float, points: PackedVector3Array, follow: float, loop_phase: float = -1.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	var ventral_flip := -1.0 if side == "ventral" else 1.0
	if shell_profile.size() < 2:
		for point in points:
			result.append(Vector3(point.x, point.y * ventral_flip, 0.0))
		return result
	var x_span := maxf(shell_profile[shell_profile.size() - 1].x - shell_profile[0].x, 0.001)
	var embed_margin := margin - FIN_BASE_EMBED
	var theta := deg_to_rad(_surface_tangent_angle_degrees(side, attach_t))
	var cos_t := cos(-theta)
	var sin_t := sin(-theta)
	var cos_theta := absf(cos(theta))
	var pivot := _surface_contour_point(side, attach_t) + _contour_outward_normal(side, attach_t) * embed_margin
	# Travelling-wave ripple: each lengthwise slice tilts about its base by a
	# head-to-tail phase, so the free edge undulates while the membrane keeps its
	# length (tilt, not stretch) and the base stays on the body.
	var ripple := loop_phase >= 0.0
	var ring_span := float(maxi(shell_profile.size() - 1, 1))
	var phase_delay := param_float("phase_delay", 0.65)
	var tilt_amp := _median_fin_wave_tilt_amount()
	for point in points:
		var flat := Vector2(point.x, point.y * ventral_flip)
		var t_prime := clampf(attach_t + (point.x * cos_theta) / x_span, 0.0, 1.0)
		var base := _surface_contour_point(side, t_prime)
		var normal := _contour_outward_normal(side, t_prime)
		var world := base + normal * (embed_margin + point.y)
		var rel := world - pivot
		var local := Vector2(rel.x * cos_t - rel.y * sin_t, rel.x * sin_t + rel.y * cos_t)
		var blended := flat.lerp(local, follow)
		var out_y := blended.y
		var z := 0.0
		if ripple:
			var tilt := clampf(sin(loop_phase * TAU - t_prime * ring_span * phase_delay) * tilt_amp, -1.2, 1.2)
			z = out_y * sin(tilt)
			out_y = out_y * cos(tilt)
		result.append(Vector3(blended.x, out_y, z))
	return result

func _animated_curved_fin_points(fin_node: MeshInstance3D, side: String, attach_t: float, margin: float, points: PackedVector3Array, follow: float, loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> PackedVector3Array:
	if centers.is_empty() or shell_profile.size() < 2:
		return _curved_fin_points(side, attach_t, margin, points, follow, loop_phase)
	var result := PackedVector3Array()
	var x_span := maxf(shell_profile[shell_profile.size() - 1].x - shell_profile[0].x, 0.001)
	var ring_span := float(maxi(shell_profile.size() - 1, 1))
	var phase_delay := param_float("phase_delay", 0.65)
	var tilt_amp := _median_fin_wave_tilt_amount()
	var inverse_transform := fin_node.transform.affine_inverse()
	var pivot_surface := _animated_surface_position(side, attach_t, margin, 0.0, 0.0, centers, yaws)
	var min_z_follow := clampf(param_float("median_fin_body_z_follow", 0.45), 0.0, 1.0)
	var z_follow_t := clampf((absf(param_float("body_wave_amount", 0.35)) - 100.0) / 1000.0, 0.0, 1.0)
	var z_follow := lerpf(1.0, min_z_follow, z_follow_t)
	var turn_amount := clampf(param_float("turn_amount", 0.0), 0.0, 1.0)
	var turn_phase := clampf(param_float("turn_phase", 0.0), 0.0, 1.0)
	var median_turn := turn_amount
	if turn_amount > 0.001 and turn_phase > 0.001:
		median_turn = sin(PI * pow(turn_phase, 0.33))
		
	var turn_direction := _turn_direction()
	var turn_median_bias_angle := param_float("turn_median_fin_bias", 0.5) * median_turn * turn_direction * 12.0
	# Soft free-edge flutter, layered on top of the body-wave tilt. When active the
	# outline is subdivided so the flowing ripple stays smooth; amplitude grows toward
	# the free margin (+y) and several crests travel head-to-tail along the span (x).
	var softness := _effective_fin_softness(_fin_name_to_slot(fin_node.name))
	var work_points := points
	var min_x_local := INF
	var max_x_local := -INF
	var max_height := 0.001
	var soft_drive := 0.0
	var soft_lag := 0.6 + softness * 5.2
	var soft_down := Vector3.ZERO
	if softness > 0.001:
		soft_drive = _swim_drive_strength()
		soft_down = fin_node.global_transform.basis.inverse() * Vector3.DOWN
		work_points = PF.subdivide_fin_outline(points, 8)
		for point in work_points:
			min_x_local = minf(min_x_local, point.x)
			max_x_local = maxf(max_x_local, point.x)
			max_height = maxf(max_height, absf(point.y))
	var x_span_local := maxf(max_x_local - min_x_local, 0.001)
	for point in work_points:
		var t_prime := clampf(attach_t + point.x / x_span, 0.0, 1.0)
		var tilt := clampf(sin(loop_phase * TAU - t_prime * ring_span * phase_delay) * tilt_amp, -1.2, 1.2)
		var fin_height := maxf(point.y, 0.0)
		var turn_bias_z := fin_height * sin(deg_to_rad(turn_median_bias_angle))
		var local_z := fin_height * sin(tilt) + turn_bias_z
		var surface_margin := margin + fin_height * cos(tilt)
		var animated_point := _animated_surface_position(side, t_prime, surface_margin, local_z, 0.0, centers, yaws)
		animated_point.z = lerpf(pivot_surface.z, animated_point.z, z_follow)
		var static_point := _curved_fin_points(side, attach_t, margin, PackedVector3Array([point]), follow, loop_phase)[0]
		var blended := static_point.lerp(inverse_transform * animated_point, follow)
		if softness > 0.001:
			# Free edge trails the body wave passing along the fin (head-to-tail),
			# locked to that motion so it flows with the swim instead of self-rippling.
			var tip_t := clampf((point.x - min_x_local) / x_span_local, 0.0, 1.0)
			var edge_norm := clampf(absf(point.y) / max_height, 0.0, 1.0)
			var membrane_weight := 0.4 + 0.6 * edge_norm
			var trail := _membrane_trail(loop_phase * TAU - phase_delay, tip_t, soft_lag)
			blended.z += FIN_SOFT_AMPLITUDE * soft_drive * trail * max_height * softness * pow(edge_norm, 1.2) * membrane_weight
			var sag := FIN_SOFT_DROOP * softness * pow(edge_norm, 1.1) * max_height
			var sag_offset := Vector3(0.0, soft_down.y, soft_down.z) * sag
			blended += sag_offset
		result.append(blended)
	return result

func _sample_shell_profile(attach_t: float) -> Vector3:
	if shell_profile.is_empty():
		return Vector3(0.0, 0.4, 0.24)
	var scaled := clampf(attach_t, 0.0, 1.0) * float(shell_profile.size() - 1)
	var index := int(floor(scaled))
	var next_index := mini(index + 1, shell_profile.size() - 1)
	var local_t := scaled - float(index)
	return shell_profile[index].lerp(shell_profile[next_index], local_t)

func _sample_shell_center_y(attach_t: float) -> float:
	if shell_center_y_offsets.is_empty():
		return 0.0
	var scaled := clampf(attach_t, 0.0, 1.0) * float(shell_center_y_offsets.size() - 1)
	var index := int(floor(scaled))
	var next_index := mini(index + 1, shell_center_y_offsets.size() - 1)
	var local_t := scaled - float(index)
	return lerpf(shell_center_y_offsets[index], shell_center_y_offsets[next_index], local_t)

func _sample_shell_center_y_at_x(x: float) -> float:
	if shell_profile.is_empty() or shell_center_y_offsets.is_empty():
		return 0.0
	if x <= shell_profile[0].x:
		return shell_center_y_offsets[0]
	for i in shell_profile.size() - 1:
		var from_x := shell_profile[i].x
		var to_x := shell_profile[i + 1].x
		if x <= to_x:
			var local_t := 0.0 if is_equal_approx(from_x, to_x) else clampf((x - from_x) / (to_x - from_x), 0.0, 1.0)
			return lerpf(shell_center_y_offsets[i], shell_center_y_offsets[i + 1], local_t)
	return shell_center_y_offsets[shell_center_y_offsets.size() - 1]

func set_head_shape(shape: String) -> void:
	parameters["head_shape"] = shape
	rebuild()

func set_mouth_type(mouth_type: String) -> void:
	parameters["mouth_type"] = mouth_type
	rebuild()

func set_body_profile_shape(shape: String) -> void:
	parameters["body_profile_shape"] = shape
	parameters["body_profile"] = {"rings": BodyProfileScript.default_fish_rings(shape)}
	rebuild()

func _head_sculpt_params() -> Dictionary:
	var mouth_type := String(parameters.get("mouth_type", "terminal"))
	var mouth_base_y := 0.0
	# Phase 7: mouth_type now also seeds the jaw-linkage geometry (hinge height, jaw
	# length ratio, default protrusion) rather than only sliding the bite line up/down.
	var jaw_hinge_y_def := 0.0
	var jaw_ratio_def := 1.0
	var jaw_protr_def := 0.0
	match mouth_type:
		"superior":
			mouth_base_y = 0.11
			jaw_hinge_y_def = -0.03   # low hinge -> lower jaw juts up and forward
			jaw_ratio_def = 1.15
		"inferior":
			mouth_base_y = -0.14
			jaw_hinge_y_def = 0.03    # high hinge -> upper jaw overhangs
			jaw_ratio_def = 0.82
		"subterminal":
			mouth_base_y = -0.07
			jaw_ratio_def = 0.9
		"protrusible":
			jaw_protr_def = 0.12      # the extending-tube mouth
	return {
		"snout_base": param_float("snout_base", HeadProfile.SNOUT_BLEND_HALF),
		"snout_thickness": param_float("snout_thickness", 1.0),
		"snout_taper": param_float("snout_taper", 0.0),
		"snout_y_shift": _snout_jaw_shift(),
		"snout_curve": param_float("snout_curve", 0.0),
		"head_top_curve": param_float("head_top_curve", 0.0),
		"head_top_peak": param_float("head_top_peak", 0.35),
		"head_belly_curve": param_float("head_belly_curve", 0.0),
		"head_bump_height": param_float("head_bump_height", 0.0),
		"head_bump_pos": param_float("head_bump_pos", -0.2),
		"head_bump_width": param_float("head_bump_width", 0.18),
		"head_bump_angle": param_float("head_bump_angle", 35.0),
		"head_bump_round": param_float("head_bump_round", 0.6),
		"mouth_open": param_float("mouth_open", 0.25),
		"mouth_size": param_float("mouth_size", 0.08),
		"mouth_center_y": mouth_base_y + _snout_tip_displacement(),
		"lower_jaw_scale": _head_lower_jaw_scale(),
		"jaw_hinge_x": param_float("jaw_hinge_x", HeadProfile.JAW_DEFAULTS["jaw_hinge_x"]),
		"jaw_hinge_y": param_float("jaw_hinge_y", jaw_hinge_y_def),
		"jaw_protrusion": param_float("jaw_protrusion", jaw_protr_def),
		"lower_upper_ratio": param_float("lower_upper_ratio", jaw_ratio_def),
	}

func _head_lower_jaw_scale() -> float:
	var profile := BodyProfileScript.ensure_body_profile(parameters)
	var rings: Array = profile.get("rings", [])
	var head_ring := _ring_by_id(rings, "head", 1)
	var ring_scale := float(head_ring.get("lower_height", 0.36)) / 0.36
	var belly_scale := 1.0 + clampf(param_float("head_belly_curve", 0.0), -1.0, 1.0) * 0.45
	return clampf(ring_scale * belly_scale, 0.45, 1.8)

# Linear jaw shear of the snout tip. Matches the mouth's own vertical offset from
# its no-jaw baseline (see _mouth_position_for_type) so the snout geometry and the
# mouth move together instead of the mouth floating.
func _snout_jaw_shift() -> float:
	var jaw_offset := param_float("jaw_offset", 0.0)
	if String(parameters.get("mouth_type", "terminal")) == "superior":
		return absf(jaw_offset)
	return jaw_offset

# Total vertical displacement at the snout tip (jaw shear + curve arc). Used to keep
# the mouth, snout socket, and barbels riding the deformed snout tip.
func _snout_tip_displacement() -> float:
	return HeadProfile.snout_y_shift(_snout_jaw_shift(), 0.0, param_float("snout_base", HeadProfile.SNOUT_BLEND_HALF), param_float("snout_curve", 0.0))

func _head_scale_for_shape(shape: String, head_size: float, body_height: float, body_width: float) -> Vector3:
	var flatten := clampf(param_float("head_flattening", 0.0), 0.0, 0.65)
	var head_scale := Vector3(head_size, body_height * 0.82, body_width * 0.92)
	match shape:
		"pointed":
			head_scale.x *= 1.34 + param_float("snout_length", 0.0)
			head_scale.y *= 0.72
			head_scale.z *= 0.78
		"blunt":
			head_scale.x *= 0.86
			head_scale.y *= 0.95
			head_scale.z *= 1.02
		"broad":
			head_scale.x *= 1.02
			head_scale.y *= 0.9
			head_scale.z *= 1.42
		"flattened":
			head_scale.x *= 1.12
			head_scale.y *= 0.55
			head_scale.z *= 1.28
		"hump":
			head_scale.x *= 1.05
			head_scale.y *= 0.92
			head_scale.z *= 1.0
		"steep_forehead":
			head_scale.x *= 0.96
			head_scale.y *= 1.12
			head_scale.z *= 0.98
		"tapered":
			head_scale.x *= 1.18
			head_scale.y *= 0.82
			head_scale.z *= 0.86
		_:
			pass
	head_scale.y *= 1.0 - flatten
	head_scale.z *= 1.0 + flatten * 0.35
	return head_scale

func _add_eyes(eye_mat: Material, stalk_mat: Material, head_center: Vector3, head_scale: Vector3, eye_size: float) -> void:
	eye_head_center = head_center
	eye_head_scale = head_scale
	var eye_style := String(parameters.get("eye_style", "bead"))
	match eye_style:
		"large":
			eye_size *= 1.35
		"telescope":
			eye_size *= 1.5
		"celestial":
			eye_size *= 1.2
		"tiny_puffer":
			eye_size *= 0.62
	eye_radius = eye_size
	var layout := _eye_layout()
	var anchor: Vector3 = layout["anchor"]
	var eye_center_z := float(layout["eye_center_z"])
	var stalk_inner := float(layout["stalk_inner"])
	var stalk_length := float(layout["stalk_length"])
	
	var z_scale_mult := 1.0
	match eye_style:
		"large", "bead":
			z_scale_mult = 0.55
		"tiny_puffer":
			z_scale_mult = 0.70
		"telescope", "celestial":
			z_scale_mult = 1.0
			
	var theta := 0.0
	if eye_style == "celestial":
		theta = deg_to_rad(55.0)

	# Real teleost eyes read as a bright metallic iris ring (guanine iridophores)
	# around a fixed round pupil that the spherical lens bulges through, topped by a
	# wet catchlight — not the flat black bead we used to draw. eye_mat now colors the
	# pupil; the iris ellipsoid carries the metallic ring colour underneath it.
	var iris_mat := TMF.make_dark(String(parameters.get("eye_iris_color", "#d8b24a")))
	var catchlight_mat := TMF.make_dark("#f2fbff")
	var pupil_scale := clampf(param_float("eye_pupil_scale", 0.6), 0.2, 0.95)

	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		var v: Vector3 = Vector3(0.0, sin(theta), side * cos(theta))
		var rot_x: float = side * (90.0 - rad_to_deg(theta))

		var eye := PF.ellipsoid("Eye%s" % suffix, Vector3(eye_size, eye_size * z_scale_mult, eye_size), iris_mat)
		eye.position = anchor + v * eye_center_z
		eye.rotation_degrees = Vector3(rot_x, 0.0, 0.0)
		body_pivot.add_child(eye)
		_add_eye_details(eye, eye_mat, catchlight_mat, side, pupil_scale)
		if side < 0.0:
			eye_l = eye
		else:
			eye_r = eye
		if bool(layout["has_stalk"]):
			var is_thick_stalk := eye_style == "telescope" or eye_style == "celestial"
			var r_bottom := eye_size * 0.6 if is_thick_stalk else eye_size * 0.34
			var r_top := eye_size * 0.8 if is_thick_stalk else eye_size * 0.34
			
			var stalk := PF.tapered_cylinder("EyeStalk%s" % suffix, r_bottom, r_top, stalk_length, stalk_mat)
			stalk.rotation_degrees = Vector3(rot_x, 0.0, 0.0)
			stalk.position = anchor + v * (stalk_inner + stalk_length * 0.5)
			body_pivot.add_child(stalk)
			if side < 0.0:
				eye_stalk_l = stalk
			else:
				eye_stalk_r = stalk

# Builds the fish-eye detail stack on top of the iris ellipsoid: a round dark pupil
# the spherical lens bulges through, plus a small specular catchlight on that lens.
# Children inherit the eye's (flattened, side-facing) transform so they ride along
# with every reposition/animation pass without extra bookkeeping.
func _add_eye_details(eye: MeshInstance3D, pupil_mat: Material, catchlight_mat: Material, side: float, pupil_scale: float) -> void:
	# Local +Y is the eye's outward pole (the squashed axis faces sideways), so the
	# pupil rides out along +Y and bulges past the iris surface like a real lens.
	var pupil := PF.ellipsoid("Pupil", Vector3(pupil_scale, pupil_scale, pupil_scale), pupil_mat)
	pupil.position = Vector3(0.0, 0.30, 0.0)
	eye.add_child(pupil)
	# Catchlight is a flat specular spot painted onto the pupil's outer face toward the
	# upper-front (eye-local: world-up maps to -side*Z, snout/world -X maps to -X). It is
	# squashed flat along the outward axis (Y) and sat just on the lens surface so it
	# reads as a glint flush with the eye, not a 3D bead stuck on top of the pupil.
	var catchlight := PF.ellipsoid("Catchlight", Vector3(0.30, 0.04, 0.30), catchlight_mat)
	catchlight.position = Vector3(-0.20, 0.43, -side * 0.20)
	pupil.add_child(catchlight)

# Projects the requested eye spot onto the head ellipsoid, clamped inside the
# silhouette so the eye sits on the head instead of floating past the snout.
# eye_bulge pushes it outward, from a flush goldfish eye to a hammerhead stalk.
func _eye_layout() -> Dictionary:
	var half := eye_head_scale * 0.5
	var eye_x := param_float("eye_position_x", -0.78)
	var eye_y := param_float("eye_position_y", 0.12)
	var eye_style := String(parameters.get("eye_style", "bead"))
	var default_bulge := 0.0
	if eye_style == "telescope":
		default_bulge = 0.85
	elif eye_style == "celestial":
		default_bulge = 0.45
	var eye_bulge := clampf(float(parameters.get("eye_bulge", default_bulge)), 0.0, 1.0)
	if eye_style == "celestial":
		eye_y += eye_head_scale.y * 0.12
	var ux := (eye_x - eye_head_center.x) / maxf(half.x, 0.001)
	var uy := eye_y / maxf(half.y, 0.001)
	var planar_radius := sqrt(ux * ux + uy * uy)
	# Allow the eye almost out to the front rim (0.98) instead of 0.9 so it can ride
	# onto an elongated snout; the snout shift below carries it the rest of the way.
	var max_planar := 0.98
	if planar_radius > max_planar:
		var shrink := max_planar / planar_radius
		ux *= shrink
		uy *= shrink
	var surface_z := maxf(half.z, 0.02) * sqrt(maxf(1.0 - ux * ux - uy * uy, 0.0))
	# Carry the eye forward along the snout stretch (and thin it onto the tapered
	# snout girth) using the same deformation the head mesh / mouth anchor use, so a
	# long tube snout (butterflyfish, arowana) lets the eye sit ahead of the round head.
	var anchor_x := eye_head_center.x + ux * half.x
	var anchor_y := eye_head_center.y + uy * half.y
	if String(parameters.get("head_shape", "rounded")) != "cephalofoil":
		var snout_base := param_float("snout_base", HeadProfile.SNOUT_BLEND_HALF)
		var u := ux * 0.5 + 0.5 # head-local x (-0.5..0.5) mapped to 0=tip .. 1=nape
		var snout_length := param_float("snout_length", 0.0)
		if snout_length > 0.0:
			anchor_x -= HeadProfile.snout_forward_x_shift(snout_length, u, snout_base) * eye_head_scale.x
			var snout_r := HeadProfile.snout_radial_scale(snout_length, u, snout_base, param_float("snout_thickness", 1.0), param_float("snout_taper", 0.0))
			surface_z *= snout_r
		# Ride the eye with the snout's vertical jaw shear + curve (same deformation the mesh
		# and mouth use), so raising/lowering the jaw carries the eye's reachable range with the
		# new silhouette instead of pinning it to the pre-shear head. Length-independent: the
		# shear applies across the whole front window even with no snout elongation.
		anchor_y += HeadProfile.snout_y_shift(_snout_jaw_shift(), u, snout_base, param_float("snout_curve", 0.0)) * eye_head_scale.y
	var protrusion := eye_bulge * maxf(half.z, 0.05) * 1.7
	var stalk_inner := surface_z * 0.55
	var eye_center_z := surface_z * 0.82 + protrusion
	return {
		"anchor": Vector3(anchor_x, anchor_y, 0.0),
		"eye_center_z": eye_center_z,
		"has_stalk": protrusion > eye_radius * 0.5,
		"stalk_inner": stalk_inner,
		"stalk_length": maxf(eye_center_z - eye_radius * 0.35 - stalk_inner, eye_radius * 0.4)
	}

# Lightweight live update used while dragging the eyes, avoiding a full rebuild.
func _reposition_eyes() -> void:
	if eye_l == null or eye_r == null:
		return
	var layout := _eye_layout()
	var anchor: Vector3 = layout["anchor"]
	var eye_center_z := float(layout["eye_center_z"])
	var stalk_inner := float(layout["stalk_inner"])
	var stalk_length := float(layout["stalk_length"])
	var eye_style := String(parameters.get("eye_style", "bead"))
	
	var theta := 0.0
	if eye_style == "celestial":
		theta = deg_to_rad(55.0)
		
	for side in [-1.0, 1.0]:
		var eye := eye_l if side < 0.0 else eye_r
		var v: Vector3 = Vector3(0.0, sin(theta), side * cos(theta))
		var rot_x: float = side * (90.0 - rad_to_deg(theta))
		eye.position = anchor + v * eye_center_z
		eye.rotation_degrees = Vector3(rot_x, 0.0, 0.0)
		
	for stalk_side in [eye_stalk_l, eye_stalk_r]:
		if stalk_side == null:
			continue
		var side := -1.0 if stalk_side == eye_stalk_l else 1.0
		var v: Vector3 = Vector3(0.0, sin(theta), side * cos(theta))
		var rot_x: float = side * (90.0 - rad_to_deg(theta))
		
		var stalk_mesh := stalk_side.mesh as CylinderMesh
		if stalk_mesh:
			stalk_mesh.height = stalk_length
			var is_thick_stalk := eye_style == "telescope" or eye_style == "celestial"
			var r_bottom := eye_radius * 0.6 if is_thick_stalk else eye_radius * 0.34
			var r_top := eye_radius * 0.8 if is_thick_stalk else eye_radius * 0.34
			stalk_mesh.bottom_radius = r_bottom
			stalk_mesh.top_radius = r_top
			
		stalk_side.position = anchor + v * (stalk_inner + stalk_length * 0.5)
		stalk_side.rotation_degrees = Vector3(rot_x, 0.0, 0.0)

func _add_head_features(head: MeshInstance3D, material: Material) -> void:
	var dark_mat := TMF.make_dark("#15191b")
	var shape := String(parameters.get("head_shape", "rounded"))
	var mouth_type := String(parameters.get("mouth_type", "terminal"))
	var snout_length := param_float("snout_length", 0.0)
	var mouth_size := param_float("mouth_size", 0.08)
	_add_head_ornament(head, String(parameters.get("head_ornament", "none")), material)
	_add_gill_mark(head, String(parameters.get("gill_mark", "none")), dark_mat)
	
	# Snout Appendage Socket
	var snout_app_type := String(parameters.get("snout_appendage", "none"))
	if snout_app_type != "none":
		var snout_socket := Node3D.new()
		snout_socket.name = "SnoutSocket"
		snout_socket.position = Vector3(-0.5 - snout_length, _snout_tip_displacement(), 0.0)
		# Cancel out head scaling so the appendage isn't deformed
		snout_socket.scale = Vector3(1.0 / head.scale.x, 1.0 / head.scale.y, 1.0 / head.scale.z)
		head.add_child(snout_socket)
		
		var app_length := param_float("snout_appendage_length", 0.4)
		var app_node := PF.snout_appendage(snout_app_type, app_length, head.scale, material)
		snout_socket.add_child(app_node)

	_add_barbel_cluster(head, String(parameters.get("barbel_style", "none")), material, snout_length)
		
	var mouth_position := _mouth_position_for_type(mouth_type, head.scale, snout_length)
	_add_mouth(head, mouth_position, mouth_type, mouth_size, param_float("mouth_open", 0.25), dark_mat)
	if MOUTH_DECOR_ENABLED:
		_add_mouth_detail(head, String(parameters.get("mouth_detail", "dot")), mouth_position, mouth_size, dark_mat)

# The mouth is built as CURVED BANDS that hug the snout surface, not a flat disc pasted on
# the tip. Each band samples the head's front silhouette across the mouth width (z), so its
# x recedes toward the edges and it wraps around the tapering snout. A dark aperture band
# (the opening) is framed by an upper and lower lip band in a darkened body tone (flat,
# unshaded -> defined by colour). mouth_open grows the aperture height for an open look.
# The aperture keeps the node name `Mouth` (MeshInstance3D at mouth_position) so jaw shear
# still rides it and tests keep their handle.
func _add_mouth(head: MeshInstance3D, mouth_position: Vector3, mouth_type: String, mouth_size: float, mouth_open: float, dark_mat: Material) -> void:
	var t := clampf(mouth_open, 0.0, 1.0)
	var angle := _mouth_angle_for_type(mouth_type)
	var my := mouth_position.y

	# Phase 7: drive the gape from the shared jaw linkage so the lower jaw and lower lip rotate
	# by the SAME depression the carve/landmarks use. open_deg is the lower-jaw depression.
	var sculpt := _head_sculpt_params()
	var jaw_lm := HeadProfile.jaw_landmarks(sculpt, t)
	var open_deg: float = rad_to_deg(jaw_lm["gape_angle"])
	# Hinge controls (resolved value = mouth_type seed + user override). Applied as offsets
	# to the lower jaw / cheek hinges so the jaw visibly lengthens (hinge back) or the pivot
	# rides up/down. 0 reproduces the legacy jaw position.
	var jaw_hinge_x_off: float = sculpt["jaw_hinge_x"]
	var jaw_hinge_y_off: float = sculpt["jaw_hinge_y"]
	# Premaxilla protrusion at the current gape (head-local; 0 without protrusion). The lip
	# bands already ride it because they clamp to the protruded head surface; the lower-jaw
	# dome does not, so we extend its front forward by this so the jaws meet as a tube
	# instead of the lower jaw lagging behind the protruded upper jaw.
	var premax_fwd: float = HeadProfile.JAW_SNOUT_FRONT_X - jaw_lm["upper_tip"].x

	var lip_mat := TMF.make_surface(parameters.get("base_color", "#46c6cf"))
	lip_mat.albedo_color = lip_mat.albedo_color.darkened(0.34)

	# Clamp/sample against the ACTUAL head mesh where needed: snout taper / profile make the
	# real surface recede from the radius-0.5 sphere, so a large band that wraps onto those
	# regions would bury. Sampling the built head vertices keeps the decoration honest.
	var head_verts: PackedVector3Array = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	# Shared jaw hinge (local offset behind the mouth node) used by the lower jaw and (when
	# enabled) both lip bands so they pivot about one corner.
	var hinge_x := mouth_size * MOUTH_HINGE_FRAC
	var lower_jaw_scale := _head_lower_jaw_scale()
	var lower_jaw_length := clampf(param_float("lower_jaw_length", 1.0), 0.6, 1.6)
	var lower_jaw_angle := clampf(param_float("lower_jaw_angle", 0.0), -60.0, 60.0)
	var lower_jaw_thickness := clampf(param_float("lower_jaw_thickness", 1.0), 0.5, 1.8)
	var lower_jaw_tip := clampf(param_float("lower_jaw_tip", 0.0), -1.0, 1.0)
	var lower_jaw_open_deg := open_deg - lower_jaw_angle

	# The lower jaw is a wide front face that FILLS the head's carved upper-jaw void when
	# closed - it samples the analytic, un-carved silhouette (clamp_surface = false) from the
	# bite line down to the carve depth, so it sits where the head surface was before the
	# carve. As mouth_open rises it hinges down about the shared hinge, exposing the dark
	# interior. Its width matches the carve so head + jaw read as one closed shape.
	var lower_jaw := MeshInstance3D.new()
	lower_jaw.name = "MouthLowerJaw"
	# The lower jaw drops the full gape so it clears the dark socket (no teal bar across the
	# mouth); it is built shallower (see _mouth_lower_jaw_mesh) so the dropped jaw still reads
	# as a chin/lower lip without swinging far past the round silhouette.
	lower_jaw.mesh = _mouth_lower_jaw_mesh(my, mouth_position, lower_jaw_scale, mouth_size, lower_jaw_open_deg, angle, jaw_hinge_x_off, jaw_hinge_y_off, premax_fwd, lower_jaw_length, lower_jaw_thickness, lower_jaw_tip)
	lower_jaw.material_override = lip_mat
	lower_jaw.position = mouth_position
	head.add_child(lower_jaw)
	jaw_hinge_local = _lower_jaw_hinge_local(mouth_position, lower_jaw_scale, jaw_hinge_x_off, jaw_hinge_y_off)
	jaw_hinge_valid = true

	# Dark mouth patch: a FLAT dark decal on the head's front surface (no volume), revealed as
	# the lower jaw drops in front of it, so the open mouth reads as a dark recess instead of
	# the body-coloured surface. Its height grows with mouth_open. Skipped on a fully closed
	# mouth so it can never show on a shut mouth.
	if t > 0.01:
		# Dark socket lining: fills the real mouth pit the head shell is dented into (same
		# HeadProfile.mouth_pit math), sitting a hair proud of the dented shell so it shows.
		# Because it lives inside a true concavity it reads as depth from any angle and never
		# pokes out of the silhouette. Grows with mouth_open along with the pit.
		# Top edge fixed at the bite line, growing DOWNWARD with gape to follow the lower jaw
		# (must mirror PrimitiveFactory block 6c so the lining sits in the shell's dent).
		var mouth_width_scale := clampf(mouth_size / 0.08, 0.45, 2.2)
		var mouth_depth_scale := lerpf(0.85, 1.25, clampf((mouth_width_scale - 0.65) / 1.55, 0.0, 1.0))
		
		var buffer_y: float = 0.03 * lower_jaw_scale * sqrt(mouth_width_scale)
		var pit_top: float = (jaw_lm["upper_tip"] as Vector2).y + buffer_y
		var pit_bottom: float = (jaw_lm["lower_tip"] as Vector2).y - buffer_y
		var pit_h: float = pit_top - pit_bottom
		var pit_half_h: float = pit_h * 0.5
		var pit_center_y: float = (pit_top + pit_bottom) * 0.5
		var lower_jaw_half_w := PF.UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.72, 1.12, clampf((lower_jaw_scale - 0.45) / 1.35, 0.0, 1.0)) * mouth_width_scale
		var pit_half_w := lower_jaw_half_w * 0.84
		var pit_depth := PF.UPPER_JAW_CARVE_DEPTH * 0.5 * lower_jaw_scale * mouth_depth_scale
		var cavity := MeshInstance3D.new()
		cavity.name = "MouthCavity"
		cavity.mesh = _mouth_pit_dark_mesh(pit_center_y, mouth_position, t, pit_half_h, pit_half_w, pit_depth, angle, head_verts)
		var cavity_mat := dark_mat.duplicate()
		if cavity_mat is BaseMaterial3D:
			cavity_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cavity.material_override = cavity_mat
		cavity.position = mouth_position
		head.add_child(cavity)

		var upper_interior := MeshInstance3D.new()
		upper_interior.name = "MouthUpperInterior"
		upper_interior.mesh = _mouth_upper_interior_mesh(mouth_position, mouth_size, t, lower_jaw_scale, angle, jaw_hinge_x_off, jaw_hinge_y_off, premax_fwd, lower_jaw_length, head_verts)
		var upper_interior_mat := dark_mat.duplicate()
		if upper_interior_mat is BaseMaterial3D:
			upper_interior_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		upper_interior.material_override = upper_interior_mat
		upper_interior.position = mouth_position
		head.add_child(upper_interior)

		var side_aperture := MeshInstance3D.new()
		side_aperture.name = "MouthSideAperture"
		side_aperture.mesh = _mouth_side_aperture_mesh(mouth_position, mouth_size, t, lower_jaw_scale, angle, jaw_hinge_x_off, jaw_hinge_y_off, premax_fwd, lower_jaw_length, head_verts)
		var side_aperture_mat := dark_mat.duplicate()
		if side_aperture_mat is BaseMaterial3D:
			side_aperture_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		side_aperture.material_override = side_aperture_mat
		side_aperture.position = mouth_position
		head.add_child(side_aperture)

		# Dark mouth floor: a dark lining over the lower jaw's upper (inner) face that HINGES
		# down with the jaw (same open angle/hinge), so the mouth interior is dark on the floor
		# too, not just the roof. A shallower dome nested just above the jaw's inner surface.
		var floor := MeshInstance3D.new()
		floor.name = "MouthFloor"
		floor.mesh = _mouth_lower_jaw_mesh(my, mouth_position, lower_jaw_scale * 0.82, mouth_size, lower_jaw_open_deg, angle, jaw_hinge_x_off, jaw_hinge_y_off, premax_fwd, lower_jaw_length, lower_jaw_thickness, lower_jaw_tip)
		var floor_mat := dark_mat.duplicate()
		if floor_mat is BaseMaterial3D:
			floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		floor.material_override = floor_mat
		floor.position = mouth_position + Vector3(0.0, PF.UPPER_JAW_CARVE_DEPTH * lower_jaw_scale * 0.06, 0.0)
		head.add_child(floor)

	if not MOUTH_DECOR_ENABLED:
		return

	var upper_open_y := mouth_size * 0.05
	var lower_open_y := mouth_size * lerpf(0.05, 0.62, t)
	var lip_h := mouth_size * 0.28
	var z_half := mouth_size * 0.95

	# Closed-mouth dark slit. Once the mouth opens, the true concave MouthCavity and
	# MouthFloor own the interior shadow; keeping this surface decal would darken the upper
	# jaw face and, on long tapered snouts, read as a torn patch.
	if t <= 0.01:
		var mouth := MeshInstance3D.new()
		mouth.name = "Mouth"
		mouth.mesh = _mouth_band_mesh(my, mouth_position, -lower_open_y, upper_open_y, z_half, mouth_size * 0.03, 0.0, 0.0, angle, true, head_verts)
		mouth.material_override = dark_mat
		mouth.position = mouth_position
		head.add_child(mouth)

	# Only the upper lip remains as a thin frame on the snout above the mouth; the lower lip is
	# the separate lower-jaw mesh (a teal band inside the dark socket read as a bar, so it was
	# dropped in favour of the jaw + dark pit).
	var jaws := [
		{"name": "MouthLipUpper", "lo": upper_open_y, "hi": upper_open_y + lip_h, "open": 0.0},
	]
	var upper_lip_recess_x := maxf(mouth_size - 0.08, 0.0) * 0.28
	for jw in jaws:
		var lip := MeshInstance3D.new()
		lip.name = String(jw["name"])
		lip.mesh = _mouth_band_mesh(my, mouth_position, float(jw["lo"]), float(jw["hi"]), z_half * 0.98, mouth_size * 0.06, hinge_x, float(jw["open"]), angle, true, head_verts, 10, upper_lip_recess_x)
		lip.material_override = lip_mat
		lip.position = mouth_position
		head.add_child(lip)

# Builds a thin ribbon that follows the head's front silhouette across the mouth width, so
# the mouth curves around the snout instead of sitting flat. Coordinates are local to
# `origin` (the mouth node). The jaw open rotation (`open_deg` about a z-hinge `hinge_x`
# behind the mouth) and the mouth-type tilt (`tilt_deg` about the origin) are baked in; when
# `clamp_surface` is set, each vertex is pulled forward so it never sinks behind the head
# front surface (the jaw slides along the snout as it gapes instead of burying into it).
func _mouth_band_mesh(center_y: float, origin: Vector3, y_lo: float, y_hi: float, z_half: float, outset: float, hinge_x: float = 0.0, open_deg: float = 0.0, tilt_deg: float = 0.0, clamp_surface: bool = false, head_verts: PackedVector3Array = PackedVector3Array(), z_segs: int = 10, recess_x: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hinge_world_x := origin.x + hinge_x
	var open_r := deg_to_rad(open_deg)
	var tilt_r := deg_to_rad(tilt_deg)
	var rows: Array[float] = [y_lo, y_hi]
	var grid := []
	for ry in rows:
		var line := []
		for j in range(z_segs + 1):
			var z := lerpf(-z_half, z_half, float(j) / float(z_segs))
			var ay: float = center_y + ry
			var p := Vector3(_head_front_surface_x(ay, z, outset), ay, z)
			if open_r != 0.0:
				var dx := p.x - hinge_world_x
				var dy := p.y - center_y
				p.x = hinge_world_x + dx * cos(open_r) - dy * sin(open_r)
				p.y = center_y + dx * sin(open_r) + dy * cos(open_r)
			if tilt_r != 0.0:
				var tx := p.x - origin.x
				var ty := p.y - origin.y
				p.x = origin.x + tx * cos(tilt_r) - ty * sin(tilt_r)
				p.y = origin.y + tx * sin(tilt_r) + ty * cos(tilt_r)
			if clamp_surface:
				p.x = _head_mesh_front_x(head_verts, p.y, p.z, outset)
			p.x += recess_x
			line.append(p - origin)
		grid.append(line)
	for j in range(z_segs):
		var p00: Vector3 = grid[0][j]
		var p01: Vector3 = grid[0][j + 1]
		var p10: Vector3 = grid[1][j]
		var p11: Vector3 = grid[1][j + 1]
		st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
		st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

# Dark socket lining for the real mouth pit. Samples a fine grid over the mouth region on the
# analytic head front, applies the SAME HeadProfile.mouth_pit dent (a hair shallower so it sits
# just proud of the dented shell), and emits it dark. Smooth (analytic, no nearest-vertex
# jaggies), recessed (lives in the pit, never pokes out), and grows with gape.
func _mouth_pit_dark_mesh(center_y: float, origin: Vector3, gape_t: float, half_h: float, half_w: float, depth: float, tilt_deg: float, head_verts: PackedVector3Array = PackedVector3Array(), rows: int = 8, cols: int = 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt_r := deg_to_rad(tilt_deg)
	var g := clampf(gape_t, 0.0, 1.0)
	var top := center_y + half_h
	var bottom := center_y - half_h

	# Fetch sculpt params and calculate protrusion parameters to match PrimitiveFactory.gd
	var sculpt := _head_sculpt_params()
	var lower_jaw_scale: float = sculpt["lower_jaw_scale"]
	var mouth_center_y: float = sculpt["mouth_center_y"]
	var mouth_size_scale := clampf(float(sculpt.get("mouth_size", 0.08)) / 0.08, 0.65, 2.2)
	var upper_carve_size_scale := lerpf(0.75, 1.35, clampf((mouth_size_scale - 0.65) / 1.55, 0.0, 1.0))
	var shape := String(parameters.get("head_shape", "rounded"))

	var jaw_lm := HeadProfile.jaw_landmarks(sculpt, g)
	var premax_fwd: float = HeadProfile.JAW_SNOUT_FRONT_X - jaw_lm["upper_tip"].x
	var shift := _snout_tip_displacement()

	var sample := func(ay: float, az: float) -> Vector3:
		# 1. Unshift y to get the correct base coordinate on the sphere before snout curve/shift
		var ay_unshifted := ay - shift
		var base_x := _head_front_surface_x(ay_unshifted, az, 0.0)
		
		# 2. Get the base sphere 'u' coordinate (matching PrimitiveFactory.gd line 79)
		var x_sq := maxf(0.25 - ay_unshifted * ay_unshifted - az * az, 0.0)
		var x_sphere := -sqrt(x_sq)
		var u_base := x_sphere + 0.5
		
		# 3. Apply Upper-Jaw Carve (mirrors PrimitiveFactory.gd lines 145-154)
		var cx := base_x
		var cy := ay
		if shape != "cephalofoil" and cx < 0.04:
			var front_w := smoothstep(PF.UPPER_JAW_CARVE_LENGTH, 0.0, u_base)
			var carve_depth := PF.UPPER_JAW_CARVE_DEPTH * lower_jaw_scale * upper_carve_size_scale
			var carve_half_width := PF.UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.82, 1.12, clampf((lower_jaw_scale - 0.45) / 1.35, 0.0, 1.0)) * upper_carve_size_scale
			var lower_edge := mouth_center_y - carve_depth
			var lower_w := smoothstep(mouth_center_y + 0.04, lower_edge, cy)
			var center_w := 1.0 - clampf(absf(az) / carve_half_width, 0.0, 1.0)
			var carve_w := front_w * lower_w * center_w
			cx += PF.UPPER_JAW_CARVE_BACK * lower_jaw_scale * upper_carve_size_scale * carve_w
			cy += PF.UPPER_JAW_CARVE_UP * lower_jaw_scale * upper_carve_size_scale * carve_w
			
		# 4. Apply Premaxilla Protrusion (mirrors PrimitiveFactory.gd lines 159-160)
		if shape != "cephalofoil" and premax_fwd > 0.0 and cx < 0.1:
			cx -= premax_fwd * smoothstep(PF.UPPER_JAW_CARVE_LENGTH, 0.0, u_base)
			
		# 5. Apply Real Mouth Pit Offset (mirrors PrimitiveFactory.gd lines 166-178)
		var off := HeadProfile.mouth_pit_offset(u_base, cy, az, center_y, half_h, half_w, depth * 0.85, g)
		var p := Vector3(cx + off.x - 0.004, cy + off.y, az + off.z)
		if not head_verts.is_empty():
			p.x = minf(p.x, _head_mesh_front_x(head_verts, p.y, p.z, 0.006))

		if tilt_r != 0.0:
			var tx := p.x - origin.x
			var ty := p.y - origin.y
			p.x = origin.x + tx * cos(tilt_r) - ty * sin(tilt_r)
			p.y = origin.y + tx * sin(tilt_r) + ty * cos(tilt_r)
		return p - origin
	var grid := []
	for i in range(rows + 1):
		var ay := lerpf(top, bottom, float(i) / float(rows))
		# Taper the width toward the top/bottom rows so the socket reads as a rounded oval
		# instead of a hard-edged rectangle.
		var ev := (ay - center_y) / maxf(half_h, 0.001)
		var row_w := half_w * sqrt(maxf(1.0 - ev * ev, 0.0))
		var line := []
		for j in range(cols + 1):
			var az := lerpf(-row_w, row_w, float(j) / float(cols))
			line.append(sample.call(ay, az))
		grid.append(line)
	for i in range(rows):
		for j in range(cols):
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j + 1]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

func _mouth_upper_interior_mesh(origin: Vector3, mouth_size: float, gape_t: float, jaw_scale: float, tilt_deg: float, hinge_x_off: float = 0.0, hinge_y_off: float = 0.0, front_extend: float = 0.0, length_scale: float = 1.0, head_verts: PackedVector3Array = PackedVector3Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := clampf(gape_t, 0.0, 1.0)
	var hinge_pt := _lower_jaw_hinge_local(origin, jaw_scale, hinge_x_off, hinge_y_off)
	var rear_x := hinge_pt.x - 0.025
	var front_x := origin.x - front_extend * 0.25 + mouth_size * 0.03
	var length_mul := clampf(length_scale, 0.6, 1.6)
	rear_x = front_x + (rear_x - front_x) * length_mul
	rear_x = maxf(rear_x, front_x + mouth_size * 1.35)
	var top_front_y := origin.y + mouth_size * 0.08
	var top_rear_y := origin.y + mouth_size * 0.02
	var bottom_front_y := origin.y - mouth_size * lerpf(0.34, 0.76, g)
	var bottom_rear_y := origin.y - mouth_size * lerpf(0.22, 0.54, g)
	var half_z := maxf(mouth_size * 0.18, 0.018)
	var tilt_r := deg_to_rad(tilt_deg)
	var rows := 4
	var cols := 4
	var grid := []
	for i in range(rows + 1):
		var v := float(i) / float(rows)
		var x := lerpf(front_x, rear_x, v)
		var top_y := lerpf(top_front_y, top_rear_y, v)
		var bottom_y := lerpf(bottom_front_y, bottom_rear_y, v)
		var line := []
		for j in range(cols + 1):
			var h := float(j) / float(cols)
			var y := lerpf(top_y, bottom_y, h)
			var side := (h - 0.5) * 2.0
			var z := side * half_z * sin(PI * v)
			var p := Vector3(x, y, z)
			if not head_verts.is_empty():
				p.x = minf(p.x, _head_mesh_front_x(head_verts, p.y, p.z, 0.006))
			if tilt_r != 0.0:
				p = _rotate_mouth_point(p, origin, tilt_r)
			line.append(p - origin)
		grid.append(line)
	for i in range(rows):
		for j in range(cols):
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j + 1]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

func _mouth_side_aperture_mesh(origin: Vector3, mouth_size: float, gape_t: float, jaw_scale: float, tilt_deg: float, hinge_x_off: float = 0.0, hinge_y_off: float = 0.0, front_extend: float = 0.0, length_scale: float = 1.0, head_verts: PackedVector3Array = PackedVector3Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g := clampf(gape_t, 0.0, 1.0)
	var front_x := origin.x - front_extend * 0.22 + mouth_size * 0.02
	var rear_x := front_x + mouth_size * 0.72 * clampf(length_scale, 0.7, 1.25)
	var top_front_y := origin.y + mouth_size * 0.07
	var bottom_front_y := origin.y - mouth_size * lerpf(0.30, 0.74, g)
	var rear_mid_y := origin.y - mouth_size * lerpf(0.08, 0.18, g)
	var tilt_r := deg_to_rad(tilt_deg)
	var rows := 5
	var cols := 5
	for side in [-1.0, 1.0]:
		var grid := []
		for i in range(rows + 1):
			var v := float(i) / float(rows)
			var rear_fade := pow(v, 1.4)
			var x := lerpf(front_x, rear_x, v)
			var top_y := lerpf(top_front_y, rear_mid_y + mouth_size * 0.018, rear_fade)
			var bottom_y := lerpf(bottom_front_y, rear_mid_y - mouth_size * 0.018, rear_fade)
			var line := []
			for j in range(cols + 1):
				var h := float(j) / float(cols)
				var y := lerpf(top_y, bottom_y, h)
				var p := Vector3(x, y, _head_mesh_side_z(head_verts, x, y, side, 0.012))
				if tilt_r != 0.0:
					p = _rotate_mouth_point(p, origin, tilt_r)
				line.append(p - origin)
			grid.append(line)
		for i in range(rows):
			for j in range(cols):
				var p00: Vector3 = grid[i][j]
				var p01: Vector3 = grid[i][j + 1]
				var p10: Vector3 = grid[i + 1][j]
				var p11: Vector3 = grid[i + 1][j + 1]
				if side > 0.0:
					st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
					st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
				else:
					st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p10)
					st.add_vertex(p01); st.add_vertex(p11); st.add_vertex(p10)
	st.generate_normals()
	return st.commit()

func _mouth_lower_jaw_mesh(center_y: float, origin: Vector3, jaw_scale: float, mouth_size: float, open_deg: float, tilt_deg: float = 0.0, hinge_x_off: float = 0.0, hinge_y_off: float = 0.0, front_extend: float = 0.0, length_scale: float = 1.0, thickness_scale: float = 1.0, tip_shape: float = 0.0, ring_count: int = 7, segments: int = 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var scale := clampf(jaw_scale, 0.45, 1.8)
	var width_scale := clampf(mouth_size / 0.08, 0.45, 2.2)
	var thickness := clampf(thickness_scale, 0.5, 1.8)
	var tip := clampf(tip_shape, -1.0, 1.0)
	var depth := PF.UPPER_JAW_CARVE_DEPTH * scale * 1.2 * thickness
	var z_radius := PF.UPPER_JAW_CARVE_HALF_WIDTH * lerpf(0.72, 1.12, clampf((scale - 0.45) / 1.35, 0.0, 1.0)) * width_scale
	# hinge_x_off lengthens the jaw (hinge further back -> bigger x_radius); hinge_y_off
	# raises/lowers the whole jaw with its pivot. Phase 7 jaw_hinge_x/_y controls. The pivot
	# comes from the shared helper so the editor's hinge marker lands on the real pivot.
	var hinge_pt := _lower_jaw_hinge_local(origin, jaw_scale, hinge_x_off, hinge_y_off)
	var top_y := hinge_pt.y
	# front_extend reaches the jaw tip forward (toward the protruded premaxilla) while the
	# hinge stays fixed, so the lower jaw lengthens into the tube rather than translating.
	var hinge_x := hinge_pt.x
	var base_front_x := origin.x - 0.045 - front_extend
	var front_x := hinge_x - (hinge_x - base_front_x) * clampf(length_scale, 0.6, 1.6)
	var center_x := (front_x + hinge_x) * 0.5
	var x_radius := maxf((hinge_x - front_x) * 0.5, 0.18)
	var hinge := Vector3(hinge_x, top_y, 0.0)
	var open_r := deg_to_rad(open_deg)
	var tilt_r := deg_to_rad(tilt_deg)
	var top_center := Vector3(center_x, top_y, 0.0)
	if open_r != 0.0:
		var cdx := top_center.x - hinge.x
		var cdy := top_center.y - hinge.y
		top_center.x = hinge.x + cdx * cos(open_r) - cdy * sin(open_r)
		top_center.y = hinge.y + cdx * sin(open_r) + cdy * cos(open_r)
	if tilt_r != 0.0:
		top_center = _rotate_mouth_point(top_center, origin, tilt_r)
	var grid := []
	for i in range(ring_count + 1):
		var a := (PI * 0.5) * float(i) / float(ring_count)
		var row_radius := cos(a)
		var y := top_y - depth * sin(a)
		var row := []
		for j in range(segments + 1):
			var theta := TAU * float(j) / float(segments)
			var base_x_offset := x_radius * row_radius * cos(theta)
			var front_t := clampf((center_x + base_x_offset - front_x) / maxf(hinge_x - front_x, 0.001), 0.0, 1.0)
			var pointed_w := lerpf(0.22, 1.0, pow(front_t, 0.65))
			var blunt_w := lerpf(1.28, 1.0, pow(front_t, 1.8))
			var tip_w := lerpf(1.0, pointed_w, -tip) if tip < 0.0 else lerpf(1.0, blunt_w, tip)
			var x_tip_push := (1.0 - front_t) * maxf(tip, 0.0) * x_radius * 0.16
			var p := Vector3(center_x + base_x_offset + x_tip_push, y, z_radius * row_radius * sin(theta) * tip_w)
			if open_r != 0.0:
				var dx := p.x - hinge.x
				var dy := p.y - hinge.y
				p.x = hinge.x + dx * cos(open_r) - dy * sin(open_r)
				p.y = hinge.y + dx * sin(open_r) + dy * cos(open_r)
			if tilt_r != 0.0:
				p = _rotate_mouth_point(p, origin, tilt_r)
			row.append(p - origin)
		grid.append(row)
	for j in range(segments):
		st.add_vertex(top_center - origin)
		st.add_vertex(grid[0][j + 1])
		st.add_vertex(grid[0][j])
	for i in range(ring_count):
		for j in range(segments):
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j + 1]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p01); st.add_vertex(p10); st.add_vertex(p11)
	st.generate_normals()
	return st.commit()

func _rotate_mouth_point(p: Vector3, origin: Vector3, tilt_r: float) -> Vector3:
	var tx := p.x - origin.x
	var ty := p.y - origin.y
	p.x = origin.x + tx * cos(tilt_r) - ty * sin(tilt_r)
	p.y = origin.y + tx * sin(tilt_r) + ty * cos(tilt_r)
	return p

# Local front-surface x at (y, z), read from the REAL deformed head mesh (taper / profile /
# jaw-shear included) so the mouth clamps onto the actual skin, not the analytic sphere. Uses
# the FRONT vertex (x < 0.25) closest in the (y, z) plane - the local surface, not the most
# forward neighbour, which would sit proud of a receding snout and let the mouth bury. Returns
# that x minus `outset` so the mouth sits just proud of the skin.
func _head_mesh_front_x(verts: PackedVector3Array, y: float, z: float, outset: float) -> float:
	var best_d := INF
	var best_x := INF
	for v in verts:
		if v.x > 0.25:
			continue # ignore the back hemisphere
		var dy := v.y - y
		var dz := v.z - z
		var d := dy * dy + dz * dz
		if d < best_d:
			best_d = d
			best_x = v.x
	if best_x == INF:
		return _head_front_surface_x(y, z, outset)
	return best_x - outset

func _head_mesh_side_z(verts: PackedVector3Array, x: float, y: float, side: float, outset: float, max_sample_x: float = 0.25) -> float:
	var best_d := INF
	var best_z := 0.0
	for v in verts:
		if side > 0.0 and v.z < 0.0:
			continue
		if side < 0.0 and v.z > 0.0:
			continue
		if v.x > max_sample_x:
			continue
		var dx := v.x - x
		var dy := v.y - y
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best_z = v.z
	if best_d == INF:
		return side * _head_side_surface_z(x, y, outset)
	return best_z + side * outset

func _head_side_surface_z(local_x: float, local_y: float, outset: float = 0.025) -> float:
	var radius := 0.5
	var z_sq := maxf(radius * radius - local_x * local_x - local_y * local_y, 0.0)
	return sqrt(z_sq) + outset

func _head_top_surface_y(local_x: float, local_z: float, outset: float = 0.025) -> float:
	var radius := 0.5
	var y_sq := maxf(radius * radius - local_x * local_x - local_z * local_z, 0.0)
	return sqrt(y_sq) + outset

func _head_front_surface_x(local_y: float, local_z: float, outset: float = 0.025) -> float:
	# Front-most x of the head silhouette at (local_y, local_z), accounting for the
	# snout stretch so mouths/sockets stay anchored to the real deformed snout tip
	# instead of a plain radius-0.5 sphere.
	var radius := 0.5
	var x_sq := maxf(radius * radius - local_y * local_y - local_z * local_z, 0.0)
	var x_base := -sqrt(x_sq)
	if String(parameters.get("head_shape", "rounded")) != "cephalofoil":
		var snout_length := param_float("snout_length", 0.0)
		var snout_base := param_float("snout_base", HeadProfile.SNOUT_BLEND_HALF)
		x_base -= HeadProfile.snout_forward_x_shift(snout_length, x_base + 0.5, snout_base)
	return x_base - outset

func _add_head_ornament(head: MeshInstance3D, ornament: String, material: Material) -> void:
	if ornament == "none" or ornament == "":
		return
	var root := Node3D.new()
	root.name = "HeadOrnament_%s" % ornament
	head.add_child(root)
	match ornament:
		"wen":
			var lobe_positions := [
				Vector3(-0.18, 0.24, 0.0),
				Vector3(-0.10, 0.30, -0.08),
				Vector3(-0.10, 0.30, 0.08),
				Vector3(0.02, 0.27, -0.10),
				Vector3(0.02, 0.27, 0.10),
				Vector3(0.12, 0.20, -0.06),
				Vector3(0.12, 0.20, 0.06)
			]
			for i in lobe_positions.size():
				var lobe := PF.ellipsoid("WenLobe%d" % i, Vector3(0.09, 0.07, 0.07), material)
				var lobe_position: Vector3 = lobe_positions[i]
				lobe_position.y = _head_top_surface_y(lobe_position.x, lobe_position.z, 0.035)
				lobe.position = lobe_position
				root.add_child(lobe)
		"nuchal_hump", "forehead_bump":
			var hump := PF.ellipsoid("ForeheadMass", Vector3(0.18, 0.18, 0.14), material)
			hump.position = Vector3(-0.10, _head_top_surface_y(-0.10, 0.0, 0.055), 0.0)
			root.add_child(hump)
		"cheek_pad":
			for side in [-1.0, 1.0]:
				var pad := PF.ellipsoid("CheekPad%s" % ("L" if side < 0.0 else "R"), Vector3(0.10, 0.08, 0.05), material)
				var pad_x := -0.16
				var pad_y := -0.03
				pad.position = Vector3(pad_x, pad_y, side * _head_side_surface_z(pad_x, pad_y, 0.03))
				root.add_child(pad)

func _add_gill_mark(head: MeshInstance3D, mark: String, seam_mat: Material) -> void:
	if mark == "none" or mark == "":
		return
	# Operculum is a real flap anchored to the body shell surface (not the head
	# sphere), so it lives under body_pivot, not the head node. Handled separately.
	if mark == "operculum":
		_add_operculum_flaps(head.material_override, seam_mat)
		return
	if not ["line", "crescent", "plate"].has(mark):
		return
	var root := Node3D.new()
	root.name = "GillMark_%s" % mark
	head.add_child(root)
	match mark:
		"line":
			for side in [-1.0, 1.0]:
				var line_x := 0.18
				var line_y := 0.02
				var line := PF.cylinder("GillLine%s" % ("L" if side < 0.0 else "R"), 0.009, 0.24, seam_mat)
				line.position = Vector3(line_x, line_y, side * _head_side_surface_z(line_x, line_y, 0.04))
				line.rotation_degrees.x = 6.0 * side
				root.add_child(line)
		"crescent":
			for side in [-1.0, 1.0]:
				for i in range(3):
					var dash_x := 0.15 + float(i) * 0.025
					var dash_y := 0.07 - float(i) * 0.065
					var dash := PF.cylinder("GillCrescent%s_%d" % [("L" if side < 0.0 else "R"), i], 0.008, 0.12, seam_mat)
					dash.position = Vector3(dash_x, dash_y, side * _head_side_surface_z(dash_x, dash_y, 0.04))
					dash.rotation_degrees.z = -18.0 + float(i) * 18.0
					root.add_child(dash)
		"plate":
			for side in [-1.0, 1.0]:
				var plate_x := 0.18
				var plate_y := 0.0
				var plate := PF.ellipsoid("GillPlate%s" % ("L" if side < 0.0 else "R"), Vector3(0.045, 0.17, 0.018), seam_mat)
				plate.position = Vector3(plate_x, plate_y, side * _head_side_surface_z(plate_x, plate_y, 0.04))
				root.add_child(plate)

# Operculum (gill cover) as a real flap, built in body_pivot space hugging the
# outer shell's egg cross-section at the gill region (~14-24% back). The front
# (preopercle hinge) sits just proud of the shell and the rear free margin lifts
# further off it, so the trailing edge reads as a true silhouette step with a
# dark gill opening tucked underneath. Anchoring to the shell (not the head
# sphere) keeps it from being buried, since the shell is the widest surface here.
func _add_operculum_flaps(body_material: Material, dark_material: Material) -> void:
	if body_pivot == null:
		return
	var root := Node3D.new()
	root.name = "GillMark_operculum"
	body_pivot.add_child(root)
	var op_len := clampf(float(parameters.get("operculum_size", 1.0)), 0.5, 1.5)
	var op_h := clampf(float(parameters.get("operculum_height", 1.0)), 0.5, 1.5)
	var op_open := clampf(float(parameters.get("operculum_open", 0.0)), 0.0, 1.0)
	var op_ridge := clampf(float(parameters.get("operculum_ridge", 0.45)), 0.0, 1.0)
	var lift := 0.012 + 0.03 * op_open
	for side in [-1.0, 1.0]:
		root.add_child(_build_operculum_flap(
			"OperculumFlap%s" % ("L" if side < 0.0 else "R"),
			side, op_len, op_h, lift, op_ridge, body_material, dark_material))

func _build_operculum_flap(flap_name: String, side: float, length: float, height: float, lift: float, ridge: float, body_material: Material, dark_material: Material) -> MeshInstance3D:
	var center_t := 0.19
	var half_t := 0.05 * length
	var t_front := maxf(center_t - half_t, 0.02)
	var t_rear := center_t + half_t
	var vfrac_max := 0.62 * height
	var sgn := -1.0 if side < 0.0 else 1.0

	# Optional hand-drawn silhouette (normalized side-view outline). When present,
	# the flap follows the polygon's top/bottom edge per column (smooth, not a
	# blocky grid mask) and size/height still scale it. No points -> parametric band.
	var raw_points: Array = parameters.get("operculum_custom_points", [])
	var poly := PackedVector2Array()
	for k in range(0, raw_points.size() - 1, 2):
		poly.append(Vector2(float(raw_points[k]), float(raw_points[k + 1])))
	var use_outline := poly.size() >= 3

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if use_outline:
		# Row sweep: at each height v the flap spans the polygon's longitudinal
		# extent [u_min(v), u_max(v)]. The rear edge u_max(v) is the SAME scan the
		# gill-opening uses, so flap and opening always agree (incl. concave edits).
		# Fine nv -> smooth front/rear curves; nu cols carry the rear lift gradient.
		var v_lo := INF
		var v_hi := -INF
		for p in poly:
			v_lo = minf(v_lo, p.y)
			v_hi = maxf(v_hi, p.y)
		var nv := 48
		var nu := 12
		var valid := []
		var rverts := []
		var ruvs := []
		for r in range(nv + 1):
			var v := lerpf(v_lo, v_hi, float(r) / float(nv))
			var uspan := _operculum_poly_u_span(poly, v)
			if uspan.y < uspan.x:
				valid.append(false)
				rverts.append([])
				ruvs.append([])
				continue
			var f := clampf(v * vfrac_max, -0.985, 0.985)
			var uvy := asin(f) / TAU
			if uvy < 0.0:
				uvy += 1.0
			var verts := []
			var uvs := []
			for c in range(nu + 1):
				var u := lerpf(uspan.x, uspan.y, float(c) / float(nu))
				# Front hinge flush on the shell; only the rear free margin lifts off (no float).
				var out := 0.002 + (0.012 + lift) * smoothstep(0.05, 1.0, u)
				verts.append(_op_shell_point(u, f, t_front, t_rear, sgn, out))
				uvs.append(Vector2(lerpf(t_front, t_rear, u), uvy))
			valid.append(true)
			rverts.append(verts)
			ruvs.append(uvs)
		for r in nv:
			if valid[r] and valid[r + 1]:
				for c in nu:
					_op_quad(st, [rverts[r], rverts[r + 1]], [ruvs[r], ruvs[r + 1]], 0, c, 1)
	else:
		var ns := 12
		var nt := 10
		var grid := []
		var ugrid := []
		for i in range(ns + 1):
			var u := float(i) / float(ns)
			var at_t := lerpf(t_front, t_rear, u)
			var env := lerpf(0.82, 1.0, smoothstep(0.0, 0.6, u))
			# Front hinge sits flush on the shell (tiny epsilon avoids z-fighting);
			# only the rear free margin lifts off, so it never floats in front/rear view.
			var out := 0.002 + (0.012 + lift) * smoothstep(0.05, 1.0, u)
			var sample := _sample_shell_profile(at_t)
			var cy := _sample_shell_center_y(at_t)
			var prow := []
			var urow := []
			for j in range(nt + 1):
				var tv := lerpf(-1.0, 1.0, float(j) / float(nt))
				var f := clampf(tv * env * vfrac_max, -0.985, 0.985)
				var y := cy + f * sample.y
				var zfrac := sqrt(maxf(1.0 - f * f, 0.0))
				prow.append(Vector3(sample.x, y, (sample.z * zfrac + out) * sgn))
				var uvy := asin(f) / TAU
				if uvy < 0.0:
					uvy += 1.0
				urow.append(Vector2(at_t, uvy))
			grid.append(prow)
			ugrid.append(urow)
		for i in ns:
			for j in nt:
				_op_quad(st, grid, ugrid, i, j)
	st.generate_normals()

	var node := MeshInstance3D.new()
	node.name = flap_name
	node.mesh = st.commit()
	node.material_override = body_material
	if use_outline:
		node.add_child(_build_operculum_opening_outline("%s_Opening" % flap_name, side, poly, t_front, t_rear, vfrac_max, dark_material))
	else:
		node.add_child(_build_operculum_opening("%s_Opening" % flap_name, side, t_rear, ridge, vfrac_max, dark_material))
	return node

# U-extent [u_min, u_max] of the outline polygon at vertical v (horizontal scan).
# u_max is the rear (trailing) edge. Returns y<x sentinel when v is outside.
func _operculum_poly_u_span(poly: PackedVector2Array, v: float) -> Vector2:
	var n := poly.size()
	var umin := INF
	var umax := -INF
	var hits := 0
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		if (a.y <= v) != (b.y <= v):
			var x := a.x + (v - a.y) / (b.y - a.y) * (b.x - a.x)
			umin = minf(umin, x)
			umax = maxf(umax, x)
			hits += 1
	if hits < 2:
		return Vector2(1.0, -1.0)
	return Vector2(umin, umax)

func _op_shell_point(u: float, f: float, t_front: float, t_rear: float, sgn: float, outset: float) -> Vector3:
	var at_t := lerpf(t_front, t_rear, u)
	var sample := _sample_shell_profile(at_t)
	var cy := _sample_shell_center_y(at_t)
	var zfrac := sqrt(maxf(1.0 - f * f, 0.0))
	return Vector3(sample.x, cy + f * sample.y, (sample.z * zfrac + outset) * sgn)

# Dark gill opening that traces the silhouette's trailing (rear) edge top-to-bottom:
# for each height v across the outline's full vertical extent we find the rear-most
# x and lay a thin dark strip just behind it. So it spans the whole free margin and
# reshapes with the silhouette instead of collapsing to a narrow rear column.
func _build_operculum_opening_outline(open_name: String, side: float, poly: PackedVector2Array, t_front: float, t_rear: float, vfrac_max: float, dark_material: Material) -> MeshInstance3D:
	var sgn := -1.0 if side < 0.0 else 1.0
	var v_lo := INF
	var v_hi := -INF
	for p in poly:
		v_lo = minf(v_lo, p.y)
		v_hi = maxf(v_hi, p.y)
	var nt := 16
	var valid := []
	var inner := []
	var outer := []
	for r in range(nt + 1):
		var v := lerpf(v_lo, v_hi, float(r) / float(nt))
		var uspan := _operculum_poly_u_span(poly, v)
		if uspan.y < uspan.x:
			valid.append(false)
			inner.append(Vector3.ZERO)
			outer.append(Vector3.ZERO)
			continue
		var f := clampf(v * vfrac_max, -0.985, 0.985)
		var u_edge: float = uspan.y
		inner.append(_op_shell_point(clampf(u_edge - 0.03, 0.0, 1.5), f, t_front, t_rear, sgn, 0.010))
		outer.append(_op_shell_point(u_edge + 0.05, f, t_front, t_rear, sgn, 0.010))
		valid.append(true)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in nt:
		if valid[r] and valid[r + 1]:
			_op_quad(st, [[inner[r], inner[r + 1]], [outer[r], outer[r + 1]]], [], 0, 0, 1)
	st.generate_normals()

	var node := MeshInstance3D.new()
	node.name = open_name
	node.mesh = st.commit()
	node.material_override = dark_material
	return node

# Thin dark strip on the shell surface just under the lifted free edge, reading
# as the gill opening.
func _build_operculum_opening(open_name: String, side: float, t_rear: float, ridge: float, vfrac_max: float, dark_material: Material) -> MeshInstance3D:
	var nt := 10
	var sgn := -1.0 if side < 0.0 else 1.0
	var cols := [t_rear - (0.02 + 0.02 * ridge), t_rear + 0.006]
	var grid := []
	for c in range(2):
		var at_t: float = cols[c]
		var sample := _sample_shell_profile(at_t)
		var cy := _sample_shell_center_y(at_t)
		var col := []
		for j in range(nt + 1):
			var tv := lerpf(-1.0, 1.0, float(j) / float(nt))
			var f := clampf(tv * vfrac_max, -0.985, 0.985)
			var y := cy + f * sample.y
			var zfrac := sqrt(maxf(1.0 - f * f, 0.0))
			col.append(Vector3(sample.x, y, (sample.z * zfrac + 0.010) * sgn))
		grid.append(col)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nt:
		_op_quad(st, grid, [], 0, j, 1)
	st.generate_normals()

	var node := MeshInstance3D.new()
	node.name = open_name
	node.mesh = st.commit()
	node.material_override = dark_material
	return node

# Emits one grid quad as 4 triangles (double-sided) so winding/backface culling
# can never hide the flap. UVs are optional (pass empty ugrid + col_a/col_b for a
# 2-column strip). Body shading is flat/unshaded so averaged normals are fine.
func _op_quad(st: SurfaceTool, grid: Array, ugrid: Array, i: int, j: int, i_next: int = -1) -> void:
	var ib := i + 1 if i_next < 0 else i_next
	var p00: Vector3 = grid[i][j]
	var p01: Vector3 = grid[i][j + 1]
	var p10: Vector3 = grid[ib][j]
	var p11: Vector3 = grid[ib][j + 1]
	var has_uv := not ugrid.is_empty()
	var u00: Vector2 = ugrid[i][j] if has_uv else Vector2.ZERO
	var u01: Vector2 = ugrid[i][j + 1] if has_uv else Vector2.ZERO
	var u10: Vector2 = ugrid[ib][j] if has_uv else Vector2.ZERO
	var u11: Vector2 = ugrid[ib][j + 1] if has_uv else Vector2.ZERO
	# front
	_op_v(st, u00, p00); _op_v(st, u10, p10); _op_v(st, u01, p01)
	_op_v(st, u10, p10); _op_v(st, u11, p11); _op_v(st, u01, p01)
	# back
	_op_v(st, u00, p00); _op_v(st, u01, p01); _op_v(st, u10, p10)
	_op_v(st, u10, p10); _op_v(st, u01, p01); _op_v(st, u11, p11)

func _op_v(st: SurfaceTool, uv: Vector2, p: Vector3) -> void:
	st.set_uv(uv)
	st.set_uv2(uv)
	st.add_vertex(p)

func _add_barbel_cluster(head: MeshInstance3D, style: String, material: Material, snout_length: float) -> void:
	if style == "none" or style == "":
		return
	var root := Node3D.new()
	root.name = "BarbelCluster_%s" % style
	root.position = Vector3(-0.48 - snout_length * 0.18, -0.12 + _snout_tip_displacement(), 0.0)
	head.add_child(root)
	var specs := []
	match style:
		"koi":
			specs = [[-1.0, 0.18, -24.0], [1.0, 0.18, -24.0]]
		"loach":
			specs = [[-1.0, 0.16, -18.0], [1.0, 0.16, -18.0], [-1.0, 0.12, -38.0], [1.0, 0.12, -38.0], [-1.0, 0.10, 8.0], [1.0, 0.10, 8.0]]
		_:
			specs = [[-1.0, 0.14, -20.0], [1.0, 0.14, -20.0], [-1.0, 0.11, -42.0], [1.0, 0.11, -42.0]]
	for i in specs.size():
		var spec: Array = specs[i]
		var side := float(spec[0])
		var length := float(spec[1])
		var angle := float(spec[2])
		var socket := Node3D.new()
		socket.name = "Barbel%d" % i
		socket.position = Vector3(0.0, 0.0, side * 0.06)
		socket.rotation_degrees = Vector3(0.0, side * 22.0, angle)
		root.add_child(socket)
		var whisker := PF.cylinder("BarbelSegment", 0.004, length, material)
		whisker.rotation_degrees.z = 90.0
		whisker.position.x = -length * 0.5
		socket.add_child(whisker)

func _add_mouth_detail(head: MeshInstance3D, detail: String, mouth_position: Vector3, mouth_size: float, material: Material, side_suffix: String = "") -> void:
	if detail == "none" or detail == "dot" or detail == "":
		return
	var root := Node3D.new()
	root.name = "MouthDetail_%s%s" % [detail, side_suffix]
	root.position = mouth_position
	head.add_child(root)
	match detail:
		"lip":
			var lip := PF.ellipsoid("LipPad", Vector3(mouth_size * 1.25, mouth_size * 0.42, mouth_size * 0.72), material)
			root.add_child(lip)
		"beak":
			for i in range(2):
				var beak := PF.ellipsoid("BeakHalf%d" % i, Vector3(mouth_size * 0.92, mouth_size * 0.24, mouth_size * 0.42), material)
				beak.position = Vector3(-mouth_size * 0.18, mouth_size * (0.22 if i == 0 else -0.22), 0.0)
				root.add_child(beak)
		"sucker":
			var disc := PF.ellipsoid("SuckerDisc", Vector3(mouth_size * 1.45, mouth_size * 0.72, mouth_size * 1.15), material)
			disc.rotation_degrees.z = -18.0
			root.add_child(disc)
		"downturned":
			var downturn := PF.ellipsoid("DownturnedLip", Vector3(mouth_size * 1.05, mouth_size * 0.32, mouth_size * 0.58), material)
			downturn.position = Vector3(0.0, -mouth_size * 0.36, 0.0)
			root.add_child(downturn)

func _mouth_position_for_type(mouth_type: String, _head_scale: Vector3, _snout_length: float) -> Vector3:
	# The mouth sits on the snout at its no-jaw baseline height, then rides the snout
	# vertical shift so it stays attached to the deformed geometry (the mesh applies the
	# same shift via snout_y_shift). _head_front_surface_x already follows the snout tip
	# in x, so the snout length is not re-added to the outset here.
	var base_y := 0.0
	var outset := 0.035
	match mouth_type:
		"superior":
			base_y = 0.11
		"inferior":
			base_y = -0.14
			outset = 0.028
		"subterminal":
			base_y = -0.07
			outset = 0.032
		"protrusible":
			outset = 0.10
	var shift := _snout_tip_displacement()
	return Vector3(_head_front_surface_x(base_y, 0.0, outset), base_y + shift, 0.0)

func _mouth_angle_for_type(mouth_type: String) -> float:
	match mouth_type:
		"superior":
			return 18.0
		"inferior":
			return -18.0
		"subterminal":
			return -9.0
	return 0.0
