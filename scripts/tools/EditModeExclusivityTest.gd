extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var fin_toggle: CheckButton = main.get("fin_edit_toggle")
	var head_toggle: CheckButton = main.get("head_edit_toggle")
	var body_toggle: CheckButton = main.get("body_edit_toggle")
	assert(fin_toggle != null)
	assert(head_toggle != null)
	assert(body_toggle != null)

	# Activate a fish preset so the body-part editor panels are eligible to show.
	var presets: Array = main.get("presets")
	var fish_index := -1
	for i in presets.size():
		if String(presets[i].get("creature_type", "fish")) == "fish":
			fish_index = i
			break
	assert(fish_index >= 0)
	main.call("_load_preset", fish_index)
	await get_tree().process_frame

	var fin_panel: Control = main.get("fin_editor_panel")
	var head_panel: Control = main.get("head_editor_panel")
	var body_panel: Control = main.get("body_editor_panel")

	# Enabling one edit mode must disable the other two and reveal only its panel.
	fin_toggle.button_pressed = true
	assert(fin_toggle.button_pressed)
	assert(not head_toggle.button_pressed)
	assert(not body_toggle.button_pressed)
	assert(fin_panel.visible)

	head_toggle.button_pressed = true
	assert(head_toggle.button_pressed)
	assert(not fin_toggle.button_pressed)
	assert(not body_toggle.button_pressed)
	assert(head_panel.visible)
	assert(not fin_panel.visible)

	body_toggle.button_pressed = true
	assert(body_toggle.button_pressed)
	assert(not fin_toggle.button_pressed)
	assert(not head_toggle.button_pressed)
	assert(body_panel.visible)
	assert(not head_panel.visible)

	body_toggle.button_pressed = false
	assert(not body_toggle.button_pressed)
	assert(not body_panel.visible)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/edit_mode_exclusivity.ok", FileAccess.WRITE)
	file.store_string("edit mode toggles stay mutually exclusive")
	file.close()
	print("EDIT_MODE_EXCLUSIVITY_TEST_OK")
	get_tree().quit(0)
