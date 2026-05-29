class_name FishRig
extends "res://scripts/creature/CreatureRig.gd"

const PF := preload("res://scripts/creature/PrimitiveFactory.gd")
const TMF := preload("res://scripts/materials/ToonMaterialFactory.gd")

var body_pivot: Node3D
var tail_pivot_1: Node3D
var tail_pivot_2: Node3D
var tail_fin_pivot: Node3D
var outer_shell: MeshInstance3D
var shell_profile: Array[Vector3] = []
var shell_center_y_offsets: Array[float] = []
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
var dorsal_base_position := Vector3.ZERO
var dorsal_2_base_position := Vector3.ZERO
var anal_base_position := Vector3.ZERO
var pelvic_l_base_position := Vector3.ZERO
var pelvic_r_base_position := Vector3.ZERO
var pectoral_l_base_position := Vector3.ZERO
var pectoral_r_base_position := Vector3.ZERO
var head_node: MeshInstance3D

func rebuild() -> void:
	super.rebuild()
	await get_tree().process_frame
	outer_shell = null
	shell_profile = []
	shell_center_y_offsets = []
	dorsal_fin = null
	dorsal_2_fin = null
	anal_fin = null
	pelvic_l = null
	pelvic_r = null
	pectoral_l = null
	pectoral_r = null
	head_node = null
	var base_mat := TMF.make_surface(param_color("base_color", "#49c7d1"), param_float("shadow_strength", 0.35), param_float("highlight_strength", 0.42))
	var secondary_mat := TMF.make_surface(param_color("secondary_color", "#d8fbff"), 0.2, 0.5)
	var fin_mat := TMF.make_surface(param_color("fin_color", "#7ee1e8"), 0.28, 0.35)
	var eye_mat := TMF.make_dark("#10161a")
	var shell_color := param_color("base_color", "#49c7d1").lerp(param_color("secondary_color", "#d8fbff"), param_float("shell_color_mix", 0.22))
	var shell_mat := TMF.make_shell(shell_color, param_float("shell_opacity", 0.72))

	var body_length := param_float("body_length", 1.45)
	var body_height := param_float("body_height", 0.58)
	var body_width := param_float("body_width", 0.34)
	var body_profile := _body_profile_values(String(parameters.get("body_profile_shape", "fusiform")))
	var head_depth_scale := param_float("head_depth_scale", float(body_profile["head_depth_scale"]))
	var shoulder_depth_scale := param_float("shoulder_depth_scale", float(body_profile["shoulder_depth_scale"]))
	var midbody_depth_scale := param_float("midbody_depth_scale", float(body_profile["midbody_depth_scale"]))
	var tail_base_depth_scale := param_float("tail_base_depth_scale", float(body_profile["tail_base_depth_scale"]))
	var caudal_peduncle_depth_scale := param_float("caudal_peduncle_depth_scale", float(body_profile["caudal_peduncle_depth_scale"]))
	var body_width_scale := param_float("body_width_scale", float(body_profile["body_width_scale"]))
	var lateral_compression := clampf(param_float("lateral_compression", float(body_profile["lateral_compression"])), 0.0, 0.8)
	var body_depth_bias := clampf(param_float("body_depth_bias", float(body_profile["body_depth_bias"])), -1.0, 1.0)
	var head_vertical_offset := param_float("head_vertical_offset", 0.0)
	var tail_vertical_offset := param_float("tail_vertical_offset", 0.0)
	var body_z_scale := body_width_scale * (1.0 - lateral_compression * 0.62)
	var head_size := param_float("head_size", 0.44)
	var head_offset := param_float("head_offset", -0.58)
	var tail_length := param_float("tail_length", 0.78)
	var tail_height := param_float("tail_height", 0.24)
	var tail_fin_size := param_float("tail_fin_size", 0.46)
	var eye_size := param_float("eye_size", 0.055)
	var shell_expand := param_float("shell_expand", 0.08)
	shell_tail_pivot_1_x = body_length * 0.48
	shell_tail_pivot_2_x = shell_tail_pivot_1_x + tail_length * 0.5

	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)

	if param_float("shell_enabled", 1.0) > 0.5:
		var base_depths := [
			body_height * 0.24,
			body_height * 0.42,
			body_height * 0.52,
			body_height * 0.46,
			tail_height * 0.56,
			tail_height * 0.32,
			tail_height * 0.16
		]
		var depth_scales := [
			head_depth_scale,
			head_depth_scale,
			shoulder_depth_scale,
			midbody_depth_scale,
			tail_base_depth_scale,
			caudal_peduncle_depth_scale,
			caudal_peduncle_depth_scale
		]
		shell_center_y_offsets = _shell_center_offsets(base_depths, depth_scales, body_depth_bias)
		shell_center_y_offsets = _apply_part_vertical_offsets(shell_center_y_offsets, head_vertical_offset, tail_vertical_offset)
		shell_profile = [
			Vector3(head_offset - head_size * 0.33, body_height * 0.24 * head_depth_scale + shell_expand, body_width * 0.18 * body_z_scale * _head_width_boost(body_profile) + shell_expand),
			Vector3(head_offset - head_size * 0.08, body_height * 0.42 * head_depth_scale + shell_expand, body_width * 0.34 * body_z_scale * _head_width_boost(body_profile) + shell_expand),
			Vector3(-body_length * 0.16, body_height * 0.52 * shoulder_depth_scale + shell_expand, body_width * 0.46 * body_z_scale + shell_expand),
			Vector3(body_length * 0.26, body_height * 0.46 * midbody_depth_scale + shell_expand, body_width * 0.38 * body_z_scale + shell_expand),
			Vector3(body_length * 0.48 + tail_length * 0.26, tail_height * 0.56 * tail_base_depth_scale + shell_expand * 0.45, body_width * 0.24 * body_z_scale + shell_expand * 0.45),
			Vector3(body_length * 0.48 + tail_length * 0.58, tail_height * 0.32 * caudal_peduncle_depth_scale + shell_expand * 0.28, body_width * 0.16 * body_z_scale + shell_expand * 0.28),
			Vector3(body_length * 0.48 + tail_length * 0.92, tail_height * 0.16 * caudal_peduncle_depth_scale + shell_expand * 0.16, body_width * 0.07 * body_z_scale + shell_expand * 0.16)
		]
		outer_shell = PF.fish_outer_shell("OuterShell", shell_profile, shell_mat, shell_segments, PackedFloat32Array(shell_center_y_offsets))
		body_pivot.add_child(outer_shell)

	var body := PF.ellipsoid("Body", Vector3(body_length, body_height * midbody_depth_scale, body_width * body_z_scale), base_mat)
	body.position.y = _sample_shell_center_y_at_x(0.0)
	body_pivot.add_child(body)

	var head_scale := _head_scale_for_shape(String(parameters.get("head_shape", "rounded")), head_size, body_height * head_depth_scale, body_width * body_z_scale * _head_width_boost(body_profile))
	head_node = PF.ellipsoid("Head", head_scale, secondary_mat)
	head_node.position = Vector3(head_offset, 0.02 + _sample_shell_center_y_at_x(head_offset), 0.0)
	body_pivot.add_child(head_node)
	_add_head_features(head_node, secondary_mat)

	dorsal_fin = PF.fin_shape(
		"DorsalFin1",
		String(parameters.get("dorsal_1_shape", "single")),
		param_float("dorsal_1_length", 0.42),
		param_float("dorsal_1_height", param_float("dorsal_fin_size", 0.28)),
		fin_mat
	)
	dorsal_base_position = _surface_position("dorsal", param_float("dorsal_1_attach_t", 0.45), 0.035)
	dorsal_fin.position = dorsal_base_position
	body_pivot.add_child(dorsal_fin)

	if param_float("dorsal_2_enabled", 0.0) > 0.5:
		dorsal_2_fin = PF.fin_shape(
			"DorsalFin2",
			String(parameters.get("dorsal_2_shape", "single")),
			param_float("dorsal_2_length", 0.34),
			param_float("dorsal_2_height", 0.18),
			fin_mat
		)
		dorsal_2_base_position = _surface_position("dorsal", param_float("dorsal_2_attach_t", 0.68), 0.028)
		dorsal_2_fin.position = dorsal_2_base_position
		body_pivot.add_child(dorsal_2_fin)

	anal_fin = PF.fin_shape(
		"AnalFin",
		String(parameters.get("anal_shape", "long")),
		param_float("anal_length", 0.36),
		param_float("anal_height", param_float("anal_fin_size", 0.2)),
		fin_mat,
		true
	)
	anal_base_position = _surface_position("ventral", param_float("anal_attach_t", 0.64), 0.03)
	anal_fin.position = anal_base_position
	body_pivot.add_child(anal_fin)

	if param_float("pelvic_enabled", 0.0) > 0.5:
		pelvic_l = PF.fin_shape("PelvicFinL", String(parameters.get("pelvic_shape", "triangle")), param_float("pelvic_length", 0.22), param_float("pelvic_height", 0.14), fin_mat, true)
		pelvic_r = PF.fin_shape("PelvicFinR", String(parameters.get("pelvic_shape", "triangle")), param_float("pelvic_length", 0.22), param_float("pelvic_height", 0.14), fin_mat, true)
		var pelvic_center := _surface_position("ventral", param_float("pelvic_attach_t", 0.36), 0.02)
		var pelvic_z := _surface_radius_z(param_float("pelvic_attach_t", 0.36)) * 0.32
		pelvic_l_base_position = pelvic_center + Vector3(0.0, 0.0, -pelvic_z)
		pelvic_r_base_position = pelvic_center + Vector3(0.0, 0.0, pelvic_z)
		pelvic_l.position = pelvic_l_base_position
		pelvic_r.position = pelvic_r_base_position
		pelvic_l.rotation_degrees = Vector3(0.0, 12.0, 0.0)
		pelvic_r.rotation_degrees = Vector3(0.0, -12.0, 0.0)
		body_pivot.add_child(pelvic_l)
		body_pivot.add_child(pelvic_r)

	pectoral_l = PF.oval_fin("PectoralFinL", param_float("pectoral_fin_size", 0.16), param_float("pectoral_fin_size", 0.16) * 0.5, fin_mat)
	var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
	var pectoral_center := _surface_position("side", pectoral_attach_t, 0.0)
	pectoral_l_base_position = Vector3(pectoral_center.x, -0.02, -_surface_radius_z(pectoral_attach_t) - shell_expand * 0.55)
	pectoral_l.position = pectoral_l_base_position
	pectoral_l.rotation_degrees = Vector3(0.0, 25.0, -28.0)
	body_pivot.add_child(pectoral_l)

	pectoral_r = PF.oval_fin("PectoralFinR", param_float("pectoral_fin_size", 0.16), param_float("pectoral_fin_size", 0.16) * 0.5, fin_mat)
	pectoral_r_base_position = Vector3(pectoral_center.x, -0.02, _surface_radius_z(pectoral_attach_t) + shell_expand * 0.55)
	pectoral_r.position = pectoral_r_base_position
	pectoral_r.rotation_degrees = Vector3(0.0, -25.0, -28.0)
	body_pivot.add_child(pectoral_r)
	_apply_fin_offsets()

	var eye_y := param_float("eye_position_y", 0.12)
	var eye_x := param_float("eye_position_x", -0.78)
	for side in [-1.0, 1.0]:
		var eye := PF.ellipsoid("Eye%s" % ("L" if side < 0.0 else "R"), Vector3(eye_size, eye_size, eye_size), eye_mat)
		eye.position = Vector3(eye_x, eye_y + _sample_shell_center_y_at_x(eye_x), side * body_width * 0.48)
		body_pivot.add_child(eye)

	tail_pivot_1 = Node3D.new()
	tail_pivot_1.name = "TailPivot1"
	var tail_pivot_1_y := _sample_shell_center_y_at_x(shell_tail_pivot_1_x)
	tail_pivot_1.position = Vector3(body_length * 0.48, tail_pivot_1_y, 0.0)
	body_pivot.add_child(tail_pivot_1)

	var tail_1 := PF.tapered_segment("Tail1", tail_length * 0.5, tail_height * tail_base_depth_scale, body_width * 0.52 * body_z_scale, base_mat)
	tail_1.position = Vector3(tail_length * 0.25, 0.0, 0.0)
	tail_pivot_1.add_child(tail_1)

	tail_pivot_2 = Node3D.new()
	tail_pivot_2.name = "TailPivot2"
	var tail_pivot_2_y := _sample_shell_center_y_at_x(shell_tail_pivot_2_x)
	tail_pivot_2.position = Vector3(tail_length * 0.5, tail_pivot_2_y - tail_pivot_1_y, 0.0)
	tail_pivot_1.add_child(tail_pivot_2)

	var tail_2 := PF.tapered_segment("Tail2", tail_length * 0.42, tail_height * 0.72 * caudal_peduncle_depth_scale, body_width * 0.34 * body_z_scale, base_mat)
	tail_2.position = Vector3(tail_length * 0.2, 0.0, 0.0)
	tail_pivot_2.add_child(tail_2)

	tail_fin_pivot = Node3D.new()
	tail_fin_pivot.name = "TailFinPivot"
	var tail_fin_y := _sample_shell_center_y_at_x(shell_tail_pivot_2_x + tail_length * 0.42)
	tail_fin_pivot.position = Vector3(tail_length * 0.42, tail_fin_y - tail_pivot_2_y, 0.0)
	tail_pivot_2.add_child(tail_fin_pivot)

	var tail_fin := PF.caudal_fin_shape("TailFin", String(parameters.get("caudal_shape", "forked_shallow")), tail_fin_size, tail_fin_size * param_float("caudal_height_scale", 0.72), fin_mat)
	tail_fin_pivot.add_child(tail_fin)

