extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")

func _ready() -> void:
	var fish: FishRig = FishRigScript.new()
	add_child(fish)
	fish.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.14,
		"shell_color_mix": 0.35,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var fish_shell := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	assert(fish_shell != null)
	var fish_shell_before := _ring_center(fish_shell, 3, 28)
	fish.apply_pose(0.25)
	var fish_shell_after := _ring_center(fish_shell, 3, 28)
	assert(fish_shell_before.distance_to(fish_shell_after) > 0.001)
	var fish_body := fish.get_node("BodyPivot") as Node3D
	var fish_tail_tip := fish.get_node("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
	var shell_tail_center := _ring_center(fish_shell, 5, 28)
	var tail_tip_in_body := fish_body.to_local(fish_tail_tip.global_position)
	assert(abs(shell_tail_center.z - tail_tip_in_body.z) < 0.08)
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	var pectoral_l := fish.get_node_or_null("BodyPivot/PectoralFinL") as MeshInstance3D
	assert(dorsal != null)
	assert(pectoral_l != null)
	assert(dorsal.position.y > 0.34)
	assert(abs(pectoral_l.position.z) > 0.25)

	var ray: RayRig = RayRigScript.new()
	add_child(ray)
	ray.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.12,
		"shell_color_mix": 0.25,
		"base_color": "#5aaeb7",
		"underside_color": "#d6eeea"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var ray_shell := ray.get_node_or_null("DiscBody/MantleShell") as MeshInstance3D
	assert(ray_shell != null)
	var ray_shell_before := _last_vertex(ray_shell)
	ray.apply_pose(0.25)
	var ray_shell_after := _last_vertex(ray_shell)
	assert(ray_shell_before.distance_to(ray_shell_after) > 0.001)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/shell_rig.ok", FileAccess.WRITE)
	file.store_string("shell nodes present")
	file.close()
	print("SHELL_RIG_TEST_OK")
	get_tree().quit(0)

func _last_vertex(mesh_instance: MeshInstance3D) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices[vertices.size() - 1]

func _ring_center(mesh_instance: MeshInstance3D, ring_index: int, segments: int) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var center := Vector3.ZERO
	for segment in segments:
		center += vertices[ring_index * segments + segment]
	return center / float(segments)
