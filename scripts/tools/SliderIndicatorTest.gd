extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"gill_mark": "operculum",
		"mouth_open": 0.6,
		"eye_size": 0.06,
	})
	await get_tree().process_frame

	assert(fish.has_method("get_indicator_world"))
	var jaw_indicator: Vector3 = fish.call("get_indicator_world", "jaw_hinge_x")
	var jaw_world: Vector3 = fish.get_jaw_hinge_world()
	assert(not is_inf(jaw_indicator.x))
	assert(jaw_indicator.distance_to(jaw_world) < 0.001)

	var eye_indicator: Vector3 = fish.call("get_indicator_world", "eye_size")
	assert(not is_inf(eye_indicator.x))
	assert(eye_indicator.distance_to(fish.eye_l.global_position) < 0.001)

	var operculum_indicator: Vector3 = fish.call("get_indicator_world", "operculum_size")
	assert(not is_inf(operculum_indicator.x))
	fish.set_parameters({"shell_enabled": 1.0, "gill_mark": "none", "mouth_open": 0.6})
	await get_tree().process_frame
	operculum_indicator = fish.call("get_indicator_world", "operculum_size")
	assert(is_inf(operculum_indicator.x))

	fish.set_selected_body_ring("mid_body")
	await get_tree().process_frame
	var upper_indicator: Vector3 = fish.call("get_indicator_world", "upper_height")
	var expected_upper := _ring_world(fish, "mid_body", "top")
	assert(not is_inf(upper_indicator.x))
	assert(upper_indicator.distance_to(expected_upper) < 0.001)

	var unknown_indicator: Vector3 = fish.call("get_indicator_world", "no_such_key")
	assert(is_inf(unknown_indicator.x))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/slider_indicator.ok", FileAccess.WRITE)
	file.store_string("slider indicator world points resolved")
	file.close()
	print("SLIDER_INDICATOR_TEST_OK")
	get_tree().quit(0)

func _ring_world(fish: FishRig, ring_id: String, part: String) -> Vector3:
	var body_pivot := fish.body_pivot
	if body_pivot == null:
		return Vector3.INF
	for i in fish.shell_ring_ids.size():
		if String(fish.shell_ring_ids[i]) != ring_id:
			continue
		var profile := fish.shell_profile[i]
		var center_y := fish.shell_center_y_offsets[i] if i < fish.shell_center_y_offsets.size() else 0.0
		match part:
			"top":
				center_y += profile.y
			"bottom":
				center_y -= profile.y
		return body_pivot.to_global(Vector3(profile.x, center_y, -profile.z - 0.03))
	return Vector3.INF