func apply_pose(loop_phase: float) -> void:
	var wave := sin(loop_phase * TAU)
	var delayed := sin(loop_phase * TAU - param_float("phase_delay", 0.65))
	position.y = wave * param_float("idle_bob_amount", 0.035)
	if body_pivot:
		body_pivot.rotation_degrees.y = wave * param_float("body_sway_amount", 3.0)
	if tail_pivot_1:
		tail_pivot_1.rotation_degrees.y = delayed * param_float("tail_1_sway_amount", 10.0)
	if tail_pivot_2:
		tail_pivot_2.rotation_degrees.y = sin(loop_phase * TAU - param_float("phase_delay", 0.65) * 1.8) * param_float("tail_2_sway_amount", 18.0)
	if tail_fin_pivot:
		tail_fin_pivot.rotation_degrees.y = sin(loop_phase * TAU - param_float("phase_delay", 0.65) * 2.4) * param_float("tail_fin_sway_amount", 24.0)
	if pectoral_l:
		pectoral_l.rotation_degrees.x = sin(loop_phase * TAU * 2.0) * param_float("pectoral_flap_amount", 10.0)
	if pectoral_r:
		pectoral_r.rotation_degrees.x = sin(loop_phase * TAU * 2.0) * param_float("pectoral_flap_amount", 10.0)
	_deform_shell(loop_phase)

