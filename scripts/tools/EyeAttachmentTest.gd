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
		"eye_size": 0.06,
		"eye_position_x": -0.7,
		"eye_position_y": 0.1,
		"eye_bulge": 0.0
	}
	fish.set_parameters(base)
	await get_tree().process_frame

	var eye_l := fish.get_node_or_null("BodyPivot/EyeL") as MeshInstance3D
	var eye_r := fish.get_node_or_null("BodyPivot/EyeR") as MeshInstance3D
	assert(eye_l != null)
	assert(eye_r != null)
	# Eyes sit on opposite sides of the head, symmetric about the centerline.
	assert(eye_l.position.z < 0.0)
	assert(eye_r.position.z > 0.0)
	assert(abs(eye_l.position.z + eye_r.position.z) < 0.0001)
	var flush_z := eye_r.position.z
	assert(flush_z > 0.0)
	# A flush eye sits near the head surface and grows no stalk.
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	assert(flush_z < head.scale.z)
	assert(fish.get_node_or_null("BodyPivot/EyeStalkL") == null)

	# Bulging the eyes pushes them outward and adds a connecting stalk.
	var bulged := base.duplicate(true)
	bulged["eye_bulge"] = 1.0
	fish.set_parameters(bulged)
	await get_tree().process_frame
	var eye_r_bulged := fish.get_node_or_null("BodyPivot/EyeR") as MeshInstance3D
	assert(eye_r_bulged != null)
	assert(eye_r_bulged.position.z > flush_z + 0.05)
	var stalk_l := fish.get_node_or_null("BodyPivot/EyeStalkL") as MeshInstance3D
	var stalk_r := fish.get_node_or_null("BodyPivot/EyeStalkR") as MeshInstance3D
	assert(stalk_l != null)
	assert(stalk_r != null)
	# The stalk bridges the head surface and the bulged eye.
	assert(stalk_r.position.z > 0.0)
	assert(stalk_r.position.z < eye_r_bulged.position.z)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/eye_attachment.ok", FileAccess.WRITE)
	file.store_string("eye attachment and bulge applied")
	file.close()
	print("EYE_ATTACHMENT_TEST_OK")
	get_tree().quit(0)
