class_name SpeciesArchetypeQAExporter
extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SpeciesArchetypeStoreScript := preload("res://scripts/species/SpeciesArchetypeStore.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")

const QA_DIR := "res://exports/_qa/species_archetypes"

static func contact_sheet_path(archetype_id: String) -> String:
	return "%s/%s_contact.png" % [QA_DIR, archetype_id]

static func build_qa_preset(archetype: Dictionary, parameters: Dictionary) -> Dictionary:
	var archetype_id := String(archetype.get("id", "unnamed"))
	return {
		"name": "_qa_species_%s" % archetype_id,
		"type": "fish",
		"creature_type": "fish",
		"parameters": parameters.duplicate(true),
		"export_settings": {
			"direction_count": 8,
			"frame_count": 4,
			"frame_rate": 8,
			"render_resolution": {"w": 128, "h": 128}
		},
		"display_target_size": {"w": 64, "h": 64}
	}

func export_contact_sheet(archetype_id: String, viewport: SubViewport) -> Dictionary:
	var archetype := SpeciesArchetypeStoreScript.load_archetype(archetype_id)
	if archetype.is_empty():
		return {"error": ERR_DOES_NOT_EXIST, "path": ""}
	var parameters := SpeciesArchetypeStoreScript.apply_archetype({}, archetype, 1.0, 1)
	var preset := build_qa_preset(archetype, parameters)
	var rig: FishRig = FishRigScript.new()
	add_child(rig)
	rig.set_parameters(parameters)
	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	await exporter.export_preset(preset, rig, viewport)
	var source_path := "res://exports/%s/%s_sheet.png" % [String(preset.get("name", "")), String(preset.get("name", ""))]
	var target_path := contact_sheet_path(archetype_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	var copy_error := _copy_file(source_path, target_path)
	rig.queue_free()
	exporter.queue_free()
	return {"error": copy_error, "path": target_path}

static func _copy_file(source_path: String, target_path: String) -> Error:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ERR_CANT_OPEN
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return ERR_CANT_CREATE
	target.store_buffer(bytes)
	target.close()
	return OK
