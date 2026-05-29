class_name SpriteSheetBuilder
extends RefCounted

static func build_sheet(frame_paths: PackedStringArray, output_path: String) -> Error:
	if frame_paths.is_empty():
		return ERR_INVALID_DATA
	var first := Image.load_from_file(frame_paths[0])
	if first == null:
		return ERR_FILE_CANT_READ
	var cell_size := first.get_size()
	var sheet := Image.create(cell_size.x * frame_paths.size(), cell_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in frame_paths.size():
		var image := Image.load_from_file(frame_paths[i])
		if image == null:
			return ERR_FILE_CANT_READ
		if image.get_size() != cell_size:
			image.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell_size), Vector2i(i * cell_size.x, 0))
	return sheet.save_png(output_path)
