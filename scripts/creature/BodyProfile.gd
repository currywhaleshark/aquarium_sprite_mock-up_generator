class_name BodyProfile
extends RefCounted

const MIN_RING_COUNT := 3
const RING_KEYS := ["x", "y_offset", "upper_height", "lower_height", "width", "roundness", "sway_weight"]
# Default operculum (gill cover) silhouette as a closed outline in normalized
# side-view space: x 0 (front/preopercle hinge) .. 1 (rear free edge),
# y -1 (ventral) .. 1 (dorsal). Shared by the head editor (display default) and
# FishRig._build_operculum_flap (mesh fallback) so the two never drift.
const DEFAULT_OPERCULUM_POINTS := [0.0, -0.55, 0.0, 0.55, 0.5, 0.95, 1.0, 0.7, 1.0, -0.7, 0.5, -0.95]
const SWIM_MODE_PRESETS := {
	"eel": {
		"body_wave_amount": 0.90,
		"body_wave_start": 0.02,
		"body_wave_falloff": 0.35,
		"tail_sway_multiplier": 1.05,
		"tail_fin_extra_swing": 0.35,
		"fin_flap_amount": 3.0,
		"fin_yaw_follow_strength": 0.15,
		"median_fin_flap_amount": 1.0,
		"median_fin_flap_phase": 0.50,
		"turn_tail_lag": 0.90,
		"inside_pectoral_fold": 0.30,
		"outside_pectoral_brace": 0.20,
		"turn_curve_bias": 0.80,
		"turn_median_fin_bias": 0.20,
		"turn_bank_roll": 5.0
	},
	"general": {
		"body_wave_amount": 0.35,
		"body_wave_start": 0.16,
		"body_wave_falloff": 0.75,
		"tail_sway_multiplier": 1.20,
		"tail_fin_extra_swing": 0.45,
		"fin_flap_amount": 6.0,
		"fin_yaw_follow_strength": 0.25,
		"median_fin_flap_amount": 1.5,
		"median_fin_flap_phase": 0.50,
		"turn_tail_lag": 0.75,
		"inside_pectoral_fold": 0.80,
		"outside_pectoral_brace": 0.50,
		"turn_curve_bias": 0.50,
		"turn_median_fin_bias": 0.50,
		"turn_bank_roll": 10.0
	},
	"mackerel": {
		"body_wave_amount": 0.26,
		"body_wave_start": 0.36,
		"body_wave_falloff": 1.05,
		"tail_sway_multiplier": 1.35,
		"tail_fin_extra_swing": 0.50,
		"fin_flap_amount": 4.5,
		"fin_yaw_follow_strength": 0.20,
		"median_fin_flap_amount": 1.0,
		"median_fin_flap_phase": 0.50,
		"turn_tail_lag": 0.60,
		"inside_pectoral_fold": 0.70,
		"outside_pectoral_brace": 0.80,
		"turn_curve_bias": 0.40,
		"turn_median_fin_bias": 0.40,
		"turn_bank_roll": 15.0
	},
	"tuna": {
		"body_wave_amount": 0.12,
		"body_wave_start": 0.56,
		"body_wave_falloff": 1.45,
		"tail_sway_multiplier": 1.55,
		"tail_fin_extra_swing": 0.42,
		"fin_flap_amount": 2.5,
		"fin_yaw_follow_strength": 0.12,
		"median_fin_flap_amount": 0.6,
		"median_fin_flap_phase": 0.50,
		"turn_tail_lag": 0.60,
		"inside_pectoral_fold": 0.70,
		"outside_pectoral_brace": 0.80,
		"turn_curve_bias": 0.40,
		"turn_median_fin_bias": 0.40,
		"turn_bank_roll": 15.0
	},
	"puffer": {
		"body_wave_amount": 0.08,
		"body_wave_start": 0.68,
		"body_wave_falloff": 1.60,
		"tail_sway_multiplier": 0.85,
		"tail_fin_extra_swing": 0.20,
		"fin_flap_amount": 12.0,
		"fin_yaw_follow_strength": 0.10,
		"median_fin_flap_amount": 8.0,
		"median_fin_flap_phase": 0.25,
		"turn_tail_lag": 0.30,
		"inside_pectoral_fold": 0.90,
		"outside_pectoral_brace": 0.70,
		"turn_curve_bias": 0.10,
		"turn_median_fin_bias": 0.85,
		"turn_bank_roll": 2.0
	},
	"boxfish": {
		"body_wave_amount": 0.03,
		"body_wave_start": 0.82,
		"body_wave_falloff": 1.80,
		"tail_sway_multiplier": 0.75,
		"tail_fin_extra_swing": 0.32,
		"fin_flap_amount": 8.0,
		"fin_yaw_follow_strength": 0.08,
		"median_fin_flap_amount": 5.0,
		"median_fin_flap_phase": 0.25,
		"turn_tail_lag": 0.30,
		"inside_pectoral_fold": 0.90,
		"outside_pectoral_brace": 0.70,
		"turn_curve_bias": 0.10,
		"turn_median_fin_bias": 0.85,
		"turn_bank_roll": 2.0
	}
}
const MOTION_MODE_KEYS := [
	"body_wave_amount",
	"body_wave_start",
	"body_wave_falloff",
	"tail_sway_multiplier",
	"tail_fin_extra_swing",
	"fin_flap_amount",
	"fin_yaw_follow_strength",
	"median_fin_flap_amount",
	"median_fin_flap_phase",
	"turn_tail_lag",
	"inside_pectoral_fold",
	"outside_pectoral_brace",
	"turn_curve_bias",
	"turn_median_fin_bias",
	"turn_bank_roll"
]
const UNUSED_PARAMETER_KEYS := [
	"overall_scale",
	"body_height_scale",
	"facing_direction",
	"render_angle",
	"show_pivot_guides",
	"visual_thickness",
	"tail_height",
	"outline_width",
	"toon_steps",
	"rim_light_strength"
]

