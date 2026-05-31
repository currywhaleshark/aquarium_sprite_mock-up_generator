extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var body_panel: Object = main.get("body_editor_panel")
	var fin_panel: Object = main.get("fin_editor_panel")
	var body_toggle: CheckButton = main.get("body_edit_toggle")
	var fin_toggle: CheckButton = main.get("fin_edit_toggle")
	var camera_controller: Object = main.get("camera_controller")
	var root := main.get_node("RootLayout") as HBoxContainer
	var side_scroll := root.get_child(1) as ScrollContainer
	assert(body_panel != null)
	assert(fin_panel != null)
	assert(body_toggle != null)
	assert(fin_toggle != null)
	assert(camera_controller != null)
	assert(side_scroll != null)
	var side_content := side_scroll.get_child(0) as VBoxContainer
	assert(side_content != null)
	assert(side_scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL)

	body_toggle.button_pressed = true
	await get_tree().process_frame
	assert(bool(camera_controller.get("input_enabled")))
	fin_toggle.button_pressed = true
	await get_tree().process_frame
	assert(bool(camera_controller.get("input_enabled")))

	body_panel.call("select_ring_by_id", "mid_body")
	body_panel.call("set_ring_parameter", "upper_height", 0.74)
	await get_tree().process_frame
	var after_body: Dictionary = main.get("current_preset")
	var after_body_rings: Array = after_body.get("parameters", {}).get("body_profile", {}).get("rings", [])
	assert(after_body_rings.size() >= 4)
	assert(abs(float(after_body_rings[3].get("upper_height", 0.0)) - 0.74) < 0.001)

	fin_panel.call("set_slot_shape", "dorsal_1", "spiny")
	await get_tree().process_frame
	var after_fin: Dictionary = main.get("current_preset")
	var parameters: Dictionary = after_fin.get("parameters", {})
	assert(String(parameters.get("dorsal_1_shape", "")) == "spiny")
	var rings: Array = parameters.get("body_profile", {}).get("rings", [])
	assert(abs(float(rings[3].get("upper_height", 0.0)) - 0.74) < 0.001)

	var parameter_panel: Control = main.get("parameter_panel")
	assert(parameter_panel != null)
	var swim_mode_option := _find_option_for_label(parameter_panel, "헤엄 방식")
	assert(swim_mode_option != null)
	var tuna_index := -1
	for i in swim_mode_option.item_count:
		if String(swim_mode_option.get_item_metadata(i)) == "tuna":
			tuna_index = i
	assert(tuna_index >= 0)
	swim_mode_option.select(tuna_index)
	swim_mode_option.item_selected.emit(tuna_index)
	await get_tree().process_frame
	var after_swim_mode: Dictionary = main.get("current_preset")
	var swim_parameters: Dictionary = after_swim_mode.get("parameters", {})
	assert(String(swim_parameters.get("swim_mode", "")) == "tuna")
	assert(abs(float(swim_parameters.get("body_wave_amount", 0.0)) - 0.12) < 0.001)
	assert(abs(float(swim_parameters.get("tail_sway_multiplier", 0.0)) - 1.55) < 0.001)
	assert(abs(float(after_swim_mode.get("motion_profile", {}).get("fin_yaw_follow_strength", 0.0)) - 0.12) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_parameter_sync.ok", FileAccess.WRITE)
	file.store_string("editor parameter sync preserved")
	file.close()
	print("EDITOR_PARAMETER_SYNC_TEST_OK")
	get_tree().quit(0)

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
