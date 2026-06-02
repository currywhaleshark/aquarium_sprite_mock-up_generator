extends Node

const MainScript := preload("res://scripts/ui/Main.gd")

func _ready() -> void:
	var main := MainScript.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var archetype_option: OptionButton = main.get("archetype_option")
	var archetype_strength_slider: HSlider = main.get("archetype_strength_slider")
	var apply_archetype_button: Button = main.get("apply_archetype_button")
	var new_variant_button: Button = main.get("new_variant_button")
	var archetype_read_label: Label = main.get("archetype_read_label")
	assert(archetype_option != null)
	assert(archetype_strength_slider != null)
	assert(apply_archetype_button != null)
	assert(new_variant_button != null)
	assert(archetype_read_label != null)
	assert(archetype_option.item_count >= 3)

	var neon_index := _find_archetype_index(archetype_option, "neon_tetra")
	assert(neon_index >= 0)
	archetype_option.select(neon_index)
	archetype_option.item_selected.emit(neon_index)
	await get_tree().process_frame
	assert(archetype_read_label.text.contains("blue lateral stripe"))

	archetype_strength_slider.value = 1.0
	apply_archetype_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var current_preset: Dictionary = main.get("current_preset")
	var parameters: Dictionary = current_preset.get("parameters", {})
	assert(String(parameters.get("archetype_id", "")) == "neon_tetra")
	assert(abs(float(parameters.get("archetype_strength", 0.0)) - 1.0) < 0.001)
	assert(String(parameters.get("body_profile_shape", "")) == "slender_lateral")
	assert((parameters.get("marking_layers", []) as Array).size() >= 2)
	var current_rig: Object = main.get("current_rig")
	assert(current_rig != null)
	var rig_parameters: Dictionary = current_rig.get("parameters")
	assert(String(rig_parameters.get("archetype_id", "")) == "neon_tetra")
	assert(String(current_preset.get("archetype_id", "")) == "neon_tetra")

	var first_seed := int(parameters.get("variant_seed", -1))
	new_variant_button.pressed.emit()
	await get_tree().process_frame
	var variant_preset: Dictionary = main.get("current_preset")
	var variant_parameters: Dictionary = variant_preset.get("parameters", {})
	assert(String(variant_parameters.get("archetype_id", "")) == "neon_tetra")
	assert(int(variant_parameters.get("variant_seed", first_seed)) != first_seed)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/species_archetype_main.ok", FileAccess.WRITE)
	file.store_string("main ui applied species archetypes")
	file.close()
	print("SPECIES_ARCHETYPE_MAIN_TEST_OK")
	get_tree().quit(0)

func _find_archetype_index(option: OptionButton, archetype_id: String) -> int:
	for i in option.item_count:
		if String(option.get_item_metadata(i)) == archetype_id:
			return i
	return -1
