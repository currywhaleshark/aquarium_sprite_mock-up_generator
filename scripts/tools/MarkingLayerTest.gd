extends Node

const SpeciesMarkingLayerScript := preload("res://scripts/species/SpeciesMarkingLayer.gd")
const ToonMaterialFactoryScript := preload("res://scripts/materials/ToonMaterialFactory.gd")

func _ready() -> void:
	_test_marking_layer_encoder_limits_and_normalizes()
	_test_marking_layer_region_and_blend_fields()
	_test_invalid_region_and_blend_use_safe_defaults()
	_test_legacy_zone_defaults_preserve_existing_body_behavior()
	_test_body_material_receives_marking_uniforms()
	_test_shader_contains_marking_mask_path()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/marking_layer.ok", FileAccess.WRITE)
	file.store_string("species marking layers encoded for body shader")
	file.close()
	print("MARKING_LAYER_TEST_OK")
	get_tree().quit(0)

func _test_marking_layer_encoder_limits_and_normalizes() -> void:
	var raw_layers := [
		{"type": "lateral_line", "zone": "body", "color": "#22d8ff", "x_start": -0.2, "x_end": 1.2, "y": 0.12, "thickness": 0.04, "emissive": 0.75},
		{"type": "horizontal_band", "zone": "body", "color": "#e93a3a", "x_start": 0.48, "x_end": 0.96, "y": -0.12, "thickness": 0.08, "emissive": 0.15},
		{"type": "unknown", "zone": "body", "color": "#ffffff"},
		{"type": "vertical_bar", "zone": "body", "color": "#111111", "x_start": 0.1, "x_end": 0.2, "y": 0.0, "thickness": 0.05},
		{"type": "caudal_spot", "zone": "body", "color": "#222222", "x_start": 0.8, "x_end": 0.9, "y": 0.0, "thickness": 0.05},
		{"type": "head_mask", "zone": "head", "color": "#333333", "x_start": 0.0, "x_end": 0.2, "y": 0.0, "thickness": 0.05},
		{"type": "saddle", "zone": "body", "color": "#444444", "x_start": 0.2, "x_end": 0.4, "y": 0.4, "thickness": 0.12},
		{"type": "ocellus", "zone": "body", "color": "#555555", "x_start": 0.74, "x_end": 0.84, "y": 0.0, "thickness": 0.08},
		{"type": "calico_patch", "zone": "body", "color": "#666666", "x_start": 0.3, "x_end": 0.6, "y": -0.1, "thickness": 0.2},
		{"type": "scale_grid", "zone": "body", "color": "#777777", "x_start": 0.0, "x_end": 1.0, "y": 0.0, "thickness": 0.02}
	]
	var encoded := SpeciesMarkingLayerScript.encode_uniforms(raw_layers)
	assert(int(encoded.get("marking_count", 0)) == 8)
	assert(int(encoded.get("marking_type_0", 0)) == SpeciesMarkingLayerScript.TYPE_LATERAL_LINE)
	assert(encoded.get("marking_color_0") is Color)
	var rect0: Vector4 = encoded.get("marking_rect_0")
	assert(abs(rect0.x - 0.0) < 0.001)
	assert(abs(rect0.y - 1.0) < 0.001)
	assert(abs(rect0.z - 0.12) < 0.001)
	assert(abs(rect0.w - 0.04) < 0.001)
	var params0: Vector4 = encoded.get("marking_params_0")
	assert(abs(params0.z - 0.75) < 0.001)

