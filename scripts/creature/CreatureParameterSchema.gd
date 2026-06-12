class_name CreatureParameterSchema
extends RefCounted

const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")

const SHARK_GILL_KEYS := {
	"shark_gill_slit_enabled": true,
	"shark_gill_slit_count": true,
	"shark_gill_slit_length": true,
	"shark_gill_slit_spacing": true,
	"shark_gill_slit_angle": true,
	"shark_gill_slit_depth": true,
	"shark_gill_slit_position_x": true,
	"shark_gill_slit_position_y": true
}

const RAY_ONLY_KEYS := {
	"ray_head_shape": true,
	"ray_disc_shape": true,
	"ray_tail_style": true,
	"ray_tail_spine_enabled": true,
	"ray_dorsal_tail_fins": true,
	"ray_locomotion_mode": true,
	"wave_ripples": true,
	"flap_amplitude": true,
	"flap_speed": true,
	"wing_phase_offset": true,
	"tail_follow_amount": true,
	"glide_bob_amount": true,
	"pectoral_flap_sync": true,
	"cephalic_horns": true,
	"eye_spacing": true,
	"underside_color": true
}

const RAY_PREFIXES := [
	"disc_",
	"wing_"
]

const FISH_GILL_KEYS := {
	"gill_mark": true
}

const FISH_ONLY_KEYS := {
	"barbel_style": true,
	"adipose_fin_shape": true,
	"finlet_shape": true
}

const FISH_MOTION_KEYS := {
	"swim_mode": true,
	"tail_fin_extra_swing": true,
	"median_fin_wave_amount": true,
	"median_fin_flap_amount": true,
	"median_fin_flap_phase": true,
	"inside_pectoral_fold": true,
	"outside_pectoral_brace": true
}

const FISH_MOTION_PREFIXES := [
	"body_wave_"
]

const TELEOST_FIN_PREFIXES := [
	"fin_ray_",
	"fin_spine_",
	"adipose_fin_",
	"finlet_"
]

const COMMON_KEYS := {
	"creature_type": false,
	"body_length": true,
	"body_height": true,
	"body_width": true,
	"shell_enabled": true,
	"shell_expand": true,
	"shell_color_mix": true,
	"shell_opacity": true,
	"shell_roundness": true,
	"head_shape": true,
	"head_size": true,
	"head_offset": true,
	"snout_length": true,
	"forehead_slope": true,
	"jaw_offset": true,
	"mouth_type": true,
	"mouth_size": true,
	"mouth_open": true,
	"eye_size": true,
	"eye_position_x": true,
	"eye_position_y": true,
	"base_color": true,
	"secondary_color": true,
	"belly_color": true,
	"fin_color": true,
	"outline_color": true,
	"highlight_strength": true,
	"shadow_strength": true,
	"pattern_type": true,
	"pattern_color": true,
	"pattern_intensity": true,
	"pattern_scale_x": true,
	"pattern_scale_y": true,
	"marking_layers": true,
	"palette_scheme": true,
	"scale_type": true,
	"scale_strength": true,
	"scale_size": true,
	"swim_speed": true,
	"global_sway_amount": true,
	"phase_delay": true,
	"tail_sway_multiplier": true,
	"fin_flap_amount": true,
	"fin_yaw_follow_strength": true,
	"turn_rate": true,
	"turn_radius": true,
	"camera_preset": true,
	"camera_yaw": true,
	"camera_pitch": true,
	"camera_roll": true,
	"orthographic_size": true,
	"frame_count": true,
	"frame_rate": true,
	"frame_ticks": true,
	"padding_px": true,
	"render_resolution": true,
	"direction_count": true,
	"target_display_w": true,
	"target_display_h": true,
	"output_resolution": true
}

const FISH_FIN_KEYS := {
	"dorsal_fin_size": true,
	"anal_fin_size": true,
	"pectoral_fin_size": true,
	"dorsal_fin_offset_x": true,
	"anal_fin_offset_x": true,
	"pectoral_fin_offset_x": true,
	"pectoral_offset_y": true,
	"pectoral_fin_yaw": true,
	"pectoral_fin_pitch": true,
	"pectoral_fin_roll": true,
	"dorsal_1_attach_t": true,
	"dorsal_1_shape": true,
	"dorsal_1_length": true,
	"dorsal_1_height": true,
	"dorsal_2_enabled": true,
	"dorsal_2_attach_t": true,
	"dorsal_2_shape": true,
	"dorsal_2_length": true,
	"dorsal_2_height": true,
	"pectoral_attach_t": true,
	"pectoral_shape": true,
	"pelvic_enabled": true,
	"pelvic_attach_t": true,
	"pelvic_shape": true,
	"pelvic_length": true,
	"pelvic_height": true,
	"anal_attach_t": true,
	"anal_shape": true,
	"anal_length": true,
	"anal_height": true,
	"caudal_shape": true,
	"tail_length": true,
	"tail_height": true,
	"tail_fin_size": true,
	"caudal_height_scale": true
}

const SHARK_CAUDAL_VALUES := {
	"shark_heterocercal": true,
	"thresher": true,
	"pointed": true,
	"lunate": true,
	"forked_shallow": true,
	"forked_deep": true
}

static func is_parameter_visible(mode: String, key: String) -> bool:
	var normalized_mode := CreatureModeScript.normalize(mode)
	if COMMON_KEYS.has(key):
		return bool(COMMON_KEYS[key])
	if SHARK_GILL_KEYS.has(key):
		return normalized_mode == CreatureModeScript.SHARK
	if FISH_GILL_KEYS.has(key) or key.begins_with("operculum_"):
		return normalized_mode == CreatureModeScript.FISH
	if RAY_ONLY_KEYS.has(key) or _has_any_prefix(key, RAY_PREFIXES):
		return normalized_mode == CreatureModeScript.RAY
	if _is_teleost_fin_key(key):
		return normalized_mode == CreatureModeScript.FISH
	if FISH_ONLY_KEYS.has(key):
		return normalized_mode == CreatureModeScript.FISH
	if FISH_MOTION_KEYS.has(key) or _has_any_prefix(key, FISH_MOTION_PREFIXES):
		return normalized_mode != CreatureModeScript.RAY
	if FISH_FIN_KEYS.has(key):
		return normalized_mode != CreatureModeScript.RAY
	return normalized_mode == CreatureModeScript.FISH

static func is_option_value_visible(mode: String, key: String, value: String) -> bool:
	var normalized_mode := CreatureModeScript.normalize(mode)
	if key == "caudal_shape" and normalized_mode == CreatureModeScript.SHARK:
		return SHARK_CAUDAL_VALUES.has(value)
	if key == "caudal_shape" and normalized_mode == CreatureModeScript.RAY:
		return false
	return true

static func allowed_fin_slots(mode: String) -> Array[String]:
	match CreatureModeScript.normalize(mode):
		CreatureModeScript.RAY:
			return ["cephalic", "pelvic"] as Array[String]
		CreatureModeScript.SHARK:
			return ["dorsal_1", "dorsal_2", "pectoral", "pelvic", "anal", "caudal"] as Array[String]
		_:
			return ["dorsal_1", "dorsal_2", "pectoral", "pelvic", "anal", "caudal", "adipose_fin", "finlet"] as Array[String]

static func _is_teleost_fin_key(key: String) -> bool:
	if key == "adipose_fin_enabled" or key == "finlet_enabled":
		return true
	return _has_any_prefix(key, TELEOST_FIN_PREFIXES)

static func _has_any_prefix(key: String, prefixes: Array) -> bool:
	for prefix in prefixes:
		if key.begins_with(String(prefix)):
			return true
	return false
