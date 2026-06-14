extends Node

const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")
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
	if not _assert_turn_clip_metadata_contract():
		return
	if not _test_turn_export_row_pose_without_viewport():
		return
	if not _test_turn_preview_gif_row_order():
		return
	if not _assert_fixed_quarter_view_export_metadata(eight_direction_metadata):
		return
	var directions: Array = eight_direction_metadata.get("directions", [])
	assert(directions.size() == 8)
	assert(String(directions[0]) == "east")
	assert(String(directions[7]) == "south_east")
	assert(SpriteExporterScript.direction_yaw_degrees(0) == 225.0)
	assert(SpriteExporterScript.direction_yaw_degrees(7) == 180.0)
	assert(SpriteExporterScript.export_yaw_degrees(1, 0, 45.0) == 45.0)
	assert(SpriteExporterScript.export_yaw_degrees(8, 0, 45.0) == 225.0)
	if not _assert_export_camera_application():
		return
	if not _assert_direction_yaws_project_to_screen_facing_names():
		return

	await _test_exporter_rig_rotation()
	await _test_exporter_turn_clip_sequence()

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

	var expected_yaws: Array[float] = [225.0, 270.0, 315.0, 0.0, 45.0, 90.0, 135.0, 180.0]
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

func _assert_turn_clip_metadata_contract() -> bool:
	var metadata := ExportMetadataScript.build({
		"name": "turns",
		"export_settings": {
			"frame_count": 3,
			"direction_count": 8,
			"include_turn_clips": true
		}
	}, Vector2i(4, 4))
	if not _expect(bool(metadata.get("turn_clips_enabled", false)), "8-direction export with include_turn_clips must mark turn clips enabled."):
		return false
	if not _expect(int(metadata.get("sheet_columns", 0)) == 3, "Turn clip sheet columns must remain the frame count."):
		return false
	if not _expect(int(metadata.get("sheet_rows", 0)) == 24, "Turn clip export must add 16 rows after the 8 swim rows."):
		return false
	var rows: Array = metadata.get("animation_rows", [])
	if not _expect(rows.size() == 24, "Turn clip metadata must include one row descriptor per sheet row."):
		return false
	var first_swim: Dictionary = rows[0]
	if not _expect(int(first_swim.get("row", -1)) == 0, "First swim row must be row 0."):
		return false
	if not _expect(String(first_swim.get("clip", "")) == "swim", "First row must be the east swim clip."):
		return false
	if not _expect(String(first_swim.get("direction", "")) == "east", "First swim row must face east."):
		return false
	var first_left: Dictionary = rows[8]
	if not _expect(int(first_left.get("row", -1)) == 8, "First left turn row must follow the 8 swim rows."):
		return false
	if not _expect(String(first_left.get("clip", "")) == "turn_left", "First left turn row must be tagged turn_left."):
		return false
	if not _expect(String(first_left.get("from_direction", "")) == "east", "First left turn row must start east."):
		return false
	if not _expect(String(first_left.get("to_direction", "")) == "north_east", "First left turn row must end north_east."):
		return false
	if not _expect(String(first_left.get("turn_direction", "")) == "left", "First left turn row must record left direction."):
		return false
	if not _expect(int(first_left.get("turn_step", 0)) == 1, "Left turn row must advance by +1 direction step."):
		return false
	if not _expect(int(first_left.get("delta_degrees", 0)) == 45, "Turn row must record a 45 degree delta."):
		return false
	if not _expect(bool(first_left.get("chainable", false)), "Turn rows must be marked chainable."):
		return false
	var first_right: Dictionary = rows[16]
	if not _expect(int(first_right.get("row", -1)) == 16, "First right turn row must follow the left turn rows."):
		return false
	if not _expect(String(first_right.get("clip", "")) == "turn_right", "First right turn row must be tagged turn_right."):
		return false
	if not _expect(String(first_right.get("from_direction", "")) == "east", "First right turn row must start east."):
		return false
	if not _expect(String(first_right.get("to_direction", "")) == "south_east", "First right turn row must end south_east."):
		return false
	if not _expect(String(first_right.get("turn_direction", "")) == "right", "First right turn row must record right direction."):
		return false
	if not _expect(int(first_right.get("turn_step", 0)) == -1, "Right turn row must advance by -1 direction step."):
		return false
	if not _expect(int(first_right.get("delta_degrees", 0)) == 45, "Right turn row must record a 45 degree delta."):
		return false
	if not _expect(bool(first_right.get("chainable", false)), "Right turn rows must be marked chainable."):
		return false
	var second_right: Dictionary = rows[17]
	if not _expect(String(second_right.get("from_direction", "")) == "south_east", "Second right turn row must continue from south_east after east->south_east."):
		return false
	if not _expect(String(second_right.get("to_direction", "")) == "south", "Second right turn row must continue to south."):
		return false
	var final_right: Dictionary = rows[23]
	if not _expect(String(final_right.get("from_direction", "")) == "north_east", "Final right turn row must start north_east."):
		return false
	if not _expect(String(final_right.get("to_direction", "")) == "east", "Final right turn row must return to east."):
		return false

	var single_metadata := ExportMetadataScript.build({
		"name": "single_turn_ignored",
		"export_settings": {
			"frame_count": 3,
			"direction_count": 1,
			"include_turn_clips": true
		}
	}, Vector2i(4, 4))
	if not _expect(not bool(single_metadata.get("turn_clips_enabled", true)), "Single-direction export must ignore turn clip requests."):
		return false
	if not _expect(int(single_metadata.get("sheet_rows", 0)) == 1, "Single-direction export with turn clips requested must stay one row."):
		return false
	return true

