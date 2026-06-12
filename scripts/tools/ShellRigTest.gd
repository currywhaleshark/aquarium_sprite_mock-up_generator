extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

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
	var pectoral_attach_t := float(fish.parameters.get("pectoral_attach_t", 0.32))
	assert(absf(absf(pectoral_l.position.z) - fish._surface_radius_z(pectoral_attach_t)) < 0.002)

	for mode in BodyProfileScript.swim_mode_names():
		var mode_fish: FishRig = FishRigScript.new()
		add_child(mode_fish)
		var mode_parameters := {
			"shell_enabled": 1.0,
			"shell_expand": 0.12,
			"base_color": "#46c6cf",
			"secondary_color": "#d6fbff"
		}
		BodyProfileScript.apply_swim_mode(mode_parameters, mode)
		mode_fish.set_parameters(mode_parameters)
		await get_tree().process_frame
		mode_fish.apply_pose(0.25)
		var mode_tail := mode_fish.get_node("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
		var mode_dorsal := mode_fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
		var mode_anal := mode_fish.get_node_or_null("BodyPivot/AnalFin") as MeshInstance3D
		assert(mode_tail != null)
		assert(mode_dorsal != null)
		assert(mode_anal != null)
		assert(is_finite(mode_tail.rotation_degrees.y))
		assert(is_finite(mode_dorsal.rotation_degrees.x))
		assert(is_finite(mode_anal.rotation_degrees.x))
		if mode == "puffer":
			assert(abs(mode_dorsal.rotation_degrees.x) > 0.1)
			assert(abs(mode_anal.rotation_degrees.x) > 0.1)
		mode_fish.queue_free()

	var ray: RayRig = RayRigScript.new()
	add_child(ray)
	ray.set_parameters({
		"shell_enabled": 1.0,
		"shell_expand": 0.12,
		"shell_color_mix": 0.25,
		"base_color": "#5aaeb7",
		"underside_color": "#d6eeea",
		"pattern_type": "spots",
		"pattern_color": "#1f5560",
		"pattern_intensity": 0.64
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var ray_shell := ray.get_node_or_null("DiscBody/BodyMesh") as MeshInstance3D
	assert(ray_shell != null)
	var ray_dorsal_material := ray_shell.get_surface_override_material(0)
	var ray_underside_material := ray_shell.get_surface_override_material(1)
	assert(ray_dorsal_material is ShaderMaterial)
	assert(int((ray_dorsal_material as ShaderMaterial).get_shader_parameter("pattern_type")) == BodyProfileScript.pattern_type_index("spots"))
	assert(abs(float((ray_dorsal_material as ShaderMaterial).get_shader_parameter("pattern_intensity")) - 0.64) < 0.0001)
	assert(ray_underside_material is StandardMaterial3D)
	assert(not (ray_underside_material is ShaderMaterial))
	var ray_shell_before := _last_vertex(ray_shell)
	ray.apply_pose(0.25)
	var ray_shell_after := _last_vertex(ray_shell)
	assert(ray_shell_before.distance_to(ray_shell_after) > 0.001)
	var default_sync_left_y := _grid_vertex(ray_shell, 8, 16).y
	var default_sync_right_y := _grid_vertex(ray_shell, 8, 0).y
	assert(absf(default_sync_left_y - default_sync_right_y) < 0.0001)

	var turning_ray: RayRig = RayRigScript.new()
	add_child(turning_ray)
	turning_ray.set_parameters({
		"ray_locomotion_mode": "mobuliform",
		"pectoral_flap_sync": "synchronous",
		"turn_amount": 1.0,
		"turn_direction": 1.0,
		"turn_phase": 0.5,
		"flap_amplitude": 8.0,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var turning_body := turning_ray.get_node_or_null("DiscBody") as Node3D
	var turning_shell := turning_ray.get_node_or_null("DiscBody/BodyMesh") as MeshInstance3D
	assert(turning_body != null)
	assert(turning_shell != null)
	turning_ray.apply_pose(0.25)
	assert(turning_body.rotation_degrees.x > 0.1)
	var turn_left_y := _grid_vertex(turning_shell, 8, 16).y
	var turn_right_y := _grid_vertex(turning_shell, 8, 0).y
	assert(absf(turn_left_y - turn_right_y) > 0.002)
	var reverse_turn_ray: RayRig = RayRigScript.new()
	add_child(reverse_turn_ray)
	reverse_turn_ray.set_parameters({
		"ray_locomotion_mode": "mobuliform",
		"turn_amount": 1.0,
		"turn_direction": -1.0,
		"turn_phase": 0.5,
		"flap_amplitude": 8.0,
		"base_color": "#5aaeb7"
	})
	reverse_turn_ray.apply_pose(0.25)
	var reverse_turn_body := reverse_turn_ray.get_node_or_null("DiscBody") as Node3D
	assert(reverse_turn_body != null)
	assert(reverse_turn_body.rotation_degrees.x < -0.1)
	reverse_turn_ray.queue_free()
	turning_ray.queue_free()

	# Test roundness impact on shell shape
	var ray_diamond: RayRig = RayRigScript.new()
	add_child(ray_diamond)
	ray_diamond.set_parameters({
		"shell_roundness": 0.0,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_dia := ray_diamond.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var vert_dia := _last_vertex(shell_dia)

	var ray_ellipse: RayRig = RayRigScript.new()
	add_child(ray_ellipse)
	ray_ellipse.set_parameters({
		"shell_roundness": 1.0,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_ell := ray_ellipse.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var vert_ell := _last_vertex(shell_ell)
	
	assert(vert_dia.distance_to(vert_ell) > 0.01)
	ray_diamond.queue_free()
	ray_ellipse.queue_free()

	var ray_disc_diamond: RayRig = RayRigScript.new()
	add_child(ray_disc_diamond)
	ray_disc_diamond.set_parameters({
		"ray_disc_shape": "diamond",
		"disc_length": 1.0,
		"wing_width": 1.0,
		"shell_roundness": 0.7,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var disc_diamond_shell := ray_disc_diamond.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var diamond_front := _grid_vertex(disc_diamond_shell, 0, 8)
	var diamond_wing := _grid_vertex(disc_diamond_shell, 8, 16)

	var ray_disc_round: RayRig = RayRigScript.new()
	add_child(ray_disc_round)
	ray_disc_round.set_parameters({
		"ray_disc_shape": "electric",
		"disc_length": 1.0,
		"wing_width": 1.0,
		"shell_roundness": 0.7,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var disc_round_shell := ray_disc_round.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var round_front := _grid_vertex(disc_round_shell, 0, 8)
	var round_wing := _grid_vertex(disc_round_shell, 8, 16)
	assert(absf(round_front.x - diamond_front.x) < absf(diamond_front.x) * 0.2)
	assert(round_wing.z < diamond_wing.z)
	ray_disc_diamond.queue_free()
	ray_disc_round.queue_free()

	var ray_wing_short: RayRig = RayRigScript.new()
	add_child(ray_wing_short)
	ray_wing_short.set_parameters({
		"wing_length": 0.65,
		"wing_curve": 0.0,
		"base_color": "#5aaeb7"
	})
	var ray_wing_long: RayRig = RayRigScript.new()
	add_child(ray_wing_long)
	ray_wing_long.set_parameters({
		"wing_length": 1.35,
		"wing_curve": 0.0,
		"base_color": "#5aaeb7"
	})
	var short_wing_shell := ray_wing_short.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var long_wing_shell := ray_wing_long.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var short_span_edge := _grid_vertex(short_wing_shell, 8, 16)
	var long_span_edge := _grid_vertex(long_wing_shell, 8, 16)
	assert(absf(long_span_edge.z) > absf(short_span_edge.z) + 0.01)
	ray_wing_short.queue_free()
	ray_wing_long.queue_free()

	var ray_wing_narrow: RayRig = RayRigScript.new()
	add_child(ray_wing_narrow)
	ray_wing_narrow.set_parameters({
		"wing_width": 0.65,
		"base_color": "#5aaeb7"
	})
	var ray_wing_wide: RayRig = RayRigScript.new()
	add_child(ray_wing_wide)
	ray_wing_wide.set_parameters({
		"wing_width": 1.35,
		"base_color": "#5aaeb7"
	})
	var narrow_wing_shell := ray_wing_narrow.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var wide_wing_shell := ray_wing_wide.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var narrow_front_edge := _grid_vertex(narrow_wing_shell, 4, 16)
	var wide_front_edge := _grid_vertex(wide_wing_shell, 4, 16)
	assert(absf(wide_front_edge.x) > absf(narrow_front_edge.x) + 0.01)
	ray_wing_narrow.queue_free()
	ray_wing_wide.queue_free()

	var ray_short_snout: RayRig = RayRigScript.new()
	add_child(ray_short_snout)
	ray_short_snout.set_parameters({
		"ray_head_shape": "eagle",
		"snout_length": 0.0,
		"base_color": "#5aaeb7"
	})
	var ray_long_snout: RayRig = RayRigScript.new()
	add_child(ray_long_snout)
	ray_long_snout.set_parameters({
		"ray_head_shape": "eagle",
		"snout_length": 0.6,
		"base_color": "#5aaeb7"
	})
	var short_snout_shell := ray_short_snout.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var long_snout_shell := ray_long_snout.get_node("DiscBody/BodyMesh") as MeshInstance3D
	assert(_mesh_min_x(long_snout_shell) < _mesh_min_x(short_snout_shell) - 0.03)
	ray_short_snout.queue_free()
	ray_long_snout.queue_free()

	var ray_wing_flat: RayRig = RayRigScript.new()
	add_child(ray_wing_flat)
	ray_wing_flat.set_parameters({
		"wing_curve": 0.0,
		"base_color": "#5aaeb7"
	})
	var ray_wing_curved: RayRig = RayRigScript.new()
	add_child(ray_wing_curved)
	ray_wing_curved.set_parameters({
		"wing_curve": 0.12,
		"base_color": "#5aaeb7"
	})
	var flat_wing_shell := ray_wing_flat.get_node("DiscBody/BodyMesh") as MeshInstance3D
	var curved_wing_shell := ray_wing_curved.get_node("DiscBody/BodyMesh") as MeshInstance3D
	assert(_grid_vertex(curved_wing_shell, 8, 16).y > _grid_vertex(flat_wing_shell, 8, 16).y + 0.01)
	ray_wing_flat.queue_free()
	ray_wing_curved.queue_free()

	var ray_tail_manta: RayRig = RayRigScript.new()
	add_child(ray_tail_manta)
	ray_tail_manta.set_parameters({
		"ray_tail_style": "manta_thread",
		"tail_length": 1.0,
		"tail_thickness": 0.06,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var manta_tail_pivot := ray_tail_manta.get_node("DiscBody/TailPivot1/TailPivot2") as Node3D
	var manta_tail_mesh := ray_tail_manta.get_node("DiscBody/TailPivot1/Tail1") as MeshInstance3D

	var ray_tail_skate: RayRig = RayRigScript.new()
	add_child(ray_tail_skate)
	ray_tail_skate.set_parameters({
		"ray_tail_style": "stout_skate",
		"tail_length": 1.0,
		"tail_thickness": 0.06,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var skate_tail_pivot := ray_tail_skate.get_node("DiscBody/TailPivot1/TailPivot2") as Node3D
	var skate_tail_mesh := ray_tail_skate.get_node("DiscBody/TailPivot1/Tail1") as MeshInstance3D
	assert(manta_tail_pivot.position.x > skate_tail_pivot.position.x)
	assert(_mesh_max_abs_y(skate_tail_mesh) * skate_tail_mesh.scale.y > _mesh_max_abs_y(manta_tail_mesh) * manta_tail_mesh.scale.y)
	ray_tail_manta.queue_free()
	ray_tail_skate.queue_free()

	var ray_tail_details: RayRig = RayRigScript.new()
	add_child(ray_tail_details)
	ray_tail_details.set_parameters({
		"ray_tail_spine_enabled": true,
		"ray_dorsal_tail_fins": true,
		"tail_length": 1.0,
		"tail_thickness": 0.06,
		"base_color": "#5aaeb7"
	})
	await get_tree().process_frame
	await get_tree().process_frame
	assert(ray_tail_details.get_node_or_null("DiscBody/TailPivot1/TailSpine") != null)
	assert(ray_tail_details.get_node_or_null("DiscBody/TailPivot1/TailDorsalFin1") != null)
	assert(ray_tail_details.get_node_or_null("DiscBody/TailPivot1/TailPivot2/TailDorsalFin2") != null)
	ray_tail_details.queue_free()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/shell_rig.ok", FileAccess.WRITE)
	file.store_string("shell nodes present")
	file.close()
	print("SHELL_RIG_TEST_OK")
	get_tree().quit(0)

func _last_vertex(mesh_instance: MeshInstance3D) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() > 152:
		return vertices[152] # Wingtip vertex for unified grid mesh
	return vertices[vertices.size() - 1]

func _grid_vertex(mesh_instance: MeshInstance3D, col: int, row: int) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices[col * 17 + row]

func _mesh_max_abs_y(mesh_instance: MeshInstance3D) -> float:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var max_y := 0.0
	for vertex in vertices:
		max_y = maxf(max_y, absf(vertex.y))
	return max_y

func _mesh_min_x(mesh_instance: MeshInstance3D) -> float:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_x := INF
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
	return min_x

func _ring_center(mesh_instance: MeshInstance3D, ring_index: int, segments: int) -> Vector3:
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var center := Vector3.ZERO
	for segment in segments:
		center += vertices[ring_index * segments + segment]
	return center / float(segments)
