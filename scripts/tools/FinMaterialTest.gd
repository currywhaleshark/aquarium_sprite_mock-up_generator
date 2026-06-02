extends Node

const PrimitiveFactoryScript := preload("res://scripts/creature/PrimitiveFactory.gd")
const ToonMaterialFactoryScript := preload("res://scripts/materials/ToonMaterialFactory.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

func _ready() -> void:
	_test_polygon_and_oval_fins_have_uvs()
	_test_fin_material_exposes_detail_uniforms()
	_test_fish_rig_uses_fin_material()
	_test_fin_detail_parameters_round_trip_through_fin_profile()

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
		"fin_gradient_color": "#336699"
	})
	assert(material is ShaderMaterial)
	assert(material.shader is Shader)
	assert(abs(float(material.get_shader_parameter("fin_opacity")) - 0.64) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_edge_width")) - 0.09) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 7.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.45) < 0.001)
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
		"fin_gradient_color": "#334455"
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
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(abs(float(rebuilt.get("fin_opacity", 0.0)) - 0.66) < 0.001)
	assert(String(rebuilt.get("fin_edge_color", "")) == "#111222")

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