func _deform_shell(loop_phase: float) -> void:
	if outer_shell == null or shell_profile.is_empty():
		return
	var phase_delay := param_float("phase_delay", 0.65)
	var tail_1_yaw := sin(loop_phase * TAU - phase_delay) * param_float("tail_1_sway_amount", 10.0)
	var tail_2_yaw := sin(loop_phase * TAU - phase_delay * 1.8) * param_float("tail_2_sway_amount", 18.0)
	var body_yaw := sin(loop_phase * TAU) * param_float("body_sway_amount", 3.0) * 0.22
	var centers := PackedVector3Array()
	var yaws := PackedFloat32Array()
	for ring_index in shell_profile.size():
		var t := float(ring_index) / maxf(float(shell_profile.size() - 1), 1.0)
		var point := shell_profile[ring_index]
		var bend := _tail_bent_center_and_yaw(point.x, tail_1_yaw, tail_2_yaw)
		var center: Vector3 = bend["center"]
		var yaw: float = bend["yaw"]
		center.z += sin(loop_phase * TAU) * 0.01 * (1.0 - t)
		centers.append(center)
		yaws.append(yaw + body_yaw * (1.0 - t * 0.55))
	PF.update_fish_outer_shell_bent(outer_shell, shell_profile, centers, yaws, shell_segments, PackedFloat32Array(shell_center_y_offsets))

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

