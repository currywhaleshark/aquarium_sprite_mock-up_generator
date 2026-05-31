extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	var panel := ParameterPanelScript.new()
	add_child(panel)
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
		"tail_fin_extra_swing": 0.45,
		"fin_yaw_follow_strength": 0.25,
		"median_fin_flap_amount": 1.5,
		"median_fin_flap_phase": 0.5,
		"base_color": "#46c6cf",
		"body_length": 1.2,
		"midbody_depth_scale": 1.4
	})
	assert(panel.get_section_body("Head") == null)
	assert(panel.get_section_body("Fins") == null)
	assert(panel.get_section_body("Motion Settings") != null)
	assert(panel.get_section_body("Visual Settings") != null)
	assert(panel.get_section_body("Global Settings") != null)
	assert(_find_option_for_label(panel, UiText.parameter("swim_mode")) != null)
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
	assert(_find_slider_for_label(panel, UiText.parameter("body_length")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("midbody_depth_scale")) == null)
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
