extends Node

# Dev-only: renders the default fish at full side view with scales turned on so we can
# see the imbricated scale pattern. Run NON-headless (needs a GPU). Not a *Test scene.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 420)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.13, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0.0, 0.0, 5.0)
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)

	var variants := [
		{"name": "scales_on", "params": {"scale_strength": 1.0, "scale_size": 16.0}, "cam": 2.0},
		{"name": "scales_fine", "params": {"scale_strength": 1.0, "scale_size": 34.0}, "cam": 2.0},
		{"name": "scales_zoom", "params": {"scale_strength": 1.0, "scale_size": 16.0}, "cam": 0.8, "cx": -0.1},
		{"name": "scales_off", "params": {"scale_strength": 0.0}, "cam": 2.0},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots"))
	for variant in variants:
		var params := {"base_color": "#46c6cf", "belly_color": "#c8f4ec", "secondary_color": "#d6fbff", "shell_enabled": 1.0}
		for k in variant["params"].keys():
			params[k] = variant["params"][k]
		fish.set_parameters(params)
		cam.size = float(variant.get("cam", 2.0))
		cam.position = Vector3(float(variant.get("cx", 0.0)), 0.0, 5.0)
		await get_tree().process_frame
		fish.apply_pose(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("res://exports/_shots/%s.png" % String(variant["name"]))
		print("SCALE_SHOT_SAVED ", variant["name"])
	get_tree().quit(0)
