class_name ToonMaterialFactory
extends RefCounted

const BODY_SHADER_PATH := "res://shaders/fish_body_toon.gdshader"
const FIN_SHADER_PATH := "res://shaders/fish_fin_toon.gdshader"
const SpeciesMarkingLayerScript := preload("res://scripts/species/SpeciesMarkingLayer.gd")

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
	material.set_shader_parameter("belly_slope", clampf(float(parameters.get("belly_slope", 0.22)), 0.02, 1.0))
	material.set_shader_parameter("pattern_type", BodyProfile.pattern_type_index(String(parameters.get("pattern_type", "none"))))
	material.set_shader_parameter("pattern_scale_x", maxf(float(parameters.get("pattern_scale_x", 6.0)), 0.0))
	material.set_shader_parameter("pattern_scale_y", maxf(float(parameters.get("pattern_scale_y", 4.0)), 0.0))
	material.set_shader_parameter("pattern_intensity", clampf(float(parameters.get("pattern_intensity", 0.7)), 0.0, 1.0))
	material.set_shader_parameter("iridescence_strength", clampf(float(parameters.get("iridescence_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("iridescence_color", _as_color(parameters.get("iridescence_color", "#bfe9ff")))
	material.set_shader_parameter("iridescence_frequency", clampf(float(parameters.get("iridescence_frequency", 2.0)), 0.1, 10.0))
	material.set_shader_parameter("wetness", clampf(float(parameters.get("wetness", 0.0)), 0.0, 1.0))
	var marking_uniforms := SpeciesMarkingLayerScript.encode_uniforms(parameters.get("marking_layers", []))
	for key in marking_uniforms.keys():
		material.set_shader_parameter(String(key), marking_uniforms[key])
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
	# Unshaded so fins and appendages match the flat, surface-driven body shader:
	# the whole sprite then reads consistently and renders identically regardless of
	# scene light, camera, or pose. highlight_strength/shadow_strength are retained
	# in the signature for callers but no longer drive lighting under unshaded.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

static func make_fin_material(parameters: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(FIN_SHADER_PATH)
	material.set_shader_parameter("fin_color", _as_color(parameters.get("fin_color", "#7ee1e8")))
	material.set_shader_parameter("fin_edge_color", _as_color(parameters.get("fin_edge_color", parameters.get("outline_color", "#162126"))))
	material.set_shader_parameter("fin_tip_color", _as_color(parameters.get("fin_tip_color", parameters.get("fin_color", "#d8fbff"))))
	material.set_shader_parameter("fin_gradient_color", _as_color(parameters.get("fin_gradient_color", parameters.get("fin_color", "#7ee1e8"))))
	material.set_shader_parameter("fin_opacity", clampf(float(parameters.get("fin_opacity", 1.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_edge_width", clampf(float(parameters.get("fin_edge_width", 0.035)), 0.0, 0.25))
	material.set_shader_parameter("fin_ray_count", clampf(float(parameters.get("fin_ray_count", 0.0)), 0.0, 32.0))
	material.set_shader_parameter("fin_ray_strength", clampf(float(parameters.get("fin_ray_strength", 0.0)), 0.0, 1.0))
	return material

static func make_dark(color_value: Variant) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _as_color(color_value)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Flat to match the rest of the sprite (eyes stay a crisp solid dark dot).
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
