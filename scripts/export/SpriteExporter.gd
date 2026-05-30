extends Node

signal export_finished(output_dir: String)
signal export_failed(message: String)

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const SpriteSheetBuilderScript := preload("res://scripts/export/SpriteSheetBuilder.gd")
const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")

func export_preset(preset: Dictionary, rig: CreatureRig, viewport: SubViewport) -> void:
	var preset_name := String(preset.get("name", "unnamed"))
	var export_settings: Dictionary = preset.get("export_settings", {})
	var resolution_dict: Dictionary = export_settings.get("render_resolution", {"w": 256, "h": 256})
	var resolution := Vector2i(int(resolution_dict.get("w", 256)), int(resolution_dict.get("h", 256)))
	var frame_count := int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT))
	var output_dir := "res://exports/%s" % preset_name
	var frames_dir := "%s/frames" % output_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
	viewport.size = resolution
	rig.auto_animate = false

	var frame_paths := PackedStringArray()
	for i in frame_count:
		var phase := float(i) / float(frame_count)
		rig.apply_pose(phase)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var frame_path := "%s/frame_%03d.png" % [frames_dir, i]
		var err := image.save_png(frame_path)
		if err != OK:
			export_failed.emit("Failed to save %s: %s" % [frame_path, error_string(err)])
			rig.auto_animate = true
			return
		frame_paths.append(frame_path)

	var sheet_path := "%s/%s_sheet.png" % [output_dir, preset_name]
	var sheet_err := SpriteSheetBuilderScript.build_sheet(frame_paths, sheet_path)
	if sheet_err != OK:
		export_failed.emit("Failed to build sheet: %s" % error_string(sheet_err))
		rig.auto_animate = true
		return

	var metadata := ExportMetadataScript.build(preset, resolution)
	var metadata_file := FileAccess.open("%s/%s_metadata.json" % [output_dir, preset_name], FileAccess.WRITE)
	if metadata_file == null:
		export_failed.emit("Failed to write metadata JSON.")
		rig.auto_animate = true
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()
	rig.auto_animate = true
	export_finished.emit(ProjectSettings.globalize_path(output_dir))
