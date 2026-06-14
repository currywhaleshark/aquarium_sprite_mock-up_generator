extends Node

const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")

func _ready() -> void:
	var fish_panel := ParameterPanelScript.new()
	var ray_panel := ParameterPanelScript.new()
	var shark_panel := ParameterPanelScript.new()
	add_child(fish_panel)
	add_child(ray_panel)
	add_child(shark_panel)
	await get_tree().process_frame

	fish_panel.set_creature_type("fish")
	fish_panel.set_parameters({
		"body_length": 1.4,
		"mouth_type": "terminal",
		"mouth_size": 0.08,
		"disc_width": 1.2,
		"ray_disc_shape": "diamond",
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_width": 0.18,
		"shark_lower_teeth_visible": true,
		"fin_ray_count": 12.0,
		"adipose_fin_enabled": true,
		"finlet_enabled": true,
		"pectoral_flap_sync": "alternating"
	})
	assert(_find_slider_for_key(fish_panel, "body_length") != null)
	assert(_find_option_for_key(fish_panel, "mouth_type") != null)
	assert(_find_slider_for_key(fish_panel, "mouth_size") != null)
	assert(_find_slider_for_key(fish_panel, "disc_width") == null)
	assert(_find_option_for_key(fish_panel, "ray_disc_shape") == null)
	assert(_find_option_for_key(fish_panel, "gill_mark") != null)
	assert(_find_slider_for_key(fish_panel, "operculum_size") != null)
	assert(_find_checkbox_for_key(fish_panel, "shark_gill_slit_enabled") == null)
	assert(_find_slider_for_key(fish_panel, "shark_gill_slit_count") == null)
	assert(_find_option_for_key(fish_panel, "shark_mouth_profile") == null)
	assert(_find_slider_for_key(fish_panel, "shark_mouth_width") == null)
	assert(_find_checkbox_for_key(fish_panel, "shark_lower_teeth_visible") == null)
	assert(_find_slider_for_key(fish_panel, "fin_ray_count") != null)
	assert(_find_checkbox_for_key(fish_panel, "adipose_fin_enabled") != null)
	assert(_find_checkbox_for_key(fish_panel, "finlet_enabled") != null)
	assert(_find_option_for_key(fish_panel, "pectoral_flap_sync") != null)

	ray_panel.set_creature_type("ray")
	ray_panel.set_parameters({
		"disc_width": 1.2,
		"ray_disc_shape": "manta",
		"mouth_type": "terminal",
		"mouth_size": 0.08,
		"swim_mode": "eel",
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_width": 0.18,
		"shark_lower_teeth_visible": true,
		"fin_ray_count": 12.0,
		"adipose_fin_enabled": true,
		"finlet_enabled": true,
		"pectoral_flap_sync": "synchronous"
	})
	assert(_find_slider_for_key(ray_panel, "disc_width") != null)
	assert(_find_option_for_key(ray_panel, "ray_disc_shape") != null)
	assert(_find_option_for_key(ray_panel, "mouth_type") == null)
	assert(_find_slider_for_key(ray_panel, "mouth_size") == null)
	assert(_find_option_for_key(ray_panel, "swim_mode") == null)
	assert(_find_option_for_key(ray_panel, "gill_mark") == null)
	assert(_find_slider_for_key(ray_panel, "operculum_size") == null)
	assert(_find_checkbox_for_key(ray_panel, "shark_gill_slit_enabled") == null)
	assert(_find_slider_for_key(ray_panel, "shark_gill_slit_count") == null)
	assert(_find_option_for_key(ray_panel, "shark_mouth_profile") == null)
	assert(_find_slider_for_key(ray_panel, "shark_mouth_width") == null)
	assert(_find_checkbox_for_key(ray_panel, "shark_lower_teeth_visible") == null)
	assert(_find_slider_for_key(ray_panel, "fin_ray_count") == null)
	assert(_find_checkbox_for_key(ray_panel, "adipose_fin_enabled") == null)
	assert(_find_checkbox_for_key(ray_panel, "finlet_enabled") == null)
	assert(_find_option_for_key(ray_panel, "pectoral_flap_sync") != null)

	shark_panel.set_creature_type("shark")
	shark_panel.set_parameters({
		"body_length": 5.8,
		"head_size": 0.42,
		"head_offset": -0.78,
		"snout_length": 0.22,
		"forehead_slope": 0.2,
		"head_bump_height": 0.4,
		"head_bump_pos": -0.1,
		"head_top_flatness": 0.5,
		"head_left_flatness": 0.5,
		"ray_disc_shape": "diamond",
		"caudal_shape": "shark_heterocercal",
		"mouth_type": "terminal",
		"mouth_size": 0.08,
		"lower_jaw_length": 1.0,
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_gill_slit_length": 0.22,
		"shark_gill_slit_spacing": 0.055,
		"shark_gill_slit_angle": -8.0,
		"shark_gill_slit_depth": 0.65,
		"shark_gill_slit_position_x": -0.28,
		"shark_gill_slit_position_y": 0.08,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_width": 0.18,
		"shark_jaw_projection": 0.08,
		"shark_tooth_size": 0.018,
		"shark_lower_teeth_visible": true,
		"fin_ray_count": 12.0,
		"adipose_fin_enabled": true,
		"finlet_enabled": true,
		"pectoral_flap_sync": "alternating"
	})
	assert(_find_slider_for_key(shark_panel, "body_length") != null)
	assert(_find_slider_for_key(shark_panel, "head_size") != null)
	assert(_find_slider_for_key(shark_panel, "head_offset") != null)
	assert(_find_slider_for_key(shark_panel, "snout_length") != null)
	assert(_find_slider_for_key(shark_panel, "forehead_slope") != null)
	assert(_find_slider_for_key(shark_panel, "head_bump_height") == null)
	assert(_find_slider_for_key(shark_panel, "head_bump_pos") == null)
	assert(_find_slider_for_key(shark_panel, "head_top_flatness") == null)
	assert(_find_slider_for_key(shark_panel, "head_left_flatness") == null)
	assert(_find_option_for_key(shark_panel, "ray_disc_shape") == null)
	assert(_find_option_for_key(shark_panel, "caudal_shape") != null)
	assert(_find_option_for_key(shark_panel, "mouth_type") == null)
	assert(_find_slider_for_key(shark_panel, "mouth_size") == null)
	assert(_find_slider_for_key(shark_panel, "lower_jaw_length") == null)
	assert(_find_option_for_key(shark_panel, "gill_mark") == null)
	assert(_find_slider_for_key(shark_panel, "operculum_size") == null)
	assert(_find_checkbox_for_key(shark_panel, "shark_gill_slit_enabled") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_count") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_length") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_spacing") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_angle") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_depth") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_position_x") != null)
	assert(_find_slider_for_key(shark_panel, "shark_gill_slit_position_y") != null)
	assert(_find_option_for_key(shark_panel, "shark_mouth_profile") != null)
	assert(_find_slider_for_key(shark_panel, "shark_mouth_width") != null)
	assert(_find_slider_for_key(shark_panel, "shark_jaw_projection") != null)
	assert(_find_slider_for_key(shark_panel, "shark_tooth_size") != null)
	assert(_find_checkbox_for_key(shark_panel, "shark_lower_teeth_visible") != null)
	assert(_find_slider_for_key(shark_panel, "fin_ray_count") == null)
	assert(_find_checkbox_for_key(shark_panel, "adipose_fin_enabled") == null)
	assert(_find_checkbox_for_key(shark_panel, "finlet_enabled") == null)
	assert(_find_option_for_key(shark_panel, "pectoral_flap_sync") != null)

	print("PARAMETER_MODE_VISIBILITY_TEST_OK")
	get_tree().quit(0)

func _find_slider_for_key(panel: Control, key: String) -> HSlider:
	var sliders: Dictionary = panel.get("sliders")
	return sliders.get(key, null) as HSlider

func _find_option_for_key(panel: Control, key: String) -> OptionButton:
	var option_buttons: Dictionary = panel.get("option_buttons")
	return option_buttons.get(key, null) as OptionButton

func _find_checkbox_for_key(panel: Control, key: String) -> CheckBox:
	var sliders: Dictionary = panel.get("sliders")
	return sliders.get(key, null) as CheckBox