const PATTERN_TYPE_NAMES := ["none", "stripes", "horizontal_stripes", "spots", "zebra", "marbled", "reticulated", "whale_grid"]
const SCALE_TYPE_NAMES := ["cycloid", "ctenoid", "ganoid", "placoid", "pearlscale"]
const PALETTE_SCHEME_NAMES := ["manual", "countershade", "complementary", "analogous", "muted"]
const FIN_RAY_STYLE_NAMES := ["none", "soft", "spiny", "mixed", "fan", "threaded"]
const VISUAL_PATTERN_DEFAULTS := {
	"pattern_type": "none",
	"pattern_color": "#1f5560",
	"pattern_scale_x": 6.0,
	"pattern_scale_y": 4.0,
	"pattern_intensity": 0.7,
	"pattern_invert": 0.0,
	"pattern_seed": 0.0,
	"pattern_size_lock": 0.0,
	"palette_scheme": "manual",
	"belly_height": 0.5,
	"belly_slope": 0.22,
	"iridescence_strength": 0.0,
	"iridescence_color": "#bfe9ff",
	"iridescence_frequency": 2.0,
	"wetness": 0.0,
	"scale_type": "cycloid",
	"scale_strength": 0.0,
	"scale_size": 16.0,
	"lateral_line_strength": 0.0,
	"pearlscale_strength": 0.0,
	"metallic_scale_strength": 0.0,
	"emissive_marking_strength": 0.0,
	"eye_iris_color": "#d8b24a",
	"eye_pupil_scale": 0.6
}
const FIN_RAY_DEFAULTS := {
	"fin_ray_style": "none",
	"fin_ray_count": 0.0,
	"fin_ray_strength": 0.0,
	"fin_ray_root_bias": 0.0,
	"fin_ray_spread": 0.75,
	"fin_spine_count": 0.0,
	"fin_spine_strength": 0.0,
	"fin_ray_branching": 0.0,
	"fin_ray_segmentation": 0.0,
	"fin_ray_irregularity": 0.0
}
const ADIPOSE_FIN_DEFAULTS := {
	"adipose_fin_enabled": false,
	"adipose_fin_shape": "nub",
	"adipose_fin_size": 0.0,
	"adipose_fin_position": 0.82,
	"adipose_fin_height": 0.18,
	"adipose_fin_roundness": 0.75,
	"adipose_fin_opacity": 0.72,
	"adipose_fin_rayed": 0.0
}
const FINLET_DEFAULTS := {
	"finlet_enabled": false,
	"finlet_shape": "triangle",
	"finlet_dorsal_count": 0.0,
	"finlet_ventral_count": 0.0,
	"finlet_size": 0.25,
	"finlet_taper": 0.35,
	"finlet_spacing": 0.72,
	"finlet_pitch": 0.25,
	"finlet_color_blend": 0.5
}

