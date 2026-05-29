class_name ToonMaterialFactory
extends RefCounted

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