func _test_turn_export_row_pose_without_viewport() -> bool:
	var dummy_script := GDScript.new()
	dummy_script.source_code = "extends \"res://scripts/creature/CreatureRig.gd\"\nvar pose_records := []\nfunc apply_pose(phase: float) -> void:\n\tpose_records.append({\"phase\": phase, \"yaw\": rotation_degrees.y, \"turn_amount\": float(parameters.get(\"turn_amount\", -1.0)), \"turn_direction\": float(parameters.get(\"turn_direction\", 0.0)), \"turn_phase\": float(parameters.get(\"turn_phase\", -1.0))})"
	dummy_script.reload()
	var dummy_rig := Node3D.new()
	dummy_rig.set_script(dummy_script)
	add_child(dummy_rig)
	var original_parameters := {
		"turn_amount": 0.25,
		"turn_direction": -1.0,
		"turn_phase": 0.33,
		"custom_export_restore": 7
	}
	dummy_rig.set("parameters", original_parameters.duplicate(true))
	dummy_rig.set("auto_animate", false)
	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	var rows: Array = SpriteExporterScript.animation_rows(8, true)
	var left_row: Dictionary = rows[8]
	var right_row: Dictionary = rows[16]

	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, original_parameters, left_row, 0, 3, 8)
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, original_parameters, left_row, 1, 3, 8)
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, original_parameters, left_row, 2, 3, 8)
	exporter.call("_apply_export_row_pose", dummy_rig, Vector3.ZERO, original_parameters, right_row, 2, 3, 8)

	var records: Array = dummy_rig.get("pose_records")
	if not _expect(records.size() == 4, "Turn row pose test must record four sampled poses."):
		return false
	if not _expect(_same_float(float(records[0].get("yaw", 0.0)), 225.0), "Left turn first frame must start at east yaw."):
		return false
	if not _expect(_same_float(float(records[0].get("turn_amount", -1.0)), 0.0), "Left turn first frame must start neutral."):
		return false
	if not _expect(float(records[1].get("yaw", 0.0)) > 225.0 and float(records[1].get("yaw", 0.0)) < 270.0, "Left turn middle frame must rotate toward north_east."):
		return false
	if not _expect(_same_float(float(records[1].get("turn_amount", 0.0)), 1.0), "Left turn middle frame must use full turn amount."):
		return false
	if not _expect(_same_float(float(records[1].get("turn_phase", 0.0)), 0.5), "Left turn middle frame must expose turn phase 0.5."):
		return false
	if not _expect(_same_float(float(records[2].get("yaw", 0.0)), 270.0), "Left turn final frame must end at north_east yaw."):
		return false
	if not _expect(float(records[3].get("turn_direction", 0.0)) < 0.0, "Right turn row must set negative turn_direction."):
		return false
	if not _expect(_same_float(float(records[3].get("yaw", 0.0)), 180.0), "Right turn final frame must end at south_east yaw."):
		return false

	exporter.call("_restore_rig_state", dummy_rig, true, Vector3(0.0, 99.0, 0.0), null, 0.0, Transform3D.IDENTITY, false, null, original_parameters, true)
	if not _expect(bool(dummy_rig.get("auto_animate")), "Exporter restore must restore auto_animate."):
		return false
	if not _expect(_same_float(dummy_rig.rotation_degrees.y, 99.0), "Exporter restore must restore rig rotation."):
		return false
	if not _expect(dummy_rig.get("parameters") == original_parameters, "Exporter restore must restore original parameters."):
		return false

	dummy_rig.queue_free()
	exporter.queue_free()
	return true

