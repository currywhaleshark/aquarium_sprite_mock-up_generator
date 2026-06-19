class_name SharkRig
extends FishRig

const SharkGillSlitMarkingScript := preload("res://scripts/creature/SharkGillSlitMarking.gd")
const SharkMouthMarkingScript := preload("res://scripts/creature/SharkMouthMarking.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

func set_parameters(new_parameters: Dictionary) -> void:
	super.set_parameters(_shark_parameters(new_parameters))

func rebuild() -> void:
	super.rebuild()
	if body_pivot == null:
		return
	SharkGillSlitMarkingScript.rebuild(body_pivot, parameters)
	SharkMouthMarkingScript.rebuild(body_pivot, parameters)

func _apply_animated_attachments(loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	super._apply_animated_attachments(loop_phase, centers, yaws)
	_apply_animated_shark_gill_slits()

func _apply_animated_shark_gill_slits() -> void:
	if body_pivot == null:
		return
	var head := body_pivot.get_node_or_null("Head") as Node3D
	var root := body_pivot.get_node_or_null("SharkGillSlits") as Node3D
	if head == null or root == null:
		return
	var rest_head_transform: Transform3D = root.get_meta("rest_head_transform", head.transform)
	root.transform = head.transform * rest_head_transform.affine_inverse()

func _shark_parameters(source: Dictionary) -> Dictionary:
	var shark_parameters := source.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	shark_parameters["mouth_carve_enabled"] = false
	shark_parameters["mouth_open"] = 0.0
	shark_parameters["mouth_size"] = 0.0
	shark_parameters["mouth_detail"] = "none"
	for key in shark_parameters.keys():
		var text_key := String(key)
		if text_key == "gill_mark" or text_key.begins_with("operculum_"):
			shark_parameters.erase(key)
	return shark_parameters

# head_offset/long_map_* are the body-shell longitudinal UV map the fish head uses to
# join the shell seamlessly. The shark's integrated head mesh owns its own UV span, so
# they are accepted (to match the parent signature) but not consumed here.
func _create_head_node(name: String, shape: String, head_scale: Vector3, snout_length: float, forehead_slope: float, material: Material, sculpt: Dictionary = {}, head_offset: float = 0.0, long_map_x: PackedFloat32Array = PackedFloat32Array(), long_map_u: PackedFloat32Array = PackedFloat32Array()) -> MeshInstance3D:
	return SharkHeadProfile.build_head(name, parameters, head_scale, snout_length, forehead_slope, material, sculpt)

func _get_head_contour_radius(x_local_unscaled: float, shape: String, forehead_slope: float, snout_length: float, snout_base: float = HeadProfile.SNOUT_BLEND_HALF, snout_thickness: float = 1.0, snout_taper: float = 0.0) -> Vector2:
	return SharkHeadProfile.contour_radius_at_x(parameters, x_local_unscaled, snout_length, forehead_slope, _head_sculpt_params())

func _head_shell_profile_offsets(x_local_unscaled: float, head_scale: Vector3, metrics: Dictionary, _blend_factor: float) -> Dictionary:
	var snout_length := float(metrics.get("snout_length", param_float("snout_length", 0.0)))
	var forehead_slope := float(metrics.get("forehead_slope", param_float("forehead_slope", 0.35)))
	var sculpt := _head_sculpt_params()
	var front_x := SharkHeadProfile.ROSTRUM_FRONT_X - clampf(snout_length, 0.0, 0.6) * 0.35
	var u := clampf((x_local_unscaled - front_x) / maxf(SharkHeadProfile.NECK_X - front_x, 0.001), 0.0, 1.0)
	var contour := SharkHeadProfile.contour_radius_at_x(parameters, x_local_unscaled, snout_length, forehead_slope, sculpt)
	var top_y := SharkHeadProfile.point_at(parameters, u, PI * 0.5, snout_length, forehead_slope, sculpt).y
	var bottom_y := -SharkHeadProfile.point_at(parameters, u, PI * 1.5, snout_length, forehead_slope, sculpt).y
	return {
		"top": maxf(head_scale.y * (top_y - contour.x), 0.0),
		"bottom": maxf(head_scale.y * (bottom_y - contour.x), 0.0),
	}

func _head_grid_for_unified_surface(_head_shape: String, _head_scale: Vector3, snout_length: float, forehead_slope: float, sculpt: Dictionary, boundary_x: float, boundary_index: int = 0) -> Array:
	var grid := []
	var front_x := SharkHeadProfile.ROSTRUM_FRONT_X - clampf(snout_length, 0.0, 0.6) * 0.35
	var boundary_local_x := (boundary_x - param_float("head_offset", -0.58)) / maxf(absf(_head_scale.x), 0.001)
	var boundary_u := clampf((boundary_local_x - front_x) / maxf(SharkHeadProfile.NECK_X - front_x, 0.001), 0.0, 1.0)
	var samples := SharkHeadProfile.u_samples(parameters)
	for sample in samples:
		var u := float(sample)
		if u < boundary_u - 0.0005:
			grid.append(_shark_head_ring_to_body_space(u, snout_length, forehead_slope, sculpt))
	grid.append(_unified_body_boundary_ring(boundary_index))
	return grid

func _shark_head_ring_to_body_space(u: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> PackedVector3Array:
	var ring := PackedVector3Array()
	if head_node == null:
		return ring
	var xf := head_node.transform
	for segment in range(shell_segments + 1):
		var theta := TAU * float(segment) / float(shell_segments)
		ring.append(xf * SharkHeadProfile.point_at(parameters, u, theta, snout_length, forehead_slope, sculpt))
	return ring
# A shark head is a SHORT, DEEP, robust wedge - roughly as deep as it is long - not the
# long thin cone the fish "pointed" profile produces (the old "ballpoint pen" head). The
# fish branch multiplied x by ~1.5 and squashed y/z, giving a ~4.5:1 length:depth dolphin
# snout. We ignore head_shape here and build a shark-tuned scale from the same size inputs
# so the integrated head mesh AND the body shell (both call this) stay in lock-step.
func _head_scale_for_shape(shape: String, head_size: float, head_length: float, body_height: float, body_width: float) -> Vector3:
	var flatten := clampf(param_float("head_flattening", 0.0), 0.0, 0.65)
	var size_scale := maxf(head_size, 0.001) / DEFAULT_HEAD_SIZE
	var head_scale := Vector3(head_length, body_height * 0.82 * size_scale, body_width * 0.92 * size_scale)
	# snout_length only gently lengthens the head now; depth/width stay near body girth so
	# the head reads stocky from every angle.
	head_scale.x *= 0.86 + clampf(param_float("snout_length", 0.0), 0.0, 0.6) * 0.45
	head_scale.y *= 1.06
	head_scale.z *= 1.0
	head_scale.y *= 1.0 - flatten
	head_scale.z *= 1.0 + flatten * 0.35
	return head_scale

func _add_head_features(head: MeshInstance3D, material: Material) -> void:
	var root := Node3D.new()
	root.name = "SharkMouth"
	head.add_child(root)

func _eye_layout() -> Dictionary:
	var eye_x := param_float("eye_position_x", -0.92)
	var eye_y := param_float("eye_position_y", 0.06)
	var local_x := (eye_x - eye_head_center.x) / maxf(absf(eye_head_scale.x), 0.001)
	var local_y := (eye_y - eye_head_center.y) / maxf(absf(eye_head_scale.y), 0.001)
	var snout_length := param_float("snout_length", 0.0)
	var front_x := SharkHeadProfile.ROSTRUM_FRONT_X - clampf(snout_length, 0.0, 0.6) * 0.35
	local_x = clampf(local_x, front_x + 0.05, SharkHeadProfile.NECK_X - 0.08)
	local_y = clampf(local_y, -0.36, 0.32)
	var u := clampf((local_x - front_x) / (SharkHeadProfile.NECK_X - front_x), 0.0, 1.0)
	var surface_z_local := SharkHeadProfile.surface_z_at(parameters, u, local_y, 1.0)
	var eye_style := String(parameters.get("eye_style", "bead"))
	var default_bulge := 0.0
	if eye_style == "telescope":
		default_bulge = 0.85
	elif eye_style == "celestial":
		default_bulge = 0.45
	var eye_bulge := clampf(float(parameters.get("eye_bulge", default_bulge)), 0.0, 1.0)
	var anchor := Vector3(
		eye_head_center.x + local_x * eye_head_scale.x,
		eye_head_center.y + local_y * eye_head_scale.y,
		0.0
	)
	var surface_z_world := absf(surface_z_local) * maxf(absf(eye_head_scale.z), 0.001)
	var protrusion := eye_radius * (0.28 + eye_bulge * 1.25)
	var eye_center_z := surface_z_world + protrusion
	var stalk_inner := maxf(surface_z_world * 0.82, 0.0)
	return {
		"anchor": anchor,
		"eye_center_z": eye_center_z,
		"has_stalk": eye_bulge > 0.15,
		"stalk_inner": stalk_inner,
		"stalk_length": maxf(eye_center_z - eye_radius * 0.35 - stalk_inner, eye_radius * 0.4)
	}
