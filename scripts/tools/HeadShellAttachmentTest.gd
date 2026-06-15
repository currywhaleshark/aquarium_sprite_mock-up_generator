extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false

	var base := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.66,
		"head_length": 0.44,
		"shell_expand": 0.08,
		"body_height": 0.58,
		"body_width": 0.34,
	}
	fish.set_parameters(base)
	await get_tree().process_frame
	_assert_front_shell_ring_attached(fish, "large-rounded")

	var tapered := base.duplicate(true)
	tapered["head_shape"] = "tapered"
	tapered["head_length"] = 0.62
	fish.set_parameters(tapered)
	await get_tree().process_frame
	_assert_front_shell_ring_attached(fish, "long-tapered")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_shell_attachment.ok", FileAccess.WRITE)
	file.store_string("front shell ring stays attached to the head contour")
	file.close()
	print("HEAD_SHELL_ATTACHMENT_TEST_OK")
	get_tree().quit(0)

func _assert_front_shell_ring_attached(fish: FishRig, label: String) -> void:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	assert(not fish.shell_profile.is_empty())
	var shell_front: Vector3 = fish.shell_profile[0]
	var x_local := (shell_front.x - head.position.x) / head.scale.x
	var contour: Vector2 = fish._get_head_contour_radius(
		x_local,
		String(fish.parameters.get("head_shape", "rounded")),
		float(fish.parameters.get("forehead_slope", 0.35)),
		float(fish.parameters.get("snout_length", 0.0)),
		float(fish.parameters.get("snout_base", 0.32)),
		float(fish.parameters.get("snout_thickness", 1.0)),
		float(fish.parameters.get("snout_taper", 0.0))
	)
	var head_radius_y := head.scale.y * contour.x
	var head_radius_z := head.scale.z * contour.y
	var gap_y := shell_front.y - head_radius_y
	var gap_z := shell_front.z - head_radius_z
	print("  %s front_shell_gap_y=%.4f front_shell_gap_z=%.4f" % [label, gap_y, gap_z])
	if gap_y > 0.004 or gap_z > 0.004:
		push_error("%s front shell ring is detached from head contour: y=%.4f z=%.4f" % [label, gap_y, gap_z])
		get_tree().quit(1)
