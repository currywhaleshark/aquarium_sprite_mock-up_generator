extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

var _failed := false

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"unified_surface_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.48,
		"head_length": 0.52,
		"body_length": 1.6,
		"body_height": 0.58,
		"body_width": 0.34,
		"gill_mark": "operculum",
		"operculum_size": 1.1,
		"operculum_height": 1.0,
		"operculum_open": 0.4,
		"operculum_position_x": 0.08,
		"operculum_position_y": 0.18,
		"turn_amount": 1.0,
		"turn_phase": 0.52,
		"turn_direction": 1.0,
		"turn_curve_bias": 1.0,
	})
	await get_tree().process_frame
	var root := fish.get_node_or_null("BodyPivot/GillMark_operculum") as Node3D
	if not _require(root != null, "operculum root must exist"):
		return
	var rest_origin := root.transform.origin
	fish.apply_pose(0.33)
	await get_tree().process_frame
	var attach_t := fish._operculum_center_t()
	var expected_yaw := fish._sample_animated_shell_yaw(attach_t, fish.animated_shell_yaws)
	var rest_center := fish._sample_animated_shell_center(attach_t, PackedVector3Array())
	var anim_center := fish._sample_animated_shell_center(attach_t, fish.animated_shell_centers)
	var expected_basis := Basis(Vector3.UP, deg_to_rad(expected_yaw))
	var expected_origin := anim_center - expected_basis * rest_center
	if not _require(root.transform.origin.distance_to(expected_origin) < 0.001, "operculum root must follow animated shell center"):
		return
	if not _require(absf(wrapf(root.rotation_degrees.y - expected_yaw, -180.0, 180.0)) < 0.05, "operculum root must follow animated shell yaw"):
		return
	if not _require(root.transform.origin.distance_to(rest_origin) > 0.001 or absf(expected_yaw) > 0.05, "operculum pose check must exercise a non-rest transform"):
		return
	print("OPERCULUM_POSE_ATTACHMENT_TEST_OK")
	get_tree().quit(0)

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false