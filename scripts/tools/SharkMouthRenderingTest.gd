extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	var shark := SharkRigScript.new()
	add_child(shark)
	var parameters := {
		"creature_type": "shark",
		"body_length": 5.8,
		"body_height": 0.42,
		"body_width": 0.28,
		"head_shape": "pointed",
		"head_size": 0.42,
		"head_offset": -0.78,
		"snout_length": 0.22,
		"forehead_slope": 0.2,
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
		"shark_mouth_gape": 0.16,
		"shark_jaw_projection": 0.08,
		"shark_lower_jaw_drop": 0.10,
		"shark_lower_teeth_visible": true,
		"shark_tooth_visible_count": 11,
		"shark_tooth_size": 0.018,
		"shark_tooth_angle": -8.0,
		"shark_labial_furrow_length": 0.04
	}
	shark.set_parameters(parameters)
	await get_tree().process_frame

	var root := shark.get_node_or_null("BodyPivot/Head/SharkMouth")
	assert(root != null)
	assert(root.get_node_or_null("MouthCrescent") != null)
	assert(root.get_node_or_null("LowerTeeth") != null)
	assert(root.get_node_or_null("UpperTeeth") != null)
	assert(root.get_node_or_null("ProjectedUpperJaw") == null)
	_assert_mouth_hugs_head_surface(shark)
	_assert_no_fish_mouth_nodes(shark)
	_assert_head_carve_suppressed(shark, parameters)

	parameters["shark_mouth_gape"] = 0.32
	parameters["shark_jaw_projection"] = 0.16
	shark.set_parameters(parameters)
	await get_tree().process_frame
	var moved_root := shark.get_node_or_null("BodyPivot/Head/SharkMouth")
	assert(moved_root != null)
	assert(moved_root.get_node_or_null("ProjectedUpperJaw") != null)
	_assert_mouth_hugs_head_surface(shark)

	parameters["mouth_open"] = 0.0
	parameters["shark_mouth_gape"] = 0.0
	parameters["shark_jaw_projection"] = 0.0
	shark.set_parameters(parameters)
	await get_tree().process_frame
	_assert_no_fish_mouth_nodes(shark)

	shark.rebuild()
	await get_tree().process_frame
	assert(shark.get_node_or_null("BodyPivot/Head/SharkMouth") != null)
	assert(shark.get_node_or_null("BodyPivot/SharkGillSlits") != null)
	_assert_no_fish_mouth_nodes(shark)

	print("SHARK_MOUTH_RENDERING_TEST_OK")
	get_tree().quit(0)

func _assert_no_fish_mouth_nodes(shark: Node) -> void:
	var body := shark.get_node_or_null("BodyPivot")
	assert(body != null)
	var head := shark.get_node_or_null("BodyPivot/Head")
	assert(head != null)
	for node_name in ["Mouth", "MouthLowerJaw", "MouthCavity", "MouthFloor", "MouthLipUpper", "MouthDetail_lip"]:
		assert(body.get_node_or_null(node_name) == null)
		assert(head.get_node_or_null(node_name) == null)
		assert(shark.find_child(node_name, true, false) == null)

func _assert_mouth_hugs_head_surface(shark: Node) -> void:
	var head := shark.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	var root := head.get_node_or_null("SharkMouth")
	assert(root != null)
	assert(root.get_parent() == head)
	var mouth := root.get_node_or_null("MouthCrescent") as MeshInstance3D
	assert(mouth != null)
	var bounds := _mesh_y_bounds(head)
	assert(mouth.position.y >= bounds.x - 0.01)
	assert(mouth.position.y <= bounds.y + 0.01)
	var surface_z := _positive_head_surface_z(head, mouth.position.x, mouth.position.y)
	assert(mouth.position.z >= surface_z - 0.005)
	assert(mouth.position.z <= surface_z + 0.06)

func _assert_head_carve_suppressed(shark: Node, parameters: Dictionary) -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	var fish_params := parameters.duplicate(true)
	fish_params["creature_type"] = "fish"
	fish_params["mouth_open"] = 0.0
	fish.set_parameters(fish_params)
	var shark_front := _mouth_region_average_x(shark.get_node("BodyPivot/Head") as MeshInstance3D)
	var fish_front := _mouth_region_average_x(fish.get_node("BodyPivot/Head") as MeshInstance3D)
	assert(shark_front < fish_front - 0.004)
	remove_child(fish)
	fish.free()

func _mouth_region_average_x(head: MeshInstance3D) -> float:
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sum := 0.0
	var count := 0
	for vertex in verts:
		if vertex.x < 0.1 and absf(vertex.z) < 0.09 and vertex.y > -0.22 and vertex.y < -0.02:
			sum += vertex.x
			count += 1
	assert(count > 0)
	return sum / float(count)

func _positive_head_surface_z(head: MeshInstance3D, local_x: float, local_y: float) -> float:
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var best_distance := INF
	var best_z := 0.0
	for vertex in verts:
		if vertex.z < 0.0:
			continue
		var dx := vertex.x - local_x
		var dy := vertex.y - local_y
		var distance := dx * dx + dy * dy
		if distance < best_distance:
			best_distance = distance
			best_z = vertex.z
	return best_z

func _mesh_y_bounds(mesh_instance: MeshInstance3D) -> Vector2:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_y := INF
	var max_y := -INF
	for vertex in verts:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	return Vector2(min_y, max_y)
