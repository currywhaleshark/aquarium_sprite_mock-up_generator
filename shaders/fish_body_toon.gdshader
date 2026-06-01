// Opaque toon body shader for the procedural fish rig.
// Reuses Godot's built-in toon diffuse while adding back-to-belly countershading
// and seamless procedural patterns. The body shell and the head mesh share this
// material, so colours and patterns flow continuously across the neck.
//
// All coordinates come from the mesh UV (topological), never from world/model
// position. This keeps the pattern painted on the surface, so it bends, turns,
// and rolls WITH the body instead of sliding (shimmering) when the fish manoeuvres.
//   U (UV.x) = longitudinal, snout(0) to tail(1).
//   V (UV.y) = circumference; seam-duplicated so patterns wrap with no seam.
// "Up" for countershading is derived from V: sin(V*TAU) is +1 at the back and
// -1 at the belly, so the gradient rolls with the body.
shader_type spatial;
render_mode diffuse_toon, specular_schlick_ggx, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.27, 0.78, 0.81, 1.0);
uniform vec4 belly_color : source_color = vec4(0.84, 0.98, 1.0, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.12, 0.33, 0.38, 1.0);

uniform float belly_height : hint_range(0.0, 1.0) = 0.5;
uniform float belly_slope : hint_range(0.02, 1.0) = 0.22;

uniform int pattern_type = 0;
uniform float pattern_scale_x = 6.0;
uniform float pattern_scale_y = 4.0;
uniform float pattern_intensity : hint_range(0.0, 1.0) = 0.7;

uniform float highlight_strength : hint_range(0.0, 1.0) = 0.45;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.62;

varying float v_long;
varying float v_circ;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// Value noise that is periodic along the V (y) axis with the given integer
// period, so circumferential patterns have no visible seam at V = 0 / V = 1.
float pnoise(vec2 p, float per) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(vec2(i.x, mod(i.y, per)));
	float b = hash21(vec2(i.x + 1.0, mod(i.y, per)));
	float c = hash21(vec2(i.x, mod(i.y + 1.0, per)));
	float d = hash21(vec2(i.x + 1.0, mod(i.y + 1.0, per)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float pfbm(vec2 p, float per) {
	float total = 0.0;
	float amp = 0.5;
	float pr = per;
	for (int k = 0; k < 4; k++) {
		total += pnoise(p, pr) * amp;
		p *= 2.0;
		pr *= 2.0;
		amp *= 0.5;
	}
	return total;
}

float pattern_mask(int kind, float u, float v) {
	float sx = max(pattern_scale_x, 0.0001);
	float per = max(1.0, floor(pattern_scale_y + 0.5));
	if (kind == 1) {
		// Vertical stripes, wobbled for organic waviness.
		float wob = (pnoise(vec2(u * sx * 0.5, v * per), per) - 0.5) * 0.5;
		float s = 0.5 + 0.5 * sin((u * sx + wob) * TAU);
		return smoothstep(0.45, 0.55, s);
	}
	if (kind == 2) {
		// Horizontal stripes, periodic in V.
		float s = 0.5 + 0.5 * sin(v * per * TAU);
		return smoothstep(0.45, 0.55, s);
	}
	if (kind == 3) {
		// Spots.
		float n = pnoise(vec2(u * sx, v * per), per);
		return smoothstep(0.62, 0.74, n);
	}
	if (kind == 4) {
		// Zebra: noise-warped hard stripes.
		float warp = (pfbm(vec2(u * sx * 0.3, v * per), per) - 0.5) * 1.2;
		float s = sin((u * sx + warp) * TAU);
		return smoothstep(-0.05, 0.05, s);
	}
	if (kind == 5) {
		// Marbled turbulence.
		float n = pfbm(vec2(u * sx, v * per), per);
		float m = 0.5 + 0.5 * sin((u * sx * 0.5 + n * 3.0) * TAU);
		return smoothstep(0.4, 0.6, m);
	}
	return 0.0;
}

void vertex() {
	v_long = UV.x;
	v_circ = UV.y;
}

void fragment() {
	// V maps around the tube: +1 at the back/dorsal, -1 at the belly. Using it
	// (not world Y) keeps the gradient attached to the body as it rolls.
	float up = sin(v_circ * TAU);
	float vfrac = 0.5 + 0.5 * up;
	float belly_t = smoothstep(belly_height - belly_slope, belly_height + belly_slope, vfrac);
	vec3 body_col = mix(belly_color.rgb, base_color.rgb, belly_t);

	float mask = pattern_mask(pattern_type, v_long, v_circ);
	vec3 col = mix(body_col, pattern_color.rgb, mask * pattern_intensity);

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = clamp(0.1 + 0.5 * highlight_strength, 0.0, 1.0);
	RIM = rim_strength;
	RIM_TINT = 0.3;
}
