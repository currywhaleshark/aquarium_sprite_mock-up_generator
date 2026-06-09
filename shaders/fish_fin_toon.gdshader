// Unshaded fin shader for readable aquarium sprites.
// UV.x runs root->tip and UV.y runs lower->upper within the fin bounds.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 fin_color : source_color = vec4(0.49, 0.88, 0.91, 1.0);
uniform vec4 fin_edge_color : source_color = vec4(0.08, 0.14, 0.17, 1.0);
uniform vec4 fin_tip_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
uniform vec4 fin_gradient_color : source_color = vec4(0.49, 0.88, 0.91, 1.0);
uniform float fin_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float fin_edge_width : hint_range(0.0, 0.25) = 0.035;
uniform float fin_ray_count : hint_range(0.0, 48.0) = 0.0;
uniform float fin_ray_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_style_id : hint_range(0.0, 5.0) = 0.0;
uniform float fin_ray_axis : hint_range(0.0, 2.0) = 0.0;
uniform float fin_ray_root_bias : hint_range(-1.0, 1.0) = 0.0;
uniform float fin_ray_spread : hint_range(0.0, 1.0) = 0.75;
uniform float fin_spine_count : hint_range(0.0, 12.0) = 0.0;
uniform float fin_spine_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_branching : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_segmentation : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_irregularity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fin_body_color : source_color = vec4(0.49, 0.88, 0.91, 1.0);
uniform float fin_color_blend : hint_range(0.0, 1.0) = 0.0;
uniform float fin_translucency_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fin_tornness : hint_range(0.0, 1.0) = 0.0;
uniform float fin_trailing_threads : hint_range(0.0, 1.0) = 0.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453);
}

float repeated_line(float coord, float count, float width) {
	float scaled = coord * max(count, 1.0);
	float cell = abs(fract(scaled) - 0.5);
	float aa = max(fwidth(scaled), 0.001);
	return 1.0 - smoothstep(width, width + aa, cell);
}

float ray_coordinate(vec2 uv) {
	if (fin_ray_axis < 0.5) {
		vec2 root = vec2(0.0, 0.5 + fin_ray_root_bias * 0.35);
		float angle = atan(uv.y - root.y, max(uv.x, 0.001));
		float radial_coord = clamp((angle / PI) + 0.5, 0.0, 1.0);
		return mix(uv.y, radial_coord, fin_ray_spread);
	}
	float root_y = fin_ray_axis < 1.5 ? 0.0 : 1.0;
	float distance_from_root = fin_ray_axis < 1.5 ? uv.y : 1.0 - uv.y;
	vec2 root = vec2(0.5 + fin_ray_root_bias * 0.35, root_y);
	float angle = atan(uv.x - root.x, max(distance_from_root, 0.001));
	float radial_coord = clamp((angle / PI) + 0.5, 0.0, 1.0);
	return mix(uv.x, radial_coord, fin_ray_spread);
}

float ray_distance(vec2 uv) {
	if (fin_ray_axis < 0.5) {
		return uv.x;
	}
	if (fin_ray_axis < 1.5) {
		return uv.y;
	}
	return 1.0 - uv.y;
}

void fragment() {
	vec3 col = mix(fin_gradient_color.rgb, fin_color.rgb, 1.0 - v_uv.x);
	col = mix(col, fin_tip_color.rgb, smoothstep(0.68, 1.0, v_uv.x) * fin_tip_color.a);
	col = mix(col, fin_body_color.rgb, fin_color_blend * fin_body_color.a);

	float edge = 1.0 - smoothstep(fin_edge_width, fin_edge_width + 0.02, min(v_uv.y, 1.0 - v_uv.y));
	edge = max(edge, smoothstep(1.0 - fin_edge_width - 0.02, 1.0 - fin_edge_width, v_uv.x));
	col = mix(col, fin_edge_color.rgb, edge * fin_edge_color.a);

	if (fin_ray_count > 0.5 && fin_ray_strength > 0.0) {
		float legacy_ray = pow(abs(sin(v_uv.y * fin_ray_count * TAU)), 18.0);
		float coord = ray_coordinate(v_uv);
		float organic = (hash11(floor(coord * fin_ray_count)) - 0.5) * fin_ray_irregularity * 0.06;
		float soft_ray = repeated_line(coord + organic, fin_ray_count, 0.45);
		float dist = ray_distance(v_uv);
		float branch_offset = smoothstep(0.55, 1.0, dist) * fin_ray_branching * 0.035;
		float branch_ray = max(
			repeated_line(coord + branch_offset, fin_ray_count, 0.44),
			repeated_line(coord - branch_offset, fin_ray_count, 0.44)
		);
		float segment = repeated_line(dist, mix(8.0, 18.0, dist), 0.42) * fin_ray_segmentation;
		float ray = legacy_ray;
		if (fin_ray_style_id > 0.5) {
			ray = mix(soft_ray, branch_ray, fin_ray_branching);
			ray = max(ray, segment * ray * 0.45);
		}
		float ray_fade = smoothstep(0.05, 0.8, dist);
		col = mix(col, fin_edge_color.rgb, ray * ray_fade * fin_ray_strength);
	}

	if (fin_spine_count > 0.5 && fin_spine_strength > 0.0) {
		float coord = ray_coordinate(v_uv);
		float spine_zone = 1.0 - smoothstep(0.35, 0.85, coord);
		float spine = repeated_line(coord, fin_spine_count, 0.38) * spine_zone;
		col = mix(col, fin_edge_color.rgb, spine * fin_spine_strength);
	}

	float backlight = smoothstep(0.45, 1.0, v_uv.x) * (1.0 - smoothstep(0.0, 0.18, min(v_uv.y, 1.0 - v_uv.y)));
	col += fin_translucency_strength * backlight * fin_tip_color.rgb * 0.45;

	float thread_mask = 0.0;
	if (fin_trailing_threads > 0.0) {
		thread_mask = pow(abs(sin(v_uv.y * max(fin_ray_count, 6.0) * TAU)), 30.0) * smoothstep(0.62, 1.0, v_uv.x);
		col = mix(col, fin_tip_color.rgb, thread_mask * fin_trailing_threads);
	}

	float torn_noise = sin(v_uv.y * 37.0 + v_uv.x * 11.0) * 0.5 + 0.5;
	float torn_cut = smoothstep(1.0 - fin_tornness * 0.35, 1.0, v_uv.x + torn_noise * fin_tornness * 0.2);
	float alpha = fin_opacity * (1.0 - torn_cut * fin_tornness * (1.0 - thread_mask * 0.65));

	ALBEDO = clamp(col, 0.0, 1.0);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
