extends Node

const MainScript := preload("res://scripts/ui/Main.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame

	var mode_option: OptionButton = main.get("creature_mode_option")
	assert(mode_option != null)
	assert(mode_option.item_count == 3)
	assert(String(main.get("active_creature_mode")) == "fish")
	assert((main.get("current_rig") as Node).get_script() == FishRigScript)
	assert(_only_mode_root_visible(main, "FishModeRoot"))
	_assert_mode_state(main, "fish")
	_assert_archetype_visibility(main, true)
	var fish_preset_names := _preset_names(main)

	main.call("_select_creature_mode", "ray")
	await get_tree().process_frame
	assert(String(main.get("active_creature_mode")) == "ray")
	assert((main.get("current_rig") as Node).get_script() == RayRigScript)
	assert(_only_mode_root_visible(main, "RayModeRoot"))
	_assert_mode_state(main, "ray")
	_assert_archetype_visibility(main, false)
	var ray_preset_names := _preset_names(main)
	assert(ray_preset_names != fish_preset_names)

	main.call("_select_creature_mode", "shark")
	await get_tree().process_frame
	assert(String(main.get("active_creature_mode")) == "shark")
	assert((main.get("current_rig") as Node).get_script() == SharkRigScript)
	assert(_only_mode_root_visible(main, "SharkModeRoot"))
	_assert_mode_state(main, "shark")
	_assert_archetype_visibility(main, false)
	var shark_preset_names := _preset_names(main)
	assert(shark_preset_names != fish_preset_names)
	assert(shark_preset_names != ray_preset_names)

	var presets: Array = main.get("presets")
	for preset in presets:
		assert(String(preset.get("creature_type", "")) == "shark")

	main.call("_select_creature_mode", "fish")
	await get_tree().process_frame
	assert(String(main.get("active_creature_mode")) == "fish")
	assert((main.get("current_rig") as Node).get_script() == FishRigScript)
	assert(_only_mode_root_visible(main, "FishModeRoot"))
	_assert_mode_state(main, "fish")
	_assert_archetype_visibility(main, true)

	print("MAIN_CREATURE_MODE_TEST_OK")
	get_tree().quit(0)

func _assert_mode_state(main: Node, mode: String) -> void:
	var current_preset: Dictionary = main.get("current_preset")
	assert(String(current_preset.get("creature_type", "")) == mode)
	var current_rig := main.get("current_rig") as Node
	var rig_parameters: Dictionary = current_rig.get("parameters")
	assert(String(rig_parameters.get("creature_type", "")) == mode)
	var label := main.get("creature_type_label") as Label
	assert(label != null)
	assert(label.text.contains(UiText.creature_type(mode)))
	_assert_export_direction_matches_preset(main)

func _assert_export_direction_matches_preset(main: Node) -> void:
	var export_panel := main.get("export_panel") as Node
	var current_preset: Dictionary = main.get("current_preset")
	var export_settings: Dictionary = current_preset.get("export_settings", {})
	var expected_count := int(export_settings.get("direction_count", 1))
	assert(int(export_panel.call("get_direction_count")) == expected_count)

func _assert_archetype_visibility(main: Node, expected_visible: bool) -> void:
	var container := main.get("archetype_section_container") as Control
	assert(container != null)
	assert(container.visible == expected_visible)

func _preset_names(main: Node) -> PackedStringArray:
	var names := PackedStringArray()
	var presets: Array = main.get("presets")
	for preset in presets:
		names.append(String(preset.get("name", "")))
	return names

func _only_mode_root_visible(main: Node, active_root_name: String) -> bool:
	var roots: Dictionary = main.get("mode_roots")
	for mode in roots.keys():
		var root := roots[mode] as Node3D
		var should_be_active := root.name == active_root_name
		if root.visible != should_be_active:
			return false
		if should_be_active and root.get_child_count() != 1:
			return false
		if should_be_active and root.get_child(0).name != "ActiveRig":
			return false
		if not should_be_active and root.get_child_count() != 0:
			return false
	return true
