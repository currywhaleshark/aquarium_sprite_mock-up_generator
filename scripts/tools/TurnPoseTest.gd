extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

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

	assert(absf(turn_tail_yaw - straight_tail_yaw) > 24.0)
	assert(absf(turn_left.rotation_degrees.x - straight_left_x) > 8.0)
	assert(absf(turn_right.rotation_degrees.x - straight_right_x) > 8.0)
	assert(absf(turn_left.rotation_degrees.x - turn_right.rotation_degrees.x) > 14.0)

	var early_turn_parameters: Dictionary = fish.get("parameters")
	early_turn_parameters["turn_amount"] = 0.35
	early_turn_parameters["turn_phase"] = 0.12
	early_turn_parameters["turn_direction"] = 1.0
	fish.parameters = early_turn_parameters
	fish.apply_pose(0.25)
	var head: MeshInstance3D = fish.get_node("BodyPivot/Head")
	assert(absf(head.rotation_degrees.y) > 10.0)
	var shark_turn_ok := await _test_shark_full_body_c_arc_yaw_profile()
	if not shark_turn_ok:
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/turn_pose.ok", FileAccess.WRITE)
	file.store_string("turn pose layer bends shell and pectoral fins")
	file.close()
	print("TURN_POSE_TEST_OK")
	get_tree().quit(0)

func _test_shark_full_body_c_arc_yaw_profile() -> bool:
	var shark: SharkRig = SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false
	shark.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"turn_amount": 1.0,
		"turn_direction": 1.0,
		"turn_phase": 0.0,
	})
	await get_tree().process_frame
	var head_yaw := absf(shark._turn_ring_yaw(0.0, 1.0, 1.0, 0.75))
	var shoulder_yaw := absf(shark._turn_ring_yaw(0.25, 1.0, 1.0, 0.75))
	var mid_yaw := absf(shark._turn_ring_yaw(0.5, 1.0, 1.0, 0.75))
	var rear_yaw := absf(shark._turn_ring_yaw(0.75, 1.0, 1.0, 0.75))
	var tail_yaw := absf(shark._turn_ring_yaw(1.0, 1.0, 1.0, 0.75))
	if head_yaw < 27.5 or head_yaw > 28.5:
		push_error("SHARK_TURN_HEAD_C_ARC_OUT_OF_RANGE %.2f" % head_yaw)
		return false
	if shoulder_yaw < 24.5 or shoulder_yaw > 26.0:
		push_error("SHARK_TURN_SHOULDER_C_ARC_OUT_OF_RANGE %.2f" % shoulder_yaw)
		return false
	if mid_yaw < 19.5 or mid_yaw > 21.0:
		push_error("SHARK_TURN_MIDBODY_C_ARC_OUT_OF_RANGE %.2f" % mid_yaw)
		return false
	if rear_yaw < 15.5 or rear_yaw > 17.0:
		push_error("SHARK_TURN_REARBODY_C_ARC_OUT_OF_RANGE %.2f" % rear_yaw)
		return false
	if tail_yaw < 11.5 or tail_yaw > 12.5:
		push_error("SHARK_TURN_TAIL_C_ARC_OUT_OF_RANGE %.2f" % tail_yaw)
		return false
	if not (head_yaw > shoulder_yaw and shoulder_yaw > mid_yaw and mid_yaw > rear_yaw and rear_yaw > tail_yaw):
		push_error("SHARK_TURN_C_ARC_NOT_MONOTONIC head=%.2f shoulder=%.2f mid=%.2f rear=%.2f tail=%.2f" % [head_yaw, shoulder_yaw, mid_yaw, rear_yaw, tail_yaw])
		return false
	shark.queue_free()
	return true
