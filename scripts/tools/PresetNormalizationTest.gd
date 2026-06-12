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

	var ray_split := BodyProfileScript.split_parameters_into_profiles({
		"creature_type": "ray",
		"ray_disc_shape": "electric",
		"ray_tail_style": "stout_skate",
		"ray_tail_spine_enabled": true,
		"ray_dorsal_tail_fins": true,
		"ray_head_shape": "cownose",
		"cephalic_horns": "rolled"
	}, {"name": "ray_split_check", "creature_type": "ray"})
	var ray_fin_profile: Dictionary = ray_split.get("fin_profile", {})
	var ray_tail_profile: Dictionary = ray_split.get("tail_profile", {})
	assert(String(ray_fin_profile.get("ray_disc_shape", "")) == "electric")
	assert(String(ray_tail_profile.get("ray_tail_style", "")) == "stout_skate")
	assert(bool(ray_tail_profile.get("ray_tail_spine_enabled", false)))
	assert(bool(ray_tail_profile.get("ray_dorsal_tail_fins", false)))
	var rebuilt_ray := BodyProfileScript.make_parameters_from_structured_preset(ray_split)
	assert(String(rebuilt_ray.get("ray_disc_shape", "")) == "electric")
	assert(String(rebuilt_ray.get("ray_tail_style", "")) == "stout_skate")
	assert(bool(rebuilt_ray.get("ray_tail_spine_enabled", false)))
	assert(bool(rebuilt_ray.get("ray_dorsal_tail_fins", false)))

	var fish_split := BodyProfileScript.split_parameters_into_profiles({
		"creature_type": "fish",
		"body_length": 1.4,
		"ray_disc_shape": "manta",
		"ray_tail_style": "whip",
		"shark_gill_slit_count": 5,
		"shark_mouth_width": 0.18,
		"shark_lower_teeth_visible": true
	}, {"name": "fish_split_check", "creature_type": "fish"})
	assert(not (fish_split.get("fin_profile", {}) as Dictionary).has("ray_disc_shape"))
	assert(not (fish_split.get("tail_profile", {}) as Dictionary).has("ray_tail_style"))
	assert(not (fish_split.get("parameters", {}) as Dictionary).has("shark_gill_slit_count"))
	assert(not (fish_split.get("parameters", {}) as Dictionary).has("shark_mouth_width"))
	assert(not (fish_split.get("parameters", {}) as Dictionary).has("shark_lower_teeth_visible"))

	var shark_split := BodyProfileScript.split_parameters_into_profiles({
		"creature_type": "shark",
		"body_length": 5.8,
		"caudal_shape": "shark_heterocercal",
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_width": 0.18,
		"shark_lower_teeth_visible": true,
		"shark_tooth_size": 0.018,
		"ray_disc_shape": "diamond",
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"mouth_type": "terminal",
		"mouth_size": 0.08,
		"fin_ray_count": 12.0,
		"adipose_fin_enabled": true,
		"finlet_enabled": true
	}, {"name": "shark_split_check", "creature_type": "shark"})
	assert(String(shark_split.get("creature_type", "")) == "shark")
	assert(String(shark_split.get("type", "")) == "shark")
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("ray_disc_shape"))
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("gill_mark"))
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("operculum_size"))
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("fin_ray_count"))
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("adipose_fin_enabled"))
	assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("finlet_enabled"))
	assert(float((shark_split.get("parameters", {}) as Dictionary).get("shark_gill_slit_count", 0.0)) == 5.0)
	assert(String((shark_split.get("parameters", {}) as Dictionary).get("shark_mouth_profile", "")) == "predatory_u")
	assert(float((shark_split.get("parameters", {}) as Dictionary).get("shark_mouth_width", 0.0)) == 0.18)
	assert(bool((shark_split.get("parameters", {}) as Dictionary).get("shark_lower_teeth_visible", false)))
	assert(float((shark_split.get("parameters", {}) as Dictionary).get("shark_tooth_size", 0.0)) == 0.018)
	assert(not (shark_split.get("parameters", {}) as Dictionary).has("mouth_type"))
	assert(not (shark_split.get("parameters", {}) as Dictionary).has("mouth_size"))

	var polluted_ray_split := BodyProfileScript.split_parameters_into_profiles({
		"creature_type": "ray",
		"disc_width": 1.2,
		"ray_disc_shape": "manta",
		"shark_gill_slit_count": 5,
		"shark_mouth_width": 0.18,
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"fin_ray_count": 12.0,
		"adipose_fin_enabled": true,
		"finlet_enabled": true
	}, {"name": "ray_split_check", "creature_type": "ray"})
	assert(String(polluted_ray_split.get("creature_type", "")) == "ray")
	assert(not (polluted_ray_split.get("fin_profile", {}) as Dictionary).has("gill_mark"))
	assert(not (polluted_ray_split.get("fin_profile", {}) as Dictionary).has("operculum_size"))
	assert(not (polluted_ray_split.get("fin_profile", {}) as Dictionary).has("fin_ray_count"))
	assert(not (polluted_ray_split.get("fin_profile", {}) as Dictionary).has("adipose_fin_enabled"))
	assert(not (polluted_ray_split.get("fin_profile", {}) as Dictionary).has("finlet_enabled"))
	assert(not (polluted_ray_split.get("parameters", {}) as Dictionary).has("shark_gill_slit_count"))
	assert(not (polluted_ray_split.get("parameters", {}) as Dictionary).has("shark_mouth_width"))
	assert(String((polluted_ray_split.get("fin_profile", {}) as Dictionary).get("ray_disc_shape", "")) == "manta")

	var polluted_loaded := PresetStoreScript.normalize_preset({
		"name": "polluted_fish_load_check",
		"creature_type": "fish",
		"type": "fish",
		"parameters": {
			"body_length": 1.4,
			"disc_width": 1.2,
			"ray_disc_shape": "manta",
			"shark_gill_slit_count": 5,
			"shark_mouth_width": 0.18,
			"body_profile": {"rings": BodyProfileScript.default_fish_rings()}
		}
	})
	var loaded_params: Dictionary = polluted_loaded.get("parameters", {})
	assert(loaded_params.has("body_profile"))
	assert(not loaded_params.has("disc_width"))
	assert(not loaded_params.has("ray_disc_shape"))
	assert(not loaded_params.has("shark_gill_slit_count"))
	assert(not loaded_params.has("shark_mouth_width"))

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

	var operculum_split := BodyProfileScript.split_parameters_into_profiles({
		"gill_mark": "operculum",
		"operculum_size": 1.25,
		"operculum_height": 1.35,
		"operculum_open": 0.6,
		"operculum_ridge": 0.8,
		"operculum_position_x": 0.08,
		"operculum_position_y": -0.22
	}, {"name": "operculum_roundtrip", "type": "fish"})
	var operculum_fin_profile: Dictionary = operculum_split.get("fin_profile", {})
	assert(String(operculum_fin_profile.get("gill_mark", "")) == "operculum")
	assert(abs(float(operculum_fin_profile.get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_ridge", 0.0)) - 0.8) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_position_x", 0.0)) - 0.08) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_position_y", 0.0)) + 0.22) < 0.001)
	var rebuilt_operculum := BodyProfileScript.make_parameters_from_structured_preset(operculum_split)
	assert(String(rebuilt_operculum.get("gill_mark", "")) == "operculum")
	assert(abs(float(rebuilt_operculum.get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_ridge", 0.0)) - 0.8) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_position_x", 0.0)) - 0.08) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_position_y", 0.0)) + 0.22) < 0.001)
	var legacy_no_operculum_split := BodyProfileScript.split_parameters_into_profiles({
		"gill_mark": "none"
	}, {"name": "legacy_no_operculum_keys", "type": "fish"})
	var legacy_no_operculum := BodyProfileScript.make_parameters_from_structured_preset(legacy_no_operculum_split)
	assert(String(legacy_no_operculum.get("gill_mark", "")) == "none")
	assert(not legacy_no_operculum.has("operculum_size"))
	assert(not legacy_no_operculum.has("operculum_height"))
	assert(not legacy_no_operculum.has("operculum_open"))
	assert(not legacy_no_operculum.has("operculum_ridge"))
	assert(not legacy_no_operculum.has("operculum_position_x"))
	assert(not legacy_no_operculum.has("operculum_position_y"))

	var sculpt_split := BodyProfileScript.split_parameters_into_profiles({
		"head_shape": "rounded",
		"head_top_flatness": 0.7,
		"head_bottom_flatness": 0.2,
		"head_left_flatness": 0.3,
		"head_right_flatness": 0.4,
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.24, "lower_height": 0.20, "width": 0.18, "top_width": 0.16, "bottom_width": 0.21, "top_flatness": 0.5, "bottom_flatness": 0.0, "left_flatness": 0.0, "right_flatness": 0.25, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.42, "lower_height": 0.36, "width": 0.34, "top_width": 0.32, "bottom_width": 0.36, "top_flatness": 0.0, "bottom_flatness": 0.0, "left_flatness": 0.2, "right_flatness": 0.2, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.52, "lower_height": 0.48, "width": 0.46, "top_width": 0.42, "bottom_width": 0.50, "top_flatness": 0.0, "bottom_flatness": 0.3, "left_flatness": 0.0, "right_flatness": 0.0, "roundness": 0.9, "sway_weight": 0.15}
			]
		}
	}, {"name": "directional_sculpt"})
	var rebuilt_sculpt := BodyProfileScript.make_parameters_from_structured_preset(sculpt_split)
	assert(abs(float(rebuilt_sculpt.get("head_top_flatness", 0.0)) - 0.7) < 0.001)
	var rebuilt_rings: Array = rebuilt_sculpt.get("body_profile", {}).get("rings", [])
	assert(abs(float(rebuilt_rings[0].get("top_width", 0.0)) - 0.16) < 0.001)
	assert(abs(float(rebuilt_rings[0].get("bottom_width", 0.0)) - 0.21) < 0.001)
	assert(abs(float(rebuilt_rings[0].get("top_flatness", 0.0)) - 0.5) < 0.001)

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
