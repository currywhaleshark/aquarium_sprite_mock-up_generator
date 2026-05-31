extends Node

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

var created_paths: Array[String] = []

func _ready() -> void:
	assert(PresetStoreScript.sanitize_preset_filename("My Preset! 01") == "My_Preset_01")
	assert(PresetStoreScript.sanitize_preset_filename(" !!! ") == "user_preset")
	assert(PresetStoreScript.sanitize_preset_filename("금붕어 튜닝 🐟") == "금붕어_튜닝")

	var preset := PresetStoreScript.load_preset("res://presets/basic_fish.json")
	assert(not preset.is_empty())
	var parameters: Dictionary = preset.get("parameters", {}).duplicate(true)
	BodyProfileScript.apply_swim_mode(parameters, "tuna")
	var body_profile: Dictionary = parameters.get("body_profile", {}).duplicate(true)
	var rings: Array = body_profile.get("rings", []).duplicate(true)
	assert(rings.size() >= 4)
	var mid_ring: Dictionary = rings[3].duplicate(true)
	mid_ring["upper_height"] = 0.73
	rings[3] = mid_ring
	body_profile["rings"] = rings
	parameters["body_profile"] = body_profile
	preset = BodyProfileScript.split_parameters_into_profiles(parameters, preset)

	var preset_name := "codex_user_preset_store_%d" % Time.get_ticks_msec()
	var result: Dictionary = PresetStoreScript.save_user_preset(preset_name, preset)
	assert(int(result.get("error", FAILED)) == OK, "save_user_preset failed: %s" % result)
	var saved_path := String(result.get("path", ""))
	assert(saved_path.begins_with(PresetStoreScript.USER_PRESET_DIR))
	created_paths.append(saved_path)

	var loaded := PresetStoreScript.load_preset(saved_path)
	assert(String(loaded.get("name", "")) == preset_name)
	var loaded_parameters: Dictionary = loaded.get("parameters", {})
	assert(String(loaded_parameters.get("swim_mode", "")) == "tuna")
	assert(abs(float(loaded_parameters.get("body_wave_amount", 0.0)) - 0.12) < 0.001)
	var loaded_rings: Array = loaded_parameters.get("body_profile", {}).get("rings", [])
	assert(abs(float(loaded_rings[3].get("upper_height", 0.0)) - 0.73) < 0.001)

	var all_presets: Array[Dictionary] = PresetStoreScript.load_all()
	var found := false
	for loaded_preset in all_presets:
		if String(loaded_preset.get("name", "")) == preset_name:
			found = true
			assert(String(loaded_preset.get("_preset_source", "")) == "user")
			assert(String(loaded_preset.get("_preset_path", "")) == saved_path)
	assert(found)

	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/user_preset_store.ok", FileAccess.WRITE)
	file.store_string("user preset store preserved body and motion profiles")
	file.close()
	print("USER_PRESET_STORE_TEST_OK")
	get_tree().quit(0)

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	for path in created_paths:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	created_paths.clear()
