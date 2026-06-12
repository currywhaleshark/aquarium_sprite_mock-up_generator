extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING := 3
const SEG := 28

func _ring_sample(fish: Node, segment_index: int) -> Vector3:
	var shell := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	assert(shell != null)
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var base := RING * (SEG + 1)
	return verts[base + segment_index]

func _shape_span(fish: Node) -> Dictionary:
	return {
		"right_mid": _ring_sample(fish, 0).z,
		"top": _ring_sample(fish, int(SEG / 4)).y,
		"left_mid": _ring_sample(fish, int(SEG / 2)).z,
		"bottom": _ring_sample(fish, int(3 * SEG / 4)).y,
		"right_near_upper": _ring_sample(fish, 1),
		"right_near_lower": _ring_sample(fish, SEG - 1),
		"upper_right": _ring_sample(fish, int(SEG / 8)),
		"upper_left": _ring_sample(fish, int(3 * SEG / 8)),
		"lower_left": _ring_sample(fish, int(5 * SEG / 8)),
		"lower_right": _ring_sample(fish, int(7 * SEG / 8)),
	}

func _mutate_ring(fish: Node, updates: Dictionary) -> void:
	var rings: Array = fish.parameters["body_profile"]["rings"]
	var ring: Dictionary = rings[RING].duplicate(true)
	for key in updates.keys():
		ring[key] = updates[key]
	rings[RING] = ring
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)

func _pelvic_positions(fish: Node) -> Dictionary:
	var left := fish.get_node_or_null("BodyPivot/PelvicFinL") as Node3D
	var right := fish.get_node_or_null("BodyPivot/PelvicFinR") as Node3D
	assert(left != null)
	assert(right != null)
	return {"left_z": left.position.z, "right_z": right.position.z}

func _pectoral_positions(fish: Node) -> Dictionary:
	var left := fish.get_node_or_null("BodyPivot/PectoralFinL") as Node3D
	var right := fish.get_node_or_null("BodyPivot/PectoralFinR") as Node3D
	assert(left != null)
	assert(right != null)
	return {"left_z": left.position.z, "right_z": right.position.z}

