class_name BodyProfile
extends RefCounted

const MIN_RING_COUNT := 3
const RING_KEYS := ["x", "y_offset", "upper_height", "lower_height", "width", "roundness", "sway_weight"]

static func default_fish_rings(shape: String = "default_fish") -> Array[Dictionary]:
	match shape:
		"deep_compressed":
			return default_fish_rings("tall_flat_fish")
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
	parameters["creature_type"] = String(preset.get("type", preset.get("creature_type", "fish")))
	normalize_motion_parameters(parameters)
	return parameters

static func split_parameters_into_profiles(parameters: Dictionary, preset: Dictionary) -> Dictionary:
	var updated: Dictionary = preset.duplicate(true)
	var normalized_parameters := parameters.duplicate(true)
	normalize_motion_parameters(normalized_parameters)
	updated["global"] = _pick(parameters, [
		"overall_scale", "body_length", "body_height", "body_width", "body_height_scale",
		"visual_thickness", "facing_direction", "render_angle", "projection_hint",
		"show_ring_guides", "show_pivot_guides", "shell_enabled", "shell_expand",
		"shell_color_mix", "shell_opacity", "head_size", "head_offset",
		"eye_size", "eye_position_x", "eye_position_y", "mouth_position"
	])
	updated["body_profile"] = parameters.get("body_profile", {})
	updated["tail_profile"] = _pick(parameters, ["tail_length", "tail_height", "tail_fin_size", "caudal_shape", "caudal_height_scale"])
	updated["fin_profile"] = _pick(parameters, [
		"dorsal_fin_size", "anal_fin_size", "pectoral_fin_size",
		"dorsal_fin_offset_x", "anal_fin_offset_x", "pectoral_fin_offset_x",
		"dorsal_1_attach_t", "dorsal_1_shape", "dorsal_1_length", "dorsal_1_height",
		"dorsal_2_enabled", "dorsal_2_attach_t", "dorsal_2_shape",
		"pectoral_attach_t", "pelvic_enabled", "pelvic_attach_t", "pelvic_shape",
		"anal_attach_t", "anal_shape", "head_shape", "mouth_type", "snout_length",
		"forehead_slope", "jaw_offset", "mouth_size", "head_flattening"
	])
	updated["motion_profile"] = _pick(normalized_parameters, [
		"swim_speed", "global_sway_amount", "phase_delay", "tail_sway_multiplier",
		"fin_flap_amount", "pectoral_flap_amount", "idle_bob_amount"
	])
	updated["visual_profile"] = _pick(parameters, [
		"base_color", "belly_color", "secondary_color", "fin_color", "outline_color",
		"outline_width", "highlight_strength", "shadow_strength", "toon_steps", "rim_light_strength"
	])
	updated["parameters"] = normalized_parameters
	return updated

static func normalize_motion_parameters(parameters: Dictionary) -> void:
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
	parameters.erase("body_sway_amount")
	parameters.erase("tail_1_sway_amount")
	parameters.erase("tail_2_sway_amount")
	parameters.erase("tail_fin_sway_amount")

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

static func _pick(source: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key in keys:
		if source.has(key):
			result[key] = source[key]
	return result
