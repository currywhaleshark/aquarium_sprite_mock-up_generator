extends Node

# Dev-only diagnostic: renders the shark head/mouth from several angles, zoomed on the
# head, and saves PNGs so the mouth geometry can be inspected instead of guessed. Run
# NON-headless (needs a GPU). Not a *Test scene, so the suite ignores it.
#   godot --path . scenes/SharkMouthShot.tscn

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _merged(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

func _base_parameters() -> Dictionary:
	return {
		"creature_type": "shark",
		"base_color": "#6f7d8c",
		"secondary_color": "#d8e2ea",
		"body_length": 5.8,
		"body_height": 0.42,
		"body_width": 0.28,
		"head_shape": "pointed",
		"head_size": 0.42,
		"head_offset": -0.78,
		"snout_length": 0.22,
		"forehead_slope": 0.2,
		"mouth_type": "terminal",
		"shark_gill_slit_enabled": true,
		"shark_gill_slit_count": 5,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_position_x": -0.96,
		"shark_mouth_position_y": -0.13,
		"shark_mouth_width": 0.18,
		"shark_mouth_curve": 0.58,
		"shark_mouth_gape": 0.16,
		"shark_jaw_projection": 0.08,
		"shark_lower_jaw_drop": 0.10,
		"shark_lower_teeth_visible": true,
		"shark_tooth_visible_count": 11,
		"shark_tooth_size": 0.018,
		"shark_tooth_angle": -8.0,
		"shark_labial_furrow_length": 0.04,
	}

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("SHARK_MOUTH_SHOT_NEEDS_GPU")
		get_tree().quit(1)
		return

	var vp := SubViewport.new()
	vp.size = Vector2i(640, 640)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.70)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.75)
	e.ambient_light_energy = 1.0
	env.environment = e
	vp.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -40, 0)
	light.light_energy = 1.6
	vp.add_child(light)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.9
	cam.current = true
	vp.add_child(cam)

	var shark: Node3D = SharkRigScript.new()
	shark.set("auto_animate", false)
	vp.add_child(shark)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/_shots/shark"))

	var default_params := _base_parameters()
	var wide_open := _merged(default_params, {
		"shark_mouth_gape": 0.9,
		"shark_lower_jaw_drop": 0.4,
		"shark_jaw_projection": 0.3,
	})

	var sets := [
		{"tag": "default", "params": default_params},
		{"tag": "open", "params": wide_open},
	]
	# yaw: 0 = side profile (looking down +Z at the flank), 35 = three-quarter,
	# 90 = head-on front, -90 = rear-ish. pitch via camera elevation offset.
	var angles := [
		{"name": "side", "yaw": 0.0, "elev": 0.0},
		{"name": "threeq", "yaw": 40.0, "elev": 10.0},
		{"name": "front", "yaw": 90.0, "elev": 8.0},
		{"name": "belowfront", "yaw": 70.0, "elev": -25.0},
		{"name": "top", "yaw": 20.0, "elev": 55.0},
		{"name": "zoom_side", "yaw": 8.0, "elev": -8.0, "size": 0.32},
		{"name": "zoom_threeq", "yaw": 38.0, "elev": -6.0, "size": 0.32},
		{"name": "zoom_front", "yaw": 78.0, "elev": -18.0, "size": 0.32},
	]

	for s in sets:
		var tag := String(s["tag"])
		var params: Dictionary = s["params"]
		shark.call("set_parameters", params.duplicate(true))
		await get_tree().process_frame
		if shark.has_method("apply_pose"):
			shark.call("apply_pose", 0.0)
		await get_tree().process_frame

		_dump_mouth_diagnostics(tag, shark)

		var head := shark.get_node_or_null("BodyPivot/Head") as Node3D
		var target: Vector3 = head.global_position if head != null else Vector3.ZERO

		for angle in angles:
			shark.rotation_degrees.y = float(angle["yaw"])
			await get_tree().process_frame
			# Frame tightly on the actual mouth line when zoomed.
			var head_node := shark.get_node_or_null("BodyPivot/Head") as Node3D
			target = head_node.global_position
			cam.size = float(angle.get("size", 0.9))
			if cam.size < 0.5:
				# Mouth line sits forward (-x) and low (-y) of the head origin.
				target = head_node.global_transform * Vector3(-0.38, -0.13, 0.0)
			var elev := deg_to_rad(float(angle["elev"]))
			var dist := 5.0
			cam.position = target + Vector3(0.0, sin(elev) * dist, cos(elev) * dist)
			cam.look_at(target, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var fname := "res://exports/_shots/shark/%s_%s.png" % [tag, String(angle["name"])]
			img.save_png(fname)
			print("SHOT_SAVED ", tag, "_", String(angle["name"]))

	get_tree().quit(0)

func _dump_mouth_diagnostics(tag: String, shark: Node) -> void:
	var head := shark.get_node_or_null("BodyPivot/Head") as Node3D
	var mouth := shark.get_node_or_null("BodyPivot/Head/SharkMouth") as Node3D
	if head == null or mouth == null:
		print("DIAG ", tag, " NO_HEAD_OR_MOUTH")
		return
	print("DIAG ", tag, " head.scale=", head.scale, " head.gpos=", head.global_position)
	for child in _all_mesh(mouth):
		var mi := child as MeshInstance3D
		var aabb := mi.get_aabb()
		var world_size := aabb.size * mi.global_transform.basis.get_scale()
		print("  DIAG ", tag, " ", _path_under(mouth, mi), " local_aabb_size=", aabb.size,
			" world_size~=", world_size, " gpos=", mi.global_position)

func _path_under(root: Node, node: Node) -> String:
	var parts := [node.name]
	var cur := node.get_parent()
	while cur != null and cur != root:
		parts.push_front(cur.name)
		cur = cur.get_parent()
	return "/".join(parts)

func _all_mesh(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_all_mesh(child))
	return result
