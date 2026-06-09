extends Node

const PrimitiveFactoryScript := preload("res://scripts/creature/PrimitiveFactory.gd")
const ToonMaterialFactoryScript := preload("res://scripts/materials/ToonMaterialFactory.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const SpeciesMarkingLayerScript := preload("res://scripts/species/SpeciesMarkingLayer.gd")

func _ready() -> void:
	_test_polygon_and_oval_fins_have_uvs()
	_test_fin_material_exposes_detail_uniforms()
	_test_fish_rig_uses_fin_material()
	_test_fin_detail_parameters_round_trip_through_fin_profile()
	_test_fin_ray_defaults_are_injected()
	_test_new_fin_fields_round_trip_through_fin_profile()
	_test_fin_material_exposes_ray_structure_uniforms()
	_test_fin_material_receives_filtered_marking_uniforms()
	_test_fish_rig_assigns_slot_specific_ray_axes()
	_test_rayless_material_overrides_global_rays()
	_test_legacy_parallel_ray_fallback_contract()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_material.ok", FileAccess.WRITE)
	file.store_string("fin UVs and fin material detail uniforms verified")
	file.close()
	print("FIN_MATERIAL_TEST_OK")
	get_tree().quit(0)

func _test_polygon_and_oval_fins_have_uvs() -> void:
	var polygon_mesh := PrimitiveFactoryScript.build_polygon_fin_mesh(PackedVector3Array([
		Vector3(-0.5, 0.0, 0.0),
		Vector3(0.0, 0.7, 0.0),
		Vector3(0.5, 0.0, 0.0)
	]))
	_assert_mesh_has_uvs(polygon_mesh)

	var oval := PrimitiveFactoryScript.oval_fin("TestOvalFin", 0.25, 0.12, StandardMaterial3D.new(), 12)
	_assert_mesh_has_uvs(oval.mesh)
	oval.free()

func _test_fin_material_exposes_detail_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"fin_color": "#88ddff",
		"fin_opacity": 0.64,
		"fin_edge_color": "#102030",
		"fin_edge_width": 0.09,
		"fin_ray_count": 7.0,
		"fin_ray_strength": 0.45,
		"fin_tip_color": "#ffffff",
		"fin_gradient_color": "#336699",
		"fin_translucency_strength": 0.38,
		"fin_tornness": 0.22,
		"fin_trailing_threads": 0.31
	})
	assert(material is ShaderMaterial)
	assert(material.shader is Shader)
	assert(abs(float(material.get_shader_parameter("fin_opacity")) - 0.64) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_edge_width")) - 0.09) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 7.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.45) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_translucency_strength")) - 0.38) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_tornness")) - 0.22) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_trailing_threads")) - 0.31) < 0.001)
	assert(material.get_shader_parameter("fin_color") is Color)
	assert(material.get_shader_parameter("fin_edge_color") is Color)
	assert(material.get_shader_parameter("fin_tip_color") is Color)
	assert(material.get_shader_parameter("fin_gradient_color") is Color)

func _test_fish_rig_uses_fin_material() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"fin_color": "#88ddff",
		"fin_opacity": 0.72,
		"fin_edge_color": "#112233",
		"fin_edge_width": 0.08,
		"fin_ray_count": 6.0,
		"fin_ray_strength": 0.5
	})
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	assert(dorsal != null)
	assert(dorsal.material_override is ShaderMaterial)
	assert(abs(float(dorsal.material_override.get_shader_parameter("fin_opacity")) - 0.72) < 0.001)