func _test_turn_preview_gif_row_order() -> bool:
	var rows: Array = SpriteExporterScript.animation_rows(8, true)
	var order: PackedInt32Array = SpriteExporterScript.gif_preview_row_indices(rows)
	var expected := PackedInt32Array([
		0, 1, 2, 3, 4, 5, 6, 7,
		8, 9, 10, 11, 12, 13, 14, 15,
		16, 17, 18, 19, 20, 21, 22, 23
	])
	if not _expect(order == expected, "GIF preview must follow animation row order because right-turn rows are already continuous. Got %s" % str(order)):
		return false
	return true

func _test_exporter_turn_clip_sequence() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var dummy_script := GDScript.new()
	dummy_script.source_code = "extends \"res://scripts/creature/CreatureRig.gd\"\nvar pose_records := []\nfunc apply_pose(phase: float) -> void:\n\tpose_records.append({\"phase\": phase, \"yaw\": rotation_degrees.y, \"turn_amount\": float(parameters.get(\"turn_amount\", -1.0)), \"turn_direction\": float(parameters.get(\"turn_direction\", 0.0)), \"turn_phase\": float(parameters.get(\"turn_phase\", -1.0))})"
	dummy_script.reload()

	var dummy_rig := Node3D.new()
	dummy_rig.set_script(dummy_script)
	add_child(dummy_rig)
	var original_parameters := {
		"turn_amount": 0.25,
		"turn_direction": -1.0,
		"turn_phase": 0.33,
		"custom_export_restore": 7
	}
	dummy_rig.set("parameters", original_parameters.duplicate(true))

	var exporter := SpriteExporterScript.new()
	add_child(exporter)

	var preset := {
		"name": "turn_clip_sequence",
		"export_settings": {
			"direction_count": 8,
			"frame_count": 3,
			"include_turn_clips": true,
			"render_resolution": {"w": 16, "h": 16}
		}
	}

	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	add_child(vp)

	await exporter.export_preset(preset, dummy_rig, vp)

	var records: Array = dummy_rig.get("pose_records")
	assert(records.size() >= 72, "Turn clip export must render swim + left turn + right turn rows.")
	var export_records := records.slice(records.size() - 72, records.size())
	assert(_same_float(float(export_records[0].get("yaw", 0.0)), 225.0))
	assert(float(export_records[0].get("turn_amount", -1.0)) == 0.0)
	assert(_same_float(float(export_records[24].get("yaw", 0.0)), 225.0))
	assert(float(export_records[24].get("turn_direction", 0.0)) > 0.0)
	assert(_same_float(float(export_records[25].get("turn_amount", 0.0)), 1.0))
	assert(_same_float(float(export_records[25].get("turn_phase", 0.0)), 0.5))
	assert(float(export_records[25].get("yaw", 0.0)) > 225.0 and float(export_records[25].get("yaw", 0.0)) < 270.0)
	assert(_same_float(float(export_records[26].get("yaw", 0.0)), 270.0))
	assert(float(export_records[48].get("turn_direction", 0.0)) < 0.0)
	assert(_same_float(float(export_records[50].get("yaw", 0.0)), 180.0))
	assert(dummy_rig.get("parameters") == original_parameters)

	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://exports/turn_clip_sequence/turn_clip_sequence_sheet.png"))
	assert(sheet != null)
	assert(sheet.get_size() == Vector2i(48, 384))
	assert(FileAccess.file_exists("res://exports/turn_clip_sequence/frames/turn_left/from_east_to_north_east/frame_000.png"))
	assert(FileAccess.file_exists("res://exports/turn_clip_sequence/frames/turn_right/from_east_to_south_east/frame_000.png"))

	_remove_export_tree("res://exports/turn_clip_sequence")
	dummy_rig.queue_free()
	exporter.queue_free()
	vp.queue_free()