static func swim_mode_names() -> Array[String]:
	return ["eel", "general", "mackerel", "tuna", "puffer", "boxfish"]

static func pattern_type_names() -> Array[String]:
	var names: Array[String] = []
	for name in PATTERN_TYPE_NAMES:
		names.append(String(name))
	return names

static func pattern_type_index(pattern_type: String) -> int:
	return maxi(PATTERN_TYPE_NAMES.find(pattern_type), 0)

static func scale_type_names() -> Array[String]:
	var names: Array[String] = []
	for name in SCALE_TYPE_NAMES:
		names.append(String(name))
	return names

static func scale_type_index(scale_type: String) -> int:
	return maxi(SCALE_TYPE_NAMES.find(scale_type), 0)

static func palette_scheme_names() -> Array[String]:
	var names: Array[String] = []
	for name in PALETTE_SCHEME_NAMES:
		names.append(String(name))
	return names

static func fin_ray_style_names() -> Array[String]:
	var names: Array[String] = []
	for name in FIN_RAY_STYLE_NAMES:
		names.append(String(name))
	return names

# Injects defaults for the back/belly gradient and procedural pattern controls so
# every preset (including ones saved before this feature) exposes them in the UI.
static func ensure_visual_parameters(parameters: Dictionary) -> void:
	for key in VISUAL_PATTERN_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = VISUAL_PATTERN_DEFAULTS[key]
	for key in FIN_RAY_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = FIN_RAY_DEFAULTS[key]
	for key in ADIPOSE_FIN_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = ADIPOSE_FIN_DEFAULTS[key]
	for key in FINLET_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = FINLET_DEFAULTS[key]
	if not parameters.has("shell_roundness"):
		parameters["shell_roundness"] = 1.0
	if not parameters.has("cephalic_horns"):
		parameters["cephalic_horns"] = "none"
	# Surface colours and the regional marking editor are key-driven in the UI, so
	# inject them when absent or their controls never appear (e.g. a preset that
	# predates the feature, or a base preset that omitted belly_color). Defaults
	# mirror the renderer's own fallbacks so injecting them changes no appearance.
	if not parameters.has("belly_color"):
		parameters["belly_color"] = String(parameters.get("base_color", "#d6fbff"))
	if not parameters.has("secondary_color"):
		parameters["secondary_color"] = "#d8fbff"
	if not parameters.has("fin_color"):
		parameters["fin_color"] = "#7ee1e8"
	if not parameters.has("marking_layers"):
		parameters["marking_layers"] = []

static func suggest_pattern(body_length: float, body_height: float) -> String:
	var ratio := body_length / maxf(body_height, 0.001)
	if ratio >= 3.2:
		return "horizontal_stripes"
	if ratio <= 1.7:
		return "spots"
	return "stripes"

static func derive_palette(base_color: Color, scheme: String) -> Dictionary:
	match scheme:
		"countershade":
			return {
				"belly_color": _shift_color(base_color, -0.02, 0.34, 1.42),
				"pattern_color": _shift_color(base_color, 0.02, 1.18, 0.48)
			}
		"complementary":
			return {
				"belly_color": _shift_color(base_color, 0.0, 0.32, 1.35),
				"pattern_color": _shift_color(base_color, 0.5, 1.05, 0.82)
			}
		"analogous":
			return {
				"belly_color": _shift_color(base_color, -0.05, 0.45, 1.32),
				"pattern_color": _shift_color(base_color, 0.08, 1.0, 0.72)
			}
		"muted":
			return {
				"belly_color": _shift_color(base_color, 0.0, 0.22, 1.22),
				"pattern_color": _shift_color(base_color, 0.03, 0.42, 0.62)
			}
	return {}

