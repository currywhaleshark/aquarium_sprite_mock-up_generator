extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"head_bump_height": 0.3,
		"head_bump_pos": -0.2,
		"jaw_hinge_x": 0.0,
		"jaw_hinge_y": 0.0
	})
	await get_tree().process_frame

	var handles := fish.get_drag_handles()
	assert(handles.has("jaw_hinge"))
	assert(_near(handles["jaw_hinge"], fish.get_jaw_hinge_world()))
	assert(handles.has("head_bump"))
	assert(_near(handles["head_bump"], fish.get_head_bump_world()))

	var jaw_plane: Dictionary = fish.get_head_drag_plane("jaw_hinge")
	assert(_near(jaw_plane["point"], fish.get_jaw_hinge_world()))
	assert(_near(jaw_plane["normal"], fish.head_node.global_transform.basis.z.normalized()))

	var hinge_before := fish.get_jaw_hinge_world()
	var jaw_x0 := float(fish.parameters.get("jaw_hinge_x", 0.0))
	var jaw_y0 := float(fish.parameters.get("jaw_hinge_y", 0.0))
	fish.move_jaw_hinge(Vector3(0.05, 0.02, 0.0))
	assert(float(fish.parameters.get("jaw_hinge_x", 0.0)) > jaw_x0)
	assert(float(fish.parameters.get("jaw_hinge_y", 0.0)) > jaw_y0)
	assert(fish.get_jaw_hinge_world().distance_to(hinge_before) > 0.001)

	var bump_x0 := float(fish.parameters.get("head_bump_pos", 0.0))
	var bump_y0 := float(fish.parameters.get("head_bump_height", 0.0))
	fish.move_head_bump(Vector3(0.1, 0.05, 0.0))
	assert(float(fish.parameters.get("head_bump_pos", 0.0)) > bump_x0)
	assert(float(fish.parameters.get("head_bump_height", 0.0)) > bump_y0)

	fish.move_jaw_hinge(Vector3(100.0, 100.0, 0.0))
	assert(absf(float(fish.parameters.get("jaw_hinge_x", 0.0)) - 1.0) < 0.0001)
	assert(absf(float(fish.parameters.get("jaw_hinge_y", 0.0)) - 0.4) < 0.0001)
	fish.move_head_bump(Vector3(100.0, 100.0, 0.0))
	assert(absf(float(fish.parameters.get("head_bump_pos", 0.0)) - 0.5) < 0.0001)
	assert(absf(float(fish.parameters.get("head_bump_height", 0.0)) - 0.8) < 0.0001)

	fish.set_parameters({
		"shell_enabled": 1.0,
		"head_bump_height": 0.0
	})
	await get_tree().process_frame
	assert(not fish.get_drag_handles().has("head_bump"))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_handle_drag.ok", FileAccess.WRITE)
	file.store_string("head drag handles move jaw hinge and head bump")
	file.close()
	print("HEAD_HANDLE_DRAG_TEST_OK")
	get_tree().quit(0)

func _near(a: Vector3, b: Vector3, epsilon: float = 0.0001) -> bool:
	return a.distance_to(b) < epsilon
