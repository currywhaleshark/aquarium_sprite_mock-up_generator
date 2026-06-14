extends Node

# Dev-only sprite export runner. Renders a named preset through SpriteExporter
# exactly like the in-app export button. Run non-headless because SubViewport
# rendering needs the GPU path:
#   godot --path . scenes/PresetExportShot.tscn -- preset=아로와나_레드
#
# Quick preview while tuning a preset (renders into exports/<name>_preview so the
# real export is not clobbered; an 8-direction preset keeps its quarter camera so
# the preview matches the full export's east row):
#   godot --path . scenes/PresetExportShot.tscn -- preset=아로와나_레드 frames=1 directions=1

const CreatureRigFactoryScript := preload("res://scripts/creature/CreatureRigFactory.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

const DEFAULT_PRESET_NAME := "아로와나_레드"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PRESET_EXPORT_SHOT_NEEDS_GPU")
		get_tree().quit(1)
		return

	var preset_name := DEFAULT_PRESET_NAME
	var preview_frames := 0
	var preview_directions := 0
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("preset="):
			preset_name = text.trim_prefix("preset=")
		elif text.begins_with("frames="):
			preview_frames = maxi(int(text.trim_prefix("frames=")), 1)
		elif text.begins_with("directions="):
			preview_directions = maxi(int(text.trim_prefix("directions=")), 1)

	var preset := _find_preset(PresetStoreScript.load_all(), preset_name)
	if preset.is_empty():
		push_error("PRESET_EXPORT_SHOT_PRESET_NOT_FOUND %s" % preset_name)
		get_tree().quit(1)
		return

	var original_direction_count := int((preset.get("export_settings", {}) as Dictionary).get("direction_count", 1))
	if preview_frames > 0 or preview_directions > 0:
		preset = preset.duplicate(true)
		var export_settings: Dictionary = preset.get("export_settings", {})
		if preview_frames > 0:
			export_settings["frame_count"] = preview_frames
		if preview_directions > 0:
			export_settings["direction_count"] = preview_directions
		preset["export_settings"] = export_settings
		preset["name"] = "%s_preview" % String(preset.get("name", preset_name))

	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	add_child(viewport)

	var world_root := Node3D.new()
	viewport.add_child(world_root)

	# Same lighting as Main._build_preview_world so the export matches the app.
	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 2.1
	key_light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	world_root.add_child(key_light)

	var fill := OmniLight3D.new()
	fill.light_energy = 0.45
	fill.position = Vector3(-1.2, 1.1, 2.0)
	world_root.add_child(fill)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	CameraPresetScript.apply_to_camera(camera, SpriteExporterScript.export_camera_preset_name(original_direction_count, String(preset.get("camera_preset", "aquarium_side_quarter"))))

	var rig: CreatureRig = CreatureRigFactoryScript.create(String(preset.get("creature_type", "fish")))
	world_root.add_child(rig)
	rig.set_parameters(preset.get("parameters", {}))

	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(func(path: String) -> void:
		print("PRESET_EXPORT_SHOT_OK %s" % path)
		get_tree().quit(0)
	)
	exporter.export_failed.connect(func(message: String) -> void:
		push_error("PRESET_EXPORT_SHOT_FAIL %s" % message)
		get_tree().quit(1)
	)
	await get_tree().process_frame
	await exporter.export_preset(preset, rig, viewport)

func _find_preset(presets: Array[Dictionary], preset_name: String) -> Dictionary:
	for preset in presets:
		if String(preset.get("name", "")) == preset_name:
			return preset
	return {}
