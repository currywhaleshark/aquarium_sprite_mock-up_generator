extends Node

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

func _ready() -> void:
	var presets: Array[Dictionary] = PresetStoreScript.load_all()
	var basic := _find_preset(presets, "basic_fish")
	assert(not basic.is_empty())
	var parameters: Dictionary = basic.get("parameters", {})
	assert(parameters.has("global_sway_amount"))
	assert(not parameters.has("body_sway_amount"))
	assert(not parameters.has("tail_1_sway_amount"))
	assert(not parameters.has("tail_2_sway_amount"))
	assert(not parameters.has("tail_fin_sway_amount"))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/preset_normalization.ok", FileAccess.WRITE)
	file.store_string("legacy motion parameters normalized")
	file.close()
	print("PRESET_NORMALIZATION_TEST_OK")
	get_tree().quit(0)

func _find_preset(presets: Array[Dictionary], preset_name: String) -> Dictionary:
	for preset in presets:
		if String(preset.get("name", "")) == preset_name:
			return preset
	return {}
