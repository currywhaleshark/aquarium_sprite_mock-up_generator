extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var left_button: Button = main.get("turn_left_button")
	var right_button: Button = main.get("turn_right_button")
	assert(left_button != null)
	assert(right_button != null)
	assert(int(main.get("preview_direction_index")) == 0)

	right_button.pressed.emit()
	await get_tree().process_frame
	main.call("_update_preview_turn", 999.0)
	assert(int(main.get("preview_direction_index")) == 1)
	var rig: Node3D = main.get("current_rig")
	assert(rig != null)
	assert(absf(rig.rotation_degrees.y - 45.0) < 0.001)
	var parameters: Dictionary = rig.get("parameters")
	assert(absf(float(parameters.get("turn_amount", -1.0))) < 0.001)

	left_button.pressed.emit()
	await get_tree().process_frame
	main.call("_update_preview_turn", 999.0)
	assert(int(main.get("preview_direction_index")) == 0)
	assert(absf(rig.rotation_degrees.y) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/turn_preview_controls.ok", FileAccess.WRITE)
	file.store_string("turn preview controls advance direction state")
	file.close()
	print("TURN_PREVIEW_CONTROLS_TEST_OK")
	get_tree().quit(0)