static func apply_visual_generation_defaults(parameters: Dictionary, explicit_visual: Dictionary = {}) -> void:
	var explicit_pattern := explicit_visual.has("pattern_type")
	var pattern_value := String(parameters.get("pattern_type", ""))
	if (explicit_pattern and pattern_value == "auto") or (not explicit_pattern and (pattern_value == "" or pattern_value == "none" or pattern_value == "auto")):
		parameters["pattern_type"] = suggest_pattern(
			float(parameters.get("body_length", 1.28)),
			float(parameters.get("body_height", 0.5))
		)

	var scheme := String(parameters.get("palette_scheme", "manual"))
	if scheme == "" or scheme == "manual":
		return
	var palette := derive_palette(_as_color(parameters.get("base_color", "#46c6cf")), scheme)
	if palette.is_empty():
		return
	if palette.has("belly_color") and not explicit_visual.has("belly_color"):
		parameters["belly_color"] = _color_to_html(palette["belly_color"])
	if palette.has("pattern_color") and not explicit_visual.has("pattern_color"):
		parameters["pattern_color"] = _color_to_html(palette["pattern_color"])

static func valid_swim_mode(swim_mode: String) -> String:
	if SWIM_MODE_PRESETS.has(swim_mode):
		return swim_mode
	return "general"

static func swim_mode_values(swim_mode: String) -> Dictionary:
	return SWIM_MODE_PRESETS[valid_swim_mode(swim_mode)].duplicate(true)

static func apply_swim_mode(parameters: Dictionary, swim_mode: String) -> void:
	var valid_mode := valid_swim_mode(swim_mode)
	parameters["swim_mode"] = valid_mode
	var values := swim_mode_values(valid_mode)
	for key in values.keys():
		parameters[key] = values[key]

static func default_fish_rings(shape: String = "default_fish") -> Array[Dictionary]:
	match shape:
		"slender_lateral":
			return default_fish_rings("slender_fish")
		"deep_compressed":
			return default_fish_rings("tall_flat_fish")
		"round_fancy":
			return default_fish_rings("round_chubby_fish")
		"round_puffer":
			return default_fish_rings("round_chubby_fish")
		"bottom_flat":
			return default_fish_rings("bottom_dweller_fish")
		"eel_ribbon":
			return default_fish_rings("slender_fish")
		"boxy":
			return default_fish_rings("round_chubby_fish")
		"elongated", "eel_like", "narrow_peduncle":
			return default_fish_rings("slender_fish")
		"depressed", "broad_head":
			return default_fish_rings("bottom_dweller_fish")
		"round_chubby_fish":
			return _rings([
				["snout", "Snout", 0.0, 0.02, 0.24, 0.20, 0.22, 0.76, 0.0],
				["head", "Head", 0.15, 0.02, 0.46, 0.42, 0.42, 0.9, 0.05],
				["front_body", "Front Body", 0.34, 0.0, 0.66, 0.62, 0.52, 0.95, 0.15],
				["mid_body", "Mid Body", 0.56, -0.02, 0.70, 0.66, 0.5, 0.96, 0.35],
				["rear_body", "Rear Body", 0.78, -0.02, 0.38, 0.34, 0.28, 0.86, 0.65],
				["tail_stem", "Tail Stem", 1.0, -0.03, 0.16, 0.14, 0.1, 0.74, 1.0]
			])
		"slender_fish":
			return _rings([
				["snout", "Snout", 0.0, 0.0, 0.16, 0.14, 0.14, 0.66, 0.0],
				["head", "Head", 0.16, 0.0, 0.28, 0.24, 0.26, 0.8, 0.05],
				["front_body", "Front Body", 0.36, 0.0, 0.36, 0.34, 0.34, 0.88, 0.15],
				["mid_body", "Mid Body", 0.58, 0.0, 0.34, 0.32, 0.3, 0.86, 0.35],
				["rear_body", "Rear Body", 0.78, 0.0, 0.24, 0.22, 0.18, 0.78, 0.65],
				["tail_stem", "Tail Stem", 1.0, 0.0, 0.11, 0.1, 0.07, 0.7, 1.0]
			])
		"tall_flat_fish":
			return _rings([
				["snout", "Snout", 0.0, 0.05, 0.24, 0.2, 0.16, 0.7, 0.0],
				["head", "Head", 0.15, 0.04, 0.46, 0.38, 0.28, 0.82, 0.05],
				["front_body", "Front Body", 0.34, -0.04, 0.86, 0.76, 0.36, 0.92, 0.15],
				["mid_body", "Mid Body", 0.55, -0.08, 0.94, 0.82, 0.34, 0.9, 0.35],
				["rear_body", "Rear Body", 0.77, -0.08, 0.42, 0.34, 0.2, 0.78, 0.65],
				["tail_stem", "Tail Stem", 1.0, -0.08, 0.13, 0.12, 0.06, 0.68, 1.0]
			])
		"bottom_dweller_fish":
			return _rings([
				["snout", "Snout", 0.0, -0.05, 0.14, 0.20, 0.24, 0.62, 0.0],
				["head", "Head", 0.17, -0.06, 0.26, 0.38, 0.48, 0.78, 0.05],
				["front_body", "Front Body", 0.36, -0.08, 0.34, 0.46, 0.58, 0.82, 0.15],
				["mid_body", "Mid Body", 0.58, -0.08, 0.36, 0.44, 0.54, 0.8, 0.35],
				["rear_body", "Rear Body", 0.79, -0.05, 0.24, 0.26, 0.32, 0.74, 0.65],
				["tail_stem", "Tail Stem", 1.0, -0.03, 0.1, 0.1, 0.1, 0.68, 1.0]
			])
	return _rings([
		["snout", "Snout", 0.0, 0.0, 0.24, 0.20, 0.18, 0.65, 0.0],
		["head", "Head", 0.16, 0.0, 0.42, 0.36, 0.34, 0.82, 0.05],
		["front_body", "Front Body", 0.36, 0.0, 0.52, 0.48, 0.46, 0.9, 0.15],
		["mid_body", "Mid Body", 0.58, 0.0, 0.46, 0.42, 0.38, 0.86, 0.35],
		["rear_body", "Rear Body", 0.78, 0.0, 0.28, 0.26, 0.24, 0.78, 0.65],
		["tail_stem", "Tail Stem", 1.0, 0.0, 0.12, 0.12, 0.08, 0.7, 1.0]
	])

