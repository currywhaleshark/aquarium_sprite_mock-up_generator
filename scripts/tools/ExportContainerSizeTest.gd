extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

# Regression: a SubViewportContainer with stretch enabled re-imposes its size on the
# viewport every frame, so render_resolution was silently overridden and in-app
# exports came out at the preview panel's pixel size instead of 256x256. The
# exporter must suspend container stretch while rendering and restore it after.
# Needs the GPU path (skips headless, like ExportSmokeTest).
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("EXPORT_CONTAINER_SIZE_TEST_SKIPPED_HEADLESS")
		get_tree().quit(0)
		return

	var preset := PresetStoreScript.find_default_for_mode("fish")
	if preset.is_empty():
		push_error("Default fish preset not found.")
		get_tree().quit(1)
		return
	preset = preset.duplicate(true)
	preset["name"] = "container_size_test"
	preset["export_settings"] = {
		"frame_count": 2,
		"direction_count": 1,
		"frame_rate": 12,
		"render_resolution": {"w": 256, "h": 256}
	}

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(900, 700)
	add_child(container)

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	container.add_child(viewport)

	var light := DirectionalLight3D.new()
	light.light_energy = 2.0
	light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	viewport.add_child(light)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	CameraPresetScript.apply_to_camera(camera, String(preset.get("camera_preset", "aquarium_side_quarter")))

	var rig: CreatureRig = FishRigScript.new()
	viewport.add_child(rig)
	rig.set_parameters(preset.get("parameters", {}))

	# Let the container impose its size once so the export starts from the bad state.
	await get_tree().process_frame
	if viewport.size != Vector2i(900, 700):
		push_error("Test setup failed: container did not impose its size (viewport %s)." % viewport.size)
		get_tree().quit(1)
		return

	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(func(_path: String) -> void:
		var frame := Image.load_from_file(ProjectSettings.globalize_path("res://exports/container_size_test/frames/frame_000.png"))
		if frame == null:
			push_error("Exported frame missing.")
			get_tree().quit(1)
			return
		if frame.get_size() != Vector2i(256, 256):
			push_error("Exported frame is %s, expected 256x256 (render_resolution ignored)." % frame.get_size())
			get_tree().quit(1)
			return
		if not container.stretch:
			push_error("Container stretch was not restored after the export.")
			get_tree().quit(1)
			return
		print("EXPORT_CONTAINER_SIZE_TEST_OK")
		get_tree().quit(0)
	)
	exporter.export_failed.connect(func(message: String) -> void:
		push_error("Export failed: %s" % message)
		get_tree().quit(1)
	)
	await exporter.export_preset(preset, rig, viewport)
