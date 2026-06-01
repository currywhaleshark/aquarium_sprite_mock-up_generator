extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	# A strongly arched back so the dorsal contour has clear curvature.
	fish.set_parameters({
		"shell_enabled": 1.0,
		"body_length": 1.45,
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.20, "lower_height": 0.18, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.40, "lower_height": 0.30, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.66, "lower_height": 0.42, "width": 0.46, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": 0.0, "upper_height": 0.44, "lower_height": 0.40, "width": 0.38, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": 0.0, "upper_height": 0.26, "lower_height": 0.24, "width": 0.22, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": 0.0, "upper_height": 0.12, "lower_height": 0.12, "width": 0.08, "roundness": 0.7, "sway_weight": 1.0}
			]
		}
	})
	await get_tree().process_frame

	var points := PackedVector3Array([
		Vector3(-0.18, 0.0, 0.0),
		Vector3(0.0, 0.3, 0.0),
		Vector3(0.18, 0.0, 0.0)
	])

	# follow = 0 reproduces the original flat fin shape.
	var flat := fish._curved_fin_points("dorsal", 0.45, 0.035, points, 0.0)
	assert((flat[0] - points[0]).length() < 0.0001)
	assert((flat[2] - points[2]).length() < 0.0001)

	# follow = 1 rides the curved back: base endpoints leave the straight base
	# line and the whole shape differs from the flat fin.
	var curved := fish._curved_fin_points("dorsal", 0.45, 0.035, points, 1.0)
	assert(abs(curved[0].y) > 0.01)
	assert(abs(curved[2].y) > 0.01)
	var total := 0.0
	for i in points.size():
		total += (curved[i] - flat[i]).length()
	assert(total > 0.02)

	# Ventral fins keep their downward orientation.
	var ventral_flat := fish._curved_fin_points("ventral", 0.5, 0.03, points, 0.0)
	assert(ventral_flat[1].y < 0.0)

	# The dorsal fin node is still built and attached above the centerline.
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	assert(dorsal != null)
	assert(dorsal.position.y > 0.0)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/curved_fin.ok", FileAccess.WRITE)
	file.store_string("median fins follow the body contour")
	file.close()
	print("CURVED_FIN_TEST_OK")
	get_tree().quit(0)
