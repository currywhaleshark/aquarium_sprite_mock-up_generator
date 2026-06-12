extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const SharkHeadProfile := preload("res://scripts/creature/SharkHeadProfile.gd")

const ROSTRUM_FRONT_X := -0.72
const NECK_X := 0.50

var _failed := false

func _ready() -> void:
	var base := _base_parameters()
	await _test_shark_uses_integrated_head_mesh(base)
	if _failed:
		return
	await _test_mouth_gape_changes_mouth_local_vertices(base)
	if _failed:
		return
	await _test_lower_jaw_drop_is_not_noop(base)
	if _failed:
		return
	await _test_rostrum_and_neck_are_closed(base)
	if _failed:
		return
	await _test_shark_eyes_follow_head_surface(base)
	if _failed:
		return
	await _test_mouth_line_has_crease_rings(base)
	if _failed:
		return
	print("SHARK_HEAD_MESH_TEST_OK")
	get_tree().quit(0)

func _base_parameters() -> Dictionary:
	return {
		"creature_type": "shark",
		"body_length": 5.8,
		"body_height": 0.42,
		"body_width": 0.28,
		"head_shape": "pointed",
		"head_size": 0.42,
		"head_offset": -0.78,
		"snout_length": 0.22,
		"forehead_slope": 0.2,
		"eye_style": "bead",
		"eye_size": 0.055,
		"eye_position_x": -0.92,
		"eye_position_y": 0.06,
		"mouth_type": "terminal",
		"mouth_detail": "lip",
		"mouth_open": 0.32,
		"mouth_size": 0.16,
		"jaw_offset": 0.4,
		"lower_jaw_length": 0.4,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_position_x": -0.96,
		"shark_mouth_position_y": -0.13,
		"shark_mouth_width": 0.18,
		"shark_mouth_curve": 0.58,
		"shark_mouth_gape": 0.28,
		"shark_jaw_projection": 0.14,
		"shark_lower_jaw_drop": 0.35,
		"shark_lower_teeth_visible": true,
		"shark_tooth_visible_count": 11,
		"shark_tooth_size": 0.018,
		"shark_tooth_angle": -8.0,
		"shark_labial_furrow_length": 0.04
	}

func _test_shark_uses_integrated_head_mesh(parameters: Dictionary) -> void:
	var shark := await _build_shark(parameters)
	var head := _head(shark)
	if _failed:
		return
	if not _require(String(head.get_meta("head_profile_type", "")) == "shark", "shark must use the integrated shark head mesh"):
		return
	for node_path in [
		"Mouth",
		"MouthLowerJaw",
		"MouthCavity",
		"MouthFloor",
		"MouthLipUpper"
	]:
		if not _require(head.get_node_or_null(node_path) == null, "fish mouth node must be absent: %s" % node_path):
			return
	for child in head.get_children():
		if not _require(not String(child.name).begins_with("MouthDetail_"), "fish mouth detail must be absent"):
			return
	if not _require(head.get_node_or_null("SharkMouth/MouthCrescent") == null, "old overlay crescent must be absent"):
		return
	if not _require(head.get_node_or_null("SharkMouth/LowerJaw") == null, "old overlay lower jaw must be absent"):
		return
	if not _require(head.get_node_or_null("SharkMouth/ProjectedUpperJaw") == null, "old overlay upper jaw must be absent"):
		return
	shark.queue_free()

func _test_mouth_gape_changes_mouth_local_vertices(parameters: Dictionary) -> void:
	var closed_params := parameters.duplicate(true)
	closed_params["shark_mouth_gape"] = 0.0
	var open_params := parameters.duplicate(true)
	open_params["shark_mouth_gape"] = 0.36
	var closed := await _build_shark(closed_params)
	var opened := await _build_shark(open_params)
	var closed_head := _head(closed)
	var open_head := _head(opened)
	var closed_vertices := _vertices(closed_head)
	var open_vertices := _vertices(open_head)
	if not _require(closed_vertices.size() == open_vertices.size(), "gape changes must keep stable vertex order"):
		return
	var mouth_u := float(closed_head.get_meta("shark_mouth_u", 0.32))
	var mouth_y := float(closed_head.get_meta("shark_mouth_center_y", -0.13))
	var mouth_delta := _max_mouth_window_delta(closed_vertices, open_vertices, mouth_u, mouth_y)
	var non_mouth_delta := _max_non_mouth_delta(closed_vertices, open_vertices, mouth_u, mouth_y)
	if not _require(mouth_delta > 0.012, "mouth-local vertices must move when gape opens"):
		return
	if not _require(non_mouth_delta < mouth_delta * 0.75, "gape deformation must stay localized near the mouth"):
		return
	if not _require(_lower_mouth_average_y_delta(closed_vertices, open_vertices, mouth_u, mouth_y) < -0.004, "lower mouth vertices must drop when gape opens"):
		return
	closed.queue_free()
	opened.queue_free()

