extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.12,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"turn_tail_lag": 0.75,
		"inside_pectoral_fold": 0.8
	})
	await get_tree().process_frame
	fish.apply_pose(0.25)
	var straight_yaws: PackedFloat32Array = fish.get("animated_shell_yaws")
	var straight_tail_yaw := float(straight_yaws[straight_yaws.size() - 1])
	var straight_left: Node3D = fish.get_node("BodyPivot/PectoralFinL")
	var straight_right: Node3D = fish.get_node("BodyPivot/PectoralFinR")
	var straight_left_x := straight_left.rotation_degrees.x
	var straight_right_x := straight_right.rotation_degrees.x

	var turn_parameters: Dictionary = fish.get("parameters")
	turn_parameters["turn_amount"] = 1.0
	turn_parameters["turn_direction"] = 1.0
	fish.parameters = turn_parameters
	fish.apply_pose(0.25)
	var turn_yaws: PackedFloat32Array = fish.get("animated_shell_yaws")
	var turn_tail_yaw := float(turn_yaws[turn_yaws.size() - 1])
	var turn_left: Node3D = fish.get_node("BodyPivot/PectoralFinL")
	var turn_right: Node3D = fish.get_node("BodyPivot/PectoralFinR")

	assert(absf(turn_tail_yaw - straight_tail_yaw) > 4.0)
	assert(absf(turn_left.rotation_degrees.x - straight_left_x) > 2.0)
	assert(absf(turn_right.rotation_degrees.x - straight_right_x) > 2.0)
	assert(absf(turn_left.rotation_degrees.x - turn_right.rotation_degrees.x) > 4.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/turn_pose.ok", FileAccess.WRITE)
	file.store_string("turn pose layer bends shell and pectoral fins")
	file.close()
	print("TURN_POSE_TEST_OK")
	get_tree().quit(0)
