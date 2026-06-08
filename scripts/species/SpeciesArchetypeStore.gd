class_name SpeciesArchetypeStore
extends RefCounted

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const SpeciesArchetypeScript := preload("res://scripts/species/SpeciesArchetype.gd")

const ARCHETYPE_DIR := "res://data/species_archetypes"
const PROFILE_SECTIONS := ["global", "tail_profile", "fin_profile", "visual_profile", "motion_profile"]

static func load_all(dir_path: String = ARCHETYPE_DIR) -> Array[Dictionary]:
	var archetypes: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return archetypes
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var archetype := load_from_path("%s/%s" % [dir_path, file_name])
			if not archetype.is_empty():
				archetypes.append(archetype)
		file_name = dir.get_next()
	dir.list_dir_end()
	archetypes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", ""))
	)
	return archetypes

static func load_archetype(archetype_id: String, dir_path: String = ARCHETYPE_DIR) -> Dictionary:
	for archetype in load_all(dir_path):
		if String(archetype.get("id", "")) == archetype_id:
			return archetype
	return {}

static func load_from_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var archetype := SpeciesArchetypeScript.normalize(parsed)
	if String(archetype.get("id", "")) == "":
		return {}
	return archetype

static func apply_archetype(parameters: Dictionary, archetype: Dictionary, strength: float = 1.0, variant_seed: int = 0) -> Dictionary:
	var result := parameters.duplicate(true)
	var normalized := SpeciesArchetypeScript.normalize(archetype)
	var clamped_strength := clampf(strength, 0.0, 1.0)
	var overrides: Dictionary = normalized.get("profile_overrides", {})
	for section_name in PROFILE_SECTIONS:
		var section: Dictionary = overrides.get(section_name, {})
		_apply_section(result, section, clamped_strength)
	var body_profile: Dictionary = overrides.get("body_profile", {})
	var body_shape := String(body_profile.get("shape", ""))
	if body_shape != "" and clamped_strength >= 0.5:
		result["body_profile_shape"] = body_shape
		result["body_profile"] = {"rings": BodyProfileScript.default_fish_rings(body_shape)}
	result["archetype_id"] = String(normalized.get("id", ""))
	result["archetype_strength"] = clamped_strength
	result["variant_seed"] = variant_seed
	result["marking_layers"] = (normalized.get("marking_layers", []) as Array).duplicate(true)
	BodyProfileScript.normalize_motion_parameters(result)
	BodyProfileScript.ensure_visual_parameters(result)
	BodyProfileScript.apply_visual_generation_defaults(result, overrides.get("visual_profile", {}))
	return result

static func _apply_section(target: Dictionary, section: Dictionary, strength: float) -> void:
	for key in section.keys():
		var value: Variant = section[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			var current := float(target.get(key, value))
			target[key] = lerpf(current, float(value), strength)
		elif strength >= 0.5:
			target[key] = value
