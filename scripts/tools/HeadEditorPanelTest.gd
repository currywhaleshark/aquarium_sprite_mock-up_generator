extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")

func _ready() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	var seen := [{}]
	var seen_vector_slot := [""]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
	)
	panel.vector_edit_target_changed.connect(func(slot: String) -> void:
		seen_vector_slot[0] = slot
	)
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"snout_appendage": "none",
		"gill_mark": "none",
		"head_offset": -0.58,
		"eye_position_y": 0.12,
		"snout_length": 0.0,
		"mouth_size": 0.08,
		"lower_jaw_length": 1.0,
		"lower_jaw_angle": 0.0,
		"lower_jaw_thickness": 1.0,
		"lower_jaw_tip": 0.0
	})
	assert(not _has_numeric_slider(panel, "forehead_slope"))
	assert(not _has_numeric_slider(panel, "snout_appendage_length"))
	assert(_has_numeric_slider(panel, "head_top_flatness"))
	assert(_has_numeric_slider(panel, "head_bottom_flatness"))
	assert(_has_numeric_slider(panel, "head_left_flatness"))
	assert(_has_numeric_slider(panel, "head_right_flatness"))
	assert(_has_numeric_slider(panel, "lower_jaw_length"))
	assert(_has_numeric_slider(panel, "lower_jaw_angle"))
	assert(_has_numeric_slider(panel, "lower_jaw_thickness"))
	assert(_has_numeric_slider(panel, "lower_jaw_tip"))
	var hinge_x_slider := _slider_for_key(panel, "jaw_hinge_x")
	var hinge_y_slider := _slider_for_key(panel, "jaw_hinge_y")
	assert(hinge_x_slider != null)
	assert(hinge_y_slider != null)
	assert(absf(hinge_x_slider.min_value + 0.8) < 0.001)
	assert(absf(hinge_x_slider.max_value - 1.0) < 0.001)
	assert(absf(hinge_y_slider.min_value + 0.4) < 0.001)
	assert(absf(hinge_y_slider.max_value - 0.4) < 0.001)
	assert(not _has_numeric_slider(panel, "operculum_size"))
	assert(not _has_numeric_slider(panel, "operculum_height"))
	assert(not _has_numeric_slider(panel, "operculum_open"))
	assert(not _has_numeric_slider(panel, "operculum_ridge"))
	assert(not _has_numeric_slider(panel, "operculum_position_x"))
	assert(not _has_numeric_slider(panel, "operculum_position_y"))
	panel.set_option_parameter("gill_mark", "operculum")
	assert(seen_vector_slot[0] == "operculum")
	assert(_has_numeric_slider(panel, "operculum_size"))
	assert(_has_numeric_slider(panel, "operculum_height"))
	assert(_has_numeric_slider(panel, "operculum_open"))
	assert(_has_numeric_slider(panel, "operculum_ridge"))
	assert(_has_numeric_slider(panel, "operculum_position_x"))
	assert(_has_numeric_slider(panel, "operculum_position_y"))
	panel.set_numeric_parameter("operculum_size", 1.25)
	panel.set_numeric_parameter("operculum_height", 1.35)
	panel.set_numeric_parameter("operculum_open", 0.6)
	panel.set_numeric_parameter("operculum_ridge", 0.8)
	panel.set_numeric_parameter("operculum_position_x", 0.08)
	panel.set_numeric_parameter("operculum_position_y", -0.22)
	assert(abs(float(seen[0].get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(seen[0].get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(seen[0].get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(seen[0].get("operculum_ridge", 0.0)) - 0.8) < 0.001)
	assert(abs(float(seen[0].get("operculum_position_x", 0.0)) - 0.08) < 0.001)
	assert(abs(float(seen[0].get("operculum_position_y", 0.0)) + 0.22) < 0.001)
	panel.set_numeric_parameter("operculum_position_x", 0.3)
	panel.set_numeric_parameter("operculum_position_y", -0.6)
	assert(abs(float(seen[0].get("operculum_position_x", 0.0)) - 0.12) < 0.001)
	assert(abs(float(seen[0].get("operculum_position_y", 0.0)) + 0.35) < 0.001)
	panel.set_option_parameter("gill_mark", "line")
	assert(seen_vector_slot[0] == "")
	assert(not _has_numeric_slider(panel, "operculum_size"))
	assert(not _has_numeric_slider(panel, "operculum_height"))
	assert(not _has_numeric_slider(panel, "operculum_open"))
	assert(not _has_numeric_slider(panel, "operculum_ridge"))
	assert(not _has_numeric_slider(panel, "operculum_position_x"))
	assert(not _has_numeric_slider(panel, "operculum_position_y"))
	panel.set_head_shape("steep_forehead")
	assert(_has_numeric_slider(panel, "forehead_slope"))
	panel.set_mouth_type("inferior")
	panel.set_snout_appendage("swordfish_bill")
	assert(_has_numeric_slider(panel, "snout_appendage_length"))
	panel.set_snout_appendage("none")
	assert(not _has_numeric_slider(panel, "snout_appendage_length"))
	panel.set_numeric_parameter("snout_length", 0.24)
	panel.set_numeric_parameter("head_offset", -0.72)
	panel.set_numeric_parameter("eye_position_y", 0.2)
	panel.set_numeric_parameter("lower_jaw_length", 1.4)
	panel.set_numeric_parameter("lower_jaw_angle", 52.0)
	panel.set_numeric_parameter("lower_jaw_thickness", 1.45)
	panel.set_numeric_parameter("lower_jaw_tip", -0.75)
	panel.set_numeric_parameter("jaw_hinge_x", 0.65)
	panel.set_numeric_parameter("jaw_hinge_y", -0.26)
	panel.set_numeric_parameter("head_top_flatness", 0.66)
	panel.set_numeric_parameter("head_bottom_flatness", 0.44)
	panel.set_numeric_parameter("head_left_flatness", 0.33)
	panel.set_numeric_parameter("head_right_flatness", 0.22)
	assert(String(seen[0].get("head_shape", "")) == "steep_forehead")
	assert(String(seen[0].get("mouth_type", "")) == "inferior")
	assert(abs(float(seen[0].get("snout_length", 0.0)) - 0.24) < 0.001)
	assert(abs(float(seen[0].get("head_offset", 0.0)) + 0.72) < 0.001)
	assert(abs(float(seen[0].get("eye_position_y", 0.0)) - 0.2) < 0.001)
	assert(abs(float(seen[0].get("lower_jaw_length", 0.0)) - 1.4) < 0.001)
	assert(abs(float(seen[0].get("lower_jaw_angle", 0.0)) - 52.0) < 0.001)
	assert(abs(float(seen[0].get("lower_jaw_thickness", 0.0)) - 1.45) < 0.001)
	assert(abs(float(seen[0].get("lower_jaw_tip", 0.0)) + 0.75) < 0.001)
	assert(abs(float(seen[0].get("jaw_hinge_x", 0.0)) - 0.65) < 0.001)
	assert(abs(float(seen[0].get("jaw_hinge_y", 0.0)) + 0.26) < 0.001)
	assert(abs(float(seen[0].get("head_top_flatness", 0.0)) - 0.66) < 0.001)
	assert(abs(float(seen[0].get("head_bottom_flatness", 0.0)) - 0.44) < 0.001)
	assert(abs(float(seen[0].get("head_left_flatness", 0.0)) - 0.33) < 0.001)
	assert(abs(float(seen[0].get("head_right_flatness", 0.0)) - 0.22) < 0.001)
	panel.set_numeric_parameter("head_top_flatness", 2.0)
	assert(abs(float(seen[0].get("head_top_flatness", 0.0)) - 1.0) < 0.001)
	panel.set_numeric_parameter("jaw_hinge_x", -0.8)
	panel.set_numeric_parameter("jaw_hinge_y", 0.4)
	assert(abs(float(seen[0].get("jaw_hinge_x", 0.0)) + 0.8) < 0.001)
	assert(abs(float(seen[0].get("jaw_hinge_y", 0.0)) - 0.4) < 0.001)
	panel.set_numeric_parameter("jaw_hinge_x", 1.5)
	panel.set_numeric_parameter("jaw_hinge_y", -0.6)
	assert(abs(float(seen[0].get("jaw_hinge_x", 0.0)) - 1.0) < 0.001)
	assert(abs(float(seen[0].get("jaw_hinge_y", 0.0)) + 0.4) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_editor_panel.ok", FileAccess.WRITE)
	file.store_string("head editor panel parameters emitted")
	file.close()
	print("HEAD_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)

func _has_numeric_slider(panel: Node, key: String) -> bool:
	var sliders: Dictionary = panel.get("numeric_sliders")
	return sliders.has(key)

func _slider_for_key(panel: Node, key: String) -> HSlider:
	var sliders: Dictionary = panel.get("numeric_sliders")
	if not sliders.has(key):
		return null
	return sliders[key]["slider"] as HSlider