func _test_fin_detail_parameters_round_trip_through_fin_profile() -> void:
	var params := {
		"fin_opacity": 0.66,
		"fin_edge_color": "#111222",
		"fin_edge_width": 0.07,
		"fin_ray_count": 9.0,
		"fin_ray_strength": 0.44,
		"fin_tip_color": "#ccddee",
		"fin_gradient_color": "#334455",
		"fin_translucency_strength": 0.37,
		"fin_tornness": 0.21,
		"fin_trailing_threads": 0.29,
		"fin_softness": 0.58,
		"caudal_softness": 0.82,
		"fin_rigidity": 0.16
	}
	var split := BodyProfileScript.split_parameters_into_profiles(params, {"name": "fin_detail_round_trip"})
	var fin_profile: Dictionary = split.get("fin_profile", {})
	assert(abs(float(fin_profile.get("fin_opacity", 0.0)) - 0.66) < 0.001)
	assert(String(fin_profile.get("fin_edge_color", "")) == "#111222")
	assert(abs(float(fin_profile.get("fin_edge_width", 0.0)) - 0.07) < 0.001)
	assert(abs(float(fin_profile.get("fin_ray_count", 0.0)) - 9.0) < 0.001)
	assert(abs(float(fin_profile.get("fin_ray_strength", 0.0)) - 0.44) < 0.001)
	assert(String(fin_profile.get("fin_tip_color", "")) == "#ccddee")
	assert(String(fin_profile.get("fin_gradient_color", "")) == "#334455")
	assert(abs(float(fin_profile.get("fin_translucency_strength", 0.0)) - 0.37) < 0.001)
	assert(abs(float(fin_profile.get("fin_tornness", 0.0)) - 0.21) < 0.001)
	assert(abs(float(fin_profile.get("fin_trailing_threads", 0.0)) - 0.29) < 0.001)
	assert(abs(float(fin_profile.get("fin_softness", 0.0)) - 0.58) < 0.001)
	assert(abs(float(fin_profile.get("caudal_softness", 0.0)) - 0.82) < 0.001)
	assert(abs(float(fin_profile.get("fin_rigidity", 0.0)) - 0.16) < 0.001)
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(abs(float(rebuilt.get("fin_opacity", 0.0)) - 0.66) < 0.001)
	assert(String(rebuilt.get("fin_edge_color", "")) == "#111222")
	assert(abs(float(rebuilt.get("fin_translucency_strength", 0.0)) - 0.37) < 0.001)
	assert(abs(float(rebuilt.get("caudal_softness", 0.0)) - 0.82) < 0.001)

func _test_fin_ray_defaults_are_injected() -> void:
	var params := {}
	BodyProfileScript.ensure_visual_parameters(params)
	assert(String(params.get("fin_ray_style", "")) == "none")
	assert(abs(float(params.get("fin_ray_count", -1.0)) - 0.0) < 0.001)
	assert(abs(float(params.get("fin_ray_spread", -1.0)) - 0.75) < 0.001)
	assert(abs(float(params.get("adipose_fin_position", 0.0)) - 0.82) < 0.001)
	assert(bool(params.get("finlet_enabled", true)) == false)

func _test_new_fin_fields_round_trip_through_fin_profile() -> void:
	var params := {
		"fin_ray_style": "fan",
		"fin_ray_root_bias": -0.2,
		"fin_ray_spread": 0.9,
		"fin_spine_count": 3.0,
		"fin_spine_strength": 0.4,
		"fin_ray_branching": 0.7,
		"fin_ray_segmentation": 0.5,
		"fin_ray_irregularity": 0.2,
		"adipose_fin_enabled": true,
		"adipose_fin_size": 0.32,
		"adipose_fin_position": 0.82,
		"adipose_fin_height": 0.18,
		"adipose_fin_roundness": 0.75,
		"adipose_fin_opacity": 0.72,
		"adipose_fin_rayed": 0.0,
		"finlet_enabled": true,
		"finlet_dorsal_count": 8.0,
		"finlet_ventral_count": 8.0,
		"finlet_size": 0.24,
		"finlet_taper": 0.35,
		"finlet_spacing": 0.72,
		"finlet_pitch": 0.25,
		"finlet_color_blend": 0.5
	}
	var split := BodyProfileScript.split_parameters_into_profiles(params, {"name": "new_fin_fields"})
	var fin_profile: Dictionary = split.get("fin_profile", {})
	assert(String(fin_profile.get("fin_ray_style", "")) == "fan")
	assert(abs(float(fin_profile.get("fin_ray_branching", 0.0)) - 0.7) < 0.001)
	assert(bool(fin_profile.get("adipose_fin_enabled", false)) == true)
	assert(abs(float(fin_profile.get("finlet_dorsal_count", 0.0)) - 8.0) < 0.001)
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(String(rebuilt.get("fin_ray_style", "")) == "fan")
	assert(bool(rebuilt.get("adipose_fin_enabled", false)) == true)
	assert(abs(float(rebuilt.get("finlet_ventral_count", 0.0)) - 8.0) < 0.001)

