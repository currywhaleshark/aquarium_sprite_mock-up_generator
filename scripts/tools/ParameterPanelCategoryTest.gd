extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	var panel := ParameterPanelScript.new()
	add_child(panel)
	var seen := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
	)
	await get_tree().process_frame
	panel.set_parameters({
		"head_offset": -0.5,
		"eye_size": 0.05,
		"head_shape": "rounded",
		"dorsal_1_attach_t": 0.45,
		"dorsal_1_height": 0.28,
		"caudal_shape": "forked_shallow",
		"tail_length": 0.7,
		"swim_speed": 1.0,
		"body_sway_amount": 2.0,
		"tail_2_sway_amount": 15.0,
		"swim_mode": "general",
		"body_wave_amount": 0.35,
		"body_wave_start": 0.16,
		"body_wave_falloff": 0.75,
		"tail_fin_extra_swing": 0.45,
		"fin_yaw_follow_strength": 0.25,
		"median_fin_flap_amount": 1.5,
		"median_fin_flap_phase": 0.5,
		"base_color": "#46c6cf",
		"belly_color": "#c8f4ec",
		"fin_color": "#2b8ca3",
		"outline_color": "#123844",
		"outline_width": 0.012,
		"toon_steps": 3.0,
		"rim_light_strength": 0.35,
		"overall_scale": 1.0,
		"body_height_scale": 1.0,
		"facing_direction": 1.0,
		"render_angle": 0.0,
		"show_pivot_guides": 1.0,
		"visual_thickness": 0.32,
		"pectoral_flap_amount": 7.5,
		"body_length": 1.2,
		"midbody_depth_scale": 1.4
	})
	assert(panel.get_section_body("Head") == null)
	assert(panel.get_section_body("Fins") == null)
	assert(panel.get_section_body("Motion Settings") != null)
	assert(panel.get_section_body("Color Settings") != null)
	assert(panel.get_section_body("Global Settings") != null)
	assert(_find_option_for_label(panel, UiText.parameter("swim_mode")) != null)
	assert(_find_slider_for_label_in_section(panel, "Motion Settings", UiText.parameter("body_wave_amount")) != null)
	assert(_find_slider_for_label_in_section(panel, "Motion Settings", UiText.parameter("body_wave_start")) != null)
	assert(_find_slider_for_label_in_section(panel, "Motion Settings", UiText.parameter("body_wave_falloff")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("tail_fin_extra_swing")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("fin_yaw_follow_strength")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("median_fin_flap_amount")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("median_fin_flap_phase")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("head_offset")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("eye_size")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("dorsal_1_height")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("dorsal_1_attach_t")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("tail_length")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("body_sway_amount")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("tail_2_sway_amount")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("outline_width")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("toon_steps")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("rim_light_strength")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("overall_scale")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("body_height_scale")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("facing_direction")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("render_angle")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("show_pivot_guides")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("visual_thickness")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("pectoral_flap_amount")) == null)
	assert(_find_slider_for_label(panel, UiText.parameter("body_length")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("midbody_depth_scale")) == null)
	var base_color_picker := _find_color_picker_for_label_in_section(panel, "Color Settings", UiText.parameter("base_color"))
	assert(base_color_picker != null)
	assert(_find_color_picker_for_label_in_section(panel, "Color Settings", UiText.parameter("belly_color")) != null)
	assert(_find_color_picker_for_label_in_section(panel, "Color Settings", UiText.parameter("fin_color")) != null)
	assert(_find_color_picker_for_label_in_section(panel, "Color Settings", UiText.parameter("outline_color")) != null)
	base_color_picker.color_changed.emit(Color(0.2, 0.3, 0.4, 1.0))
	await get_tree().process_frame
	assert(String(seen[0].get("base_color", "")).begins_with("#"))
	panel.set_parameters(seen[0])
	assert(_find_color_picker_for_label_in_section(panel, "Color Settings", UiText.parameter("base_color")) != null)
	panel.set_section_collapsed("Motion Settings", true)
	assert(not panel.get_section_body("Motion Settings").visible)
	panel.set_section_collapsed("Motion Settings", false)
	assert(panel.get_section_body("Motion Settings").visible)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/parameter_panel_category.ok", FileAccess.WRITE)
	file.store_string("parameter panel sections collapse")
	file.close()
	print("PARAMETER_PANEL_CATEGORY_TEST_OK")
	get_tree().quit(0)

func _find_slider_for_label(panel: Control, label_text: String) -> HSlider:
	var rows := panel.get_node("ParameterRows")
	for section in rows.get_children():
		var body := section.get_node_or_null("Body")
		if body == null:
			continue
		for row in body.get_children():
			var label := row.get_child(0) as Label
			if label and label.text == label_text:
				return row.get_child(1) as HSlider
	return null

func _find_option_for_label(panel: Control, label_text: String) -> OptionButton:
	var rows := panel.get_node("ParameterRows")
	for section in rows.get_children():
		var body := section.get_node_or_null("Body")
		if body == null:
			continue
		for row in body.get_children():
			var label := row.get_child(0) as Label
			if label and label.text == label_text:
				return row.get_child(1) as OptionButton
	return null

func _find_slider_for_label_in_section(panel: Control, section_name: String, label_text: String) -> HSlider:
	var body: VBoxContainer = panel.get_section_body(section_name)
	if body == null:
		return null
	for row in body.get_children():
		var label := row.get_child(0) as Label
		if label and label.text == label_text:
			return row.get_child(1) as HSlider
	return null

func _find_color_picker_for_label_in_section(panel: Control, section_name: String, label_text: String) -> ColorPickerButton:
	var body: VBoxContainer = panel.get_section_body(section_name)
	if body == null:
		return null
	for row in body.get_children():
		var label := row.get_child(0) as Label
		if label and label.text == label_text:
			return row.get_child(1) as ColorPickerButton
	return null
