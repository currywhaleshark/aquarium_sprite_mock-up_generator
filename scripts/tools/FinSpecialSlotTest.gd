extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	_test_adipose_fin_uses_rayless_material_and_safe_position()
	_test_finlets_use_rayless_material_and_animated_anchors()
	_test_finlet_spacing_controls_anchor_span()
	_test_rayed_adipose_preserves_slot_opacity()
	_test_enabled_special_slots_have_visible_defaults()
	_test_special_slot_shapes_affect_geometry()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_special_slot.ok", FileAccess.WRITE)
	file.store_string("special fin slots verified")
	file.close()
	print("FIN_SPECIAL_SLOT_TEST_OK")
	get_tree().quit(0)

func _test_adipose_fin_uses_rayless_material_and_safe_position() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"fin_ray_style": "mixed",
		"fin_ray_count": 24.0,
		"fin_ray_strength": 0.8,
		"dorsal_2_enabled": true,
		"dorsal_2_attach_t": 0.68,
		"adipose_fin_enabled": true,
		"adipose_fin_size": 0.25,
		"adipose_fin_position": 0.70,
		"adipose_fin_rayed": 0.0
	})
	await get_tree().process_frame
	var adipose := fish.get_node_or_null("BodyPivot/AdiposeFin") as MeshInstance3D
	assert(adipose != null)
	assert(adipose.material_override is ShaderMaterial)
	assert(abs(float(adipose.material_override.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	assert(adipose.position.x > 0.0)
	assert(_mesh_y_span(adipose) > _mesh_x_span(adipose))
	fish.queue_free()

func _test_finlets_use_rayless_material_and_animated_anchors() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = true
	fish.set_parameters({
		"body_wave_amount": 0.35,
		"fin_ray_style": "fan",
		"fin_ray_count": 24.0,
		"fin_ray_strength": 0.8,
		"finlet_enabled": true,
		"finlet_dorsal_count": 4.0,
		"finlet_ventral_count": 4.0,
		"finlet_size": 0.22,
		"finlet_pitch": 0.25
	})
	await get_tree().process_frame
	var first := fish.get_node_or_null("BodyPivot/FinletDorsal_0") as MeshInstance3D
	var ventral := fish.get_node_or_null("BodyPivot/FinletVentral_0") as MeshInstance3D
	assert(first != null)
	assert(ventral != null)
	assert(first.material_override is ShaderMaterial)
	assert(abs(float(first.material_override.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	assert(_mesh_y_span(first) > _mesh_x_span(first))
	var before := first.global_position
	fish._process(0.2)
	await get_tree().process_frame
	var after := first.global_position
	assert(before.distance_to(after) > 0.0001)
	fish.queue_free()

func _test_finlet_spacing_controls_anchor_span() -> void:
	var tight := FishRigScript.new()
	var wide := FishRigScript.new()
	add_child(tight)
	add_child(wide)
	_apply_finlet_spacing_parameters(tight, 0.0)
	_apply_finlet_spacing_parameters(wide, 1.0)
	await get_tree().process_frame
	var tight_span := _finlet_span(tight, "FinletDorsal")
	var wide_span := _finlet_span(wide, "FinletDorsal")
	assert(wide_span > tight_span + 0.02)
	tight.queue_free()
	wide.queue_free()

func _test_rayed_adipose_preserves_slot_opacity() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"fin_ray_style": "soft",
		"fin_ray_count": 8.0,
		"fin_ray_strength": 0.4,
		"adipose_fin_enabled": true,
		"adipose_fin_size": 0.25,
		"adipose_fin_opacity": 0.33,
		"adipose_fin_rayed": 0.6
	})
	await get_tree().process_frame
	var adipose := fish.get_node_or_null("BodyPivot/AdiposeFin") as MeshInstance3D
	assert(adipose != null)
	assert(adipose.material_override is ShaderMaterial)
	assert(abs(float(adipose.material_override.get_shader_parameter("fin_opacity")) - 0.33) < 0.001)
	assert(abs(float(adipose.material_override.get_shader_parameter("fin_ray_strength")) - 0.6) < 0.001)
	fish.queue_free()

func _test_enabled_special_slots_have_visible_defaults() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"adipose_fin_enabled": true,
		"finlet_enabled": true
	})
	await get_tree().process_frame
	assert(fish.get_node_or_null("BodyPivot/AdiposeFin") != null)
	assert(fish.get_node_or_null("BodyPivot/FinletDorsal_0") != null)
	assert(fish.get_node_or_null("BodyPivot/FinletVentral_0") != null)
	fish.queue_free()

func _test_special_slot_shapes_affect_geometry() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"adipose_fin_enabled": true,
		"adipose_fin_shape": "custom",
		"adipose_fin_custom_points": [-0.4, 0.0, 0.0, 1.4, 0.4, 0.0],
		"finlet_enabled": true,
		"finlet_shape": "rounded",
		"finlet_dorsal_count": 3.0,
		"finlet_ventral_count": 0.0,
		"finlet_size": 0.25
	})
	await get_tree().process_frame
	var adipose := fish.get_node_or_null("BodyPivot/AdiposeFin") as MeshInstance3D
	var finlet := fish.get_node_or_null("BodyPivot/FinletDorsal_0") as MeshInstance3D
	assert(adipose != null)
	assert(finlet != null)
	assert(_mesh_y_span(adipose) > _mesh_x_span(adipose) * 1.2)
	assert(_mesh_vertex_count(finlet) > 4)
	assert(fish.get_vector_edit_marker_world("adipose_fin", Vector2(0.0, 0.8)).is_finite())
	assert(fish.get_vector_edit_marker_world("finlet", Vector2(0.0, 0.8)).is_finite())
	fish.queue_free()

func _apply_finlet_spacing_parameters(fish: FishRig, spacing: float) -> void:
	fish.auto_animate = false
	fish.set_parameters({
		"finlet_enabled": true,
		"finlet_dorsal_count": 4.0,
		"finlet_ventral_count": 0.0,
		"finlet_size": 0.22,
		"finlet_spacing": spacing
	})

func _finlet_span(fish: FishRig, prefix: String) -> float:
	var first := fish.get_node_or_null("BodyPivot/%s_0" % prefix) as MeshInstance3D
	var last := fish.get_node_or_null("BodyPivot/%s_3" % prefix) as MeshInstance3D
	assert(first != null)
	assert(last != null)
	return abs(last.global_position.x - first.global_position.x)

func _mesh_x_span(node: MeshInstance3D) -> float:
	var arrays := node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_x := INF
	var max_x := -INF
	for vertex in vertices:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
	return max_x - min_x

func _mesh_y_span(node: MeshInstance3D) -> float:
	var arrays := node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_y := INF
	var max_y := -INF
	for vertex in vertices:
		min_y = minf(min_y, vertex.y)
		max_y = maxf(max_y, vertex.y)
	return max_y - min_y

func _mesh_vertex_count(node: MeshInstance3D) -> int:
	var arrays := node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size()
