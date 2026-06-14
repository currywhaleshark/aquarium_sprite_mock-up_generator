extends Node

# Dev-only: renders the default fish with the mouth wide open, zoomed on the head, from a
# couple of angles, and saves PNGs so we can actually see the mouth instead of guessing.
# Run NON-headless (needs a GPU): see tools note. Not a *Test scene, so the suite ignores it.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _merged_params(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

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

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -35, 0)
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)
	var base_params := {
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"shell_enabled": 1.0,
		"mouth_type": "terminal",
		"mouth_open": 1.0,
	}
	var sculpted_params := _merged_params(base_params, {
		"head_shape": "rounded",
		"snout_length": 0.45,
		"snout_taper": 0.7,
		"snout_thickness": 0.6,
		"head_belly_curve": -0.7,
		"head_bottom_flatness": 0.8,
		"head_bump_height": 0.3,
		"mouth_size": 0.14,
	})
	fish.set_parameters(base_params)
	await get_tree().process_frame
	fish.apply_pose(0.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots"))
	# Tight zoom on the mouth. yaw, mouth_open per shot.
	var shots := [
		{"name": "zoom_side", "yaw": 0.0, "params": _merged_params(base_params, {"mouth_open": 1.0})},
		{"name": "zoom_threeq", "yaw": 22.0, "params": _merged_params(base_params, {"mouth_open": 1.0})},
		{"name": "zoom_closed", "yaw": 0.0, "params": _merged_params(base_params, {"mouth_open": 0.0})},
	]
	for gape in [0.3, 0.6, 1.0]:
		var suffix := "%03d" % int(round(gape * 100.0))
		shots.append({"name": "zoom_sculpted_side_%s" % suffix, "yaw": 0.0, "params": _merged_params(sculpted_params, {"mouth_open": gape})})
		shots.append({"name": "zoom_sculpted_threeq_%s" % suffix, "yaw": 22.0, "params": _merged_params(sculpted_params, {"mouth_open": gape})})
	cam.size = 0.5
	for shot in shots:
		fish.set_parameters((shot["params"] as Dictionary).duplicate(true))
		await get_tree().process_frame
		fish.apply_pose(0.0)
		fish.rotation_degrees.y = float(shot["yaw"])
		await get_tree().process_frame
		var mouth := fish.get_node_or_null("BodyPivot/Head/Mouth") as Node3D
		var head := fish.get_node_or_null("BodyPivot/Head") as Node3D
		var target: Vector3 = (mouth.global_position if mouth else (head.global_position if head else Vector3.ZERO))
		cam.position = target + Vector3(0.0, 0.0, 5.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png("res://exports/_shots/mouth_%s.png" % String(shot["name"]))
		print("SHOT_SAVED ", shot["name"])
	get_tree().quit(0)
