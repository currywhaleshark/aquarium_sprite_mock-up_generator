extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

var created_paths: Array[String] = []

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var preset_name_edit: LineEdit = main.get("preset_name_edit")
	var save_preset_button: Button = main.get("save_preset_button")
	var preset_option: OptionButton = main.get("preset_option")
	assert(preset_name_edit != null)
	assert(save_preset_button != null)
	assert(preset_option != null)

	var preset_name := "codex_user_preset_main_%d" % Time.get_ticks_msec()
	preset_name_edit.text = preset_name
	save_preset_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var current_preset: Dictionary = main.get("current_preset")
	assert(String(current_preset.get("name", "")) == preset_name)
	assert(String(current_preset.get("_preset_source", "")) == "user")
	var saved_path := String(current_preset.get("_preset_path", ""))
	assert(saved_path != "")
	created_paths.append(saved_path)

	var found_in_dropdown := false
	for i in preset_option.item_count:
		if String(preset_option.get_item_text(i)).contains(preset_name):
			found_in_dropdown = true
	assert(found_in_dropdown)

	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/user_preset_main.ok", FileAccess.WRITE)
	file.store_string("main ui saved and selected user preset")
	file.close()
	print("USER_PRESET_MAIN_TEST_OK")
	get_tree().quit(0)

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	for path in created_paths:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	created_paths.clear()