func _write_color_png(path: String, color: Color) -> String:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(path) == OK)
	return path

func _same_rgb(left: Color, right: Color) -> bool:
	return absf(left.r - right.r) < 0.01 and absf(left.g - right.g) < 0.01 and absf(left.b - right.b) < 0.01

func _same_float(left: float, right: float) -> bool:
	return absf(left - right) < 0.001

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false

func _remove_export_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var child_path := path.path_join(file_name)
			if dir.current_is_dir():
				_remove_export_tree(child_path)
			else:
				dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

func _assert_fixed_quarter_view_export_metadata(metadata: Dictionary) -> bool:
	var preset := CameraPresetScript.get_preset("sprite_quarter_2to1")
	if SpriteExporterScript.export_camera_preset_name(8, "shark_side_quarter") != "sprite_quarter_2to1":
		push_error("8-direction exports must ignore preview camera presets and use the fixed 2:1 quarter-view camera.")
		get_tree().quit(1)
		return false
	if SpriteExporterScript.export_camera_preset_name(1, "shark_side_quarter") != "shark_side_quarter":
		push_error("Single-direction exports must keep their selected preview camera preset.")
		get_tree().quit(1)
		return false
	if String(metadata.get("camera_preset", "")) != "sprite_quarter_2to1":
		push_error("8-direction exports must record the fixed 2:1 quarter-view camera preset.")
		get_tree().quit(1)
		return false
	if absf(float(preset.get("yaw", 0.0)) - 45.0) > 0.001:
		push_error("sprite_quarter_2to1 yaw must align Godot +X/+Z with the quarter-view world projection.")
		get_tree().quit(1)
		return false
	if absf(float(preset.get("pitch", 0.0)) + 30.0) > 0.001:
		push_error("sprite_quarter_2to1 pitch must be -30 degrees for a 2:1 projected tile ratio.")
		get_tree().quit(1)
		return false
	if absf(float(metadata.get("camera_yaw", 0.0)) - 45.0) > 0.001:
		push_error("8-direction metadata must include the fixed export camera yaw.")
		get_tree().quit(1)
		return false
	if absf(float(metadata.get("camera_pitch", 0.0)) + 30.0) > 0.001:
		push_error("8-direction metadata must include the fixed export camera pitch.")
		get_tree().quit(1)
		return false
	var projection: Dictionary = metadata.get("world_projection", {})
	if absf(float(projection.get("logical_grid_cell", 0.0)) - 40.0) > 0.001:
		push_error("8-direction metadata must preserve the logical grid cell used by the quarter projection.")
		get_tree().quit(1)
		return false
	if absf(float(projection.get("projection_x_scale", 0.0)) - 0.72) > 0.001:
		push_error("8-direction metadata must preserve the quarter projection X scale.")
		get_tree().quit(1)
		return false
	if absf(float(projection.get("projection_y_scale", 0.0)) - 0.36) > 0.001:
		push_error("8-direction metadata must preserve the quarter projection Y scale.")
		get_tree().quit(1)
		return false
	if not _assert_quarter_view_world_axis_projection():
		return false
	return true

