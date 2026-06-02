extends Node

const PrimitiveFactoryScript := preload("res://scripts/creature/PrimitiveFactory.gd")
const ToonMaterialFactoryScript := preload("res://scripts/materials/ToonMaterialFactory.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

func _ready() -> void:
	_test_body_shell_uvs()
	_test_head_uvs()
	_test_shader_compiles_and_uniforms()
	_test_preset_round_trip()
	_test_visual_defaults_injected()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/pattern.ok", FileAccess.WRITE)
	file.store_string("patterns and colors verified")
	file.close()
	print("PATTERN_TEST_OK")
	get_tree().quit(0)

func _test_body_shell_uvs() -> void:
	var profile: Array[Vector3] = [
		Vector3(-0.6, 0.2, 0.15),
		Vector3(-0.2, 0.42, 0.34),
		Vector3(0.2, 0.34, 0.28),
		Vector3(0.6, 0.12, 0.08)
	]
	var segments := 8
	var mesh := PrimitiveFactoryScript.build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(uvs.size() > 0)
	assert(uvs.size() == verts.size())
	# Each ring carries a duplicated seam column (segments + 1) so V wraps cleanly.
	assert(verts.size() == profile.size() * (segments + 1))
	# The seam column reaches V == 1.0 while the first column is V == 0.0.
	assert(abs(uvs[0].y - 0.0) < 0.0001)
	assert(abs(uvs[segments].y - 1.0) < 0.0001)

	# The bent rebuild path must also carry UVs (it animates every frame).
	var centers := PackedVector3Array()
	for p in profile:
		centers.append(Vector3(p.x, 0.0, 0.0))
	var bent := PrimitiveFactoryScript.build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, centers, PackedFloat32Array())
	var bent_uvs: PackedVector2Array = bent.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert(bent_uvs.size() == profile.size() * (segments + 1))

func _test_head_uvs() -> void:
	var mesh := PrimitiveFactoryScript.deformed_head_mesh("rounded", 0.0, 0.35, 8, 12)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(uvs.size() > 0)
	assert(uvs.size() == verts.size())

func _test_shader_compiles_and_uniforms() -> void:
	var shader := load(ToonMaterialFactoryScript.BODY_SHADER_PATH)
	assert(shader is Shader)
	assert(String(shader.code).length() > 0)

	var material := ToonMaterialFactoryScript.make_body_material({
		"base_color": "#112233",
		"belly_color": "#445566",
		"pattern_color": "#aabbcc",
		"pattern_type": "spots",
		"pattern_scale_x": 7.0,
		"pattern_scale_y": 5.0,
		"pattern_intensity": 0.5,
		"belly_height": 0.3,
		"belly_slope": 0.4,
		"iridescence_strength": 0.6,
		"iridescence_color": "#ccddee",
		"iridescence_frequency": 3.5,
		"wetness": 0.8,
		"scale_strength": 0.36,
		"scale_size": 18.0,
		"lateral_line_strength": 0.41,
		"pearlscale_strength": 0.22,
		"metallic_scale_strength": 0.33,
		"emissive_marking_strength": 0.44,
		"body_height": 0.6,
		"body_length": 1.3
	})
	assert(material is ShaderMaterial)
	assert(material.shader is Shader)
	assert(int(material.get_shader_parameter("pattern_type")) == 3)
	assert(abs(float(material.get_shader_parameter("pattern_scale_x")) - 7.0) < 0.0001)
	assert(abs(float(material.get_shader_parameter("pattern_intensity")) - 0.5) < 0.0001)
	assert(abs(float(material.get_shader_parameter("belly_height")) - 0.3) < 0.0001)
	assert(abs(float(material.get_shader_parameter("belly_slope")) - 0.4) < 0.0001)
	assert(abs(float(material.get_shader_parameter("iridescence_strength")) - 0.6) < 0.0001)
	assert(material.get_shader_parameter("iridescence_color") is Color)
	assert(abs(float(material.get_shader_parameter("iridescence_frequency")) - 3.5) < 0.0001)
	assert(abs(float(material.get_shader_parameter("wetness")) - 0.8) < 0.0001)
	assert(abs(float(material.get_shader_parameter("scale_strength")) - 0.36) < 0.0001)
	assert(abs(float(material.get_shader_parameter("scale_size")) - 18.0) < 0.0001)
	assert(abs(float(material.get_shader_parameter("lateral_line_strength")) - 0.41) < 0.0001)
	assert(abs(float(material.get_shader_parameter("pearlscale_strength")) - 0.22) < 0.0001)
	assert(abs(float(material.get_shader_parameter("metallic_scale_strength")) - 0.33) < 0.0001)
	assert(abs(float(material.get_shader_parameter("emissive_marking_strength")) - 0.44) < 0.0001)
	assert(material.get_shader_parameter("base_color") is Color)
	assert(material.get_shader_parameter("belly_color") is Color)
	assert(material.get_shader_parameter("pattern_color") is Color)

	# pattern_type names map to stable indices for the shader.
	assert(BodyProfileScript.pattern_type_index("none") == 0)
	assert(BodyProfileScript.pattern_type_index("marbled") == 5)
	assert(BodyProfileScript.pattern_type_index("reticulated") == 6)
	assert(BodyProfileScript.pattern_type_index("not_a_pattern") == 0)
	assert(BodyProfileScript.pattern_type_names().size() == 7)

