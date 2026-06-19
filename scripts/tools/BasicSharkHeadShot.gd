extends Node

# Dev-only visual QA for the baseline shark head. Renders the default basic_shark and
# the two built-in shark head recipes from side, three-quarter, and front/head-on views.
# Run NON-headless (needs GPU). Not a *Test scene, so the CLI suite ignores it.
#   godot --path . scenes/BasicSharkHeadShot.tscn

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("BASIC_SHARK_HEAD_SHOT_NEEDS_GPU")
		get_tree().quit(1)
		return

	var preset := PresetStoreScript.load_preset("res://presets/basic_shark.json")
	if preset.is_empty():
		push_error("basic_shark preset failed to load")
		get_tree().quit(1)
		return
	var base_parameters: Dictionary = preset.get("parameters", {})

	var vp := SubViewport.new()
	vp.size = Vector2i(720, 720)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.52, 0.60, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.78, 0.78)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -38, 0)
	light.light_energy = 1.65
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	vp.add_child(cam)

	var shark: Node3D = SharkRigScript.new()
	shark.set("auto_animate", false)
	vp.add_child(shark)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots/shark_head"))

	var sets := [
		{"tag": "basic_shark", "params": base_parameters},
		{"tag": "white_shark_conical", "params": _recipe_parameters(base_parameters, "white_shark_conical")},
		{"tag": "whale_shark_blunt", "params": _recipe_parameters(base_parameters, "whale_shark_blunt")}
	]
	var angles := [
		{"name": "side", "yaw": 0.0, "elev": -2.0, "size": 0.72, "offset": Vector3(-0.20, -0.01, 0.0)},
		{"name": "threeq", "yaw": 38.0, "elev": 8.0, "size": 0.72, "offset": Vector3(-0.18, -0.01, 0.0)},
		{"name": "front", "yaw": 86.0, "elev": 6.0, "size": 0.66, "offset": Vector3(-0.10, -0.01, 0.0)}
	]

	for s in sets:
		var tag := String(s["tag"])
		var params: Dictionary = (s["params"] as Dictionary).duplicate(true)
		shark.set_parameters(params)
		await get_tree().process_frame
		if shark.has_method("apply_pose"):
			shark.call("apply_pose", 0.0)
		await get_tree().process_frame
		var head := shark.get_node_or_null("BodyPivot/Head") as Node3D
		if head == null:
			push_error("head missing for %s" % tag)
			get_tree().quit(1)
			return
		for angle in angles:
			shark.rotation_degrees.y = float(angle["yaw"])
			await get_tree().process_frame
			var target := head.global_transform * (angle["offset"] as Vector3)
			cam.size = float(angle["size"])
			var elev := deg_to_rad(float(angle["elev"]))
			var dist := 5.0
			cam.position = target + Vector3(0.0, sin(elev) * dist, cos(elev) * dist)
			cam.look_at(target, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var path := "res://exports/_shots/shark_head/%s_%s.png" % [tag, String(angle["name"])]
			var err := img.save_png(path)
			if err != OK:
				push_error("failed to save %s: %s" % [path, err])
				get_tree().quit(1)
				return
			print("BASIC_SHARK_HEAD_SHOT_SAVED ", path)
	get_tree().quit(0)

func _recipe_parameters(base_parameters: Dictionary, recipe_id: String) -> Dictionary:
	var result := base_parameters.duplicate(true)
	for key in HeadEditorPanelScript.SHARK_HEAD_RECIPE_KEYS.keys():
		var text_key := String(key)
		if HeadEditorPanelScript.SHARK_HEAD_RECIPE_DEFAULTS.has(text_key):
			result[text_key] = HeadEditorPanelScript.SHARK_HEAD_RECIPE_DEFAULTS[text_key]
	var recipe: Dictionary = HeadEditorPanelScript.SHARK_HEAD_RECIPES[recipe_id]
	for key in recipe.keys():
		var text_key := String(key)
		if HeadEditorPanelScript.SHARK_HEAD_RECIPE_KEYS.has(text_key):
			result[text_key] = recipe[key]
	return result