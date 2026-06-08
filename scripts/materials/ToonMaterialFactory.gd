class_name ToonMaterialFactory
extends RefCounted

const BODY_SHADER_PATH := "res://shaders/fish_body_toon.gdshader"
const FIN_SHADER_PATH := "res://shaders/fish_fin_toon.gdshader"
const SpeciesMarkingLayerScript := preload("res://scripts/species/SpeciesMarkingLayer.gd")
const PATTERN_REFERENCE_LENGTH := 1.45

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
	var pattern_density_scale := 1.0
	if float(parameters.get("pattern_size_lock", 0.0)) > 0.5:
		pattern_density_scale = maxf(float(parameters.get("body_length", PATTERN_REFERENCE_LENGTH)), 0.001) / PATTERN_REFERENCE_LENGTH
	material.set_shader_parameter("pattern_scale_x", maxf(float(parameters.get("pattern_scale_x", 6.0)) * pattern_density_scale, 0.0))
	material.set_shader_parameter("pattern_scale_y", maxf(float(parameters.get("pattern_scale_y", 4.0)) * pattern_density_scale, 0.0))
	material.set_shader_parameter("pattern_intensity", clampf(float(parameters.get("pattern_intensity", 0.7)), 0.0, 1.0))
	material.set_shader_parameter("pattern_invert", clampf(float(parameters.get("pattern_invert", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("pattern_seed", float(parameters.get("pattern_seed", 0.0)))
	material.set_shader_parameter("iridescence_strength", clampf(float(parameters.get("iridescence_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("iridescence_color", _as_color(parameters.get("iridescence_color", "#bfe9ff")))
	material.set_shader_parameter("iridescence_frequency", clampf(float(parameters.get("iridescence_frequency", 2.0)), 0.1, 10.0))
	material.set_shader_parameter("wetness", clampf(float(parameters.get("wetness", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("scale_type", BodyProfile.scale_type_index(String(parameters.get("scale_type", "cycloid"))))
	material.set_shader_parameter("scale_strength", clampf(float(parameters.get("scale_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("scale_size", clampf(float(parameters.get("scale_size", 16.0)), 4.0, 64.0))
	material.set_shader_parameter("lateral_line_strength", clampf(float(parameters.get("lateral_line_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("pearlscale_strength", clampf(float(parameters.get("pearlscale_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("metallic_scale_strength", clampf(float(parameters.get("metallic_scale_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("emissive_marking_strength", clampf(float(parameters.get("emissive_marking_strength", 0.0)), 0.0, 1.0))
	var marking_uniforms := SpeciesMarkingLayerScript.encode_uniforms(parameters.get("marking_layers", []))
	for key in marking_uniforms.keys():
		material.set_shader_parameter(String(key), marking_uniforms[key])
	var gill_mark := String(parameters.get("gill_mark", "none"))
	var op_on := gill_mark == "operculum"
	# Operculum is now a real flap mesh (FishRig._add_gill_mark), so the flat
	# shader-painted plate/seam/slit is disabled to avoid doubling. The uniforms
	# below are still plumbed (dormant) in case the painted form is reused.
	material.set_shader_parameter("operculum_enabled", false)
	if op_on:
		var op_size := clampf(float(parameters.get("operculum_size", 1.0)), 0.5, 1.5)
		var op_height := clampf(float(parameters.get("operculum_height", 1.0)), 0.5, 1.5)
		var posterior_u := 0.224
		var anterior_u := posterior_u - 0.085 * op_size
		material.set_shader_parameter("operculum_u", Vector2(anterior_u, posterior_u))
		material.set_shader_parameter("operculum_up", Vector2(0.0, 0.45 * op_height))
		material.set_shader_parameter("operculum_open", clampf(float(parameters.get("operculum_open", 0.0)), 0.0, 1.0))
		material.set_shader_parameter("operculum_ridge", clampf(float(parameters.get("operculum_ridge", 0.45)), 0.0, 1.0))
		material.set_shader_parameter("operculum_line_color", Color.html("#15191b"))
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

static func _fin_ray_style_id(style: String) -> float:
	match style:
		"soft":
			return 1.0
		"spiny":
			return 2.0
		"mixed":
			return 3.0
		"fan":
			return 4.0
		"threaded":
			return 5.0
		_:
			return 0.0

static func _with_overrides(parameters: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged := parameters.duplicate(true)
	for key in overrides.keys():
		merged[key] = overrides[key]
	return merged

static func make_fin_material(parameters: Dictionary, overrides: Dictionary = {}) -> ShaderMaterial:
	var effective := _with_overrides(parameters, overrides)
	var material := ShaderMaterial.new()
	material.shader = load(FIN_SHADER_PATH)
	material.set_shader_parameter("fin_color", _as_color(effective.get("fin_color", "#7ee1e8")))
	material.set_shader_parameter("fin_edge_color", _as_color(effective.get("fin_edge_color", effective.get("outline_color", "#162126"))))
	material.set_shader_parameter("fin_tip_color", _as_color(effective.get("fin_tip_color", effective.get("fin_color", "#d8fbff"))))
	material.set_shader_parameter("fin_gradient_color", _as_color(effective.get("fin_gradient_color", effective.get("fin_color", "#7ee1e8"))))
	material.set_shader_parameter("fin_opacity", clampf(float(effective.get("fin_opacity", 1.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_edge_width", clampf(float(effective.get("fin_edge_width", 0.035)), 0.0, 0.25))
	material.set_shader_parameter("fin_ray_style_id", _fin_ray_style_id(String(effective.get("fin_ray_style", "none"))))
	material.set_shader_parameter("fin_ray_count", clampf(float(effective.get("fin_ray_count", 0.0)), 0.0, 48.0))
	material.set_shader_parameter("fin_ray_strength", clampf(float(effective.get("fin_ray_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_root_bias", clampf(float(effective.get("fin_ray_root_bias", 0.0)), -1.0, 1.0))
	material.set_shader_parameter("fin_ray_spread", clampf(float(effective.get("fin_ray_spread", 0.75)), 0.0, 1.0))
	material.set_shader_parameter("fin_spine_count", clampf(float(effective.get("fin_spine_count", 0.0)), 0.0, 12.0))
	material.set_shader_parameter("fin_spine_strength", clampf(float(effective.get("fin_spine_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_branching", clampf(float(effective.get("fin_ray_branching", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_segmentation", clampf(float(effective.get("fin_ray_segmentation", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_irregularity", clampf(float(effective.get("fin_ray_irregularity", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_body_color", _as_color(effective.get("fin_body_color", effective.get("base_color", "#7ee1e8"))))
	material.set_shader_parameter("fin_color_blend", clampf(float(effective.get("fin_color_blend", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_translucency_strength", clampf(float(effective.get("fin_translucency_strength", effective.get("fin_translucency", 0.0))), 0.0, 1.0))
	material.set_shader_parameter("fin_tornness", clampf(float(effective.get("fin_tornness", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_trailing_threads", clampf(float(effective.get("fin_trailing_threads", 0.0)), 0.0, 1.0))
	return material

static func make_rayless_fin_material(parameters: Dictionary, overrides: Dictionary = {}) -> ShaderMaterial:
	var rayless := {
		"fin_ray_style": "none",
		"fin_ray_count": 0.0,
		"fin_ray_strength": 0.0,
		"fin_spine_count": 0.0,
		"fin_spine_strength": 0.0,
		"fin_ray_branching": 0.0,
		"fin_ray_segmentation": 0.0,
		"fin_ray_irregularity": 0.0,
		"fin_trailing_threads": 0.0
	}
	for key in overrides.keys():
		rayless[key] = overrides[key]
	return make_fin_material(parameters, rayless)

static func make_finlet_material(parameters: Dictionary) -> ShaderMaterial:
	return make_rayless_fin_material(parameters, {
		"fin_color_blend": clampf(float(parameters.get("finlet_color_blend", 0.5)), 0.0, 1.0)
	})

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