func _test_lower_jaw_drop_is_not_noop(parameters: Dictionary) -> void:
	var low_params := parameters.duplicate(true)
	low_params["shark_mouth_gape"] = 0.28
	low_params["shark_lower_jaw_drop"] = 0.0
	var high_params := parameters.duplicate(true)
	high_params["shark_mouth_gape"] = 0.28
	high_params["shark_lower_jaw_drop"] = 0.4
	var low := await _build_shark(low_params)
	var high := await _build_shark(high_params)
	var low_head := _head(low)
	var high_head := _head(high)
	var low_vertices := _vertices(low_head)
	var high_vertices := _vertices(high_head)
	if not _require(low_vertices.size() == high_vertices.size(), "drop changes must keep stable vertex order"):
		return
	var mouth_u := float(low_head.get_meta("shark_mouth_u", 0.32))
	var mouth_y := float(low_head.get_meta("shark_mouth_center_y", -0.13))
	if not _require(_strong_lower_mouth_average_y_delta(low_vertices, high_vertices, mouth_u, mouth_y) < -0.004, "lower jaw drop must move lower mouth vertices downward"):
		return
	low.queue_free()
	high.queue_free()

func _test_rostrum_and_neck_are_closed(parameters: Dictionary) -> void:
	var shark := await _build_shark(parameters)
	var head := _head(shark)
	var vertices := _vertices(head)
	var normals := _normals(head)
	if not _require(_extreme_ring_radius(vertices, true) <= 0.006, "rostrum tip must not expose an open ring"):
		return
	if not _require(_extreme_ring_radius(vertices, false) <= 0.006, "neck end must be capped"):
		return
	if not _require(_average_outward_normal_dot(vertices, normals) > 0.15, "head normals must face outward"):
		return
	shark.queue_free()

func _test_mouth_line_has_crease_rings(parameters: Dictionary) -> void:
	var shark := await _build_shark(parameters)
	var head := _head(shark)
	var samples: PackedFloat32Array = head.get_meta("shark_u_samples", PackedFloat32Array())
	if not _require(samples.size() > 8, "shark head must expose u sample metadata for crease verification"):
		return
	var mouth_u := float(head.get_meta("shark_mouth_u", 0.32))
	var near_count := 0
	var near_spacing := INF
	var ordinary_spacing := 0.0
	for i in range(1, samples.size()):
		var a := float(samples[i - 1])
		var b := float(samples[i])
		var spacing := absf(b - a)
		if absf(a - mouth_u) < 0.07 or absf(b - mouth_u) < 0.07:
			near_spacing = minf(near_spacing, spacing)
		else:
			ordinary_spacing = maxf(ordinary_spacing, spacing)
	for sample in samples:
		if absf(float(sample) - mouth_u) <= 0.06:
			near_count += 1
	if not _require(near_count >= 3, "mouth line must have concentrated crease rings"):
		return
	if not _require(near_spacing < ordinary_spacing * 0.75, "mouth rings must be denser than ordinary head rings"):
		return
	shark.queue_free()

func _test_shark_eyes_follow_head_surface(parameters: Dictionary) -> void:
	var shark := await _build_shark(parameters)
	var head := _head(shark)
	var eye_l := shark.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	var eye_r := shark.get_node_or_null("BodyPivot/EyeR") as MeshInstance3D
	if not _require(eye_l != null and eye_r != null, "shark eyes must exist"):
		return
	if not _require(_eye_surface_error(head, eye_l, parameters, -1.0) <= 0.18, "left eye must sit near the shark head surface"):
		return
	if not _require(_eye_surface_error(head, eye_r, parameters, 1.0) <= 0.18, "right eye must sit near the shark head surface"):
		return
	shark.queue_free()

func _build_shark(parameters: Dictionary) -> Node:
	var shark := SharkRigScript.new()
	add_child(shark)
	shark.set_parameters(parameters)
	await get_tree().process_frame
	return shark

func _head(shark: Node) -> MeshInstance3D:
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if not _require(head != null, "shark head is missing"):
		return null
	if not _require(head.mesh != null, "shark head mesh is missing"):
		return null
	return head

func _vertices(head: MeshInstance3D) -> PackedVector3Array:
	var arrays := head.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]

func _normals(head: MeshInstance3D) -> PackedVector3Array:
	var arrays := head.mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_NORMAL]

func _u_for_x(x: float) -> float:
	return clampf((x - ROSTRUM_FRONT_X) / (NECK_X - ROSTRUM_FRONT_X), 0.0, 1.0)