func _apply_fin_offsets() -> void:
	if dorsal_fin:
		dorsal_base_position = _surface_position("dorsal", param_float("dorsal_1_attach_t", 0.45), 0.035)
		dorsal_fin.position = dorsal_base_position + Vector3(float(parameters.get("dorsal_fin_offset_x", 0.0)), 0.0, 0.0)
	if dorsal_2_fin:
		dorsal_2_base_position = _surface_position("dorsal", param_float("dorsal_2_attach_t", 0.68), 0.028)
		dorsal_2_fin.position = dorsal_2_base_position
	if anal_fin:
		anal_base_position = _surface_position("ventral", param_float("anal_attach_t", 0.64), 0.03)
		anal_fin.position = anal_base_position + Vector3(float(parameters.get("anal_fin_offset_x", 0.0)), 0.0, 0.0)
	if pelvic_l and pelvic_r:
		var pelvic_attach_t := param_float("pelvic_attach_t", 0.36)
		var pelvic_center := _surface_position("ventral", pelvic_attach_t, 0.02)
		var pelvic_z := _surface_radius_z(pelvic_attach_t) * 0.32
		pelvic_l_base_position = pelvic_center + Vector3(0.0, 0.0, -pelvic_z)
		pelvic_r_base_position = pelvic_center + Vector3(0.0, 0.0, pelvic_z)
		pelvic_l.position = pelvic_l_base_position
		pelvic_r.position = pelvic_r_base_position
	var pectoral_offset := float(parameters.get("pectoral_fin_offset_x", 0.0))
	if pectoral_l:
		var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
		var pectoral_center := _surface_position("side", pectoral_attach_t, 0.0)
		pectoral_l_base_position.x = pectoral_center.x
		pectoral_l.position = pectoral_l_base_position + Vector3(pectoral_offset, 0.0, 0.0)
	if pectoral_r:
		var pectoral_attach_t := param_float("pectoral_attach_t", 0.32)
		var pectoral_center := _surface_position("side", pectoral_attach_t, 0.0)
		pectoral_r_base_position.x = pectoral_center.x
		pectoral_r.position = pectoral_r_base_position + Vector3(pectoral_offset, 0.0, 0.0)

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
			return Vector3(sample.x, center_y + sample.y + margin, 0.0)
		"ventral":
			return Vector3(sample.x, center_y - sample.y - margin, 0.0)
		"side":
			return Vector3(sample.x, center_y, 0.0)
	return Vector3(sample.x, center_y + sample.y, 0.0)

