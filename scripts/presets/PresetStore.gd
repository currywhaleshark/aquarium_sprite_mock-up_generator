class_name PresetStore
extends RefCounted

const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const PRESET_DIR := "res://presets"
const USER_PRESET_DIR := "user://presets"

static func load_all(creature_type: String = "") -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var filter_mode := ""
	if creature_type.strip_edges() != "":
		filter_mode = CreatureModeScript.normalize(creature_type)
	presets.append_array(_load_from_dir(PRESET_DIR, "built_in"))
	presets.append_array(_load_from_dir(USER_PRESET_DIR, "user"))
	if filter_mode != "":
		presets = presets.filter(func(preset: Dictionary) -> bool:
			return String(preset.get("creature_type", "")) == filter_mode
		)
	presets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "%s:%s" % [String(a.get("_preset_source", "")), String(a.get("name", ""))]
		var right := "%s:%s" % [String(b.get("_preset_source", "")), String(b.get("name", ""))]
		return left < right
	)
	return presets

static func find_default_for_mode(mode: String) -> Dictionary:
	var normalized_mode := CreatureModeScript.normalize(mode)
	var default_name := CreatureModeScript.default_preset(normalized_mode)
	var mode_presets := load_all(normalized_mode)
	for preset in mode_presets:
		if String(preset.get("name", "")) == default_name:
			return preset
	return mode_presets[0] if not mode_presets.is_empty() else {}

static func load_preset(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return normalize_preset(parsed)

static func save_preset(path: String, preset: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_string(JSON.stringify(preset, "\t"))
	file.close()
	return OK

static func sanitize_preset_filename(preset_name: String) -> String:
	var source := preset_name.strip_edges()
	var slug := ""
	var previous_was_separator := false
	for i in source.length():
		var code := source.unicode_at(i)
		var character := source.substr(i, 1)
		var is_ascii_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		var is_hangul := (code >= 0xac00 and code <= 0xd7af) or (code >= 0x1100 and code <= 0x11ff) or (code >= 0x3130 and code <= 0x318f)
		var is_separator := code <= 32 or character == "_"
		if is_ascii_letter or is_digit or is_hangul or character == "-":
			slug += character
			previous_was_separator = false
		elif is_separator:
			if slug != "" and not previous_was_separator:
				slug += "_"
				previous_was_separator = true
	if slug.ends_with("_"):
		slug = slug.substr(0, slug.length() - 1)
	if slug == "":
		return "user_preset"
	return slug

static func save_user_preset(preset_name: String, preset: Dictionary) -> Dictionary:
	var display_name := preset_name.strip_edges()
	if display_name == "":
		display_name = "user_preset"
	var saved_preset := preset.duplicate(true)
	saved_preset["name"] = display_name
	saved_preset.erase("_preset_source")
	saved_preset.erase("_preset_path")
	var parameters: Dictionary = saved_preset.get("parameters", {})
	if not parameters.is_empty():
		saved_preset = BodyProfileScript.split_parameters_into_profiles(parameters, saved_preset)
		saved_preset["name"] = display_name
	var absolute_dir := ProjectSettings.globalize_path(USER_PRESET_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		return {"error": dir_error, "path": ""}
	var path := "%s/%s.json" % [USER_PRESET_DIR, sanitize_preset_filename(display_name)]
	var error := save_preset(path, saved_preset)
	return {"error": error, "path": path}

static func _load_from_dir(dir_path: String, source: String) -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return presets
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "%s/%s" % [dir_path, file_name]
			var preset := load_preset(path)
			if not preset.is_empty():
				preset["_preset_source"] = source
				preset["_preset_path"] = path
				presets.append(preset)
		file_name = dir.get_next()
	dir.list_dir_end()
	return presets

static func normalize_preset(preset: Dictionary) -> Dictionary:
	var normalized := preset.duplicate(true)
	var mode := CreatureModeScript.normalize(String(normalized.get("creature_type", normalized.get("type", "fish"))))
	normalized["creature_type"] = mode
	normalized["type"] = mode
	if normalized.has("parameters"):
		var parameters: Dictionary = normalized["parameters"]
		parameters["creature_type"] = mode
		if mode == CreatureModeScript.FISH or mode == CreatureModeScript.SHARK:
			parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
			BodyProfileScript.normalize_motion_parameters(parameters)
		BodyProfileScript.ensure_visual_parameters(parameters)
		normalized["parameters"] = parameters
		return normalized
	var parameters := BodyProfileScript.make_parameters_from_structured_preset(normalized)
	parameters["creature_type"] = mode
	if mode == CreatureModeScript.FISH or mode == CreatureModeScript.SHARK:
		parameters["body_profile"] = BodyProfileScript.ensure_body_profile(parameters)
	normalized["parameters"] = parameters
	return normalized
