class_name ToonMaterialFactory
extends RefCounted

const BODY_SHADER_PATH := "res://shaders/fish_body_toon.gdshader"

# Opaque toon body material shared by the body shell and the head mesh. Carries
# countershading (base/belly gradient) plus procedural patterns. Pattern type is
# stored as a string key in parameters and mapped to the shader's int here.
static func make_body_material(parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(BODY_SHADER_PATH)
	var base := _as_color(parameters.get("base_color", "#46c6cf"))
	var belly := _as_color(parameters.get("belly_color", parameters.get("base_color", "#d6fbff")))
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("belly_color", belly)
	material.set_shader_parameter("pattern_color", _as_color(parameters.get("pattern_color", "#1f5560")))
	material.set_shader_parameter("belly_height", clampf(float(parameters.get("belly_height", 0.5)), 0.0, 1.0))
	material.set_shader_parameter("belly_slope", 0.22)
	material.set_shader_parameter("pattern_type", BodyProfile.pattern_type_index(String(parameters.get("pattern_type", "none"))))
	material.set_shader_parameter("pattern_scale_x", maxf(float(parameters.get("pattern_scale_x", 6.0)), 0.0))
	material.set_shader_parameter("pattern_scale_y", maxf(float(parameters.get("pattern_scale_y", 4.0)), 0.0))
	material.set_shader_parameter("pattern_intensity", clampf(float(parameters.get("pattern_intensity", 0.7)), 0.0, 1.0))
	material.set_shader_parameter("highlight_strength", clampf(float(parameters.get("highlight_strength", 0.45)), 0.0, 1.0))
	material.set_shader_parameter("rim_strength", clampf(float(parameters.get("rim_light_strength", 0.35)), 0.0, 1.0))
	material.set_shader_parameter("roughness_value", 0.62)
	return material

static func make_surface(color_value: Variant, shadow_strength: float = 0.35, highlight_strength: float = 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := _as_color(color_value)
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.rim_enabled = true
	material.rim = clampf(highlight_strength, 0.0, 1.0)
	material.rim_tint = 0.35
	material.emission_enabled = shadow_strength < 0.05
	if material.emission_enabled:
		material.emission = color * 0.12
	return material

static func make_dark(color_value: Variant) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _as_color(color_value)
	material.roughness = 0.85
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func make_shell(color_value: Variant, alpha: float = 0.72) -> StandardMaterial3D:
	var material := make_surface(color_value, 0.28, 0.45)
	var color := _as_color(color_value)
	color.a = clampf(alpha, 0.15, 1.0)
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

static func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_STRING:
		return Color.html(value)
	return Color(0.8, 0.9, 1.0, 1.0)
