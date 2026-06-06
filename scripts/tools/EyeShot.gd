extends Node

# Dev-only: renders the default fish zoomed on the eye from the side so we can see the
# new iris / pupil / catchlight stack. Run NON-headless (needs a GPU). Not a *Test scene.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(420, 420)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.10, 0.13, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.3
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)

	var variants := [
		{"name": "default", "params": {}},
		{"name": "large", "params": {"eye_style": "large", "eye_size": 0.08}},
		{"name": "silver_iris", "params": {"eye_iris_color": "#cfe3ee", "eye_pupil_scale": 0.5}},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots"))
	for variant in variants:
		var params := {"base_color": "#46c6cf", "secondary_color": "#d6fbff", "shell_enabled": 1.0}
		for k in variant["params"].keys():
			params[k] = variant["params"][k]
		fish.set_parameters(params)
		await get_tree().process_frame
		fish.apply_pose(0.0)
		await get_tree().process_frame
		var eye := fish.get_node_or_null("BodyPivot/EyeR") as Node3D
		var target: Vector3 = eye.global_position if eye else Vector3.ZERO
		cam.position = target + Vector3(0.0, 0.0, 5.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("res://exports/_shots/eye_%s.png" % String(variant["name"]))
		print("EYE_SHOT_SAVED ", variant["name"])
	get_tree().quit(0)
