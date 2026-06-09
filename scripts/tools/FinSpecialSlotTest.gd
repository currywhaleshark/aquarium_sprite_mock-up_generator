extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	_test_adipose_fin_uses_rayless_material_and_safe_position()
	_test_finlets_use_rayless_material_and_animated_anchors()

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
	var before := first.global_position
	fish._process(0.2)
	await get_tree().process_frame
	var after := first.global_position
	assert(before.distance_to(after) > 0.0001)
	fish.queue_free()
