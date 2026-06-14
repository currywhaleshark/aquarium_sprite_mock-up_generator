extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")

func _ready() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	var seen := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
	)
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"snout_appendage": "none",
		"gill_mark": "none",
		"snout_length": 0.0,
		"jaw_hinge_x": 0.0,
		"eye_size": 0.055,
	})
	await get_tree().process_frame

	assert(panel.has_method("set_search_text"))
	var section_bodies: Dictionary = panel.get("section_bodies")
	var mouth_body := section_bodies["입"] as Control
	assert(mouth_body != null)
	assert(not mouth_body.visible)

	panel.call("set_search_text", "턱")
	await get_tree().process_frame
	assert(_row_visible(panel, "jaw_hinge_x"))
	assert(mouth_body.visible)
	assert(not _row_visible(panel, "eye_size"))

	panel.set_numeric_parameter("jaw_hinge_x", 0.4)
	await get_tree().process_frame
	assert(abs(float(seen[0].get("jaw_hinge_x", 0.0)) - 0.4) < 0.001)
	assert(_row_visible(panel, "jaw_hinge_x"))
	assert(not _row_visible(panel, "eye_size"))

	panel.call("set_search_text", "")
	await get_tree().process_frame
	assert(_all_rows_visible(panel))
	assert(not mouth_body.visible)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/slider_search_filter.ok", FileAccess.WRITE)
	file.store_string("slider search filter preserves values and section state")
	file.close()
	print("SLIDER_SEARCH_FILTER_TEST_OK")
	get_tree().quit(0)

func _row_visible(panel: Node, key: String) -> bool:
	var sliders: Dictionary = panel.get("numeric_sliders")
	if not sliders.has(key):
		return false
	var row := sliders[key].get("row") as Control
	return row != null and row.visible

func _all_rows_visible(panel: Node) -> bool:
	var sliders: Dictionary = panel.get("numeric_sliders")
	for key in sliders.keys():
		var row := sliders[key].get("row") as Control
		if row == null or not row.visible:
			return false
	return true
