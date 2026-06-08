extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	var parameters := {
		"shell_enabled": 1.0,
		"body_length": 1.28,
		"body_height": 0.5,
		"body_width": 0.32,
		"tail_length": 0.7,
		"tail_fin_size": 0.34,
		"global_sway_amount": 4.0,
		"tail_sway_multiplier": 1.6,
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.24, "lower_height": 0.2, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.42, "lower_height": 0.36, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.52, "lower_height": 0.48, "width": 0.46, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": 0.0, "upper_height": 0.46, "lower_height": 0.42, "width": 0.38, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": 0.0, "upper_height": 0.28, "lower_height": 0.26, "width": 0.24, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": 0.0, "upper_height": 0.12, "lower_height": 0.12, "width": 0.08, "roundness": 0.7, "sway_weight": 1.0}
			]
		}
	}
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)
	parameters["global_sway_amount"] = 18.0
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)
	parameters["global_sway_amount"] = 2.0
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)

	var ray: RayRig = RayRigScript.new()
	add_child(ray)
	var ray_parameters := {
		"disc_length": 1.0,
		"disc_thickness": 0.14,
		"wing_width": 1.3,
		"base_color": "#5aaeb7"
	}
	ray.set_parameters(ray_parameters)
	ray_parameters["wing_width"] = 1.6
	ray.set_parameters(ray_parameters)
	ray_parameters["wing_width"] = 1.1
	ray.set_parameters(ray_parameters)
	ray.call("set_ring_editor_enabled", true)
	ray.call("set_ring_editor_enabled", false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(_count_named_children(ray, "DiscBody") == 1)
	assert(_count_named_descendants(ray, "BodyMesh") == 1)

	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	var presets: Array = main.get("presets")
	var ray_index := -1
	for i in presets.size():
		if String(presets[i].get("creature_type", "fish")) == "ray":
			ray_index = i
			break
	assert(ray_index >= 0)
	main.call("_load_preset", ray_index)
	assert(_count_named_children(main.get("world_root"), "ActiveRig") == 1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(_count_named_children(main.get("world_root"), "ActiveRig") == 1)
	var main_ray: Node = main.get("current_rig")
	var editor_parameters: Dictionary = main_ray.get("parameters").duplicate(true)
	editor_parameters["wing_width"] = float(editor_parameters.get("wing_width", 1.2)) + 0.1
	main.call("_apply_parameters_from_editor", editor_parameters)
	assert(_count_named_children(main_ray, "DiscBody") <= 1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(_count_named_children(main_ray, "DiscBody") == 1)
	assert(_count_named_descendants(main_ray, "BodyMesh") == 1)
	var body_mesh := _find_named_descendant(main_ray, "BodyMesh") as MeshInstance3D
	assert(body_mesh != null)
	main_ray.call("apply_pose", 0.0)
	var before_vertices := _sample_surface_y_values(body_mesh, 0)
	main_ray.call("apply_pose", 0.25)
	var after_vertices := _sample_surface_y_values(body_mesh, 0)
	assert(_max_y_delta(before_vertices, after_vertices) > 0.0001)
	main.call("_start_preview_turn", 1)
	for frame in 5:
		await get_tree().process_frame
		assert(_count_named_children(main.get("world_root"), "ActiveRig") == 1)
		assert(_count_named_children(main_ray, "DiscBody") == 1)
		assert(_count_named_descendants(main_ray, "BodyMesh") == 1)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/rig_immediate_rebuild.ok", FileAccess.WRITE)
	file.store_string("rebuild removes stale rig nodes immediately")
	file.close()
	print("RIG_IMMEDIATE_REBUILD_TEST_OK")
	get_tree().quit(0)

func _count_named_children(node: Node, child_name: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.name == child_name:
			count += 1
	return count

func _count_named_descendants(node: Node, child_name: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.name == child_name:
			count += 1
		count += _count_named_descendants(child, child_name)
	return count

func _find_named_descendant(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found := _find_named_descendant(child, child_name)
		if found != null:
			return found
	return null

func _sample_surface_y_values(mesh_instance: MeshInstance3D, surface_index: int) -> PackedFloat32Array:
	var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var samples := PackedFloat32Array()
	for vertex_index in [16, 64, 128, 160, 272]:
		samples.append(vertices[mini(vertex_index, vertices.size() - 1)].y)
	return samples

func _max_y_delta(before_values: PackedFloat32Array, after_values: PackedFloat32Array) -> float:
	var max_delta := 0.0
	for i in mini(before_values.size(), after_values.size()):
		max_delta = maxf(max_delta, absf(after_values[i] - before_values[i]))
	return max_delta
