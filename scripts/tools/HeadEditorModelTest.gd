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

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_model.ok", FileAccess.WRITE)
	file.store_string("head editor model applied")
	file.close()
	print("HEAD_EDITOR_MODEL_TEST_OK")
	get_tree().quit(0)

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
