extends Node

signal export_finished(output_dir: String)
signal export_failed(message: String)
signal export_progress(value: float, message: String)

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const SpriteSheetBuilderScript := preload("res://scripts/export/SpriteSheetBuilder.gd")
const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const ExportDirectionsScript := preload("res://scripts/export/ExportDirections.gd")
const GifEncoderScript := preload("res://scripts/export/GifEncoder.gd")

static func normalized_direction_count(value: int) -> int:
	return ExportDirectionsScript.normalized_direction_count(value)

static func direction_names(direction_count: int) -> Array[String]:
	return ExportDirectionsScript.direction_names(direction_count)

static func direction_yaw_degrees(direction_index: int) -> float:
	return ExportDirectionsScript.direction_yaw_degrees(direction_index)

static func export_yaw_degrees(direction_count: int, direction_index: int, original_yaw: float) -> float:
	return ExportDirectionsScript.export_yaw_degrees(direction_count, direction_index, original_yaw)

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

	# Fit the camera so the whole creature stays in frame for every direction and
	# pose (long bodies were being cropped). Bounds are measured in the rig's local
	# frame (so they are invariant to the per-direction Y rotation), turned into a
	# bounding sphere around the rotation axis, and the orthographic size is set to
	# contain it with padding. The camera is restored when the export finishes.
	var camera := viewport.get_camera_3d()
	var cam_adjusted := false
	var original_cam_size := 0.0
	var original_cam_transform := Transform3D.IDENTITY
	if camera != null:
		original_cam_size = camera.size
		original_cam_transform = camera.transform
		var framing := compute_fit_framing(rig, resolution)
		if float(framing.radius) > 0.0001:
			camera.size = float(framing.ortho_size)
			camera.global_position += Vector3(0.0, float(framing.center_y), 0.0)
			cam_adjusted = true

	var frame_rows := []
	var gif_images := []
	var total_frames := maxi(directions.size() * frame_count, 1)
	var frames_done := 0
	for direction_index in directions.size():
		var direction_name := String(directions[direction_index])
		var direction_dir := frames_dir if directions.size() == 1 else "%s/%s" % [frames_dir, direction_name]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(direction_dir))
		var target_rotation := original_rotation
		target_rotation.y = export_yaw_degrees(directions.size(), direction_index, original_rotation.y)
		rig.rotation_degrees = target_rotation
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
				_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted)
				export_failed.emit("Failed to save %s: %s" % [frame_path, error_string(err)])
				return
			frame_paths.append(frame_path)
			# Keep every direction's frames, in render order, for the preview GIF.
			# For an 8-direction export this yields a single GIF that steps through
			# all directions in sequence (each holding its swim animation before the
			# fish turns to the next), then loops.
			gif_images.append(image)
			frames_done += 1
			export_progress.emit(float(frames_done) / float(total_frames) * 0.9, "프레임 렌더링 %d/%d" % [frames_done, total_frames])
		frame_rows.append(frame_paths)

	var sheet_path := "%s/%s_sheet.png" % [output_dir, preset_name]
	var sheet_err := SpriteSheetBuilderScript.build_sheet_grid(frame_rows, sheet_path)
	if sheet_err != OK:
		_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted)
		export_failed.emit("Failed to build sheet: %s" % error_string(sheet_err))
		return

	var metadata := ExportMetadataScript.build(preset, resolution)
	var metadata_file := FileAccess.open("%s/%s_metadata.json" % [output_dir, preset_name], FileAccess.WRITE)
	if metadata_file == null:
		_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted)
		export_failed.emit("Failed to write metadata JSON.")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()

	# Animated preview GIF alongside the PNG frames. Single-direction exports give a
	# one-direction loop; 8-direction exports give a turntable cycling all directions.
	var frame_rate := maxf(float(export_settings.get("frame_rate", 12)), 1.0)
	var delay_centiseconds := int(round(100.0 / frame_rate))
	var gif_path := "%s/%s.gif" % [output_dir, preset_name]
	export_progress.emit(0.92, "GIF 생성 중...")
	# Encode the GIF on a worker thread so the LZW pass does not freeze the editor;
	# the main loop keeps ticking (UI/progress responsive) until the thread finishes.
	var gif_thread := Thread.new()
	gif_thread.start(func() -> int:
		return GifEncoderScript.encode_to_file(gif_images, delay_centiseconds, gif_path)
	)
	while gif_thread.is_alive():
		await get_tree().process_frame
	var gif_err := int(gif_thread.wait_to_finish())
	if gif_err != OK:
		push_warning("Sprite GIF export failed (%s): %s" % [gif_path, error_string(gif_err)])

	export_progress.emit(1.0, "완료")
	_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted)
	export_finished.emit(ProjectSettings.globalize_path(output_dir))

func _restore_rig_state(rig: CreatureRig, auto_animate: bool, rotation_degrees: Vector3, camera: Camera3D = null, cam_size: float = 0.0, cam_transform: Transform3D = Transform3D.IDENTITY, cam_adjusted: bool = false) -> void:
	rig.rotation_degrees = rotation_degrees
	rig.auto_animate = auto_animate
	if cam_adjusted and camera != null:
		camera.size = cam_size
		camera.transform = cam_transform

# Orthographic framing that contains the whole creature with padding, shared by the
# exporter and the editor's "export framing" preview so both match exactly. Returns
# the orthographic size, the vertical centre to aim at, and the bounding radius.
static func compute_fit_framing(rig: CreatureRig, resolution: Vector2i) -> Dictionary:
	var metrics := _compute_fit_metrics(rig)
	var radius: float = sqrt(metrics.r_h * metrics.r_h + metrics.r_v * metrics.r_v)
	var aspect := float(resolution.x) / float(maxi(resolution.y, 1))
	var ortho_size := 2.0 * radius * 1.08 * maxf(1.0, 1.0 / maxf(aspect, 0.0001))
	return {"ortho_size": maxf(ortho_size, 0.01), "center_y": metrics.cy, "radius": radius}

# Measures the creature's extent in the rig's local frame and returns the radius
# from the rotation (Y) axis (r_h), the vertical half-height (r_v) and vertical
# centre (cy). Several swim phases are sampled so animation never clips. Local space
# keeps the result invariant to the per-direction Y rotation applied during export.
static func _compute_fit_metrics(rig: CreatureRig) -> Dictionary:
	var inv := rig.global_transform.affine_inverse()
	var meshes: Array[MeshInstance3D] = []
	_gather_mesh_instances(rig, meshes)
	var r_h := 0.0
	var y_min := INF
	var y_max := -INF
	var found := false
	for phase in [0.0, 0.25, 0.5, 0.75]:
		rig.apply_pose(float(phase))
		for mi in meshes:
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var aabb := mi.mesh.get_aabb()
			if aabb.size == Vector3.ZERO:
				continue
			var xf := inv * mi.global_transform
			for c in 8:
				var p := xf * aabb.get_endpoint(c)
				r_h = maxf(r_h, sqrt(p.x * p.x + p.z * p.z))
				y_min = minf(y_min, p.y)
				y_max = maxf(y_max, p.y)
				found = true
	if not found:
		return {"r_h": 0.0, "r_v": 0.0, "cy": 0.0}
	return {"r_h": r_h, "r_v": (y_max - y_min) * 0.5, "cy": (y_min + y_max) * 0.5}

static func _gather_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		_gather_mesh_instances(child, out)
