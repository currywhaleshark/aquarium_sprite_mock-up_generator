extends Node

signal export_finished(output_dir: String)
signal export_failed(message: String)

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const SpriteSheetBuilderScript := preload("res://scripts/export/SpriteSheetBuilder.gd")
const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const ExportDirectionsScript := preload("res://scripts/export/ExportDirections.gd")

static func normalized_direction_count(value: int) -> int:
	return ExportDirectionsScript.normalized_direction_count(value)

static func direction_names(direction_count: int) -> Array[String]:
	return ExportDirectionsScript.direction_names(direction_count)

static func direction_yaw_degrees(direction_index: int) -> float:
	return ExportDirectionsScript.direction_yaw_degrees(direction_index)

func export_preset(preset: Dictionary, rig: CreatureRig, viewport: SubViewport) -> void:
	var preset_name := String(preset.get("name", "unnamed"))
	var export_settings: Dictionary = preset.get("export_settings", {})
	var resolution_dict: Dictionary = export_settings.get("render_resolution", {"w": 256, "h": 256})
	var resolution := Vector2i(int(resolution_dict.get("w", 256)), int(resolution_dict.get("h", 256)))
	var frame_count := int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT))
	var directions := direction_names(normalized_direction_count(int(export_settings.get("direction_count", 1))))
	var output_dir := "res://exports/%s" % preset_name
	var frames_dir := "%s/frames" % output_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
	viewport.size = resolution
	var original_auto_animate := rig.auto_animate
	var original_rotation := rig.rotation_degrees
	rig.auto_animate = false

	var frame_rows := []
	for direction_index in directions.size():
		var direction_name := String(directions[direction_index])
		var direction_dir := frames_dir if directions.size() == 1 else "%s/%s" % [frames_dir, direction_name]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(direction_dir))
		rig.rotation_degrees = original_rotation + Vector3(0.0, direction_yaw_degrees(direction_index), 0.0)
		var frame_paths := PackedStringArray()
		for i in frame_count:
			var phase := float(i) / float(frame_count)
			rig.apply_pose(phase)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			var frame_path := "%s/frame_%03d.png" % [direction_dir, i]
			var err := image.save_png(frame_path)
			if err != OK:
				_restore_rig_state(rig, original_auto_animate, original_rotation)
				export_failed.emit("Failed to save %s: %s" % [frame_path, error_string(err)])
				return
			frame_paths.append(frame_path)
		frame_rows.append(frame_paths)

	var sheet_path := "%s/%s_sheet.png" % [output_dir, preset_name]
	var sheet_err := SpriteSheetBuilderScript.build_sheet_grid(frame_rows, sheet_path)
	if sheet_err != OK:
		_restore_rig_state(rig, original_auto_animate, original_rotation)
		export_failed.emit("Failed to build sheet: %s" % error_string(sheet_err))
		return

	var metadata := ExportMetadataScript.build(preset, resolution)
	var metadata_file := FileAccess.open("%s/%s_metadata.json" % [output_dir, preset_name], FileAccess.WRITE)
	if metadata_file == null:
		_restore_rig_state(rig, original_auto_animate, original_rotation)
		export_failed.emit("Failed to write metadata JSON.")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	_restore_rig_state(rig, original_auto_animate, original_rotation)
	export_finished.emit(ProjectSettings.globalize_path(output_dir))

func _restore_rig_state(rig: CreatureRig, auto_animate: bool, rotation_degrees: Vector3) -> void:
	rig.rotation_degrees = rotation_degrees
	rig.auto_animate = auto_animate