static func sample_rings(rings: Array, u: float) -> Dictionary:
	if rings.is_empty():
		return {"x": u, "upper_height": 0.3, "lower_height": 0.3, "width": 0.5, "y_offset": 0.0, "roundness": 1.0, "sway_weight": 1.0}
	var r_left: Dictionary = rings[0]
	var r_right: Dictionary = rings[-1]
	if u <= float(r_left.get("x", 0.0)):
		return r_left
	if u >= float(r_right.get("x", 1.0)):
		return r_right
	for i in range(rings.size() - 1):
		var r1: Dictionary = rings[i]
		var r2: Dictionary = rings[i+1]
		var x1 := float(r1.get("x", 0.0))
		var x2 := float(r2.get("x", 1.0))
		if u >= x1 and u <= x2:
			var t := (u - x1) / maxf(x2 - x1, 0.0001)
			return {
				"x": u,
				"upper_height": lerpf(float(r1.get("upper_height", 0.3)), float(r2.get("upper_height", 0.3)), t),
				"lower_height": lerpf(float(r1.get("lower_height", 0.3)), float(r2.get("lower_height", 0.3)), t),
				"width": lerpf(float(r1.get("width", 0.5)), float(r2.get("width", 0.5)), t),
				"y_offset": lerpf(float(r1.get("y_offset", 0.0)), float(r2.get("y_offset", 0.0)), t),
				"roundness": lerpf(float(r1.get("roundness", 1.0)), float(r2.get("roundness", 1.0)), t),
				"sway_weight": lerpf(float(r1.get("sway_weight", 1.0)), float(r2.get("sway_weight", 1.0)), t)
			}
	return r_left

static func ensure_body_profile(parameters: Dictionary) -> Dictionary:
	var profile: Dictionary = parameters.get("body_profile", {})
	var rings: Array = profile.get("rings", [])
	if rings.is_empty():
		rings = default_fish_rings(String(parameters.get("body_profile_shape", "default_fish")))
	var normalized: Array[Dictionary] = []
	for i in rings.size():
		normalized.append(normalize_ring(rings[i], i))
	profile["rings"] = normalized
	return profile

static func normalize_ring(raw_ring: Dictionary, index: int) -> Dictionary:
	var defaults := default_fish_rings()[mini(index, default_fish_rings().size() - 1)]
	var ring := {}
	ring["id"] = String(raw_ring.get("id", defaults["id"]))
	ring["label"] = String(raw_ring.get("label", defaults["label"]))
	for key in RING_KEYS:
		ring[key] = float(raw_ring.get(key, defaults[key]))
	ring["x"] = clampf(float(ring["x"]), 0.0, 1.0)
	ring["upper_height"] = maxf(float(ring["upper_height"]), 0.01)
	ring["lower_height"] = maxf(float(ring["lower_height"]), 0.01)
	ring["width"] = maxf(float(ring["width"]), 0.01)
	ring["roundness"] = clampf(float(ring["roundness"]), 0.0, 1.0)
	ring["sway_weight"] = clampf(float(ring["sway_weight"]), 0.0, 1.5)
	return ring

