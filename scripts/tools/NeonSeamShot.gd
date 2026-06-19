extends Node

# Dev-only: loads the user "네온테트라" preset and renders the head/body-shell
# junction at several angles so the neck seam (step / awkward joint) is visible.
# Run NON-headless (needs GPU):
#   Godot_..._console.exe --path . scenes/NeonSeamShot.tscn -- preset=네온테트라 tag=before
#   Godot_..._console.exe --path . scenes/NeonSeamShot.tscn -- preset=네온테트라 tag=unified unified=1
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

func _ready() -> void:
	var preset_name := "네온테트라"
	var tag := "before"
	var use_unified_surface := false
	for arg in OS.get_cmdline_user_args():
		var text := String(arg)
		if text.begins_with("preset="):
			preset_name = text.trim_prefix("preset=")
		elif text.begins_with("tag="):
			tag = text.trim_prefix("tag=")
		elif text.begins_with("unified="):
			use_unified_surface = text.trim_prefix("unified=") in ["1", "true", "yes"]

	var preset := {}
	for candidate in PresetStoreScript.load_all():
		if String(candidate.get("name", "")) == preset_name:
			preset = candidate
			break
	if preset.is_empty():
		push_error("NEON_SEAM_PRESET_NOT_FOUND %s" % preset_name)
		get_tree().quit(1)
		return

	var vp := SubViewport.new()
	vp.size = Vector2i(900, 600)
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

	# Same key/fill as Main preview world so shading matches the app.
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
	cam.size = 2.0
	cam.position = Vector3(0.0, 0.0, 5.0)
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)
	var parameters: Dictionary = preset.get("parameters", {}).duplicate(true)
	if use_unified_surface:
		parameters["unified_surface_enabled"] = 1.0
	fish.set_parameters(parameters)
	await get_tree().process_frame

	# Head sits around head_offset (-0.66 for neon). Frame the neck region.
	var variants := [
		{"name": "side", "size": 1.7, "cx": -0.35, "cy": 0.0, "ry": 0.0},
		{"name": "neck", "size": 0.85, "cx": -0.55, "cy": 0.05, "ry": 0.0},
		{"name": "q34", "size": 1.0, "cx": -0.5, "cy": 0.05, "ry": 32.0},
		{"name": "q34_zoom", "size": 0.6, "cx": -0.55, "cy": 0.05, "ry": 32.0},
		{"name": "top", "size": 1.2, "cx": -0.45, "cy": 0.0, "ry": 0.0, "rx": 55.0},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots"))
	for variant in variants:
		cam.size = float(variant["size"])
		cam.position = Vector3(float(variant["cx"]), float(variant.get("cy", 0.0)), 5.0)
		fish.rotation_degrees = Vector3(float(variant.get("rx", 0.0)), float(variant.get("ry", 0.0)), 0.0)
		await get_tree().process_frame
		fish.apply_pose(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var path := "res://exports/_shots/neon_%s_%s.png" % [String(variant["name"]), tag]
		img.save_png(path)
		print("NEON_SEAM_SHOT_SAVED ", path)
	get_tree().quit(0)
