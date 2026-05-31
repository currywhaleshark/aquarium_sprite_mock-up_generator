extends Node

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

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
	assert(parameters.has("body_wave_amount"))
	assert(String(parameters.get("swim_mode", "")) == "general")
	assert(parameters.has("tail_fin_extra_swing"))
	assert(parameters.has("fin_yaw_follow_strength"))
	assert(parameters.has("median_fin_flap_amount"))
	assert(parameters.has("median_fin_flap_phase"))
	assert(not parameters.has("pectoral_flap_amount"))
	assert(not parameters.has("visual_thickness"))
	assert(not parameters.has("outline_width"))
	assert(not parameters.has("toon_steps"))
	assert(not parameters.has("rim_light_strength"))

	var general_mode := BodyProfileScript.swim_mode_values("general")
	assert(abs(float(general_mode.get("body_wave_amount", 0.0)) - 0.35) < 0.001)
	assert(abs(float(general_mode.get("tail_fin_extra_swing", 0.0)) - 0.45) < 0.001)
	assert(abs(float(general_mode.get("fin_yaw_follow_strength", 0.0)) - 0.25) < 0.001)

	var fallback_mode := BodyProfileScript.swim_mode_values("not_a_mode")
	assert(abs(float(fallback_mode.get("body_wave_start", 0.0)) - 0.16) < 0.001)

	var applied := {"swim_speed": 1.0, "body_wave_amount": 0.77}
	BodyProfileScript.apply_swim_mode(applied, "tuna")
	assert(String(applied.get("swim_mode", "")) == "tuna")
	assert(abs(float(applied.get("body_wave_amount", 0.0)) - 0.12) < 0.001)
	assert(abs(float(applied.get("tail_sway_multiplier", 0.0)) - 1.55) < 0.001)

	var explicit := {"body_profile_shape": "elongated", "body_wave_amount": 0.66}
	BodyProfileScript.normalize_motion_parameters(explicit)
	assert(String(explicit.get("swim_mode", "")) == "eel")
	assert(abs(float(explicit.get("body_wave_amount", 0.0)) - 0.66) < 0.001)
	assert(explicit.has("tail_fin_extra_swing"))
	assert(explicit.has("fin_yaw_follow_strength"))

	var legacy := {"pectoral_flap_amount": 9.25}
	BodyProfileScript.normalize_motion_parameters(legacy)
	assert(abs(float(legacy.get("fin_flap_amount", 0.0)) - 9.25) < 0.001)
	assert(not legacy.has("pectoral_flap_amount"))

	var split_preset := BodyProfileScript.split_parameters_into_profiles({
		"body_length": 1.2,
		"visual_thickness": 0.32,
		"overall_scale": 1.0,
		"body_height_scale": 1.0,
		"facing_direction": 1.0,
		"render_angle": 0.0,
		"show_pivot_guides": 1.0,
		"tail_height": 0.2,
		"outline_width": 0.012,
		"toon_steps": 3.0,
		"rim_light_strength": 0.35,
		"pectoral_flap_amount": 8.0
	}, {"name": "split_check"})
	var split_global: Dictionary = split_preset.get("global", {})
	var split_tail: Dictionary = split_preset.get("tail_profile", {})
	var split_visual: Dictionary = split_preset.get("visual_profile", {})
	var split_motion: Dictionary = split_preset.get("motion_profile", {})
	assert(not split_global.has("visual_thickness"))
	assert(not split_global.has("overall_scale"))
	assert(not split_global.has("body_height_scale"))
	assert(not split_global.has("facing_direction"))
	assert(not split_global.has("render_angle"))
	assert(not split_global.has("show_pivot_guides"))
	assert(not split_tail.has("tail_height"))
	assert(not split_visual.has("outline_width"))
	assert(not split_visual.has("toon_steps"))
	assert(not split_visual.has("rim_light_strength"))
	assert(not split_motion.has("pectoral_flap_amount"))

	var long_fish := _find_preset(presets, "long_fish")
	assert(not long_fish.is_empty())
	var long_parameters: Dictionary = long_fish.get("parameters", {})
	assert(float(long_parameters.get("body_wave_amount", 0.0)) > 0.75)
	assert(float(long_parameters.get("body_wave_start", 1.0)) < 0.08)
	assert(String(long_parameters.get("swim_mode", "")) == "eel")
	assert(long_parameters.has("tail_fin_extra_swing"))
	assert(long_parameters.has("fin_yaw_follow_strength"))

	var goldfish := _find_preset(presets, "goldfish")
	assert(not goldfish.is_empty())
	var goldfish_parameters: Dictionary = goldfish.get("parameters", {})
	assert(float(goldfish_parameters.get("body_wave_amount", 1.0)) < 0.3)
	assert(float(goldfish_parameters.get("body_wave_start", 0.0)) > 0.35)
	assert(String(goldfish_parameters.get("swim_mode", "")) == "puffer")
	assert(goldfish_parameters.has("median_fin_flap_amount"))

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