func _test_fin_material_exposes_ray_structure_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"fin_ray_style": "mixed",
		"fin_ray_count": 44.0,
		"fin_ray_strength": 0.8,
		"fin_ray_root_bias": -0.15,
		"fin_ray_spread": 0.9,
		"fin_spine_count": 4.0,
		"fin_spine_strength": 0.7,
		"fin_ray_branching": 0.45,
		"fin_ray_segmentation": 0.35,
		"fin_ray_irregularity": 0.2,
		"base_color": "#225566",
		"fin_color_blend": 0.4
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_style_id")) - 3.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 44.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_count")) - 4.0) < 0.001)
	assert(material.get_shader_parameter("fin_body_color") is Color)
	assert(abs(float(material.get_shader_parameter("fin_color_blend")) - 0.4) < 0.001)

func _test_fin_material_receives_filtered_marking_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"marking_layers": [
			{"type": "fin_spots", "region": "paired_fin", "color": "#aa8844", "intensity": 0.5},
			{"type": "horizontal_band", "region": "median_fin", "color": "#66ccff", "x_start": 0.1, "x_end": 0.8}
		]
	}, {"fin_region": "paired_fin"})
	assert(int(material.get_shader_parameter("fin_marking_count")) == 1)
	assert(int(material.get_shader_parameter("fin_marking_type_0")) == SpeciesMarkingLayerScript.TYPE_FIN_SPOTS)
	assert(material.get_shader_parameter("fin_marking_color_0") is Color)

func _test_fish_rig_assigns_slot_specific_ray_axes() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"fin_ray_style": "fan",
		"fin_ray_count": 10.0,
		"fin_ray_strength": 0.6,
		"pelvic_enabled": true,
		"adipose_fin_enabled": true,
		"adipose_fin_rayed": 0.5
	})
	await get_tree().process_frame
	assert(_fin_ray_axis(fish, "BodyPivot/DorsalFin1") == 1)
	assert(_fin_ray_axis(fish, "BodyPivot/AnalFin") == 2)
	assert(_fin_ray_axis(fish, "BodyPivot/PelvicFinL") == 2)
	assert(_fin_ray_axis(fish, "BodyPivot/PectoralFinL") == 0)
	assert(_fin_ray_axis(fish, "BodyPivot/AdiposeFin") == 1)
	assert(_fin_ray_axis(fish, "BodyPivot/TailPivot1/TailPivot2/TailFinPivot/TailFin") == 0)
	fish.queue_free()

func _test_rayless_material_overrides_global_rays() -> void:
	var material := ToonMaterialFactoryScript.make_rayless_fin_material({
		"fin_ray_style": "mixed",
		"fin_ray_count": 20.0,
		"fin_ray_strength": 0.9,
		"fin_spine_count": 6.0,
		"fin_spine_strength": 0.8
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_count")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_strength")) - 0.0) < 0.001)

func _test_legacy_parallel_ray_fallback_contract() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"fin_ray_style": "none",
		"fin_ray_count": 9.0,
		"fin_ray_strength": 0.5
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_style_id")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 9.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.5) < 0.001)

func _assert_mesh_has_uvs(mesh: Mesh) -> void:
	assert(mesh != null)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(vertices.size() > 0)
	assert(uvs.size() == vertices.size())
	var saw_nonzero := false
	for uv in uvs:
		if abs(uv.x) > 0.001 or abs(uv.y) > 0.001:
			saw_nonzero = true
	assert(saw_nonzero)

func _fin_ray_axis(fish: Node, path: String) -> int:
	var node := fish.get_node_or_null(path) as MeshInstance3D
	assert(node != null)
	assert(node.material_override is ShaderMaterial)
	return int(round(float(node.material_override.get_shader_parameter("fin_ray_axis"))))
