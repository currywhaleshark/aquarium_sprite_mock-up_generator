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
		"eye_style": "bead",
		"head_offset": -0.58,
		"eye_position_y": 0.12,
		"snout_length": 0.0,
		"mouth_size": 0.08,
		"lower_jaw_length": 1.0,
		"lower_jaw_angle": 0.0,
		"lower_jaw_thickness": 1.0,
		"lower_jaw_tip": 0.0
	})
	var head_shape_grid = panel.get("head_shape_grid")
	var mouth_type_grid = panel.get("mouth_type_grid")
	var eye_style_grid = panel.get("eye_style_grid")
	assert(head_shape_grid != null)
	assert(mouth_type_grid != null)
	assert(eye_style_grid != null)
	head_shape_grid.value_selected.emit("pointed")
	assert(String(seen[0].get("head_shape", "")) == "pointed")
	mouth_type_grid.value_selected.emit("superior")
	assert(String(seen[0].get("mouth_type", "")) == "superior")
	eye_style_grid.value_selected.emit("large")
	assert(String(seen[0].get("eye_style", "")) == "large")
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "inferior",
		"eye_style": "telescope",
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
	assert(_grid_value_pressed(head_shape_grid, "rounded"))
	assert(_grid_value_pressed(mouth_type_grid, "inferior"))
	assert(_grid_value_pressed(eye_style_grid, "telescope"))
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
	assert(not panel.is_row_changed("head_size"))
	panel.set_numeric_parameter("head_size", 0.9)
	assert(panel.is_row_changed("head_size"))
	panel.set_numeric_parameter("head_size", panel._default_numeric("head_size"))
	assert(not panel.is_row_changed("head_size"))
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

	var shark_panel := HeadEditorPanelScript.new()
	add_child(shark_panel)
	var shark_seen := [{}]
	shark_panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		shark_seen[0] = parameters
	)
	shark_panel.set_parameters({
		"creature_type": "shark",
		"head_shape": "pointed",
		"mouth_type": "terminal",
		"mouth_detail": "lip",
		"mouth_size": 0.08,
		"lower_jaw_length": 1.0,
		"eye_style": "bead",
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_gill_slit_length": 0.22,
		"shark_gill_slit_spacing": 0.055,
		"shark_gill_slit_angle": -8.0,
		"shark_gill_slit_depth": 0.65,
		"shark_gill_slit_position_x": -0.28,
		"shark_gill_slit_position_y": 0.08,
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
	})
	assert(shark_panel.get("head_shape_grid") == null)
	assert(shark_panel.get("mouth_type_grid") == null)
	assert(shark_panel.get("mouth_detail_option") == null)
	for hidden_key in ["head_bump_height", "head_bump_pos", "head_bump_width", "head_bump_angle", "head_bump_round", "head_top_flatness", "head_bottom_flatness", "head_left_flatness", "head_right_flatness", "snout_base", "snout_thickness", "snout_taper", "snout_curve"]:
		assert(not _has_numeric_slider(shark_panel, hidden_key))
	assert(_has_numeric_slider(shark_panel, "head_size"))
	assert(_has_numeric_slider(shark_panel, "head_offset"))
	assert(_has_numeric_slider(shark_panel, "snout_length"))
	assert(_has_numeric_slider(shark_panel, "forehead_slope"))
	assert(_has_boolean_control(shark_panel, "shark_gill_slit_enabled"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_count"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_length"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_spacing"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_angle"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_depth"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_position_x"))
	assert(_has_numeric_slider(shark_panel, "shark_gill_slit_position_y"))
	assert(not _has_numeric_slider(shark_panel, "operculum_size"))
	assert(not _has_numeric_slider(shark_panel, "operculum_height"))
	assert(not _has_numeric_slider(shark_panel, "mouth_size"))
	assert(not _has_numeric_slider(shark_panel, "lower_jaw_length"))
	assert(_has_boolean_control(shark_panel, "shark_lower_teeth_visible"))
	assert(_has_numeric_slider(shark_panel, "shark_mouth_position_x"))
	assert(_has_numeric_slider(shark_panel, "shark_mouth_width"))
	assert(_has_numeric_slider(shark_panel, "shark_jaw_projection"))
	assert(_has_numeric_slider(shark_panel, "shark_tooth_size"))
	var shark_mouth_x_slider := _slider_for_key(shark_panel, "shark_mouth_position_x")
	var shark_tooth_angle_slider := _slider_for_key(shark_panel, "shark_tooth_angle")
	assert(shark_mouth_x_slider != null)
	assert(absf(shark_mouth_x_slider.min_value + 1.5) < 0.001)
	assert(absf(shark_mouth_x_slider.max_value - 0.2) < 0.001)
	assert(shark_tooth_angle_slider != null)
	assert(absf(shark_tooth_angle_slider.min_value + 45.0) < 0.001)
	assert(absf(shark_tooth_angle_slider.max_value - 45.0) < 0.001)
	var shark_gill_body := _section_body_for_title(shark_panel, "아가미")
	var shark_mouth_body := _section_body_for_title(shark_panel, "입")
	assert(shark_gill_body != null)
	assert(shark_mouth_body != null)
	assert(_control_parent(shark_panel, "shark_gill_slit_enabled") == shark_gill_body)
	assert(_control_parent(shark_panel, "shark_gill_slit_count") == shark_gill_body)
	assert(_control_parent(shark_panel, "shark_lower_teeth_visible") == shark_mouth_body)
	assert(_control_parent(shark_panel, "shark_mouth_width") == shark_mouth_body)
	shark_panel.set_boolean_parameter("shark_gill_slit_enabled", false)
	assert(not bool(shark_seen[0].get("shark_gill_slit_enabled", true)))
	shark_panel.set_numeric_parameter("shark_gill_slit_count", 7)
	assert(abs(float(shark_seen[0].get("shark_gill_slit_count", 0.0)) - 7.0) < 0.001)
	shark_panel.set_boolean_parameter("shark_lower_teeth_visible", false)
	assert(not bool(shark_seen[0].get("shark_lower_teeth_visible", true)))
	shark_panel.set_numeric_parameter("shark_tooth_visible_count", 13.6)
	assert(abs(float(shark_seen[0].get("shark_tooth_visible_count", 0.0)) - 14.0) < 0.001)

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

func _has_boolean_control(panel: Node, key: String) -> bool:
	var controls: Dictionary = panel.get("boolean_controls")
	return controls.has(key)

func _control_parent(panel: Node, key: String) -> Control:
	var boolean_controls: Dictionary = panel.get("boolean_controls")
	if boolean_controls.has(key):
		var boolean_row := boolean_controls[key]["row"] as Control
		return boolean_row.get_parent() as Control
	var sliders: Dictionary = panel.get("numeric_sliders")
	if sliders.has(key):
		var slider_row := sliders[key]["row"] as Control
		return slider_row.get_parent() as Control
	return null

func _section_body_for_title(panel: Node, title: String) -> Control:
	var bodies: Dictionary = panel.get("section_bodies")
	return bodies.get(title, null) as Control

func _grid_value_pressed(grid: Node, value: String) -> bool:
	var buttons: Dictionary = grid.get("buttons_by_value")
	if not buttons.has(value):
		return false
	var button := buttons[value] as Button
	return button != null and button.button_pressed