func _load_preset_parameters(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(typeof(parsed) == TYPE_DICTIONARY)
	return (parsed as Dictionary).get("parameters", {})

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var params := {"shell_enabled": 1.0, "pelvic_enabled": 1.0}
	params["body_profile"] = BodyProfileScript.ensure_body_profile({})
	fish.set_parameters(params)
	await get_tree().process_frame

	var neutral := _shape_span(fish)

	_mutate_ring(fish, {"top_width": 0.72})
	await get_tree().process_frame
	var wide_top := _shape_span(fish)
	assert(wide_top["upper_right"].z > neutral["upper_right"].z + 0.04)
	assert(wide_top["upper_left"].z < neutral["upper_left"].z - 0.04)
	assert(absf(wide_top["lower_right"].z - neutral["lower_right"].z) < 0.0005)
	assert(absf(wide_top["lower_left"].z - neutral["lower_left"].z) < 0.0005)
	assert(absf(wide_top["top"] - neutral["top"]) < 0.0005)
	assert(absf(wide_top["bottom"] - neutral["bottom"]) < 0.0005)
	assert(absf(wide_top["right_mid"] - wide_top["right_near_lower"].z) < 0.05)

	fish.set_parameters(params)
	await get_tree().process_frame
	_mutate_ring(fish, {"bottom_width": 0.72})
	await get_tree().process_frame
	var wide_bottom := _shape_span(fish)
	assert(wide_bottom["lower_right"].z > neutral["lower_right"].z + 0.04)
	assert(wide_bottom["lower_left"].z < neutral["lower_left"].z - 0.04)
	assert(absf(wide_bottom["upper_right"].z - neutral["upper_right"].z) < 0.0005)
	assert(absf(wide_bottom["upper_left"].z - neutral["upper_left"].z) < 0.0005)
	assert(absf(wide_bottom["top"] - neutral["top"]) < 0.0005)
	assert(absf(wide_bottom["bottom"] - neutral["bottom"]) < 0.0005)
	assert(absf(wide_bottom["right_mid"] - wide_bottom["right_near_upper"].z) < 0.05)

	fish.set_parameters(params)
	await get_tree().process_frame
	_mutate_ring(fish, {"top_flatness": 1.0})
	await get_tree().process_frame
	var flat_top := _shape_span(fish)
	assert(flat_top["upper_right"].y > neutral["upper_right"].y + 0.01)
	assert(flat_top["upper_left"].y > neutral["upper_left"].y + 0.01)
	assert(absf(flat_top["bottom"] - neutral["bottom"]) < 0.0005)

	fish.set_parameters(params)
	await get_tree().process_frame
	var neutral_fins := _pelvic_positions(fish)
	var rings: Array = fish.parameters["body_profile"]["rings"]
	for i in rings.size():
		var ring: Dictionary = rings[i].duplicate(true)
		ring["bottom_width"] = float(ring.get("width", 0.34)) + 0.20
		ring["top_width"] = float(ring.get("width", 0.34))
		rings[i] = ring
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)
	await get_tree().process_frame
	var split_fins := _pelvic_positions(fish)
	assert(split_fins["right_z"] > neutral_fins["right_z"] + 0.012)
	assert(split_fins["left_z"] < neutral_fins["left_z"] - 0.012)
	assert(absf(absf(split_fins["left_z"]) - absf(split_fins["right_z"])) < 0.002)

	fish.set_parameters(params)
	await get_tree().process_frame
	var neutral_pectoral := _pectoral_positions(fish)
	rings = fish.parameters["body_profile"]["rings"]
	for i in rings.size():
		var ring: Dictionary = rings[i].duplicate(true)
		ring["top_width"] = float(ring.get("width", 0.34)) + 0.20
		ring["bottom_width"] = float(ring.get("width", 0.34)) + 0.20
		rings[i] = ring
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)
	await get_tree().process_frame
	var wide_pectoral := _pectoral_positions(fish)
	assert(wide_pectoral["right_z"] > neutral_pectoral["right_z"] + 0.02)
	assert(wide_pectoral["left_z"] < neutral_pectoral["left_z"] - 0.02)

	var op_params := params.duplicate(true)
	op_params["gill_mark"] = "operculum"
	op_params["operculum_height"] = 1.25
	op_params["body_profile"] = BodyProfileScript.ensure_body_profile({})
	fish.set_parameters(op_params)
	await get_tree().process_frame
	rings = fish.parameters["body_profile"]["rings"]
	for i in rings.size():
		var ring: Dictionary = rings[i].duplicate(true)
		ring["bottom_width"] = float(ring.get("width", 0.34)) + 0.24
		ring["top_width"] = float(ring.get("width", 0.34))
		rings[i] = ring
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)
	await get_tree().process_frame
	var op_lower := fish.get_vector_edit_marker_world("operculum", Vector2(0.5, -0.55))
	var op_upper := fish.get_vector_edit_marker_world("operculum", Vector2(0.5, 0.55))
	assert(absf(op_lower.z) > absf(op_upper.z) + 0.006)

	var arowana_params := _load_preset_parameters("res://presets/아로와나.json")
	fish.set_parameters(arowana_params)
	await get_tree().process_frame
	var arowana_pectoral := _pectoral_positions(fish)
	var arowana_attach_t := float(arowana_params.get("pectoral_attach_t", 0.32))
	var arowana_surface_z := fish._surface_radius_z(arowana_attach_t)
	assert(absf(absf(arowana_pectoral["right_z"]) - arowana_surface_z) < 0.002)
	assert(absf(absf(arowana_pectoral["left_z"]) - arowana_surface_z) < 0.002)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/ring_width_flatness.ok", FileAccess.WRITE)
	file.store_string("body ring upper/lower width and directional flatness applied")
	file.close()
	print("RING_WIDTH_FLATNESS_TEST_OK")
	get_tree().quit(0)
