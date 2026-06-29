extends Node

# Verifies the head editor demotes its numeric sliders into a collapsed "advanced" area:
# by default the slider container is hidden (sculpt-by-handles is the primary workflow), the
# workflow hint is shown, and toggling the master reveals/hides the sliders.

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	for _i in range(3):
		await get_tree().process_frame

	var presets: Array = main.get("presets")
	var fish_index := -1
	for i in presets.size():
		if String(presets[i].get("creature_type", "fish")) == "fish":
			fish_index = i
			break
	assert(fish_index >= 0)
	main.call("_load_preset", fish_index)
	await get_tree().process_frame

	var head_toggle: CheckButton = main.get("head_edit_toggle")
	head_toggle.button_pressed = true
	await get_tree().process_frame

	var panel = main.get("head_editor_panel")
	var slider_container: Control = panel.get("slider_container")
	var hint: Control = panel.get("advanced_hint")
	var sliders: Dictionary = panel.get("numeric_sliders")

	# Sliders exist but are collapsed out of sight by default.
	assert(not sliders.is_empty())
	assert(hint != null and hint.visible)
	assert(not bool(panel.get("advanced_expanded")))
	assert(not slider_container.visible)

	# Expanding the master reveals them; collapsing hides them again.
	panel.call("_set_advanced_expanded", true)
	await get_tree().process_frame
	assert(slider_container.visible)
	panel.call("_set_advanced_expanded", false)
	await get_tree().process_frame
	assert(not slider_container.visible)

	# A search forces the advanced area open even while collapsed, so matches stay reachable.
	panel.call("set_search_text", "mouth")
	await get_tree().process_frame
	assert(slider_container.visible)
	panel.call("set_search_text", "")
	await get_tree().process_frame
	assert(not slider_container.visible)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_advanced_collapse.ok", FileAccess.WRITE)
	file.store_string("head sliders demoted under collapsed advanced area")
	file.close()
	print("HEAD_ADVANCED_COLLAPSE_TEST_OK")
	get_tree().quit(0)
