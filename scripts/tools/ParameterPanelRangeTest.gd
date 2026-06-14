extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	var panel := ParameterPanelScript.new()
	var ray_panel := ParameterPanelScript.new()
	add_child(panel)
	add_child(ray_panel)
	await get_tree().process_frame
	panel.set_parameters({
		"custom_offset_x": -0.5,
		"body_length": 1.2,
		"tail_thickness": 0.055,
		"fin_ray_style": "fan",
		"fin_ray_count": 48.0,
		"fin_ray_root_bias": -0.25,
		"fin_ray_spread": 0.75,
		"fin_spine_count": 12.0,
		"fin_spine_strength": 0.5,
		"fin_ray_branching": 0.5,
		"fin_ray_segmentation": 0.5,
		"fin_ray_irregularity": 0.5,
		"adipose_fin_enabled": false,
		"adipose_fin_position": 0.82,
		"finlet_enabled": true,
		"finlet_pitch": 0.25,
		"finlet_dorsal_count": 9.0
	})
	ray_panel.set_creature_type("ray")
	ray_panel.set_parameters({
		"creature_type": "ray",
		"disc_thickness": 0.16
	})
	var offset_slider := _find_slider_for_label(panel, UiText.parameter("custom_offset_x"))
	var body_slider := _find_slider_for_label(panel, UiText.parameter("body_length"))
	var disc_thickness_slider := _find_slider_for_label(ray_panel, UiText.parameter("disc_thickness"))
	var tail_thickness_slider := _find_slider_for_label(panel, UiText.parameter("tail_thickness"))
	var fin_ray_count_slider := _find_slider_for_label(panel, UiText.parameter("fin_ray_count"))
	var fin_root_bias_slider := _find_slider_for_label(panel, UiText.parameter("fin_ray_root_bias"))
	var fin_spine_count_slider := _find_slider_for_label(panel, UiText.parameter("fin_spine_count"))
	var adipose_enabled_check := _find_checkbox_for_label(panel, UiText.parameter("adipose_fin_enabled"))
	var adipose_position_slider := _find_slider_for_label(panel, UiText.parameter("adipose_fin_position"))
	var finlet_enabled_check := _find_checkbox_for_label(panel, UiText.parameter("finlet_enabled"))
	var finlet_pitch_slider := _find_slider_for_label(panel, UiText.parameter("finlet_pitch"))
	assert(offset_slider != null)
	assert(body_slider != null)
	assert(disc_thickness_slider != null)
	assert(tail_thickness_slider != null)
	assert(offset_slider.min_value < -0.5)
	assert(offset_slider.max_value > 0.5)
	assert(body_slider.min_value == 0.0)
	assert(absf(disc_thickness_slider.max_value - 0.3) < 0.0001)
	assert(absf(tail_thickness_slider.max_value - 0.2) < 0.0001)
	assert(fin_ray_count_slider != null)
	assert(absf(fin_ray_count_slider.max_value - 48.0) < 0.0001)
	assert(fin_root_bias_slider != null)
	assert(fin_root_bias_slider.min_value <= -1.0)
	assert(fin_root_bias_slider.max_value >= 1.0)
	assert(fin_spine_count_slider != null)
	assert(absf(fin_spine_count_slider.max_value - 12.0) < 0.0001)
	assert(adipose_enabled_check != null)
	assert(adipose_enabled_check.button_pressed == false)
	assert(adipose_position_slider != null)
	assert(absf(adipose_position_slider.min_value - 0.0) < 0.0001)
	assert(absf(adipose_position_slider.max_value - 1.0) < 0.0001)
	assert(finlet_enabled_check != null)
	assert(finlet_enabled_check.button_pressed == true)
	assert(finlet_pitch_slider != null)
	assert(finlet_pitch_slider.min_value <= -1.0)
	assert(finlet_pitch_slider.max_value >= 1.0)
	assert(UiText.parameter("fin_ray_style") == "기조 스타일")
	assert(UiText.option("threaded") == "실지느러미형")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/parameter_panel_range.ok", FileAccess.WRITE)
	file.store_string("offset sliders allow negative restore")
	file.close()
	print("PARAMETER_PANEL_RANGE_TEST_OK")
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

func _find_checkbox_for_label(panel: Control, label_text: String) -> CheckBox:
	var rows := panel.get_node("ParameterRows")
	for section in rows.get_children():
		var body := section.get_node_or_null("Body")
		if body == null:
			continue
		for row in body.get_children():
			var label := row.get_child(0) as Label
			if label and label.text == label_text:
				return row.get_child(1) as CheckBox
	return null
