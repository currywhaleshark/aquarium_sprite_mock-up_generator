extends Node

# Regression for the "head splits / inside shows" seam tear: with a continuous head
# profile (e.g. arowana's concave top), the rigid head node used to poke outside the
# body shell envelope near the head/shell junction, exposing the head's interior
# backface. The shell now floors its radius at the un-profiled head contour so a concave
# profile can't shrink it below the rigid head (without fattening the head / adding a
# step). This probes head mesh vertices against the shell envelope and asserts none
# escape it in the seam zone.

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _max_escape(fish, label: String) -> float:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := head.transform
	var start_x: float = fish.shell_profile[0].x
	var back_x: float = fish.shell_profile[fish.shell_profile.size() - 1].x
	var worst := 0.0
	for v in verts:
		var w := xf * v
		if w.x <= start_x or w.x >= back_x:
			continue # exposed snout front / past the head zone
		var t: float = fish._shell_attach_t_for_x(w.x)
		var prof: Vector3 = fish._sample_shell_profile(t)
		var cy: float = fish._sample_shell_center_y(t)
		var ny := (w.y - cy) / maxf(prof.y, 0.0001)
		var nz := w.z / maxf(prof.z, 0.0001)
		worst = maxf(worst, sqrt(ny * ny + nz * nz))
	print("  %s seam worst_radial=%.3f" % [label, worst])
	return worst

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var base := {
		"shell_enabled": 1.0,
		"head_shape": "rounded",
		"head_size": 0.44,
	}

	# Neutral head: head sits comfortably inside the shell.
	fish.set_parameters(base)
	await get_tree().process_frame
	assert(_max_escape(fish, "neutral") <= 1.02)

	# Arowana: long snout + concave (flat/lowered) top. This is the reported tear case.
	var arowana := base.duplicate(true)
	arowana["snout_length"] = 0.5
	arowana["head_top_curve"] = -0.6
	fish.set_parameters(arowana)
	await get_tree().process_frame
	assert(_max_escape(fish, "arowana") <= 1.02)

	# Strong concave top + drawn-in belly, the extreme arowana silhouette.
	var extreme := base.duplicate(true)
	extreme["head_top_curve"] = -0.9
	extreme["head_belly_curve"] = -0.6
	extreme["snout_length"] = 0.6
	fish.set_parameters(extreme)
	await get_tree().process_frame
	assert(_max_escape(fish, "arowana-extreme") <= 1.02)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/head_shell_seam.ok", FileAccess.WRITE)
	file.store_string("head stays within shell envelope through the seam")
	file.close()
	print("HEAD_SHELL_SEAM_TEST_OK")
	get_tree().quit(0)
