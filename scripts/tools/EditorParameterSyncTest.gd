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

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_parameter_sync.ok", FileAccess.WRITE)
	file.store_string("editor parameter sync preserved")
	file.close()
	print("EDITOR_PARAMETER_SYNC_TEST_OK")
	get_tree().quit(0)