func _u_for_x_with_snout(x: float, parameters: Dictionary) -> float:
	var front_x := ROSTRUM_FRONT_X - clampf(float(parameters.get("snout_length", 0.0)), 0.0, 0.6) * 0.35
	return clampf((x - front_x) / (NECK_X - front_x), 0.0, 1.0)

func _eye_surface_error(head: MeshInstance3D, eye: MeshInstance3D, parameters: Dictionary, side: float) -> float:
	var local := head.to_local(eye.global_position)
	var u := _u_for_x_with_snout(local.x, parameters)
	var expected_z := SharkHeadProfile.surface_z_at(parameters, u, local.y, side)
	return absf(absf(local.z) - absf(expected_z))

func _is_mouth_vertex(vertex: Vector3, mouth_u: float, mouth_y: float) -> bool:
	return absf(_u_for_x(vertex.x) - mouth_u) <= 0.075 and absf(vertex.y - mouth_y) <= 0.13 and absf(vertex.z) >= 0.025

func _is_strong_lower_mouth_vertex(vertex: Vector3, mouth_u: float, mouth_y: float) -> bool:
	return absf(_u_for_x(vertex.x) - mouth_u) <= 0.035 and vertex.y < mouth_y + 0.02 and vertex.y > mouth_y - 0.12 and absf(vertex.z) >= 0.035

func _max_mouth_window_delta(closed_vertices: PackedVector3Array, open_vertices: PackedVector3Array, mouth_u: float, mouth_y: float) -> float:
	var max_delta := 0.0
	for i in range(mini(closed_vertices.size(), open_vertices.size())):
		if _is_mouth_vertex(closed_vertices[i], mouth_u, mouth_y):
			max_delta = maxf(max_delta, closed_vertices[i].distance_to(open_vertices[i]))
	return max_delta

func _max_non_mouth_delta(closed_vertices: PackedVector3Array, open_vertices: PackedVector3Array, mouth_u: float, mouth_y: float) -> float:
	var max_delta := 0.0
	for i in range(mini(closed_vertices.size(), open_vertices.size())):
		if not _is_mouth_vertex(closed_vertices[i], mouth_u, mouth_y):
			max_delta = maxf(max_delta, closed_vertices[i].distance_to(open_vertices[i]))
	return max_delta

func _lower_mouth_average_y_delta(closed_vertices: PackedVector3Array, open_vertices: PackedVector3Array, mouth_u: float, mouth_y: float) -> float:
	var sum := 0.0
	var count := 0
	for i in range(mini(closed_vertices.size(), open_vertices.size())):
		var vertex := closed_vertices[i]
		if _is_mouth_vertex(vertex, mouth_u, mouth_y) and vertex.y <= mouth_y:
			sum += open_vertices[i].y - vertex.y
			count += 1
	if not _require(count > 0, "mouth lower vertex window must not be empty"):
		return 0.0
	return sum / float(count)

func _strong_lower_mouth_average_y_delta(low_vertices: PackedVector3Array, high_vertices: PackedVector3Array, mouth_u: float, mouth_y: float) -> float:
	var sum := 0.0
	var count := 0
	for i in range(mini(low_vertices.size(), high_vertices.size())):
		var vertex := low_vertices[i]
		if _is_strong_lower_mouth_vertex(vertex, mouth_u, mouth_y):
			sum += high_vertices[i].y - vertex.y
			count += 1
	if not _require(count > 0, "strong lower mouth vertex window must not be empty"):
		return 0.0
	return sum / float(count)

func _extreme_ring_radius(vertices: PackedVector3Array, front: bool) -> float:
	var extreme_x := INF if front else -INF
	for vertex in vertices:
		extreme_x = minf(extreme_x, vertex.x) if front else maxf(extreme_x, vertex.x)
	var max_radius := 0.0
	for vertex in vertices:
		var near_extreme := vertex.x <= extreme_x + 0.002 if front else vertex.x >= extreme_x - 0.002
		if near_extreme:
			max_radius = maxf(max_radius, Vector2(vertex.y, vertex.z).length())
	return max_radius

func _average_outward_normal_dot(vertices: PackedVector3Array, normals: PackedVector3Array) -> float:
	if not _require(normals.size() == vertices.size(), "head mesh must include normals"):
		return 0.0
	var sum := 0.0
	var count := 0
	for i in range(vertices.size()):
		var radial := Vector3(0.0, vertices[i].y, vertices[i].z)
		if radial.length() < 0.01:
			continue
		sum += normals[i].normalized().dot(radial.normalized())
		count += 1
	if not _require(count > 0, "normal verification window must not be empty"):
		return 0.0
	return sum / float(count)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false
