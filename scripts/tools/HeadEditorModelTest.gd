extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
		"shell_enabled": 1.0,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"head_shape": "hump",
		"mouth_type": "inferior",
		"snout_length": 0.18,
		"forehead_slope": 0.65,
		"jaw_offset": -0.09,
		"mouth_size": 0.12,
		"head_flattening": 0.1
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	assert(head != null)
	assert(mouth != null)
	assert(head.scale.x > head.scale.y)
	assert(mouth.position.y < -0.05)
	# The mouth is a dark opening band framed by upper/lower lip bands that curve along the
	# snout (so it reads as a real mouth hugging the surface, not a flat coin). The opening
	# band's x must recede toward its z edges (it wraps the snout), not stay flat.
	var lip_upper := fish.get_node_or_null("BodyPivot/Head/MouthLipUpper") as MeshInstance3D
	var lip_lower := fish.get_node_or_null("BodyPivot/Head/MouthLipLower") as MeshInstance3D
	assert(lip_upper != null and lip_lower != null)
	var mouth_verts: PackedVector3Array = mouth.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var center_x := INF
	var edge_x := -INF
	for v in mouth_verts:
		if absf(v.z) < 0.01:
			center_x = minf(center_x, v.x)   # local x near centre (most negative = frontmost)
		edge_x = maxf(edge_x, v.x)            # x at the widest z (recedes back, larger)
	assert(edge_x > center_x + 0.001)         # band curves back at the edges -> hugs the snout
	var initial_head_scale_x := head.scale.x
	var initial_shell_profile: Array = fish.shell_profile
	var initial_front_radius_y := float(initial_shell_profile[1].y)
	var initial_shell_start_x := float(initial_shell_profile[0].x)

	fish.set_head_shape("pointed")
	fish.set_mouth_type("superior")
	var adjusted_parameters: Dictionary = fish.parameters.duplicate(true)
	adjusted_parameters["snout_length"] = 0.28
	adjusted_parameters["head_flattening"] = 0.55
	adjusted_parameters["snout_appendage"] = "swordfish_bill"
	adjusted_parameters["snout_appendage_length"] = 0.35
	fish.set_parameters(adjusted_parameters)
	await get_tree().process_frame
	await get_tree().process_frame
	var head_after := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var mouth_after := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	var socket_after := fish.get_node_or_null("BodyPivot/Head/SnoutSocket") as Node3D
	var appendage_after := fish.get_node_or_null("BodyPivot/Head/SnoutSocket/SnoutAppendage") as Node3D
	var pointed_shell_profile: Array = fish.shell_profile
	assert(head_after.scale.x > initial_head_scale_x)
	assert(mouth_after.position.y > 0.0)
	assert(socket_after != null)
	assert(appendage_after != null)
	assert(abs(socket_after.position.x - (-0.5 - 0.28)) < 0.001)
	assert(abs(socket_after.scale.x - (1.0 / head_after.scale.x)) < 0.001)
	assert(float(pointed_shell_profile[1].y) < initial_front_radius_y * 0.8)
	assert(float(pointed_shell_profile[0].x) > head_after.position.x - head_after.scale.x * 0.35)
	assert(float(pointed_shell_profile[0].x) < head_after.position.x - head_after.scale.x * 0.05)

	# Jaw shear: dropping the jaw moves the snout tip (and mouth) down while the head
	# body stays put - the snout shears into a flat-bottom triangle, the head does not move.
	var neutral_jaw: Dictionary = fish.parameters.duplicate(true)
	neutral_jaw["head_shape"] = "rounded"
	neutral_jaw["mouth_type"] = "terminal"
	neutral_jaw["snout_length"] = 0.2
	neutral_jaw["snout_appendage"] = "none"
	neutral_jaw["head_flattening"] = 0.0
	neutral_jaw["jaw_offset"] = 0.0
	fish.set_parameters(neutral_jaw)
	await get_tree().process_frame
	await get_tree().process_frame
	var neutral_verts := _head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)
	var neutral_tip_y := _front_tip_min_y(neutral_verts)
	var neutral_mouth_y := (fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D).position.y

	var dropped_jaw: Dictionary = neutral_jaw.duplicate(true)
	dropped_jaw["mouth_type"] = "inferior"
	dropped_jaw["jaw_offset"] = -0.28
	fish.set_parameters(dropped_jaw)
	await get_tree().process_frame
	await get_tree().process_frame
	var dropped_verts := _head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)
	var dropped_tip_y := _front_tip_min_y(dropped_verts)
	var dropped_mouth_y := (fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D).position.y
	# Mouth and snout tip drop together...
	assert(dropped_mouth_y < neutral_mouth_y - 0.2)
	assert(dropped_tip_y < neutral_tip_y - 0.1)
	# ...but the head body (behind the snout base, x > 0.1) must stay put.
	assert(_max_back_y_delta(neutral_verts, dropped_verts) < 0.001)

	# Snout curve: an upward curve raises the snout tip (jaw neutral) while the head
	# body again stays put.
	var curved_jaw: Dictionary = neutral_jaw.duplicate(true)
	curved_jaw["snout_curve"] = 0.8
	fish.set_parameters(curved_jaw)
	await get_tree().process_frame
	await get_tree().process_frame
	var curved_verts := _head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)
	assert(_front_tip_max_y(curved_verts) > _front_tip_max_y(neutral_verts) + 0.1)
	assert(_max_back_y_delta(neutral_verts, curved_verts) < 0.001)

	# Dorsal profile: a positive head_top_curve raises the top of the head (nuchal
	# hump) without dropping the belly; a negative one flattens the top (arowana).
	var flat_top: Dictionary = neutral_jaw.duplicate(true)
	flat_top["snout_length"] = 0.0
	flat_top["head_top_curve"] = 0.0
	fish.set_parameters(flat_top)
	await get_tree().process_frame
	await get_tree().process_frame
	var base_top := _max_y(_head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D))

	var humped: Dictionary = flat_top.duplicate(true)
	humped["head_top_curve"] = 0.9
	fish.set_parameters(humped)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(_max_y(_head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)) > base_top + 0.1)

	# Forehead bump: a forward-leaning crown bump must push geometry both up and
	# forward (-x), i.e. it juts out in front rather than only bulging upward.
	var no_bump: Dictionary = flat_top.duplicate(true)
	no_bump["head_bump_height"] = 0.0
	fish.set_parameters(no_bump)
	await get_tree().process_frame
	await get_tree().process_frame
	var no_bump_verts := _head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)
	var base_crown_y := _max_y(no_bump_verts)

	var bumped: Dictionary = no_bump.duplicate(true)
	bumped["head_bump_height"] = 0.35
	bumped["head_bump_pos"] = -0.2
	bumped["head_bump_angle"] = 60.0
	fish.set_parameters(bumped)
	await get_tree().process_frame
	await get_tree().process_frame
	var bumped_verts := _head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D)
	# Crown rises and the bump region pushes forward (-x).
	assert(_max_y(bumped_verts) > base_crown_y + 0.05)
	assert(_max_forward_push(no_bump_verts, bumped_verts) > 0.05)

	# The body shell follows a strong dorsal hump near the head: the head ring grows
	# taller and its center shifts up so the shell encloses the bulge.
	var shell_neutral: Dictionary = flat_top.duplicate(true)
	shell_neutral["shell_enabled"] = 1.0
	shell_neutral["head_top_curve"] = 0.0
	shell_neutral["head_bump_height"] = 0.0
	fish.set_parameters(shell_neutral)
	await get_tree().process_frame
	await get_tree().process_frame
	var hi := _shell_ring_index(fish, "snout")
	assert(hi >= 0)
	var base_radius := float(fish.shell_profile[hi].y)
	var base_center := float(fish.shell_center_y_offsets[hi])

	var shell_hump: Dictionary = shell_neutral.duplicate(true)
	shell_hump["head_top_curve"] = 0.9
	shell_hump["head_top_peak"] = 0.2
	fish.set_parameters(shell_hump)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(float(fish.shell_profile[hi].y) > base_radius + 0.01)
	assert(float(fish.shell_center_y_offsets[hi]) > base_center + 0.005)

	# mouth_open actually gapes the jaws (hinged): the lower jaw drops further than the
	# upper lifts, so the front-edge gap grows from a closed slit to a wide opening.
	var closed: Dictionary = shell_neutral.duplicate(true)
	closed["mouth_open"] = 0.0
	fish.set_parameters(closed)
	await get_tree().process_frame
	var closed_gap := _jaw_gap(fish)
	# Measure the lips relative to the HEAD (not world) so the rig's idle animation doesn't
	# add frame-phase noise to these tight stability comparisons.
	var closed_head := fish.get_node_or_null("BodyPivot/Head") as Node3D
	var closed_upper_lip_extent := _head_local_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipUpper") as MeshInstance3D, closed_head)
	var closed_lower_lip_extent := _head_local_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipLower") as MeshInstance3D, closed_head)
	var closed_lower_jaw := fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D
	# A fully closed mouth gets no dark cavity (it could otherwise peek out of a shut mouth).
	assert(fish.get_node_or_null("BodyPivot/Head/MouthCavity") == null)
	var lower_jaw_extent := _mesh_extent(closed_lower_jaw)
	assert(lower_jaw_extent.x > 0.35)
	assert(lower_jaw_extent.y > 0.16)
	assert(lower_jaw_extent.z > 0.28)
	var closed_rear_hinge := _node_rear_local_point(closed_lower_jaw)
	var closed_front_jaw := _node_front_point(closed_lower_jaw)
	assert(closed_rear_hinge.x > 0.1)
	var agape: Dictionary = shell_neutral.duplicate(true)
	agape["mouth_open"] = 1.0
	fish.set_parameters(agape)
	await get_tree().process_frame
	assert(_jaw_gap(fish) > closed_gap + 0.01)
	var open_head := fish.get_node_or_null("BodyPivot/Head") as Node3D
	var open_upper_lip_extent := _head_local_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipUpper") as MeshInstance3D, open_head)
	var open_lower_lip_extent := _head_local_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipLower") as MeshInstance3D, open_head)
	assert(absf(open_upper_lip_extent.position.y - closed_upper_lip_extent.position.y) < 0.005)
	assert(open_lower_lip_extent.position.y < closed_lower_lip_extent.position.y - 0.015)
	var upper_jaw := fish.get_node_or_null("BodyPivot/Head/MouthUpperJaw") as MeshInstance3D
	var lower_jaw := fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D
	var interior := fish.get_node_or_null("BodyPivot/Head/MouthInterior") as MeshInstance3D
	assert(upper_jaw == null)
	assert(lower_jaw != null and interior != null)
	var open_upper_front := _head_upper_mouth_point(fish)
	var open_lower_front := _node_front_point(lower_jaw)
	assert(open_upper_front.y > open_lower_front.y + 0.02)
	assert(open_lower_front.x > open_upper_front.x - 0.015)
	assert(open_lower_front.y < closed_front_jaw.y - 0.08)
	# Open mouth gets a head-scale dark cavity that fills the gape (much larger than the
	# mouth_size dark band) so the opening reads as a deep recess, not the body-coloured roof.
	var cavity := fish.get_node_or_null("BodyPivot/Head/MouthCavity") as MeshInstance3D
	assert(cavity != null)
	var cavity_extent := _mesh_extent(cavity)
	var dark_band_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D)
	assert(cavity_extent.y > dark_band_extent.y * 1.5)
	# The dark opening grows with mouth_open (it doesn't stay a fixed size).
	var half_open: Dictionary = agape.duplicate(true)
	half_open["mouth_open"] = 0.4
	fish.set_parameters(half_open)
	await get_tree().process_frame
	var half_cavity_y := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthCavity") as MeshInstance3D).y
	assert(cavity_extent.y > half_cavity_y + 0.02)

	# Premaxilla protrusion (Phase 7): a protrusible jaw throws the upper jaw FORWARD (-x)
	# as the mouth opens, so the head's snout-front vertices advance. With no protrusion the
	# snout front is stationary when opening (the legacy fixed upper jaw).
	var protr_closed: Dictionary = shell_neutral.duplicate(true)
	protr_closed["mouth_type"] = "terminal"
	protr_closed["jaw_protrusion"] = 0.2
	protr_closed["mouth_open"] = 0.0
	fish.set_parameters(protr_closed)
	await get_tree().process_frame
	await get_tree().process_frame
	var protr_closed_front := _min_x(_head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D))
	var protr_open: Dictionary = protr_closed.duplicate(true)
	protr_open["mouth_open"] = 1.0
	fish.set_parameters(protr_open)
	await get_tree().process_frame
	await get_tree().process_frame
	var protr_open_front := _min_x(_head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D))
	assert(protr_open_front < protr_closed_front - 0.05)

	var noprotr_open: Dictionary = protr_open.duplicate(true)
	noprotr_open["jaw_protrusion"] = 0.0
	fish.set_parameters(noprotr_open)
	await get_tree().process_frame
	await get_tree().process_frame
	var noprotr_open_front := _min_x(_head_vertices(fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D))
	assert(absf(noprotr_open_front - protr_closed_front) < 0.01)

	# Hinge controls (Phase 7): jaw_hinge_x lengthens the lower jaw (hinge further back ->
	# longer jaw mesh) and jaw_hinge_y raises/lowers the whole jaw with its pivot. Both were
	# inert until the jaw mesh consumed them.
	var jaw_short: Dictionary = shell_neutral.duplicate(true)
	jaw_short["mouth_type"] = "terminal"
	jaw_short["mouth_open"] = 0.2
	jaw_short["jaw_hinge_x"] = -0.15
	fish.set_parameters(jaw_short)
	await get_tree().process_frame
	var short_jaw_len := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).x
	var jaw_long: Dictionary = jaw_short.duplicate(true)
	jaw_long["jaw_hinge_x"] = 0.3
	fish.set_parameters(jaw_long)
	await get_tree().process_frame
	var long_jaw_len := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).x
	assert(long_jaw_len > short_jaw_len + 0.05)

	var jaw_low: Dictionary = jaw_short.duplicate(true)
	jaw_low["jaw_hinge_x"] = 0.0
	jaw_low["jaw_hinge_y"] = -0.12
	fish.set_parameters(jaw_low)
	await get_tree().process_frame
	var low_jaw_y := _world_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).position.y
	var jaw_high: Dictionary = jaw_low.duplicate(true)
	jaw_high["jaw_hinge_y"] = 0.12
	fish.set_parameters(jaw_high)
	await get_tree().process_frame
	var high_jaw_y := _world_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).position.y
	assert(high_jaw_y > low_jaw_y + 0.03)

	# get_jaw_hinge_world exposes the actual lower-jaw pivot (for the editor hinge marker)
	# and tracks jaw_hinge_y: a higher hinge sits higher in world space.
	var hinge_high_world := fish.get_jaw_hinge_world()
	assert(not is_inf(hinge_high_world.x))
	fish.set_parameters(jaw_low)
	await get_tree().process_frame
	var hinge_low_world := fish.get_jaw_hinge_world()
	assert(hinge_high_world.y > hinge_low_world.y + 0.03)

	# Tube mouth: at full gape the lower jaw extends forward with the protruding premaxilla
	# (front reaches out while the hinge stays put), so a protrusible jaw's lower-jaw mesh is
	# longer than a non-protrusible one instead of lagging behind the protruded upper jaw.
	var flat_open: Dictionary = shell_neutral.duplicate(true)
	flat_open["mouth_type"] = "terminal"
	flat_open["mouth_open"] = 1.0
	flat_open["jaw_protrusion"] = 0.0
	fish.set_parameters(flat_open)
	await get_tree().process_frame
	var flat_jaw_size := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).length()
	var tube_open: Dictionary = flat_open.duplicate(true)
	tube_open["jaw_protrusion"] = 0.25
	fish.set_parameters(tube_open)
	await get_tree().process_frame
	var tube_jaw_size := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D).length()
	assert(tube_jaw_size > flat_jaw_size + 0.05)

	var small_mouth: Dictionary = shell_neutral.duplicate(true)
	small_mouth["mouth_open"] = 0.0
	small_mouth["mouth_size"] = 0.06
	fish.set_parameters(small_mouth)
	await get_tree().process_frame
	var small_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	var large_mouth: Dictionary = small_mouth.duplicate(true)
	large_mouth["mouth_size"] = 0.2
	fish.set_parameters(large_mouth)
	await get_tree().process_frame
	var large_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	assert(absf(large_jaw_extent.y - small_jaw_extent.y) < 0.01)
	assert(large_jaw_extent.z > small_jaw_extent.z * 1.5)

	var shallow_head: Dictionary = shell_neutral.duplicate(true)
	shallow_head["mouth_open"] = 0.0
	shallow_head["body_profile"] = _body_profile_with_head_lower(shallow_head, 0.18)
	fish.set_parameters(shallow_head)
	await get_tree().process_frame
	var shallow_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	var deep_head: Dictionary = shell_neutral.duplicate(true)
	deep_head["mouth_open"] = 0.0
	deep_head["body_profile"] = _body_profile_with_head_lower(deep_head, 0.54)
	fish.set_parameters(deep_head)
	await get_tree().process_frame
	var deep_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	assert(deep_jaw_extent.y > shallow_jaw_extent.y * 1.5)

	var flat_belly: Dictionary = shell_neutral.duplicate(true)
	flat_belly["mouth_open"] = 0.0
	flat_belly["head_belly_curve"] = -0.8
	fish.set_parameters(flat_belly)
	await get_tree().process_frame
	var flat_belly_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	var round_belly: Dictionary = flat_belly.duplicate(true)
	round_belly["head_belly_curve"] = 0.8
	fish.set_parameters(round_belly)
	await get_tree().process_frame
	var round_belly_jaw_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as MeshInstance3D)
	assert(round_belly_jaw_extent.y > flat_belly_jaw_extent.y * 1.3)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_model.ok", FileAccess.WRITE)
	file.store_string("head editor model applied")
	file.close()
	print("HEAD_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)

func _jaw_front_edge_y(fish, node_path: String) -> float:
	var node := fish.get_node_or_null(node_path) as MeshInstance3D
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := node.global_transform
	# If upper lip, the bite edge is y_lo (index 5)
	# If lower lip, the bite edge is y_hi (index 16)
	if node.name.contains("Upper"):
		return (xf * verts[5]).y
	else:
		return (xf * verts[16]).y

func _jaw_gap(fish) -> float:
	var upper := _world_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipUpper") as MeshInstance3D)
	var lower := _world_mesh_extent(fish.get_node_or_null("BodyPivot/Head/MouthLipLower") as MeshInstance3D)
	return upper.position.y - lower.end.y

func _node_front_point(node: MeshInstance3D) -> Vector3:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := node.global_transform
	var min_x := INF
	var point := Vector3.ZERO
	for v in verts:
		var w := xf * v
		if w.x < min_x:
			min_x = w.x
			point = w
	return point

func _node_rear_local_point(node: MeshInstance3D) -> Vector3:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_x := -INF
	var point := Vector3.ZERO
	for v in verts:
		if v.x > max_x:
			max_x = v.x
			point = v
	return point

func _mesh_extent(node: MeshInstance3D) -> Vector3:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for v in verts:
		min_v.x = minf(min_v.x, v.x)
		min_v.y = minf(min_v.y, v.y)
		min_v.z = minf(min_v.z, v.z)
		max_v.x = maxf(max_v.x, v.x)
		max_v.y = maxf(max_v.y, v.y)
		max_v.z = maxf(max_v.z, v.z)
	return max_v - min_v

func _world_mesh_extent(node: MeshInstance3D) -> AABB:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := node.global_transform
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for v in verts:
		var w := xf * v
		min_v.x = minf(min_v.x, w.x)
		min_v.y = minf(min_v.y, w.y)
		min_v.z = minf(min_v.z, w.z)
		max_v.x = maxf(max_v.x, w.x)
		max_v.y = maxf(max_v.y, w.y)
		max_v.z = maxf(max_v.z, w.z)
	return AABB(min_v, max_v - min_v)

func _head_local_mesh_extent(node: MeshInstance3D, head: Node3D) -> AABB:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var to_head := head.global_transform.affine_inverse() * node.global_transform
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for v in verts:
		var w := to_head * v
		min_v.x = minf(min_v.x, w.x); min_v.y = minf(min_v.y, w.y); min_v.z = minf(min_v.z, w.z)
		max_v.x = maxf(max_v.x, w.x); max_v.y = maxf(max_v.y, w.y); max_v.z = maxf(max_v.z, w.z)
	return AABB(min_v, max_v - min_v)

func _body_profile_with_head_lower(parameters: Dictionary, lower_height: float) -> Dictionary:
	var profile: Dictionary = parameters.get("body_profile", {}).duplicate(true)
	var rings: Array = profile.get("rings", [])
	for i in rings.size():
		if String(rings[i].get("id", "")) == "head":
			var ring: Dictionary = rings[i].duplicate(true)
			ring["lower_height"] = lower_height
			rings[i] = ring
			break
	profile["rings"] = rings
	return profile

func _head_upper_mouth_point(fish) -> Vector3:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as MeshInstance3D
	var verts: PackedVector3Array = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var xf := head.global_transform
	var mouth_y := mouth.global_position.y
	var min_x := INF
	var point := Vector3.ZERO
	for v in verts:
		var w := xf * v
		if w.y < mouth_y:
			continue
		if absf(w.z - mouth.global_position.z) > head.scale.z * 0.16:
			continue
		if w.x < min_x:
			min_x = w.x
			point = w
	return point

func _head_vertices(head: MeshInstance3D) -> PackedVector3Array:
	var arr_mesh := head.mesh as ArrayMesh
	return arr_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func _front_tip_min_y(verts: PackedVector3Array) -> float:
	var min_y := INF
	for v in verts:
		if v.x < -0.45:
			min_y = minf(min_y, v.y)
	return min_y

func _front_tip_max_y(verts: PackedVector3Array) -> float:
	var max_y := -INF
	for v in verts:
		if v.x < -0.45:
			max_y = maxf(max_y, v.y)
	return max_y

func _shell_ring_index(fish: Node, ring_id: String) -> int:
	var ids: Array = fish.shell_ring_ids
	return ids.find(ring_id)

func _max_y(verts: PackedVector3Array) -> float:
	var max_y := -INF
	for v in verts:
		max_y = maxf(max_y, v.y)
	return max_y

func _min_x(verts: PackedVector3Array) -> float:
	var min_x := INF
	for v in verts:
		min_x = minf(min_x, v.x)
	return min_x

# Largest forward (-x) displacement among upper vertices between two meshes that
# share vertex ordering.
func _max_forward_push(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var max_push := 0.0
	for i in mini(a.size(), b.size()):
		if a[i].y > 0.05:
			max_push = maxf(max_push, a[i].x - b[i].x)
	return max_push

# Largest vertical change among head-body vertices (x > 0.1, behind the snout).
# The two meshes share vertex ordering, so compare index by index.
func _max_back_y_delta(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var max_delta := 0.0
	for i in mini(a.size(), b.size()):
		if a[i].x > 0.1:
			max_delta = maxf(max_delta, absf(a[i].y - b[i].y))
	return max_delta
