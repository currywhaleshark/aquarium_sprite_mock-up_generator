class_name SpeciesArchetypeQAExporter
extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SpeciesArchetypeStoreScript := preload("res://scripts/species/SpeciesArchetypeStore.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")

const QA_DIR := "res://exports/_qa/species_archetypes"
const PREVIEW_CELL_SIZE := 64

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
	var source_dir := "res://exports/%s/frames" % String(preset.get("name", ""))
	var direction_names := SpriteExporterScript.direction_names(8)
	var frame_rows := []
	for direction_name in direction_names:
		var row := PackedStringArray()
		for frame_index in range(4):
			row.append("%s/%s/frame_%03d.png" % [source_dir, String(direction_name), frame_index])
		frame_rows.append(row)
	var target_path := contact_sheet_path(archetype_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	var sheet_error := build_contact_sheet(frame_rows, target_path)
	rig.queue_free()
	exporter.queue_free()
	return {"error": sheet_error, "path": target_path}

static func build_contact_sheet(frame_rows: Array, output_path: String, preview_cell_size: int = PREVIEW_CELL_SIZE) -> Error:
	if frame_rows.is_empty():
		return ERR_INVALID_DATA
	var first_row: PackedStringArray = frame_rows[0]
	if first_row.is_empty():
		return ERR_INVALID_DATA
	var column_count := first_row.size()
	for row_value in frame_rows:
		var row: PackedStringArray = row_value
		if row.size() != column_count:
			return ERR_INVALID_DATA
	var first := Image.load_from_file(first_row[0])
	if first == null:
		return ERR_FILE_CANT_READ
	var native_cell_size := first.get_size()
	var preview_size: int = maxi(1, preview_cell_size)
	var sheet_width: int = maxi(native_cell_size.x * column_count, preview_size * column_count)
	var sheet_height: int = frame_rows.size() * (preview_size + native_cell_size.y)
	var sheet := Image.create(sheet_width, sheet_height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for row_index in frame_rows.size():
		var row: PackedStringArray = frame_rows[row_index]
		var preview_y: int = row_index * (preview_size + native_cell_size.y)
		var native_y: int = preview_y + preview_size
		for column_index in row.size():
			var image := Image.load_from_file(row[column_index])
			if image == null:
				return ERR_FILE_CANT_READ
			image.convert(Image.FORMAT_RGBA8)
			var preview := image.duplicate()
			preview.resize(preview_size, preview_size, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(preview, Rect2i(Vector2i.ZERO, Vector2i(preview_size, preview_size)), Vector2i(column_index * preview_size, preview_y))
			if image.get_size() != native_cell_size:
				image.resize(native_cell_size.x, native_cell_size.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, native_cell_size), Vector2i(column_index * native_cell_size.x, native_y))
	return sheet.save_png(output_path)
