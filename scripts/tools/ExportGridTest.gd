extends Node

const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const SpriteSheetBuilderScript := preload("res://scripts/export/SpriteSheetBuilder.gd")

func _ready() -> void:
	var output_dir := ProjectSettings.globalize_path("res://exports/test_results/export_grid")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var rows := []
	rows.append(PackedStringArray([
		_write_color_png(output_dir.path_join("r0_c0.png"), Color(1.0, 0.0, 0.0, 1.0)),
		_write_color_png(output_dir.path_join("r0_c1.png"), Color(0.0, 1.0, 0.0, 1.0)),
		_write_color_png(output_dir.path_join("r0_c2.png"), Color(0.0, 0.0, 1.0, 1.0))
	]))
	rows.append(PackedStringArray([
		_write_color_png(output_dir.path_join("r1_c0.png"), Color(1.0, 1.0, 0.0, 1.0)),
		_write_color_png(output_dir.path_join("r1_c1.png"), Color(0.0, 1.0, 1.0, 1.0)),
		_write_color_png(output_dir.path_join("r1_c2.png"), Color(1.0, 0.0, 1.0, 1.0))
	]))

	var sheet_path := output_dir.path_join("grid_sheet.png")
	assert(SpriteSheetBuilderScript.build_sheet_grid(rows, sheet_path) == OK)
	var sheet := Image.load_from_file(sheet_path)
	assert(sheet != null)
	assert(sheet.get_size() == Vector2i(12, 8))
	assert(_same_rgb(sheet.get_pixel(2, 2), Color(1.0, 0.0, 0.0, 1.0)))
	assert(_same_rgb(sheet.get_pixel(6, 2), Color(0.0, 1.0, 0.0, 1.0)))
	assert(_same_rgb(sheet.get_pixel(10, 6), Color(1.0, 0.0, 1.0, 1.0)))

	var one_direction_metadata := ExportMetadataScript.build({"name": "single", "export_settings": {"frame_count": 3}}, Vector2i(4, 4))
	assert(int(one_direction_metadata.get("direction_count", 0)) == 1)
	assert(int(one_direction_metadata.get("sheet_columns", 0)) == 3)
	assert(int(one_direction_metadata.get("sheet_rows", 0)) == 1)

	var eight_direction_metadata := ExportMetadataScript.build({"name": "eight", "export_settings": {"frame_count": 3, "direction_count": 8}}, Vector2i(4, 4))
	assert(int(eight_direction_metadata.get("direction_count", 0)) == 8)
	assert(int(eight_direction_metadata.get("sheet_columns", 0)) == 3)
	assert(int(eight_direction_metadata.get("sheet_rows", 0)) == 8)
	var directions: Array = eight_direction_metadata.get("directions", [])
	assert(directions.size() == 8)
	assert(String(directions[0]) == "east")
	assert(String(directions[7]) == "south_east")
	assert(SpriteExporterScript.direction_yaw_degrees(0) == 0.0)
	assert(SpriteExporterScript.direction_yaw_degrees(7) == 315.0)

	var file := FileAccess.open("res://exports/test_results/export_grid.ok", FileAccess.WRITE)
	file.store_string("export grid sheet and metadata contract verified")
	file.close()
	print("EXPORT_GRID_TEST_OK")
	get_tree().quit(0)

func _write_color_png(path: String, color: Color) -> String:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(path) == OK)
	return path

func _same_rgb(left: Color, right: Color) -> bool:
	return absf(left.r - right.r) < 0.01 and absf(left.g - right.g) < 0.01 and absf(left.b - right.b) < 0.01