static func duplicate_ring(ring: Dictionary) -> Dictionary:
	return normalize_ring(ring.duplicate(true), 0)

static func find_ring_index(rings: Array, ring_id: String) -> int:
	for i in rings.size():
		if String(rings[i].get("id", "")) == ring_id:
			return i
	return -1

static func make_parameters_from_structured_preset(preset: Dictionary) -> Dictionary:
	var parameters: Dictionary = {}
	_merge(parameters, _as_dictionary(preset.get("global", {})))
	_merge(parameters, _as_dictionary(preset.get("tail_profile", {})))
	_merge(parameters, _as_dictionary(preset.get("fin_profile", {})))
	_merge(parameters, _as_dictionary(preset.get("motion_profile", {})))
	_merge(parameters, _as_dictionary(preset.get("visual_profile", {})))
	if preset.has("body_profile"):
		parameters["body_profile"] = preset["body_profile"]
	for key in ["archetype_id", "archetype_strength", "variant_seed", "marking_layers"]:
		if preset.has(key):
			parameters[key] = preset[key]
	parameters["creature_type"] = String(preset.get("type", preset.get("creature_type", "fish")))
	normalize_motion_parameters(parameters)
	ensure_visual_parameters(parameters)
	return parameters

static func split_parameters_into_profiles(parameters: Dictionary, preset: Dictionary) -> Dictionary:
	var updated: Dictionary = preset.duplicate(true)
	var normalized_parameters := parameters.duplicate(true)
	normalize_motion_parameters(normalized_parameters)
	updated["global"] = _pick(parameters, [
		"body_length", "body_height", "body_width", "projection_hint",
		"show_ring_guides", "shell_enabled", "shell_expand",
		"shell_color_mix", "shell_opacity", "shell_roundness", "head_size", "head_offset",
		"eye_size", "eye_position_x", "eye_position_y", "eye_spacing"
	])
	updated["body_profile"] = parameters.get("body_profile", {})
	updated["tail_profile"] = _pick(parameters, [
		"tail_length", "tail_fin_size", "caudal_shape", "caudal_height_scale",
		"ray_tail_style", "ray_tail_spine_enabled", "ray_dorsal_tail_fins"
	])
	updated["fin_profile"] = _pick(parameters, [
		"dorsal_fin_size", "anal_fin_size", "pectoral_fin_size",
		"dorsal_fin_offset_x", "anal_fin_offset_x", "pectoral_fin_offset_x",
		"dorsal_1_attach_t", "dorsal_1_shape", "dorsal_1_length", "dorsal_1_height",
		"dorsal_2_enabled", "dorsal_2_attach_t", "dorsal_2_shape", "dorsal_2_length", "dorsal_2_height",
		"pectoral_attach_t", "pectoral_shape", "pelvic_enabled", "pelvic_attach_t", "pelvic_shape",
		"pelvic_length", "pelvic_height", "anal_attach_t", "anal_shape", "anal_length", "anal_height",
		"head_shape", "mouth_type", "snout_length",
		"snout_base", "snout_thickness", "snout_taper", "snout_curve",
		"head_top_curve", "head_top_peak", "head_belly_curve",
		"head_bump_height", "head_bump_pos", "head_bump_width", "head_bump_angle", "head_bump_round",
		"forehead_slope", "jaw_offset", "mouth_size", "lower_jaw_length", "lower_jaw_angle",
		"lower_jaw_thickness", "lower_jaw_tip", "head_flattening",
		"head_ornament", "gill_mark", "operculum_size", "operculum_height", "operculum_open", "operculum_ridge",
		"operculum_custom_points",
		"barbel_style", "eye_style", "mouth_detail",
		"fin_opacity", "fin_edge_color", "fin_edge_width", "fin_ray_count",
		"fin_ray_strength", "fin_ray_style", "fin_ray_root_bias", "fin_ray_spread",
		"fin_spine_count", "fin_spine_strength", "fin_ray_branching",
		"fin_ray_segmentation", "fin_ray_irregularity",
		"fin_tip_color", "fin_gradient_color",
		"fin_translucency", "fin_translucency_strength", "fin_tornness", "fin_trailing_threads",
		"fin_softness", "fin_rigidity",
		"dorsal_1_softness", "dorsal_1_rigidity", "dorsal_2_softness", "dorsal_2_rigidity",
		"anal_softness", "anal_rigidity", "pelvic_softness", "pelvic_rigidity",
		"pectoral_softness", "pectoral_rigidity", "caudal_softness", "caudal_rigidity",
		"adipose_fin_enabled", "adipose_fin_shape", "adipose_fin_size", "adipose_fin_position",
		"adipose_fin_height", "adipose_fin_roundness", "adipose_fin_opacity",
		"adipose_fin_rayed",
		"finlet_enabled", "finlet_shape", "finlet_dorsal_count", "finlet_ventral_count",
		"finlet_size", "finlet_taper", "finlet_spacing", "finlet_pitch",
		"finlet_color_blend",
		"pectoral_fin_yaw", "pectoral_fin_pitch", "pectoral_fin_roll",
		"dorsal_1_custom_points", "dorsal_2_custom_points", "pectoral_custom_points",
		"pelvic_custom_points", "anal_custom_points", "caudal_custom_points",
		"adipose_fin_custom_points", "finlet_custom_points",
		"adipose_fin_bezier_p1_x", "adipose_fin_bezier_p1_y",
		"adipose_fin_bezier_p2_x", "adipose_fin_bezier_p2_y",
		"finlet_bezier_p1_x", "finlet_bezier_p1_y",
		"finlet_bezier_p2_x", "finlet_bezier_p2_y",
		"cephalic_horns", "ray_head_shape", "ray_disc_shape"
	])
	updated["motion_profile"] = _pick(normalized_parameters, [
		"swim_mode", "swim_speed", "global_sway_amount", "phase_delay", "tail_sway_multiplier",
		"body_wave_amount", "body_wave_start", "body_wave_falloff",
		"tail_fin_extra_swing", "fin_flap_amount",
		"fin_yaw_follow_strength", "median_fin_flap_amount", "median_fin_flap_phase",
		"idle_bob_amount", "turn_tail_lag", "inside_pectoral_fold",
		"outside_pectoral_brace", "turn_curve_bias", "turn_median_fin_bias", "turn_bank_roll",
		"pectoral_flap_sync", "wave_ripples", "ray_locomotion_mode"
	])
	updated["visual_profile"] = _pick(parameters, [
		"base_color", "belly_color", "secondary_color", "fin_color", "outline_color",
		"highlight_strength", "shadow_strength",
		"pattern_type", "pattern_color", "pattern_scale_x", "pattern_scale_y",
		"pattern_intensity", "pattern_invert", "pattern_seed", "pattern_size_lock",
		"palette_scheme", "belly_height", "belly_slope",
		"iridescence_strength", "iridescence_color", "iridescence_frequency",
		"wetness", "scale_type", "scale_strength", "scale_size", "lateral_line_strength",
		"pearlscale_strength", "metallic_scale_strength", "emissive_marking_strength",
		"eye_iris_color", "eye_pupil_scale"
	])
	for key in ["archetype_id", "archetype_strength", "variant_seed", "marking_layers"]:
		if parameters.has(key):
			updated[key] = parameters[key]
	updated["parameters"] = normalized_parameters
	return updated

