extends Node

# Dev-only: renders the basic_shark head/body-shell NECK junction at several angles so
# the dorsal collar step and the flank crease at the seam are clearly visible. Uses the
# real SharkRig (shark head mesh + body shell), unlike NeonSeamShot which is FishRig-only.
# Run NON-headless (needs GPU):
#   Godot_..._console.exe --path . scenes/SharkNeckSeamShot.tscn -- tag=before
#   Godot_..._console.exe --path . scenes/SharkNeckSeamShot.tscn -- tag=unified unified=1

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("SHARK_NECK_SEAM_SHOT_NEEDS_GPU")
		get_tree().quit(1)
		return

	var tag := "before"
	var preset_name := ""
	var use_unified_surface := false
	var overrides := {}
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("tag="):
			tag = text.trim_prefix("tag=")
		elif text.begins_with("preset="):
			preset_name = text.trim_prefix("preset=")
		elif text.begins_with("unified="):
			use_unified_surface = text.trim_prefix("unified=") in ["1", "true", "yes"]
		elif text.begins_with("set="):
			# set=key:value (value parsed as float) - lets us reproduce head-editor tweaks
			var kv := text.trim_prefix("set=").split(":")
			if kv.size() == 2:
				overrides[kv[0]] = float(kv[1])

	var preset := {}
	if preset_name.is_empty():
		preset = PresetStoreScript.load_preset("res://presets/basic_shark.json")
	else:
		for candidate in PresetStoreScript.load_all():
			if String(candidate.get("name", "")) == preset_name:
				preset = candidate
				break
	if preset.is_empty():
		push_error("SHARK_NECK_SEAM_PRESET_NOT_FOUND %s" % preset_name)
		get_tree().quit(1)
		return
	var parameters: Dictionary = preset.get("parameters", {}).duplicate(true)
	if use_unified_surface:
		parameters["unified_surface_enabled"] = 1.0
	for key in overrides:
		parameters[key] = overrides[key]
	print("SHARK_NECK_SEAM_SHOT_OVERRIDES ", overrides)

	var vp := SubViewport.new()
	vp.size = Vector2i(900, 720)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.13, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.85)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)

	var key_light := DirectionalLight3D.new()
	key_light.light_energy = 2.1
	key_light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	vp.add_child(key_light)
	var fill := OmniLight3D.new()
	fill.light_energy = 0.45
	fill.position = Vector3(-1.2, 1.1, 2.0)
	vp.add_child(fill)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	vp.add_child(cam)

	var shark: Node3D = SharkRigScript.new()
	shark.set("auto_animate", false)
	vp.add_child(shark)
	shark.set_parameters(parameters)
	await get_tree().process_frame

	# Head sits around head_offset (-0.8); the head rear / neck is near world x ~= -0.55.
	# Frame the neck so the dorsal step and the flank seam fill the view.
	var variants := [
		{"name": "side", "size": 1.1, "cx": -0.45, "cy": 0.02, "ry": 0.0, "rx": 0.0},
		{"name": "neck", "size": 0.6, "cx": -0.52, "cy": 0.06, "ry": 0.0, "rx": 0.0},
		{"name": "q34_zoom", "size": 0.65, "cx": -0.5, "cy": 0.06, "ry": 34.0, "rx": 6.0},
		{"name": "top", "size": 0.9, "cx": -0.45, "cy": 0.0, "ry": 0.0, "rx": 62.0},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots/shark_neck"))
	for variant in variants:
		cam.size = float(variant["size"])
		cam.position = Vector3(float(variant["cx"]), float(variant.get("cy", 0.0)), 5.0)
		shark.rotation_degrees = Vector3(float(variant.get("rx", 0.0)), float(variant.get("ry", 0.0)), 0.0)
		await get_tree().process_frame
		if shark.has_method("apply_pose"):
			shark.call("apply_pose", 0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var path := "res://exports/_shots/shark_neck/%s_%s.png" % [String(variant["name"]), tag]
		var err := img.save_png(path)
		if err != OK:
			push_error("failed to save %s: %s" % [path, err])
			get_tree().quit(1)
			return
		print("SHARK_NECK_SEAM_SHOT_SAVED ", path)
	get_tree().quit(0)