func _test_preset_round_trip() -> void:
	var params := {
		"body_length": 1.2,
		"body_height": 0.5,
		"base_color": "#46c6cf",
		"belly_color": "#d6fbff",
		"pattern_type": "zebra",
		"pattern_color": "#203040",
		"pattern_scale_x": 9.0,
		"pattern_scale_y": 5.0,
		"pattern_intensity": 0.42,
		"belly_height": 0.35,
		"belly_slope": 0.18,
		"iridescence_strength": 0.55,
		"iridescence_color": "#aabbcc",
		"iridescence_frequency": 4.0,
		"wetness": 0.65,
		"scale_strength": 0.3,
		"scale_size": 15.0,
		"lateral_line_strength": 0.25,
		"pearlscale_strength": 0.2,
		"metallic_scale_strength": 0.4,
		"emissive_marking_strength": 0.45
	}
	var split := BodyProfileScript.split_parameters_into_profiles(params, {"name": "round_trip"})
	var visual: Dictionary = split.get("visual_profile", {})
	assert(String(visual.get("pattern_type", "")) == "zebra")
	assert(String(visual.get("pattern_color", "")) == "#203040")
	assert(abs(float(visual.get("pattern_scale_x", 0.0)) - 9.0) < 0.0001)
	assert(abs(float(visual.get("pattern_scale_y", 0.0)) - 5.0) < 0.0001)
	assert(abs(float(visual.get("pattern_intensity", 0.0)) - 0.42) < 0.0001)
	assert(abs(float(visual.get("belly_height", 0.0)) - 0.35) < 0.0001)
	assert(abs(float(visual.get("belly_slope", 0.0)) - 0.18) < 0.0001)
	assert(abs(float(visual.get("iridescence_strength", 0.0)) - 0.55) < 0.0001)
	assert(String(visual.get("iridescence_color", "")) == "#aabbcc")
	assert(abs(float(visual.get("iridescence_frequency", 0.0)) - 4.0) < 0.0001)
	assert(abs(float(visual.get("wetness", 0.0)) - 0.65) < 0.0001)
	assert(abs(float(visual.get("scale_strength", 0.0)) - 0.3) < 0.0001)
	assert(abs(float(visual.get("scale_size", 0.0)) - 15.0) < 0.0001)
	assert(abs(float(visual.get("lateral_line_strength", 0.0)) - 0.25) < 0.0001)
	assert(abs(float(visual.get("pearlscale_strength", 0.0)) - 0.2) < 0.0001)
	assert(abs(float(visual.get("metallic_scale_strength", 0.0)) - 0.4) < 0.0001)
	assert(abs(float(visual.get("emissive_marking_strength", 0.0)) - 0.45) < 0.0001)

	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(String(rebuilt.get("pattern_type", "")) == "zebra")
	assert(abs(float(rebuilt.get("pattern_scale_x", 0.0)) - 9.0) < 0.0001)
	assert(abs(float(rebuilt.get("belly_height", 0.0)) - 0.35) < 0.0001)
	assert(abs(float(rebuilt.get("belly_slope", 0.0)) - 0.18) < 0.0001)
	assert(abs(float(rebuilt.get("iridescence_strength", 0.0)) - 0.55) < 0.0001)
	assert(abs(float(rebuilt.get("scale_strength", 0.0)) - 0.3) < 0.0001)
	assert(abs(float(rebuilt.get("metallic_scale_strength", 0.0)) - 0.4) < 0.0001)

func _test_visual_defaults_injected() -> void:
	# A preset saved before this feature has no pattern keys; defaults must appear
	# so the controls show up in the parameter panel.
	var legacy := BodyProfileScript.make_parameters_from_structured_preset({
		"name": "legacy",
		"global": {"body_length": 1.2, "body_height": 0.5},
		"visual_profile": {"base_color": "#46c6cf"}
	})
	assert(String(legacy.get("pattern_type", "")) == "none")
	assert(legacy.has("pattern_color"))
	assert(legacy.has("pattern_scale_x"))
	assert(legacy.has("pattern_intensity"))
	assert(legacy.has("belly_height"))
	assert(legacy.has("belly_slope"))
	assert(legacy.has("iridescence_strength"))
	assert(legacy.has("iridescence_color"))
	assert(legacy.has("iridescence_frequency"))
	assert(legacy.has("wetness"))
	assert(legacy.has("scale_strength"))
	assert(legacy.has("scale_size"))
	assert(legacy.has("lateral_line_strength"))
	assert(legacy.has("pearlscale_strength"))
	assert(legacy.has("metallic_scale_strength"))
	assert(legacy.has("emissive_marking_strength"))
