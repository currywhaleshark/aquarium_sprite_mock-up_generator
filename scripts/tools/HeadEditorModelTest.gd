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

# Largest vertical change among head-body vertices (x > 0.1, behind the snout).
# The two meshes share vertex ordering, so compare index by index.
func _max_back_y_delta(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var max_delta := 0.0
	for i in mini(a.size(), b.size()):
		if a[i].x > 0.1:
			max_delta = maxf(max_delta, absf(a[i].y - b[i].y))
	return max_delta
