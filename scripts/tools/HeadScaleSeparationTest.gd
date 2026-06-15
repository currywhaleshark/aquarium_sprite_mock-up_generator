extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false

	var base := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.44,
		"head_length": 0.44,
		"body_height": 0.58,
		"body_width": 0.34,
	}
	fish.set_parameters(base)
	var base_scale := _head_scale(fish)

	var larger_head := base.duplicate(true)
	larger_head["head_size"] = 0.66
	fish.set_parameters(larger_head)
	var larger_scale := _head_scale(fish)
	assert(absf(larger_scale.x - base_scale.x) < 0.001)
	assert(larger_scale.y > base_scale.y * 1.3)
	assert(larger_scale.z > base_scale.z * 1.3)

	var longer_head := base.duplicate(true)
	longer_head["head_length"] = 0.66
	fish.set_parameters(longer_head)
	var longer_scale := _head_scale(fish)
	assert(longer_scale.x > base_scale.x * 1.3)
	assert(absf(longer_scale.y - base_scale.y) < 0.001)
	assert(absf(longer_scale.z - base_scale.z) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_scale_separation.ok", FileAccess.WRITE)
	file.store_string("head size and head length affect separate axes")
	file.close()
	print("HEAD_SCALE_SEPARATION_TEST_OK")
	get_tree().quit(0)

func _head_scale(fish: FishRig) -> Vector3:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	return head.scale
