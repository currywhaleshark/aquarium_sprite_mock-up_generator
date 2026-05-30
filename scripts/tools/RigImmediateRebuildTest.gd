extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	var parameters := {
		"shell_enabled": 1.0,
		"body_length": 1.28,
		"body_height": 0.5,
		"body_width": 0.32,
		"tail_length": 0.7,
		"tail_fin_size": 0.34,
		"global_sway_amount": 4.0,
		"tail_sway_multiplier": 1.6,
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.24, "lower_height": 0.2, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.42, "lower_height": 0.36, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.52, "lower_height": 0.48, "width": 0.46, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": 0.0, "upper_height": 0.46, "lower_height": 0.42, "width": 0.38, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": 0.0, "upper_height": 0.28, "lower_height": 0.26, "width": 0.24, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": 0.0, "upper_height": 0.12, "lower_height": 0.12, "width": 0.08, "roundness": 0.7, "sway_weight": 1.0}
			]
		}
	}
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)
	parameters["global_sway_amount"] = 18.0
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)
	parameters["global_sway_amount"] = 2.0
	fish.set_parameters(parameters)
	assert(_count_named_children(fish, "BodyPivot") == 1)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/rig_immediate_rebuild.ok", FileAccess.WRITE)
	file.store_string("rebuild removes stale rig nodes immediately")
	file.close()
	print("RIG_IMMEDIATE_REBUILD_TEST_OK")
	get_tree().quit(0)

func _count_named_children(node: Node, child_name: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.name == child_name:
			count += 1
	return count
