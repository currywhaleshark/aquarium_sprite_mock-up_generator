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
uniform float fin_ray_count : hint_range(0.0, 32.0) = 0.0;
uniform float fin_ray_strength : hint_range(0.0, 1.0) = 0.0;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec3 col = mix(fin_gradient_color.rgb, fin_color.rgb, 1.0 - v_uv.x);
	col = mix(col, fin_tip_color.rgb, smoothstep(0.68, 1.0, v_uv.x) * fin_tip_color.a);

	float edge = 1.0 - smoothstep(fin_edge_width, fin_edge_width + 0.02, min(v_uv.y, 1.0 - v_uv.y));
	edge = max(edge, smoothstep(1.0 - fin_edge_width - 0.02, 1.0 - fin_edge_width, v_uv.x));
	col = mix(col, fin_edge_color.rgb, edge * fin_edge_color.a);

	if (fin_ray_count > 0.5 && fin_ray_strength > 0.0) {
		float ray = pow(abs(sin(v_uv.y * fin_ray_count * TAU)), 18.0);
		float ray_fade = smoothstep(0.05, 0.8, v_uv.x);
		col = mix(col, fin_edge_color.rgb, ray * ray_fade * fin_ray_strength);
	}

	ALBEDO = clamp(col, 0.0, 1.0);
	ALPHA = fin_opacity;
}
