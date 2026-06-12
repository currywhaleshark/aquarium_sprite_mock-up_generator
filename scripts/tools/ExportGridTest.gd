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
	assert(SpriteExporterScript.direction_yaw_degrees(0) == 180.0)
	assert(SpriteExporterScript.direction_yaw_degrees(7) == 135.0)
	assert(SpriteExporterScript.export_yaw_degrees(1, 0, 45.0) == 45.0)
	assert(SpriteExporterScript.export_yaw_degrees(8, 0, 45.0) == 180.0)
	if not _assert_direction_yaws_match_facing_names():
		return

	await _test_exporter_rig_rotation()

	var file := FileAccess.open("res://exports/test_results/export_grid.ok", FileAccess.WRITE)
	file.store_string("export grid sheet and metadata contract verified")
	file.close()
	print("EXPORT_GRID_TEST_OK")
	get_tree().quit(0)

func _test_exporter_rig_rotation() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var dummy_script := GDScript.new()
	dummy_script.source_code = "extends \"res://scripts/creature/CreatureRig.gd\"\nfunc apply_pose(phase: float) -> void:\n\tpass"
	dummy_script.reload()
	
	var dummy_rig := Node3D.new()
	dummy_rig.set_script(dummy_script)
	add_child(dummy_rig)
	dummy_rig.rotation_degrees.y = 45.0 # Initial rotation (index 1) to check Bug 2

	var overwriter := OverwriterNode.new()
	overwriter.rig = dummy_rig
	add_child(overwriter)

	var tracker := RotationTracker.new()
	tracker.rig = dummy_rig
	add_child(tracker)

	var exporter := SpriteExporterScript.new()
	add_child(exporter)

	var preset := {
		"name": "rotation_test",
		"export_settings": {
			"direction_count": 8,
			"frame_count": 1,
			"render_resolution": {"w": 16, "h": 16}
		}
	}

	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	add_child(vp)

	# Simulate Main.gd exporting state
	overwriter.is_exporting = true

	await exporter.export_preset(preset, dummy_rig, vp)

	overwriter.is_exporting = false

	var unique_yaws: Array[float] = []
	for yaw in tracker.recorded_y_rotations:
		var rounded: float = roundf(float(yaw))
		if unique_yaws.is_empty() or unique_yaws[-1] != rounded:
			unique_yaws.append(rounded)

	var expected_yaws: Array[float] = [180.0, 225.0, 270.0, 315.0, 0.0, 45.0, 90.0, 135.0]
	var match_idx := 0
	for yaw in unique_yaws:
		if match_idx < expected_yaws.size() and absf(float(yaw) - expected_yaws[match_idx]) < 1.0:
			match_idx += 1

	assert(match_idx == expected_yaws.size(), "Exporter did not rotate rig through all 8 absolute directions correctly. Unique yaws: %s" % str(unique_yaws))

	# Clean up mock output files
	var dir := DirAccess.open("res://exports/rotation_test")
	if dir:
		for d in ["east", "north_east", "north", "north_west", "west", "south_west", "south", "south_east"]:
			var subpath: String = "res://exports/rotation_test/frames/" + String(d)
			var subdir := DirAccess.open(subpath)
			if subdir:
				subdir.remove("frame_000.png")
				DirAccess.remove_absolute(subpath)
		var frames_parent := DirAccess.open("res://exports/rotation_test/frames")
		if frames_parent:
			DirAccess.remove_absolute("res://exports/rotation_test/frames")
		dir.remove("rotation_test_sheet.png")
		dir.remove("rotation_test_metadata.json")
		DirAccess.remove_absolute("res://exports/rotation_test")

	# Clean up nodes
	dummy_rig.queue_free()
	overwriter.queue_free()
	tracker.queue_free()
	exporter.queue_free()
	vp.queue_free()

func _write_color_png(path: String, color: Color) -> String:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(path) == OK)
	return path

func _same_rgb(left: Color, right: Color) -> bool:
	return absf(left.r - right.r) < 0.01 and absf(left.g - right.g) < 0.01 and absf(left.b - right.b) < 0.01

func _assert_direction_yaws_match_facing_names() -> bool:
	var expected_headings := [
		Vector3.RIGHT,
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
		Vector3.FORWARD,
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		Vector3.LEFT,
		(Vector3.LEFT + Vector3.BACK).normalized(),
		Vector3.BACK,
		(Vector3.RIGHT + Vector3.BACK).normalized(),
	]
	for i in expected_headings.size():
		var yaw := SpriteExporterScript.direction_yaw_degrees(i)
		var heading := (Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.LEFT).normalized()
		if heading.dot(expected_headings[i]) <= 0.99:
			push_error("Direction %s yaw %.1f faces %s instead of %s" % [
				String(SpriteExporterScript.direction_names(8)[i]),
				yaw,
				str(heading),
				str(expected_headings[i])
			])
			get_tree().quit(1)
			return false
	return true

class OverwriterNode extends Node:
	var rig: Node3D
	var is_exporting := false
	func _process(_delta: float) -> void:
		if rig and not is_exporting:
			rig.rotation_degrees.y = 45.0

class RotationTracker extends Node:
	var rig: Node3D
	var recorded_y_rotations := []
	func _process(_delta: float) -> void:
		if rig:
			recorded_y_rotations.append(rig.rotation_degrees.y)
