class_name PresetStore
extends RefCounted

const PRESET_DIR := "res://presets"

static func load_all() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var dir := DirAccess.open(PRESET_DIR)
	if dir == null:
		return presets
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var preset := load_preset("%s/%s" % [PRESET_DIR, file_name])
			if not preset.is_empty():
				presets.append(preset)
		file_name = dir.get_next()
	dir.list_dir_end()
	presets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("name", "")) < String(b.get("name", "")))
	return presets

static func load_preset(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func save_preset(path: String, preset: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_string(JSON.stringify(preset, "\t"))
	file.close()
	return OK
