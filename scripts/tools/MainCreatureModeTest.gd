extends Node

const MainScript := preload("res://scripts/ui/Main.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame

	var mode_option: OptionButton = main.get("creature_mode_option")
	assert(mode_option != null)
	assert(mode_option.item_count == 3)

	main.call("_select_creature_mode", "ray")
	await get_tree().process_frame
	assert(String(main.get("active_creature_mode")) == "ray")
	assert((main.get("current_rig") as Node).get_script() == RayRigScript)
	assert(_only_mode_root_visible(main, "RayModeRoot"))

	main.call("_select_creature_mode", "shark")
	await get_tree().process_frame
	assert(String(main.get("active_creature_mode")) == "shark")
	assert((main.get("current_rig") as Node).get_script() == SharkRigScript)
	assert(_only_mode_root_visible(main, "SharkModeRoot"))

	var presets: Array = main.get("presets")
	for preset in presets:
		assert(String(preset.get("creature_type", "")) == "shark")

	print("MAIN_CREATURE_MODE_TEST_OK")
	get_tree().quit(0)

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
