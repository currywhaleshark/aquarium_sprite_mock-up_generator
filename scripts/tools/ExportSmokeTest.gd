extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SpriteExporterScript := preload("res://scripts/export/SpriteExporter.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const CameraPresetScript := preload("res://scripts/render/CameraPreset.gd")

func _ready() -> void:
	var presets: Array[Dictionary] = PresetStoreScript.load_all()
	var preset := _find_preset(presets, "basic_fish")
	if preset.is_empty():
		push_error("Smoke test preset not found.")
		get_tree().quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	add_child(viewport)

	var world_root := Node3D.new()
	viewport.add_child(world_root)

	var light := DirectionalLight3D.new()
	light.light_energy = 2.0
	light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	world_root.add_child(light)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	CameraPresetScript.apply_to_camera(camera, String(preset.get("camera_preset", "aquarium_side_quarter")))

	var rig: Node3D
	if String(preset.get("creature_type", "fish")) == "ray":
		rig = RayRigScript.new()
	else:
		rig = FishRigScript.new()
	world_root.add_child(rig)
	rig.call("set_parameters", preset.get("parameters", {}))

	var exporter := SpriteExporterScript.new()
	add_child(exporter)
	exporter.export_finished.connect(func(path: String) -> void:
		print("SMOKE_EXPORT_OK %s" % path)
		get_tree().quit(0)
	)
	exporter.export_failed.connect(func(message: String) -> void:
		push_error("SMOKE_EXPORT_FAIL %s" % message)
		get_tree().quit(1)
	)
	await get_tree().process_frame
	exporter.export_preset(preset, rig, viewport)

func _find_preset(presets: Array[Dictionary], preset_name: String) -> Dictionary:
	for preset in presets:
		if String(preset.get("name", "")) == preset_name:
			return preset
	return {}
