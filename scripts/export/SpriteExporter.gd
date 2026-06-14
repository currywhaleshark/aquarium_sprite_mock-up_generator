extends Node

signal export_finished(output_dir: String)
signal export_failed(message: String)
signal export_progress(value: float, message: String)

const RenderSettingsScript := preload("res://scripts/render/RenderSettings.gd")
const SpriteSheetBuilderScript := preload("res://scripts/export/SpriteSheetBuilder.gd")
const ExportMetadataScript := preload("res://scripts/export/ExportMetadata.gd")
const ExportDirectionsScript := preload("res://scripts/export/ExportDirections.gd")
const GifEncoderScript := preload("res://scripts/export/GifEncoder.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

static func normalized_direction_count(value: int) -> int:
	return ExportDirectionsScript.normalized_direction_count(value)

static func direction_names(direction_count: int) -> Array[String]:
	return ExportDirectionsScript.direction_names(direction_count)

static func direction_yaw_degrees(direction_index: int) -> float:
	return ExportDirectionsScript.direction_yaw_degrees(direction_index)

static func export_yaw_degrees(direction_count: int, direction_index: int, original_yaw: float) -> float:
	return ExportDirectionsScript.export_yaw_degrees(direction_count, direction_index, original_yaw)

static func uses_fixed_quarter_view_camera(direction_count: int) -> bool:
	return normalized_direction_count(direction_count) == 8

static func export_camera_preset_name(direction_count: int, fallback_name: String = "aquarium_side_quarter") -> String:
	return CameraPresetScript.SPRITE_QUARTER_2TO1 if uses_fixed_quarter_view_camera(direction_count) else fallback_name

static func apply_export_camera(camera: Camera3D, direction_count: int) -> bool:
	if camera == null or not uses_fixed_quarter_view_camera(direction_count):
		return false
	CameraPresetScript.apply_to_camera(camera, CameraPresetScript.SPRITE_QUARTER_2TO1)
	return true

func export_preset(preset: Dictionary, rig: CreatureRig, viewport: SubViewport) -> void:
	var preset_name := String(preset.get("name", "unnamed"))
	var export_settings: Dictionary = preset.get("export_settings", {})
	var resolution_dict: Dictionary = export_settings.get("render_resolution", {"w": 256, "h": 256})
	var resolution := Vector2i(int(resolution_dict.get("w", 256)), int(resolution_dict.get("h", 256)))
	var frame_count := int(export_settings.get("frame_count", RenderSettingsScript.DEFAULT_FRAME_COUNT))
	var direction_count := normalized_direction_count(int(export_settings.get("direction_count", 1)))
	var directions := direction_names(direction_count)
	var output_dir := "res://exports/%s" % preset_name
	var frames_dir := "%s/frames" % output_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
	# A SubViewportContainer with stretch enabled re-imposes its own size on the
	# viewport every frame, silently overriding render_resolution (the app's preview
	# viewport lives in one, so in-app exports came out at window size). Suspend
	# stretch for the duration of the export; restored with the rest of the state.
	var stretch_container := viewport.get_parent() as SubViewportContainer
	var suspended_stretch := stretch_container != null and stretch_container.stretch
	if suspended_stretch:
		stretch_container.stretch = false
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
		cam_adjusted = apply_export_camera(camera, direction_count)
		# Roll-free cameras get the tighter pitch-aware fit; anything rolled falls
		# back to the angle-independent sphere.
		var pitch_for_fit := camera.rotation_degrees.x if absf(camera.rotation_degrees.z) < 0.01 else NAN
		var framing := compute_fit_framing(rig, resolution, pitch_for_fit)
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
				_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted, stretch_container if suspended_stretch else null)
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
		_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted, stretch_container if suspended_stretch else null)
		export_failed.emit("Failed to build sheet: %s" % error_string(sheet_err))
		return

	var metadata := ExportMetadataScript.build(preset, resolution)
	var metadata_file := FileAccess.open("%s/%s_metadata.json" % [output_dir, preset_name], FileAccess.WRITE)
	if metadata_file == null:
		_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted, stretch_container if suspended_stretch else null)
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
	_restore_rig_state(rig, original_auto_animate, original_rotation, camera, original_cam_size, original_cam_transform, cam_adjusted, stretch_container if suspended_stretch else null)
	export_finished.emit(ProjectSettings.globalize_path(output_dir))

func _restore_rig_state(rig: CreatureRig, auto_animate: bool, rotation_degrees: Vector3, camera: Camera3D = null, cam_size: float = 0.0, cam_transform: Transform3D = Transform3D.IDENTITY, cam_adjusted: bool = false, stretch_container: SubViewportContainer = null) -> void:
	rig.rotation_degrees = rotation_degrees
	rig.auto_animate = auto_animate
	if cam_adjusted and camera != null:
		camera.size = cam_size
		camera.transform = cam_transform
	if stretch_container != null:
		stretch_container.stretch = true

# Orthographic framing that contains the whole creature with padding, shared by the
# exporter and the editor's "export framing" preview so both match exactly. Returns
# the orthographic size, the vertical centre to aim at, and the bounding radius.
#
# When camera_pitch_degrees is given (a roll-free camera at a known pitch), the
# vertical fit projects the measured extents through that pitch instead of using
# the bounding sphere, which wasted a third of the frame on tall-ish bodies. NAN
# keeps the angle-independent sphere fit (the editor preview orbits freely).
static func compute_fit_framing(rig: CreatureRig, resolution: Vector2i, camera_pitch_degrees: float = NAN) -> Dictionary:
	var metrics := _compute_fit_metrics(rig)
	var radius: float = sqrt(metrics.r_h * metrics.r_h + metrics.r_v * metrics.r_v)
	var aspect := float(resolution.x) / float(maxi(resolution.y, 1))
	var half_w: float = metrics.r_h
	var half_h: float
	if is_nan(camera_pitch_degrees):
		half_w = radius
		half_h = radius
	else:
		var pitch := absf(deg_to_rad(camera_pitch_degrees))
		half_h = metrics.r_h * sin(pitch) + metrics.r_v * cos(pitch)
	var ortho_size := 2.0 * 1.08 * maxf(half_h, half_w / maxf(aspect, 0.0001))
	return {"ortho_size": maxf(ortho_size, 0.01), "center_y": metrics.cy, "radius": radius}

# Measures the creature's extent in the rig's local frame and returns the radius
# from the rotation (Y) axis (r_h), the vertical half-height (r_v) and vertical
# centre (cy). Several swim phases are sampled so animation never clips. Local space
# keeps the result invariant to the per-direction Y rotation applied during export.
# Real mesh vertices are measured (not AABB corners, whose diagonals overshoot the
# radius on elongated bodies and inflated every frame's margins).
static func _compute_fit_metrics(rig: CreatureRig) -> Dictionary:
	var inv := rig.global_transform.affine_inverse()
	var meshes: Array[MeshInstance3D] = []
	_gather_mesh_instances(rig, meshes)
	var r_h := 0.0
	var y_min := INF
	var y_max := -INF
	var found := false
	for phase in [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]:
		rig.apply_pose(float(phase))
		for mi in meshes:
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var xf := inv * mi.global_transform
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				if arrays.is_empty():
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in vertices:
					var p := xf * v
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
