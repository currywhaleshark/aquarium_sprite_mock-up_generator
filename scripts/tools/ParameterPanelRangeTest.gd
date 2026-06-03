extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	var panel := ParameterPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	panel.set_parameters({
		"custom_offset_x": -0.5,
		"body_length": 1.2,
		"disc_thickness": 0.16,
		"tail_thickness": 0.055
	})
	var offset_slider := _find_slider_for_label(panel, UiText.parameter("custom_offset_x"))
	var body_slider := _find_slider_for_label(panel, UiText.parameter("body_length"))
	var disc_thickness_slider := _find_slider_for_label(panel, UiText.parameter("disc_thickness"))
	var tail_thickness_slider := _find_slider_for_label(panel, UiText.parameter("tail_thickness"))
	assert(offset_slider != null)
	assert(body_slider != null)
	assert(disc_thickness_slider != null)
	assert(tail_thickness_slider != null)
	assert(offset_slider.min_value < -0.5)
	assert(offset_slider.max_value > 0.5)
	assert(body_slider.min_value == 0.0)
	assert(absf(disc_thickness_slider.max_value - 0.3) < 0.0001)
	assert(absf(tail_thickness_slider.max_value - 0.2) < 0.0001)

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
