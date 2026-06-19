extends Node

# Shark-specific regression for the head/body-shell seam envelope. The shark head uses
# a separate profile mesh, so probe its head vertices against the inherited shell
# envelope across baseline and proportion-stress cases.

const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _max_escape(fish, label: String) -> float:
	var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	assert(head != null)
	var arrays := head.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := head.transform
	var start_x: float = fish.shell_profile[0].x
	var back_x: float = fish.shell_profile[fish.shell_profile.size() - 1].x
	var worst := 0.0
	var worst_x := 0.0
	var worst_y := 0.0
	var worst_z := 0.0
	var worst_ny := 0.0
	var worst_nz := 0.0
	var worst_prof := Vector3.ZERO
	var worst_cy := 0.0
	var worst_t := 0.0
	var worst_actual_index := 0.0
	for v in verts:
		var w := xf * v
		if w.x <= start_x or w.x >= back_x:
			continue # exposed snout front / past the head zone
		var t: float = fish._shell_attach_t_for_x(w.x)
		var prof: Vector3 = fish._sample_shell_profile(t)
		var cy: float = fish._sample_shell_center_y(t)
		var ny := (w.y - cy) / maxf(prof.y, 0.0001)
		var nz := w.z / maxf(prof.z, 0.0001)
		var escape := sqrt(ny * ny + nz * nz)
		if escape > worst:
			worst = escape
			worst_x = w.x
			worst_y = w.y
			worst_z = w.z
			worst_ny = ny
			worst_nz = nz
			worst_prof = prof
			worst_cy = cy
			worst_t = t
			if fish.has_method("_actual_shell_index_for_attach_t"):
				worst_actual_index = fish._actual_shell_index_for_attach_t(t)
	print("  %s seam worst_radial=%.3f x=%.3f y=%.3f z=%.3f ny=%.3f nz=%.3f prof_y=%.3f prof_z=%.3f cy=%.3f t=%.3f idx=%.3f" % [
		label,
		worst,
		worst_x,
		worst_y,
		worst_z,
		worst_ny,
		worst_nz,
		worst_prof.y,
		worst_prof.z,
		worst_cy,
		worst_t,
		worst_actual_index,
	])
	return worst

func _assert_enclosed(value: float, label: String) -> bool:
	if value <= 1.02:
		return true
	push_error("SHARK_HEAD_SHELL_SEAM_ESCAPE %s %.3f" % [label, value])
	return false

func _ready() -> void:
	var preset := PresetStoreScript.load_preset("res://presets/basic_shark.json")
	assert(not preset.is_empty())
	var base: Dictionary = preset.get("parameters", {}).duplicate(true)
	assert(not base.is_empty())

	var shark: SharkRig = SharkRigScript.new()
	add_child(shark)
	shark.auto_animate = false

	shark.set_parameters(base)
	await get_tree().process_frame
	var ok := _assert_enclosed(_max_escape(shark, "basic_shark"), "basic_shark")

	var high_rear := base.duplicate(true)
	high_rear["shark_head_rear_height"] = 0.8
	high_rear["shark_head_rear_width"] = 1.0
	shark.set_parameters(high_rear)
	await get_tree().process_frame
	ok = _assert_enclosed(_max_escape(shark, "high-rear-volume"), "high-rear-volume") and ok

	var wide_small := base.duplicate(true)
	wide_small["body_width"] = 0.5
	wide_small["head_size"] = 0.34
	wide_small["head_flattening"] = 0.11
	shark.set_parameters(wide_small)
	await get_tree().process_frame
	ok = _assert_enclosed(_max_escape(shark, "wide-body-small-head"), "wide-body-small-head") and ok

	if not ok:
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/shark_head_shell_seam.ok", FileAccess.WRITE)
	file.store_string("shark head stays within shell envelope through the seam")
	file.close()
	print("SHARK_HEAD_SHELL_SEAM_TEST_OK")
	get_tree().quit(0)
