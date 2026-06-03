class_name FishRig
extends "res://scripts/creature/CreatureRig.gd"

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")
const TMF := preload("res://scripts/materials/ToonMaterialFactory.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const HeadProfile := preload("res://scripts/creature/HeadProfile.gd")

# How far median/pelvic fin bases sink into the body so they look rooted
# instead of floating above the surface. Larger embeds the base deeper.
const FIN_BASE_EMBED := 0.05

var body_pivot: Node3D
var tail_pivot_1: Node3D
var tail_pivot_2: Node3D
var tail_fin_pivot: Node3D
var tail_fin: MeshInstance3D
var tail_fin_base_points := PackedVector3Array()
var outer_shell: MeshInstance3D
var shell_profile: Array[Vector3] = []
var shell_center_y_offsets: Array[float] = []
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
		outer_shell = PF.fish_outer_shell("OuterShell", shell_profile, body_mat, shell_segments, PackedFloat32Array(shell_center_y_offsets))
		body_pivot.add_child(outer_shell)

	var head_scale := _head_scale_for_shape(String(parameters.get("head_shape", "rounded")), head_size, body_height * head_depth_scale, body_width * body_z_scale * head_width_boost)
	var head_shape := String(parameters.get("head_shape", "rounded"))
	var snout_len := param_float("snout_length", 0.0)
	var forehead_slope := param_float("forehead_slope", 0.35)
	head_node = PF.deformed_head("Head", head_shape, head_scale, snout_len, forehead_slope, body_mat, _head_sculpt_params())
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
		shell_profile.append(Vector3(lerpf(start_x, end_x, float(ring["x"])), radius_y, radius_z))
		shell_center_y_offsets.append(center_y)
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
		return {"radius_y": radius_y, "radius_z": radius_z}
		
	var contour := _get_head_contour_radius(x_local_unscaled, shape, forehead_slope, snout_length, float(metrics.get("snout_base", HeadProfile.SNOUT_BLEND_HALF)), float(metrics.get("snout_thickness", 1.0)), float(metrics.get("snout_taper", 0.0)))
	
	var r_head_y := head_scale.y * contour.x
	var r_head_z := head_scale.z * contour.y
	
	var blend_factor := clampf((x_local_unscaled - (-0.22)) / (0.5 - (-0.22)), 0.0, 1.0)
	
	var exp_offset_y := lerpf(shell_expand * 0.15, shell_expand * lerpf(1.0, 0.22, ring_x), blend_factor)
	var exp_offset_z := lerpf(shell_expand * 0.15, shell_expand * lerpf(1.0, 0.18, ring_x), blend_factor)
	
	var target_y := lerpf(r_head_y, radius_y - shell_expand * lerpf(1.0, 0.22, ring_x), blend_factor) + exp_offset_y
	var target_z := lerpf(r_head_z, radius_z - shell_expand * lerpf(1.0, 0.18, ring_x), blend_factor) + exp_offset_z
	
	return {
		"radius_y": maxf(target_y, 0.035),
		"radius_z": maxf(target_z, 0.03)
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
			var dx := shell_profile[i].x - head_offset
			centers[i] = head_center + basis_head * Vector3(dx, 0.0, 0.0)
			yaws[i] = yaw_head

	PF.update_fish_outer_shell_bent(outer_shell, shell_profile, centers, yaws, shell_segments, PackedFloat32Array(shell_center_y_offsets))
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
	var dynamic_head_center := head_node.position
	var local_anchor := anchor - eye_head_center
	eye_l.position = dynamic_head_center + basis * (local_anchor + Vector3(0.0, 0.0, -eye_center_z))
	eye_r.position = dynamic_head_center + basis * (local_anchor + Vector3(0.0, 0.0, eye_center_z))
	var stalk_inner := float(layout["stalk_inner"])
	var stalk_length := float(layout["stalk_length"])
	for stalk_side in [eye_stalk_l, eye_stalk_r]:
		if stalk_side == null:
			continue
		var stalk_mesh := stalk_side.mesh as CylinderMesh
		if stalk_mesh:
			stalk_mesh.height = stalk_length
		var stalk_sign := -1.0 if stalk_side == eye_stalk_l else 1.0
		stalk_side.position = dynamic_head_center + basis * (local_anchor + Vector3(0.0, 0.0, stalk_sign * (stalk_inner + stalk_length * 0.5)))
		stalk_side.rotation_degrees = Vector3(90.0, yaw, 0.0)

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
		"head_bump_forward": param_float("head_bump_forward", 0.5),
	}

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
	for side in [-1.0, 1.0]:
		var suffix := "L" if side < 0.0 else "R"
		var eye := PF.ellipsoid("Eye%s" % suffix, Vector3(eye_size, eye_size, eye_size), eye_mat)
		eye.position = anchor + Vector3(0.0, 0.0, side * eye_center_z)
		body_pivot.add_child(eye)
		if side < 0.0:
			eye_l = eye
		else:
			eye_r = eye
		if bool(layout["has_stalk"]):
			var stalk_length := float(layout["stalk_length"])
			var stalk := PF.cylinder("EyeStalk%s" % suffix, eye_size * 0.34, stalk_length, stalk_mat)
			stalk.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			stalk.position = anchor + Vector3(0.0, 0.0, side * (float(layout["stalk_inner"]) + stalk_length * 0.5))
			body_pivot.add_child(stalk)
			if side < 0.0:
				eye_stalk_l = stalk
			else:
				eye_stalk_r = stalk

# Projects the requested eye spot onto the head ellipsoid, clamped inside the
# silhouette so the eye sits on the head instead of floating past the snout.
# eye_bulge pushes it outward, from a flush goldfish eye to a hammerhead stalk.
func _eye_layout() -> Dictionary:
	var half := eye_head_scale * 0.5
	var eye_x := param_float("eye_position_x", -0.78)
	var eye_y := param_float("eye_position_y", 0.12)
	var eye_bulge := clampf(param_float("eye_bulge", 0.0), 0.0, 1.0)
	var eye_style := String(parameters.get("eye_style", "bead"))
	if eye_style == "telescope":
		eye_bulge = maxf(eye_bulge, 0.85)
	elif eye_style == "celestial":
		eye_y += eye_head_scale.y * 0.12
		eye_bulge = maxf(eye_bulge, 0.45)
	var ux := (eye_x - eye_head_center.x) / maxf(half.x, 0.001)
	var uy := eye_y / maxf(half.y, 0.001)
	var planar_radius := sqrt(ux * ux + uy * uy)
	var max_planar := 0.9
	if planar_radius > max_planar:
		var shrink := max_planar / planar_radius
		ux *= shrink
		uy *= shrink
	var surface_z := maxf(half.z, 0.02) * sqrt(maxf(1.0 - ux * ux - uy * uy, 0.0))
	var protrusion := eye_bulge * maxf(half.z, 0.05) * 1.7
	var stalk_inner := surface_z * 0.55
	var eye_center_z := surface_z * 0.82 + protrusion
	return {
		"anchor": Vector3(eye_head_center.x + ux * half.x, eye_head_center.y + uy * half.y, 0.0),
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
	eye_l.position = anchor + Vector3(0.0, 0.0, -eye_center_z)
	eye_r.position = anchor + Vector3(0.0, 0.0, eye_center_z)
	var stalk_inner := float(layout["stalk_inner"])
	var stalk_length := float(layout["stalk_length"])
	for stalk_side in [eye_stalk_l, eye_stalk_r]:
		if stalk_side == null:
			continue
		var stalk_mesh := stalk_side.mesh as CylinderMesh
		if stalk_mesh:
			stalk_mesh.height = stalk_length
		var stalk_sign := -1.0 if stalk_side == eye_stalk_l else 1.0
		stalk_side.position = anchor + Vector3(0.0, 0.0, stalk_sign * (stalk_inner + stalk_length * 0.5))

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
	var mouth := PF.ellipsoid("Mouth", Vector3(mouth_size * 0.72, mouth_size * 0.34, mouth_size * 0.82), dark_mat)
	mouth.position = mouth_position
	mouth.rotation_degrees.z = _mouth_angle_for_type(mouth_type)
	head.add_child(mouth)
	_add_mouth_detail(head, String(parameters.get("mouth_detail", "dot")), mouth_position, mouth_size, dark_mat)

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

func _add_gill_mark(head: MeshInstance3D, mark: String, material: Material) -> void:
	if mark == "none" or mark == "":
		return
	var root := Node3D.new()
	root.name = "GillMark_%s" % mark
	head.add_child(root)
	match mark:
		"line":
			for side in [-1.0, 1.0]:
				var line_x := 0.18
				var line_y := 0.02
				var line := PF.cylinder("GillLine%s" % ("L" if side < 0.0 else "R"), 0.009, 0.24, material)
				line.position = Vector3(line_x, line_y, side * _head_side_surface_z(line_x, line_y, 0.04))
				line.rotation_degrees.x = 6.0 * side
				root.add_child(line)
		"crescent":
			for side in [-1.0, 1.0]:
				for i in range(3):
					var dash_x := 0.15 + float(i) * 0.025
					var dash_y := 0.07 - float(i) * 0.065
					var dash := PF.cylinder("GillCrescent%s_%d" % [("L" if side < 0.0 else "R"), i], 0.008, 0.12, material)
					dash.position = Vector3(dash_x, dash_y, side * _head_side_surface_z(dash_x, dash_y, 0.04))
					dash.rotation_degrees.z = -18.0 + float(i) * 18.0
					root.add_child(dash)
		"plate":
			for side in [-1.0, 1.0]:
				var plate_x := 0.18
				var plate_y := 0.0
				var plate := PF.ellipsoid("GillPlate%s" % ("L" if side < 0.0 else "R"), Vector3(0.045, 0.17, 0.018), material)
				plate.position = Vector3(plate_x, plate_y, side * _head_side_surface_z(plate_x, plate_y, 0.04))
				root.add_child(plate)

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