func _test_marking_layer_region_and_blend_fields() -> void:
	var encoded := SpeciesMarkingLayerScript.encode_uniforms([
		{
			"type": "region_color",
			"zone": "body",
			"region": "dorsal_flank",
			"blend_mode": "multiply",
			"color": "#112233",
			"x_start": 0.2,
			"x_end": 0.8,
			"y": 0.35,
			"thickness": 0.4,
			"intensity": 0.65,
			"softness": 0.08
		},
		{
			"type": "scale_region",
			"zone": "body",
			"region": "flank",
			"blend_mode": "normal",
			"intensity": 0.8
		},
		{
			"type": "iridescence_region",
			"zone": "body",
			"region": "ventral_flank",
			"blend_mode": "add",
			"intensity": 0.45
		}
	])
	assert(int(encoded.get("marking_count", 0)) == 3)
	assert(int(encoded.get("marking_type_0", 0)) == SpeciesMarkingLayerScript.TYPE_REGION_COLOR)
	assert(int(encoded.get("marking_region_0", -1)) == SpeciesMarkingLayerScript.REGION_DORSAL_FLANK)
	assert(int(encoded.get("marking_blend_0", -1)) == SpeciesMarkingLayerScript.BLEND_MULTIPLY)
	assert(int(encoded.get("marking_type_1", 0)) == SpeciesMarkingLayerScript.TYPE_SCALE_REGION)
	assert(int(encoded.get("marking_region_1", -1)) == SpeciesMarkingLayerScript.REGION_FLANK)
	assert(int(encoded.get("marking_type_2", 0)) == SpeciesMarkingLayerScript.TYPE_IRIDESCENCE_REGION)
	assert(int(encoded.get("marking_region_2", -1)) == SpeciesMarkingLayerScript.REGION_VENTRAL_FLANK)
	assert(int(encoded.get("marking_blend_2", -1)) == SpeciesMarkingLayerScript.BLEND_ADD)

func _test_invalid_region_and_blend_use_safe_defaults() -> void:
	var encoded := SpeciesMarkingLayerScript.encode_uniforms([
		{
			"type": "lateral_line",
			"zone": "body",
			"region": "not_a_region",
			"blend_mode": "not_a_blend",
			"color": "#22d8ff"
		}
	])
	assert(int(encoded.get("marking_count", 0)) == 1)
	assert(int(encoded.get("marking_region_0", -1)) == SpeciesMarkingLayerScript.REGION_BODY)
	assert(int(encoded.get("marking_blend_0", -1)) == SpeciesMarkingLayerScript.BLEND_NORMAL)

func _test_legacy_zone_defaults_preserve_existing_body_behavior() -> void:
	var encoded := SpeciesMarkingLayerScript.encode_uniforms([
		{"type": "head_mask", "zone": "head", "color": "#223344"},
		{"type": "fin_edge", "zone": "fin", "color": "#445566"}
	])
	assert(int(encoded.get("marking_count", 0)) == 2)
	assert(int(encoded.get("marking_region_0", -1)) == SpeciesMarkingLayerScript.REGION_BODY)
	assert(int(encoded.get("marking_region_1", -1)) == SpeciesMarkingLayerScript.REGION_FIN)

func _test_body_material_receives_marking_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_body_material({
		"base_color": "#112233",
		"belly_color": "#445566",
		"marking_layers": [
			{"type": "lateral_line", "zone": "body", "color": "#22d8ff", "x_start": 0.04, "x_end": 0.84, "y": 0.1, "thickness": 0.035, "emissive": 0.75},
			{"type": "horizontal_band", "zone": "body", "color": "#e93a3a", "x_start": 0.48, "x_end": 0.96, "y": -0.12, "thickness": 0.08, "emissive": 0.15}
		]
	})
	assert(int(material.get_shader_parameter("marking_count")) == 2)
	assert(int(material.get_shader_parameter("marking_type_0")) == SpeciesMarkingLayerScript.TYPE_LATERAL_LINE)
	assert(material.get_shader_parameter("marking_color_0") is Color)
	assert(material.get_shader_parameter("marking_rect_0") is Vector4)
	assert(material.get_shader_parameter("marking_params_0") is Vector4)
	assert(int(material.get_shader_parameter("marking_type_1")) == SpeciesMarkingLayerScript.TYPE_HORIZONTAL_BAND)

func _test_shader_contains_marking_mask_path() -> void:
	var shader := load(ToonMaterialFactoryScript.BODY_SHADER_PATH)
	assert(shader is Shader)
	var code := String(shader.code)
	assert(code.contains("marking_layer_mask"))
	assert(code.contains("marking_count"))
	assert(code.contains("marking_type_0"))
