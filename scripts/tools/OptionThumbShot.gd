extends Node

# Dev-only thumbnail generator. Run non-headless because SubViewport rendering needs
# the GPU path to produce reliable option images.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")

const THUMB_SIZE := 128
const OUTPUT_ROOT := "res://assets/option_thumbs"

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(THUMB_SIZE, THUMB_SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.74, 0.78)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	vp.add_child(env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28, -35, 0)
	key_light.light_energy = 1.35
	vp.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-12, 35, 0)
	fill_light.light_energy = 0.55
	vp.add_child(fill_light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)

	for job in _jobs():
		await _render_job(vp, cam, fish, job)
	get_tree().quit(0)

func _jobs() -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	for value in HeadEditorPanelScript.HEAD_SHAPES:
		jobs.append(_job("head_shape", String(value), {"head_shape": value}, "head", 0.86))
	for value in HeadEditorPanelScript.MOUTH_TYPES:
		jobs.append(_job("mouth_type", String(value), {
			"mouth_type": value,
			"mouth_open": 0.6,
			"mouth_size": 0.13,
			"lower_jaw_length": 1.2
		}, "mouth", 0.46))
	for value in HeadEditorPanelScript.EYE_STYLES:
		jobs.append(_job("eye_style", String(value), {
			"eye_style": value,
			"eye_size": 0.095,
			"eye_bulge": 0.45
		}, "eye", 0.38))
	return jobs

func _job(key: String, value: String, overrides: Dictionary, focus: String, camera_size: float) -> Dictionary:
	return {
		"key": key,
		"value": value,
		"params": _merged_params(_base_params(), overrides),
		"focus": focus,
		"camera_size": camera_size,
	}

func _base_params() -> Dictionary:
	return {
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"belly_color": "#d6fbff",
		"fin_color": "#7ee1e8",
		"shell_enabled": 1.0,
		"head_size": 0.52,
		"head_offset": -0.58,
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"mouth_open": 0.25,
		"mouth_size": 0.09,
		"eye_style": "bead",
		"eye_size": 0.07,
		"eye_position_x": -0.78,
		"eye_position_y": 0.12,
		"gill_mark": "operculum",
		"body_length": 1.28,
		"body_height": 0.50,
		"body_width": 0.32,
	}

func _merged_params(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

func _render_job(vp: SubViewport, cam: Camera3D, fish: FishRig, job: Dictionary) -> void:
	var key := String(job["key"])
	var value := String(job["value"])
	var output_dir := "%s/%s" % [OUTPUT_ROOT, key]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	fish.rotation_degrees = Vector3.ZERO
	fish.set_parameters((job["params"] as Dictionary).duplicate(true))
	await get_tree().process_frame
	fish.apply_pose(0.0)
	fish.rotation_degrees.y = 18.0
	await get_tree().process_frame

	var target := _focus_position(fish, String(job["focus"]))
	cam.size = float(job["camera_size"])
	cam.position = target + Vector3(0.0, 0.0, 5.0)
	cam.look_at(target, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := "%s/%s.png" % [output_dir, value]
	img.save_png(path)
	print("THUMB_SAVED %s/%s" % [key, value])

func _focus_position(fish: FishRig, focus: String) -> Vector3:
	var path := "BodyPivot/Head"
	match focus:
		"mouth":
			path = "BodyPivot/Head/Mouth"
		"eye":
			path = "BodyPivot/EyeL"
		"gill":
			path = "BodyPivot/Head"
	var node := fish.get_node_or_null(path) as Node3D
	if node != null:
		var position := node.global_position
		if focus == "gill":
			position.x += 0.08
			position.y -= 0.02
		return position
	var head := fish.get_node_or_null("BodyPivot/Head") as Node3D
	return head.global_position if head != null else fish.global_position
