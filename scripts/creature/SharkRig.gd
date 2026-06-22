class_name SharkRig
extends FishRig

const SharkGillSlitMarkingScript := preload("res://scripts/creature/SharkGillSlitMarking.gd")
const SharkMouthMarkingScript := preload("res://scripts/creature/SharkMouthMarking.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

# Shark turn = a banked arc: every rib rotates into the turn (same sign), easing off toward the
# tail, rather than the fish's head-led S-flex. Head/tail per-rib yaw limits (deg at full turn).
const SHARK_TURN_HEAD_YAW := 20.0
const SHARK_TURN_TAIL_YAW := 11.0

func set_parameters(new_parameters: Dictionary) -> void:
	super.set_parameters(_shark_parameters(new_parameters))

func rebuild() -> void:
	super.rebuild()
	if body_pivot == null:
		return
	SharkGillSlitMarkingScript.rebuild(body_pivot, parameters)
	SharkMouthMarkingScript.rebuild(body_pivot, parameters)
	_cache_gill_anchor()

func _apply_animated_attachments(loop_phase: float, centers: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	super._apply_animated_attachments(loop_phase, centers, yaws)
	_apply_animated_shark_gill_slits(centers, yaws)

# The gills sit in the neck/loft zone where the surface is a blend of the rigid head and the
# waving body, so neither the head transform nor the body centreline matches it (anchoring to
# the head let them peel off during a turn). Instead re-project the cluster onto the LIVE
# deformed OuterShell each frame: translate the rest anchor to the current surface point at the
# cluster's (x, y), and rotate by the local body yaw so the slits tilt with the flank.
# Find and cache the mesh RIB (ring index) under the gill cluster, plus that rib's rest
# centreline, off the freshly-built rest mesh. Tracking a fixed rib index (not a nearest-vertex
# search) means we follow the same material point as the surface deforms.
func _cache_gill_anchor() -> void:
	var root := body_pivot.get_node_or_null("SharkGillSlits") as Node3D
	var shell := body_pivot.get_node_or_null("OuterShell") as MeshInstance3D
	if root == null or shell == null or shell.mesh == null:
		return
	var gx := float(root.get_meta("gill_center_x", -0.28))
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ring_stride := shell_segments + 1
	var ring_count := verts.size() / ring_stride
	var best_ring := 0
	var best_dx := INF
	for r in range(ring_count):
		var cx := (verts[r * ring_stride].x + verts[r * ring_stride + shell_segments / 2].x) * 0.5
		if absf(cx - gx) < best_dx:
			best_dx = absf(cx - gx)
			best_ring = r
	root.set_meta("gill_ring_index", best_ring)
	root.set_meta("gill_rest_center", _rib_centerline(verts, best_ring))

func _apply_animated_shark_gill_slits(_centers: PackedVector3Array, _yaws: PackedFloat32Array) -> void:
	if body_pivot == null:
		return
	var root := body_pivot.get_node_or_null("SharkGillSlits") as Node3D
	var shell := body_pivot.get_node_or_null("OuterShell") as MeshInstance3D
	if root == null or shell == null or shell.mesh == null or not root.has_meta("gill_ring_index"):
		return
	var ring_index := int(root.get_meta("gill_ring_index"))
	var rest_center: Vector3 = root.get_meta("gill_rest_center")
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ring_stride := shell_segments + 1
	if (ring_index + 1) * ring_stride > verts.size():
		return
	# Live rib centreline + a rib in front of it, read off the deformed mesh so the loft/neck
	# blend is captured exactly; the heading between them is the local yaw the slits tilt with.
	var live_center := _rib_centerline(verts, ring_index)
	var front_ring := mini(ring_index + 2, verts.size() / ring_stride - 1)
	var live_front := _rib_centerline(verts, front_ring)
	var yaw := atan2(live_center.z - live_front.z, live_front.x - live_center.x)
	var basis := Basis(Vector3.UP, yaw)
	root.transform = Transform3D(basis, live_center - basis * rest_center)

# Centreline of a mesh rib = midpoint of its +z (segment 0) and -z (opposite segment) verts.
func _rib_centerline(verts: PackedVector3Array, ring_index: int) -> Vector3:
	var ring_stride := shell_segments + 1
	var base := ring_index * ring_stride
	return (verts[base] + verts[base + shell_segments / 2]) * 0.5

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

# The shark head is the integrated SharkHeadProfile mesh, sampled front -> rear over u, in
# HEAD-LOCAL space (the base class caches these and applies the head_node transform + neck
# loft per frame - see FishRig._unified_head_rings / _build_unified_weld_grid).
func _compute_head_local_rings(_head_shape: String, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> Array:
	var rings := []
	for sample in SharkHeadProfile.u_samples(parameters):
		var u := float(sample)
		var ring := PackedVector3Array()
		for segment in range(shell_segments + 1):
			var theta := TAU * float(segment) / float(shell_segments)
			ring.append(SharkHeadProfile.point_at(parameters, u, theta, snout_length, forehead_slope, sculpt))
		rings.append(ring)
	return rings

func _shark_head_ring_to_body_space(u: float, snout_length: float, forehead_slope: float, sculpt: Dictionary) -> PackedVector3Array:
	var ring := PackedVector3Array()
	if head_node == null:
		return ring
	var xf := head_node.transform
	for segment in range(shell_segments + 1):
		var theta := TAU * float(segment) / float(shell_segments)
		ring.append(xf * SharkHeadProfile.point_at(parameters, u, theta, snout_length, forehead_slope, sculpt))
	return ring

func _unified_head_ring_handle_local_positions(ring_id: String) -> Dictionary:
	if not _uses_unified_head_ring_handle(ring_id) or head_node == null:
		return {}
	var sample_t := _unified_head_ring_sample_t(ring_id)
	if sample_t < 0.0:
		return {}
	var ring := _shark_head_ring_to_body_space(
		sample_t,
		param_float("snout_length", 0.0),
		param_float("forehead_slope", 0.35),
		_head_sculpt_params()
	)
	return _ring_handle_positions_from_points(_apply_snout_curve_offset(ring))
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

# A shark turns more rigidly than a fish: the whole body banks into the turn as one arc instead
# of the fish's head-leads-then-tail-flicks S-curve. So every rib yaws the SAME direction (no
# opposite tail flick), gently easing from head to tail, and the head and tail engage together
# from the start (one phase ramp) rather than the head snapping first.
func _turn_ring_yaw(t: float, turn_amount: float, turn_direction: float, _tail_lag: float) -> float:
	if turn_amount <= 0.0:
		return 0.0
	var turn_phase := clampf(param_float("turn_phase", 0.0), 0.0, 1.0)
	var amount := turn_amount
	if turn_amount > 0.001 and turn_phase > 0.001:
		amount = turn_amount * sin(PI * pow(turn_phase, 0.6))
	var t_clamped := clampf(t, 0.0, 1.0)
	return turn_direction * amount * lerpf(SHARK_TURN_HEAD_YAW, SHARK_TURN_TAIL_YAW, t_clamped)

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
