extends Node

# Dev-only: renders the default fish with VERTICAL stripes (pattern_type 1), which are
# periodic in the longitudinal UV (v_long). Any step in v_long at the head/shell neck
# seam shows up as stripes kinking or jumping there. Full-body + a neck-zoom are saved.
# Run NON-headless (needs a GPU). Not a *Test scene.
#   Godot_..._console.exe --path . scenes/SeamShot.tscn
# Output name suffix can be set via the SEAM_SHOT_TAG environment variable.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var tag := OS.get_environment("SEAM_SHOT_TAG")
	if tag == "":
		tag = "after"

	var vp := SubViewport.new()
	vp.size = Vector2i(900, 420)
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

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0.0, 0.0, 5.0)
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)

	# Strong, high-contrast vertical stripes so the neck seam is unambiguous.
	var params := {
		"base_color": "#f4f1de",
		"belly_color": "#f4f1de",
		"secondary_color": "#d6fbff",
		"pattern_color": "#1d3557",
		"pattern_type": "stripes",
		"pattern_scale_x": 22.0,
		"pattern_intensity": 1.0,
		"shell_enabled": 1.0,
		"gill_mark": "operculum",
		"operculum_size": 1.2,
		"operculum_height": 1.1,
		"operculum_open": float(OS.get_environment("SEAM_OP_OPEN") if OS.get_environment("SEAM_OP_OPEN") != "" else "0.35"),
	}
	# Optional steady turn pose to check that attachments (operculum) track the bent shell.
	if OS.get_environment("SEAM_TURN") != "":
		params["turn_amount"] = float(OS.get_environment("SEAM_TURN"))
		params["turn_direction"] = 1.0
		params["turn_phase"] = 0.0
	fish.set_parameters(params)

	var variants := [
		{"name": "full", "size": 2.0, "cx": 0.0, "ry": 0.0},
		{"name": "neck", "size": 0.95, "cx": -0.55, "ry": 0.0},
		{"name": "gill", "size": 0.42, "cx": -0.40, "ry": 0.0},
		{"name": "gill34", "size": 0.48, "cx": -0.40, "ry": 32.0},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots"))
	for variant in variants:
		cam.size = float(variant["size"])
		cam.position = Vector3(float(variant["cx"]), 0.0, 5.0)
		fish.rotation_degrees.y = float(variant.get("ry", 0.0))
		await get_tree().process_frame
		fish.apply_pose(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var path := "res://exports/_shots/seam_%s_%s.png" % [String(variant["name"]), tag]
		img.save_png(path)
		print("SEAM_SHOT_SAVED ", path)
	get_tree().quit(0)