func _assert_quarter_view_world_axis_projection() -> bool:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	CameraPresetScript.apply_to_camera(camera, "sprite_quarter_2to1")
	camera.current = true
	var origin := camera.unproject_position(Vector3.ZERO)
	var plus_x := camera.unproject_position(Vector3.RIGHT)
	var plus_world_y := camera.unproject_position(Vector3.BACK)
	var x_delta := plus_x - origin
	var world_y_delta := plus_world_y - origin
	if x_delta.x <= 0.0 or x_delta.y <= 0.0:
		push_error("Quarter projection must map +worldX to screen right/down.")
		get_tree().quit(1)
		return false
	if world_y_delta.x >= 0.0 or world_y_delta.y <= 0.0:
		push_error("Quarter projection must map +worldY(+Z) to screen left/down.")
		get_tree().quit(1)
		return false
	var x_ratio := absf(x_delta.x / maxf(absf(x_delta.y), 0.0001))
	var world_y_ratio := absf(world_y_delta.x / maxf(absf(world_y_delta.y), 0.0001))
	if absf(x_ratio - 2.0) > 0.01 or absf(world_y_ratio - 2.0) > 0.01:
		push_error("Quarter projection must produce 2:1 screen-axis ratios; got %.3f and %.3f." % [x_ratio, world_y_ratio])
		get_tree().quit(1)
		return false
	vp.queue_free()
	return true

func _assert_export_camera_application() -> bool:
	var camera := Camera3D.new()
	add_child(camera)
	camera.size = 9.0
	var original_transform := camera.transform
	if SpriteExporterScript.apply_export_camera(camera, 1):
		push_error("Single-direction export camera application must leave the current camera untouched.")
		get_tree().quit(1)
		return false
	if camera.size != 9.0 or camera.transform != original_transform:
		push_error("Single-direction export camera application changed the camera.")
		get_tree().quit(1)
		return false
	if not SpriteExporterScript.apply_export_camera(camera, 8):
		push_error("8-direction exports must apply the fixed quarter-view camera before rendering.")
		get_tree().quit(1)
		return false
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		push_error("8-direction export camera must be orthographic.")
		get_tree().quit(1)
		return false
	if absf(camera.size - 2.25) > 0.001:
		push_error("8-direction export camera must start from the fixed quarter-view orthographic size before fit framing.")
		get_tree().quit(1)
		return false
	if absf(camera.position.y - 3.0) > 0.001:
		push_error("8-direction export camera pitch must place the camera at a 30-degree elevation.")
		get_tree().quit(1)
		return false
	camera.queue_free()
	return true

func _assert_direction_yaws_project_to_screen_facing_names() -> bool:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	CameraPresetScript.apply_to_camera(camera, "sprite_quarter_2to1")
	camera.current = true
	var origin := camera.unproject_position(Vector3.ZERO)
	var expected_projected_world_headings := [
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
		Vector3.FORWARD,
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		Vector3.LEFT,
		(Vector3.LEFT + Vector3.BACK).normalized(),
		Vector3.BACK,
		(Vector3.RIGHT + Vector3.BACK).normalized(),
		Vector3.RIGHT,
	]
	for i in expected_projected_world_headings.size():
		var yaw := SpriteExporterScript.direction_yaw_degrees(i)
		var world_heading := (Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.LEFT).normalized()
		var screen_heading := (camera.unproject_position(world_heading) - origin).normalized()
		var expected_screen_heading := (camera.unproject_position(expected_projected_world_headings[i]) - origin).normalized()
		if screen_heading.dot(expected_screen_heading) <= 0.99:
			push_error("Direction %s yaw %.1f projects to screen heading %s instead of %s" % [
				String(SpriteExporterScript.direction_names(8)[i]),
				yaw,
				str(screen_heading),
				str(expected_screen_heading)
			])
			get_tree().quit(1)
			vp.queue_free()
			return false
	vp.queue_free()
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