static func normalize_motion_parameters(parameters: Dictionary) -> void:
	if not parameters.has("fin_flap_amount") and parameters.has("pectoral_flap_amount"):
		parameters["fin_flap_amount"] = float(parameters["pectoral_flap_amount"])
	if not parameters.has("global_sway_amount"):
		if parameters.has("tail_2_sway_amount"):
			parameters["global_sway_amount"] = float(parameters["tail_2_sway_amount"])
		elif parameters.has("tail_1_sway_amount"):
			parameters["global_sway_amount"] = float(parameters["tail_1_sway_amount"]) / 0.65
		elif parameters.has("tail_fin_sway_amount"):
			parameters["global_sway_amount"] = float(parameters["tail_fin_sway_amount"]) / 1.25
		elif parameters.has("body_sway_amount"):
			parameters["global_sway_amount"] = float(parameters["body_sway_amount"])
	if not parameters.has("tail_sway_multiplier"):
		parameters["tail_sway_multiplier"] = 1.0
	if not parameters.has("pectoral_flap_sync"):
		parameters["pectoral_flap_sync"] = "alternating"
	if not parameters.has("wave_ripples"):
		parameters["wave_ripples"] = 1.2
	if not parameters.has("ray_locomotion_mode"):
		parameters["ray_locomotion_mode"] = "rajiform"
	if not parameters.has("ray_head_shape"):
		parameters["ray_head_shape"] = "manta"
	if not parameters.has("ray_disc_shape"):
		parameters["ray_disc_shape"] = "diamond"
	if not parameters.has("ray_tail_style"):
		parameters["ray_tail_style"] = "whip"
	if not parameters.has("ray_tail_spine_enabled"):
		parameters["ray_tail_spine_enabled"] = false
	if not parameters.has("ray_dorsal_tail_fins"):
		parameters["ray_dorsal_tail_fins"] = false
	var default_mode := _default_swim_mode(parameters)
	parameters["swim_mode"] = valid_swim_mode(String(parameters.get("swim_mode", default_mode)))
	var mode_values := swim_mode_values(String(parameters["swim_mode"]))
	for key in MOTION_MODE_KEYS:
		if not parameters.has(key):
			parameters[key] = mode_values[key]
	parameters.erase("body_sway_amount")
	parameters.erase("tail_1_sway_amount")
	parameters.erase("tail_2_sway_amount")
	parameters.erase("tail_fin_sway_amount")
	parameters.erase("pectoral_flap_amount")
	for key in UNUSED_PARAMETER_KEYS:
		parameters.erase(key)

