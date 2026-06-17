extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"shell_enabled": 1.0,
		"pelvic_enabled": 1.0,
		"pelvic_fin_yaw": 31.0
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var pelvic_l := fish.get_node_or_null("BodyPivot/PelvicFinL") as MeshInstance3D
	var pelvic_r := fish.get_node_or_null("BodyPivot/PelvicFinR") as MeshInstance3D
	assert(pelvic_l != null)
	assert(pelvic_r != null)
	assert(absf(pelvic_l.rotation_degrees.y - 31.0) < 0.001)
	assert(absf(pelvic_r.rotation_degrees.y + 31.0) < 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/pelvic_fin_yaw.ok", FileAccess.WRITE)
	file.store_string("pelvic fin yaw applies to paired ventral fins")
	file.close()
	print("PELVIC_FIN_YAW_TEST_OK")
	get_tree().quit(0)
