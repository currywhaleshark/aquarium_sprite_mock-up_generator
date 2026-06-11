extends Node

const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var panel := HeadEditorPanelScript.new()
	add_child(panel)
	var seen_keys: Array[String] = []
	panel.numeric_slider_hovered.connect(func(key: String) -> void:
		seen_keys.append(key)
	)
	panel.set_parameters({
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"snout_appendage": "none",
		"gill_mark": "none",
		"snout_length": 0.0,
		"jaw_hinge_x": 0.0,
		"head_size": 0.44,
	})
	await get_tree().process_frame

	var hinge_widgets := _widgets_for_key(panel, "jaw_hinge_x")
	var hinge_row := hinge_widgets["row"] as Control
	var hinge_label := hinge_widgets["name_label"] as Label
	assert(hinge_row != null)
	assert(hinge_label != null)
	assert(not hinge_label.has_theme_color_override("font_color"))
	hinge_row.emit_signal("mouse_entered")
	assert(not seen_keys.is_empty())
	assert(seen_keys.back() == "jaw_hinge_x")
	assert(hinge_label.has_theme_color_override("font_color"))
	hinge_row.emit_signal("mouse_exited")
	assert(seen_keys.size() >= 2)
	assert(seen_keys.back() == "")
	assert(not hinge_label.has_theme_color_override("font_color"))

	panel.set_numeric_parameter("head_size", 0.9)
	var changed_widgets := _widgets_for_key(panel, "head_size")
	var changed_row := changed_widgets["row"] as Control
	var changed_label := changed_widgets["name_label"] as Label
	assert(changed_label.has_theme_color_override("font_color"))
	changed_row.emit_signal("mouse_entered")
	assert(seen_keys.size() >= 3)
	assert(seen_keys.back() == "head_size")
	changed_row.emit_signal("mouse_exited")
	assert(seen_keys.size() >= 4)
	assert(seen_keys.back() == "")
	assert(changed_label.has_theme_color_override("font_color"))

	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	var overlay := main.get("drag_handles_overlay") as Control
	var timer := main.get("indicator_timer") as Timer
	assert(overlay != null)
	assert(timer != null)
	assert(main.has_method("_on_editor_numeric_slider_hovered"))
	main.call("_on_editor_numeric_slider_hovered", "jaw_hinge_x")
	assert(String(overlay.get("indicator_key")) == "jaw_hinge_x")
	assert(timer.is_stopped())
	main.call("_on_editor_numeric_slider_changed", "jaw_hinge_x")
	assert(String(overlay.get("indicator_key")) == "jaw_hinge_x")
	assert(timer.is_stopped())
	main.call("_on_editor_numeric_slider_hovered", "")
	assert(String(overlay.get("indicator_key")) == "")
	assert(timer.is_stopped())
	main.call("_on_editor_numeric_slider_changed", "jaw_hinge_x")
	assert(String(overlay.get("indicator_key")) == "jaw_hinge_x")
	assert(not timer.is_stopped())

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/slider_hover_indicator.ok", FileAccess.WRITE)
	file.store_string("slider hover indicator emits and clears")
	file.close()
	print("SLIDER_HOVER_INDICATOR_TEST_OK")
	get_tree().quit(0)

func _widgets_for_key(panel: Node, key: String) -> Dictionary:
	var sliders: Dictionary = panel.get("numeric_sliders")
	assert(sliders.has(key))
	return sliders[key]
