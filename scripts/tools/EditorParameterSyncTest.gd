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
	assert(body_panel != null)
	assert(fin_panel != null)

	body_panel.call("set_numeric_parameter", "midbody_depth_scale", 1.44)
	await get_tree().process_frame
	var after_body: Dictionary = main.get("current_preset")
	assert(abs(float(after_body.get("parameters", {}).get("midbody_depth_scale", 0.0)) - 1.44) < 0.001)

	fin_panel.call("set_slot_shape", "dorsal_1", "spiny")
	await get_tree().process_frame
	var after_fin: Dictionary = main.get("current_preset")
	var parameters: Dictionary = after_fin.get("parameters", {})
	assert(String(parameters.get("dorsal_1_shape", "")) == "spiny")
	assert(abs(float(parameters.get("midbody_depth_scale", 0.0)) - 1.44) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_parameter_sync.ok", FileAccess.WRITE)
	file.store_string("editor parameter sync preserved")
	file.close()
	print("EDITOR_PARAMETER_SYNC_TEST_OK")
	get_tree().quit(0)