static func _default_motion_distribution(parameters: Dictionary) -> Dictionary:
	var shape := String(parameters.get("body_profile_shape", ""))
	var body_length := float(parameters.get("body_length", 1.28))
	var body_height := maxf(float(parameters.get("body_height", 0.5)), 0.001)
	var slenderness := body_length / body_height
	if shape == "elongated" or shape == "eel_like" or shape == "narrow_peduncle" or slenderness > 3.2:
		return {"body_wave_amount": 0.9, "body_wave_start": 0.02, "body_wave_falloff": 0.35}
	if shape == "deep_compressed" or slenderness < 1.6:
		return {"body_wave_amount": 0.22, "body_wave_start": 0.42, "body_wave_falloff": 1.25}
	if shape == "depressed" or shape == "broad_head":
		return {"body_wave_amount": 0.28, "body_wave_start": 0.34, "body_wave_falloff": 1.0}
	return {"body_wave_amount": 0.35, "body_wave_start": 0.16, "body_wave_falloff": 0.75}

static func _default_swim_mode(parameters: Dictionary) -> String:
	var shape := String(parameters.get("body_profile_shape", ""))
	var body_length := float(parameters.get("body_length", 1.28))
	var body_height := maxf(float(parameters.get("body_height", 0.5)), 0.001)
	var slenderness := body_length / body_height
	if shape == "elongated" or shape == "eel_like" or shape == "narrow_peduncle" or slenderness > 3.2:
		return "eel"
	if shape == "deep_compressed" or slenderness < 1.6:
		return "puffer"
	return "general"

static func _rings(rows: Array) -> Array[Dictionary]:
	var rings: Array[Dictionary] = []
	for row in rows:
		rings.append({
			"id": row[0],
			"label": row[1],
			"x": row[2],
			"y_offset": row[3],
			"upper_height": row[4],
			"lower_height": row[5],
			"width": row[6],
			"roundness": row[7],
			"sway_weight": row[8]
		})
	return rings

static func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]

static func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}

static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(value)
	return Color(0.27, 0.78, 0.81, 1.0)

static func _color_to_html(color: Color) -> String:
	return "#%s" % color.to_html(false)

static func _shift_color(color: Color, hue_delta: float, saturation_mult: float, value_mult: float) -> Color:
	return Color.from_hsv(
		fposmod(color.h + hue_delta, 1.0),
		clampf(color.s * saturation_mult, 0.0, 1.0),
		clampf(color.v * value_mult, 0.0, 1.0),
		color.a
	)

static func _pick(source: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key in keys:
		if source.has(key):
			result[key] = source[key]
	return result
