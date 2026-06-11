extends Node

# Dev-only diagnostic: renders the open mouth with each mouth-related node hidden in
# turn so torn-shading artifacts can be attributed to a specific mesh. Run NON-headless
# (needs a GPU). Not a *Test scene, so the suite ignores it.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

const MOUTH_NODES := [
	"MouthCavity",
	"MouthUpperInterior",
	"MouthSideAperture",
	"MouthFloor",
	"MouthLowerJaw",
	"MouthLipUpper",
]

func _merged(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 600)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.62, 0.45)
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
	cam.size = 0.22
	cam.current = true
	vp.add_child(cam)

	var fish: FishRig = FishRigScript.new()
	fish.auto_animate = false
	vp.add_child(fish)

	# Set A: close to the user's screenshot (pale body, big mouth, default head).
	var pale_big_mouth := {
		"base_color": "#ececec",
		"secondary_color": "#46c6cf",
		"shell_enabled": 1.0,
		"mouth_type": "terminal",
		"mouth_open": 1.0,
		"mouth_size": 0.2,
	}
	# Set B: the aggressive sculpt combo from the lining plan.
	var sculpted := _merged(pale_big_mouth, {
		"head_shape": "rounded",
		"snout_length": 0.45,
		"snout_taper": 0.7,
		"snout_thickness": 0.6,
		"head_belly_curve": -0.7,
		"head_bottom_flatness": 0.8,
		"head_bump_height": 0.3,
		"mouth_size": 0.14,
	})

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots/isolate"))

	var sets := [
		{"tag": "pale", "params": pale_big_mouth},
		{"tag": "sculpt", "params": sculpted},
	]
	for s in sets:
		var tag := String(s["tag"])
		var params: Dictionary = s["params"]
		# Full render, then hide one mouth node at a time, then legacy meshes all off.
		var variants := [{"name": "full", "hide": []}]
		for n in MOUTH_NODES:
			variants.append({"name": "no_%s" % n, "hide": [n]})
		variants.append({"name": "legacy_off", "hide": ["MouthUpperInterior", "MouthSideAperture", "MouthLipUpper"]})
		for variant in variants:
			fish.set_parameters(params.duplicate(true))
			await get_tree().process_frame
			fish.apply_pose(0.0)
			fish.rotation_degrees.y = 30.0
			await get_tree().process_frame
			var head := fish.get_node_or_null("BodyPivot/Head") as Node3D
			for hide_name in variant["hide"]:
				var node := fish.get_node_or_null("BodyPivot/Head/%s" % hide_name) as Node3D
				if node:
					node.visible = false
				else:
					print("MISSING_NODE ", hide_name)
			var jaw := fish.get_node_or_null("BodyPivot/Head/MouthLowerJaw") as Node3D
			var target: Vector3 = (jaw.global_position if jaw else (head.global_position if head else Vector3.ZERO))
			cam.position = target + Vector3(0.02, -0.02, 5.0)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("res://exports/_shots/isolate/%s_%s.png" % [tag, String(variant["name"])])
			print("SHOT_SAVED ", tag, "_", String(variant["name"]))
	get_tree().quit(0)
