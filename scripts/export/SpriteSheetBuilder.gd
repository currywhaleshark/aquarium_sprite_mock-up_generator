class_name SpriteSheetBuilder
extends RefCounted

static func build_sheet(frame_paths: PackedStringArray, output_path: String) -> Error:
	return build_sheet_grid([frame_paths], output_path)

static func build_sheet_grid(frame_rows: Array, output_path: String) -> Error:
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
	var cell_size := first.get_size()
	var sheet := Image.create(cell_size.x * column_count, cell_size.y * frame_rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for row_index in frame_rows.size():
		var row: PackedStringArray = frame_rows[row_index]
		for column_index in row.size():
			var image := Image.load_from_file(row[column_index])
			if image == null:
				return ERR_FILE_CANT_READ
			if image.get_size() != cell_size:
				image.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell_size), Vector2i(column_index * cell_size.x, row_index * cell_size.y))
	return sheet.save_png(output_path)