func _surface_radius_z(attach_t: float) -> float:
	return _sample_shell_profile(attach_t).z

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
	var profile := _body_profile_values(shape)
	for key in profile.keys():
		parameters[key] = profile[key]
	rebuild()

func _body_profile_values(shape: String) -> Dictionary:
	match shape:
		"deep_compressed":
			return {
				"head_depth_scale": 0.78,
				"shoulder_depth_scale": 1.36,
				"midbody_depth_scale": 1.55,
				"tail_base_depth_scale": 0.82,
				"caudal_peduncle_depth_scale": 0.42,
				"body_width_scale": 0.82,
				"lateral_compression": 0.48,
				"body_depth_bias": -0.35,
				"head_width_boost": 1.0
			}
		"elongated":
			return {
				"head_depth_scale": 0.74,
				"shoulder_depth_scale": 0.82,
				"midbody_depth_scale": 0.82,
				"tail_base_depth_scale": 0.64,
				"caudal_peduncle_depth_scale": 0.5,
				"body_width_scale": 0.9,
				"lateral_compression": 0.16,
				"body_depth_bias": 0.0,
				"head_width_boost": 1.0
			}
		"eel_like":
			return {
				"head_depth_scale": 0.56,
				"shoulder_depth_scale": 0.58,
				"midbody_depth_scale": 0.6,
				"tail_base_depth_scale": 0.5,
				"caudal_peduncle_depth_scale": 0.42,
				"body_width_scale": 0.75,
				"lateral_compression": 0.08,
				"body_depth_bias": 0.0,
				"head_width_boost": 1.0
			}
		"depressed":
			return {
				"head_depth_scale": 0.5,
				"shoulder_depth_scale": 0.56,
				"midbody_depth_scale": 0.58,
				"tail_base_depth_scale": 0.48,
				"caudal_peduncle_depth_scale": 0.36,
				"body_width_scale": 1.35,
				"lateral_compression": 0.0,
				"body_depth_bias": -0.2,
				"head_width_boost": 1.1
			}
		"broad_head":
			return {
				"head_depth_scale": 1.35,
				"shoulder_depth_scale": 1.18,
				"midbody_depth_scale": 0.88,
				"tail_base_depth_scale": 0.72,
				"caudal_peduncle_depth_scale": 0.5,
				"body_width_scale": 1.28,
				"lateral_compression": 0.08,
				"body_depth_bias": -0.15,
				"head_width_boost": 1.25
			}
		"narrow_peduncle":
			return {
				"head_depth_scale": 0.9,
				"shoulder_depth_scale": 1.0,
				"midbody_depth_scale": 1.0,
				"tail_base_depth_scale": 0.58,
				"caudal_peduncle_depth_scale": 0.28,
				"body_width_scale": 0.95,
				"lateral_compression": 0.18,
				"body_depth_bias": 0.0,
				"head_width_boost": 1.0
			}
	return {
		"head_depth_scale": 0.9,
		"shoulder_depth_scale": 1.0,
		"midbody_depth_scale": 1.0,
		"tail_base_depth_scale": 0.8,
		"caudal_peduncle_depth_scale": 0.65,
		"body_width_scale": 1.0,
		"lateral_compression": 0.1,
		"body_depth_bias": 0.0,
		"head_width_boost": 1.0
	}

