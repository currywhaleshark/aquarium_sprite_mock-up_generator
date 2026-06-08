extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

class CountingRig:
	extends CreatureRig

	var set_count := 0
	var last_parameters: Dictionary = {}

	func set_parameters(new_parameters: Dictionary) -> void:
		set_count += 1
		last_parameters = new_parameters.duplicate(true)
		parameters = last_parameters

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var original_rig: Node = main.get("current_rig")
	if original_rig != null and original_rig.get_parent() != null:
		original_rig.get_parent().remove_child(original_rig)
		original_rig.queue_free()

	var rig := CountingRig.new()
	main.get("world_root").add_child(rig)
	main.set("current_rig", rig)
	main.set("current_preset", {
		"creature_type": "fish",
		"parameters": {"head_size": 0.4, "base_color": "#46c6cf"}
	})

	main.call("_apply_parameters_from_editor", {"head_size": 0.41, "base_color": "#46c6cf"})
	main.call("_apply_parameters_from_editor", {"head_size": 0.52, "base_color": "#46c6cf"})
	main.call("_apply_parameters_from_editor", {"head_size": 0.63, "base_color": "#46c6cf"})
	assert(rig.set_count == 0)

	await get_tree().process_frame
	assert(rig.set_count == 1)
	assert(absf(float(rig.last_parameters.get("head_size", 0.0)) - 0.63) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/editor_apply_coalescing.ok", FileAccess.WRITE)
	file.store_string("editor parameter applies are coalesced")
	file.close()
	print("EDITOR_APPLY_COALESCING_TEST_OK")
	get_tree().quit(0)
