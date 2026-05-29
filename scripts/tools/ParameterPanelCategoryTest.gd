extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")

func _ready() -> void:
	var panel := ParameterPanelScript.new()
	add_child(panel)
	await get_tree().process_frame
	panel.set_parameters({
		"head_offset": -0.5,
		"head_shape": "rounded",
		"dorsal_1_attach_t": 0.45,
		"caudal_shape": "forked_shallow",
		"swim_speed": 1.0,
		"base_color": "#46c6cf",
		"body_length": 1.2
	})
	assert(panel.get_section_body("Head") != null)
	assert(panel.get_section_body("Fins") != null)
	assert(panel.get_section_body("Motion") != null)
	assert(panel.get_section_body("Render") != null)
	assert(panel.get_section_body("Body") != null)
	assert(_find_slider_for_label(panel, "head_offset") != null)
	panel.set_section_collapsed("Head", true)
	assert(not panel.get_section_body("Head").visible)
	panel.set_section_collapsed("Head", false)
	assert(panel.get_section_body("Head").visible)

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