func _head_width_boost(profile: Dictionary) -> float:
	return float(profile.get("head_width_boost", 1.0))

func _shell_center_offsets(base_depths: Array, depth_scales: Array, depth_bias: float) -> Array[float]:
	var offsets: Array[float] = []
	for i in base_depths.size():
		var base_depth := float(base_depths[i])
		var depth_scale := float(depth_scales[i])
		offsets.append((base_depth * depth_scale - base_depth) * depth_bias)
	return offsets

func _apply_part_vertical_offsets(offsets: Array[float], head_offset: float, tail_offset: float) -> Array[float]:
	var head_weights := [1.0, 0.75, 0.25, 0.0, 0.0, 0.0, 0.0]
	var tail_weights := [0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0]
	var adjusted: Array[float] = []
	for i in offsets.size():
		var head_weight := float(head_weights[i]) if i < head_weights.size() else 0.0
		var tail_weight := float(tail_weights[i]) if i < tail_weights.size() else 0.0
		adjusted.append(offsets[i] + head_offset * head_weight + tail_offset * tail_weight)
	return adjusted

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

func _add_head_features(head: MeshInstance3D, material: Material) -> void:
	var dark_mat := TMF.make_dark("#15191b")
	var shape := String(parameters.get("head_shape", "rounded"))
	var mouth_type := String(parameters.get("mouth_type", "terminal"))
	var snout_length := param_float("snout_length", 0.0)
	var mouth_size := param_float("mouth_size", 0.08)
	if shape == "hump" or shape == "steep_forehead":
		var hump := PF.ellipsoid("NuchalHump", Vector3(0.16 + param_float("forehead_slope", 0.35) * 0.12, 0.13 + param_float("forehead_slope", 0.35) * 0.1, 0.12), material)
		hump.position = Vector3(-0.05, head.scale.y * 0.38, 0.0)
		head.add_child(hump)
	if shape == "pointed" or shape == "tapered" or shape == "blunt":
		var snout := PF.ellipsoid("Snout", Vector3(0.12 + snout_length, head.scale.y * (0.28 if shape != "blunt" else 0.4), head.scale.z * 0.58), material)
		snout.position = Vector3(-head.scale.x * 0.38 - snout_length * 0.18, 0.0, 0.0)
		head.add_child(snout)
	var mouth := PF.ellipsoid("Mouth", Vector3(mouth_size, mouth_size * 0.28, mouth_size * 0.55), dark_mat)
	mouth.position = _mouth_position_for_type(mouth_type, head.scale, snout_length)
	mouth.rotation_degrees.z = _mouth_angle_for_type(mouth_type)
	head.add_child(mouth)

func _mouth_position_for_type(mouth_type: String, head_scale: Vector3, snout_length: float) -> Vector3:
	var x := -head_scale.x * 0.43 - snout_length * 0.08
	var jaw_offset := param_float("jaw_offset", 0.0)
	match mouth_type:
		"superior":
			return Vector3(x, head_scale.y * 0.22 + absf(jaw_offset), 0.0)
		"inferior":
			return Vector3(x * 0.92, -head_scale.y * 0.28 + jaw_offset, 0.0)
		"subterminal":
			return Vector3(x * 0.96, -head_scale.y * 0.14 + jaw_offset, 0.0)
		"protrusible":
			return Vector3(x - 0.08 - snout_length * 0.12, jaw_offset, 0.0)
		_:
			return Vector3(x, jaw_offset, 0.0)

func _mouth_angle_for_type(mouth_type: String) -> float:
	match mouth_type:
		"superior":
			return 18.0
		"inferior":
			return -18.0
		"subterminal":
			return -9.0
	return 0.0
