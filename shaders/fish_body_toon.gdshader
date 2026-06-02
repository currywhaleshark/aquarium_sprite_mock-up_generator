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
// Unshaded: the sprite look is decided entirely by this shader from the mesh UV,
// never from scene lighting or normals. The body shell and the head use different
// normal conventions (analytic radial vs generate_normals), so any normal/light
// dependent term (toon diffuse, specular, rim, fresnel) made them shade
// differently and clash at the neck. Driving everything from the surface (UV)
// makes head and body identical and keeps every export stable regardless of light,
// camera, pose, turn, or roll.
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.27, 0.78, 0.81, 1.0);
uniform vec4 belly_color : source_color = vec4(0.84, 0.98, 1.0, 1.0);
uniform vec4 pattern_color : source_color = vec4(0.12, 0.33, 0.38, 1.0);

uniform float belly_height : hint_range(0.0, 1.0) = 0.5;
uniform float belly_slope : hint_range(0.02, 1.0) = 0.22;

uniform int pattern_type = 0;
uniform float pattern_scale_x = 6.0;
uniform float pattern_scale_y = 4.0;
uniform float pattern_intensity : hint_range(0.0, 1.0) = 0.7;

// Iridescence (iridophores): a view-angle driven oil-slick sheen. Defaults off.
uniform float iridescence_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 iridescence_color : source_color = vec4(0.75, 0.91, 1.0, 1.0);
// How many colour bands sweep across the fresnel ramp (thin-film frequency).
uniform float iridescence_frequency : hint_range(0.1, 10.0) = 2.0;

// Wet mucus layer: a smooth clearcoat lobe over the toon body. Defaults off.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

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

// Periodic Voronoi cell-edge field. Returns ~0 along cell borders (the net) and
// larger inside cells. The Y axis wraps with 'per' so the reticulation has no
// seam at V = 0 / V = 1.
float pvoronoi_edge(vec2 p, float per) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int yy = -1; yy <= 1; yy++) {
		for (int xx = -1; xx <= 1; xx++) {
			vec2 g = vec2(float(xx), float(yy));
			vec2 cell = i + g;
			float ox = hash21(vec2(cell.x, mod(cell.y, per)));
			float oy = hash21(vec2(cell.x + 41.3, mod(cell.y, per) + 17.1));
			vec2 r = g + vec2(ox, oy) - f;
			float d = dot(r, r);
			if (d < f1) { f2 = f1; f1 = d; }
			else if (d < f2) { f2 = d; }
		}
	}
	return sqrt(f2) - sqrt(f1);
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
	if (kind == 6) {
		// Reticulated net (e.g. moray / pufferfish): Voronoi cell borders.
		float edge = pvoronoi_edge(vec2(u * sx, v * per), per);
		return 1.0 - smoothstep(0.0, 0.12, edge);
	}
	return 0.0;
}

void vertex() {
	v_long = UV.x;
	v_circ = UV.y;
}

void fragment() {
	// up: +1 at the back/dorsal, -1 at the belly, read from the UV circumference so
	// it rolls with the body and is identical on the head and the shell.
	float up = sin(v_circ * TAU);
	float vfrac = 0.5 + 0.5 * up;

	// 1. Countershading: the painted back->belly gradient is the primary form cue.
	float belly_t = smoothstep(belly_height - belly_slope, belly_height + belly_slope, vfrac);
	vec3 col = mix(belly_color.rgb, base_color.rgb, belly_t);

	// 2. Pattern overlay.
	float mask = pattern_mask(pattern_type, v_long, v_circ);
	col = mix(col, pattern_color.rgb, mask * pattern_intensity);

	// 3. Soft surface form: a gentle top->bottom shade read from the body's own up
	// vector. Surface-driven, so it gives a hint of volume without any scene light
	// and reads the same on head and body.
	col *= mix(0.86, 1.06, smoothstep(-0.9, 0.9, up));

	// 4. Wetness: darken the whole body (wet surfaces absorb more and look deeper).
	col *= mix(1.0, 0.74, wetness);

	// 5. Optional gloss accents. Iridescence hue is surface-driven (v_long bands +
	// belly->back), with only a faint fresnel edge accent so head/body stay
	// consistent; wetness adds a weak grazing sheen. Both default off.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	float irid_phase = TAU * (v_long * iridescence_frequency + 0.5 * up);
	vec3 irid = 0.5 + 0.5 * cos(irid_phase + vec3(0.0, 2.094, 4.188));
	col += irid * iridescence_color.rgb * (iridescence_strength * (0.35 + 0.35 * fres));
	col += vec3(0.9, 0.95, 1.0) * (fres * wetness * 0.3);

	ALBEDO = clamp(col, 0.0, 1.0);
}
