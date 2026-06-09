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
uniform float pattern_invert : hint_range(0.0, 1.0) = 0.0;
uniform float pattern_seed = 0.0;

// Iridescence (iridophores): a view-angle driven oil-slick sheen. Defaults off.
uniform float iridescence_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 iridescence_color : source_color = vec4(0.75, 0.91, 1.0, 1.0);
// How many colour bands sweep across the fresnel ramp (thin-film frequency).
uniform float iridescence_frequency : hint_range(0.1, 10.0) = 2.0;

// Wet mucus layer: a smooth clearcoat lobe over the toon body. Defaults off.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform int scale_type = 0;
uniform bool is_head = false;
uniform float scale_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scale_size : hint_range(4.0, 64.0) = 16.0;
uniform float lateral_line_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pearlscale_strength : hint_range(0.0, 1.0) = 0.0;
uniform float metallic_scale_strength : hint_range(0.0, 1.0) = 0.0;
uniform float emissive_marking_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool operculum_enabled = false;
uniform vec2 operculum_u = vec2(0.139, 0.224);
uniform vec2 operculum_up = vec2(0.0, 0.38);
uniform float operculum_open : hint_range(0.0, 1.0) = 0.0;
uniform float operculum_ridge : hint_range(0.0, 1.0) = 0.25;
uniform vec4 operculum_line_color : source_color = vec4(0.08, 0.10, 0.11, 1.0);
// Occiput / neck seam where the head separates from the trunk. Kept independent
// of the operculum plate so the gill cover reads continuous with the head while
// the head-body break is its own thin crease. 0 disables it.
uniform float operculum_neck : hint_range(0.0, 1.0) = 0.4;

// Species marking layers. Fixed slots keep the material contract explicit and
// deterministic for Godot 4 shader parameters.
uniform int marking_count = 0;
uniform int marking_type_0 = 0;
uniform int marking_type_1 = 0;
uniform int marking_type_2 = 0;
uniform int marking_type_3 = 0;
uniform int marking_type_4 = 0;
uniform int marking_type_5 = 0;
uniform int marking_type_6 = 0;
uniform int marking_type_7 = 0;
const int TYPE_REGION_COLOR = 13;
const int TYPE_SCALE_REGION = 14;
const int TYPE_IRIDESCENCE_REGION = 15;

const int BLEND_NORMAL = 0;
const int BLEND_MULTIPLY = 1;
const int BLEND_SCREEN = 2;
const int BLEND_ADD = 3;

uniform int marking_region_0 = 0;
uniform int marking_region_1 = 0;
uniform int marking_region_2 = 0;
uniform int marking_region_3 = 0;
uniform int marking_region_4 = 0;
uniform int marking_region_5 = 0;
uniform int marking_region_6 = 0;
uniform int marking_region_7 = 0;
uniform int marking_blend_0 = 0;
uniform int marking_blend_1 = 0;
uniform int marking_blend_2 = 0;
uniform int marking_blend_3 = 0;
uniform int marking_blend_4 = 0;
uniform int marking_blend_5 = 0;
uniform int marking_blend_6 = 0;
uniform int marking_blend_7 = 0;
uniform vec4 marking_color_0 : source_color = vec4(1.0);
uniform vec4 marking_color_1 : source_color = vec4(1.0);
uniform vec4 marking_color_2 : source_color = vec4(1.0);
uniform vec4 marking_color_3 : source_color = vec4(1.0);
uniform vec4 marking_color_4 : source_color = vec4(1.0);
uniform vec4 marking_color_5 : source_color = vec4(1.0);
uniform vec4 marking_color_6 : source_color = vec4(1.0);
uniform vec4 marking_color_7 : source_color = vec4(1.0);
uniform vec4 marking_rect_0 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_1 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_2 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_3 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_4 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_5 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_6 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_rect_7 = vec4(0.0, 1.0, 0.0, 0.05);
uniform vec4 marking_params_0 = vec4(0.0, 0.025, 0.0, 0.0);
uniform vec4 marking_params_1 = vec4(0.0, 0.025, 0.0, 1.0);
uniform vec4 marking_params_2 = vec4(0.0, 0.025, 0.0, 2.0);
uniform vec4 marking_params_3 = vec4(0.0, 0.025, 0.0, 3.0);
uniform vec4 marking_params_4 = vec4(0.0, 0.025, 0.0, 4.0);
uniform vec4 marking_params_5 = vec4(0.0, 0.025, 0.0, 5.0);
uniform vec4 marking_params_6 = vec4(0.0, 0.025, 0.0, 6.0);
uniform vec4 marking_params_7 = vec4(0.0, 0.025, 0.0, 7.0);

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
	float seed = pattern_seed * 0.137;
	float su = u + seed;
	if (kind == 1) {
		// Vertical stripes, wobbled for organic waviness.
		float wob = (pnoise(vec2(su * sx * 0.5, v * per), per) - 0.5) * 0.5;
		float s = 0.5 + 0.5 * sin((su * sx + wob) * TAU);
		return smoothstep(0.45, 0.55, s);
	}
	if (kind == 2) {
		// Horizontal stripes, periodic in V.
		float s = 0.5 + 0.5 * sin((v * per + seed) * TAU);
		return smoothstep(0.45, 0.55, s);
	}
	if (kind == 3) {
		// Spots.
		float n = pnoise(vec2(su * sx, v * per), per);
		return smoothstep(0.62, 0.74, n);
	}
	if (kind == 4) {
		// Zebra: noise-warped hard stripes.
		float warp = (pfbm(vec2(su * sx * 0.3, v * per), per) - 0.5) * 1.2;
		float s = sin((su * sx + warp) * TAU);
		return smoothstep(-0.05, 0.05, s);
	}
	if (kind == 5) {
		// Marbled turbulence.
		float n = pfbm(vec2(su * sx, v * per), per);
		float m = 0.5 + 0.5 * sin((su * sx * 0.5 + n * 3.0) * TAU);
		return smoothstep(0.4, 0.6, m);
	}
	if (kind == 6) {
		// Reticulated net (e.g. moray / pufferfish): Voronoi cell borders.
		float edge = pvoronoi_edge(vec2(su * sx, v * per), per);
		return 1.0 - smoothstep(0.0, 0.12, edge);
	}
	if (kind == 7) {
		// Whale-shark grid: a soft orthogonal lattice with cell-center speckles.
		float gx = abs(sin(su * sx * TAU));
		float gy = abs(sin((v * per + seed) * TAU));
		float grid = max(smoothstep(0.92, 0.985, gx), smoothstep(0.92, 0.985, gy));
		vec2 cell = vec2(su * sx, v * per);
		vec2 local = fract(cell) - vec2(0.5);
		float dot_mask = 1.0 - smoothstep(0.10, 0.22, length(local));
		float jitter = smoothstep(0.35, 0.75, pnoise(floor(cell) + vec2(seed * 13.0, seed * 7.0), per));
		return clamp(grid * 0.72 + dot_mask * jitter, 0.0, 1.0);
	}
	return 0.0;
}

float band_range(float value, float start_value, float end_value, float softness) {
	float a = smoothstep(start_value - softness, start_value + softness, value);
	float b = 1.0 - smoothstep(end_value - softness, end_value + softness, value);
	return clamp(a * b, 0.0, 1.0);
}

float region_mask(int region, float u, float up) {
	if (region == 0) { return 1.0; }
	if (region == 1) { return smoothstep(0.22, 0.62, up); }
	if (region == 2) { return 1.0 - smoothstep(0.28, 0.72, abs(up)); }
	if (region == 3) { return 1.0 - smoothstep(-0.72, -0.28, up); }
	if (region == 4) { return smoothstep(0.04, 0.44, up); }
	if (region == 5) { return smoothstep(0.04, 0.44, -up); }
	if (region == 6) { return 1.0 - smoothstep(0.20, 0.28, u); }
	if (region == 7) { return (1.0 - smoothstep(0.10, 0.22, u)) * (1.0 - smoothstep(0.55, 0.9, abs(up))); }
	if (region == 8) { return band_range(u, 0.14, 0.25, 0.025) * (1.0 - smoothstep(0.18, 0.62, abs(up))); }
	if (region == 9) { return band_range(u, 0.72, 0.94, 0.04) * (1.0 - smoothstep(0.34, 0.82, abs(up))); }
	return 0.0;
}

float marking_region_gate(int kind, int region, float u, float up) {
	if (kind == TYPE_REGION_COLOR) {
		return region_mask(region, u, up);
	}
	return smoothstep(0.0, 0.18, region_mask(region, u, up));
}

vec3 blend_marking_color(vec3 base, vec3 layer, int blend_mode, float amount) {
	vec3 blended = layer;
	if (blend_mode == BLEND_MULTIPLY) {
		blended = base * layer;
	} else if (blend_mode == BLEND_SCREEN) {
		blended = 1.0 - (1.0 - base) * (1.0 - layer);
	} else if (blend_mode == BLEND_ADD) {
		blended = min(base + layer, vec3(1.0));
	}
	return mix(base, blended, amount);
}

float marking_layer_mask(int kind, vec4 rect, vec4 params, float u, float up) {
	float x0 = min(rect.x, rect.y);
	float x1 = max(rect.x, rect.y);
	float y = rect.z;
	float thickness = max(rect.w, 0.001);
	float softness = max(params.y, 0.001);
	float xmask = band_range(u, x0, x1, softness);
	if (kind == 1 || kind == 2) {
		return xmask * (1.0 - smoothstep(thickness, thickness + softness, abs(up - y)));
	}
	if (kind == 3) {
		float center = (x0 + x1) * 0.5;
		float half_width = max((x1 - x0) * 0.5, thickness * 0.5);
		return 1.0 - smoothstep(half_width, half_width + softness, abs(u - center));
	}
	if (kind == 4 || kind == 7) {
		float cx = (x0 + x1) * 0.5;
		float rx = max((x1 - x0) * 0.5, thickness);
		float dy = (up - y) / max(thickness, 0.001);
		float dx = (u - cx) / max(rx, 0.001);
		float d = sqrt(dx * dx + dy * dy);
		return 1.0 - smoothstep(1.0, 1.0 + softness * 8.0, d);
	}
	if (kind == 5 || kind == 6 || kind == 8) {
		return xmask * (1.0 - smoothstep(thickness, thickness + softness, abs(up - y)));
	}
	if (kind == 11) {
		float grid = max(abs(sin(u * 36.0 * TAU)), abs(sin((up * 0.5 + 0.5) * 16.0 * TAU)));
		return xmask * smoothstep(0.92, 0.98, grid) * 0.4;
	}
	if (kind == 12) {
		float edge = pvoronoi_edge(vec2(u * 8.0, (up * 0.5 + 0.5) * 8.0), 8.0);
		return xmask * (1.0 - smoothstep(0.0, 0.12, edge));
	}
	return 0.0;
}

void apply_marking_layer(inout vec3 col, int kind, int region, int blend_mode, vec4 color, vec4 rect, vec4 params, float u, float up) {
	if (kind == TYPE_SCALE_REGION || kind == TYPE_IRIDESCENCE_REGION) {
		return;
	}
	float mask = 0.0;
	if (kind == TYPE_REGION_COLOR) {
		mask = band_range(u, min(rect.x, rect.y), max(rect.x, rect.y), max(params.y, 0.001));
	} else {
		mask = marking_layer_mask(kind, rect, params, u, up);
	}
	mask *= marking_region_gate(kind, region, u, up) * clamp(params.x, 0.0, 1.0);
	col = blend_marking_color(col, color.rgb, blend_mode, mask * color.a);
	col += color.rgb * mask * clamp(params.z + emissive_marking_strength, 0.0, 1.0) * 0.35;
}

float regional_layer_mask(int kind, int target_kind, int region, vec4 rect, vec4 params, float u, float up) {
	if (kind != target_kind) {
		return 0.0;
	}
	float x0 = min(rect.x, rect.y);
	float x1 = max(rect.x, rect.y);
	float mask = band_range(u, x0, x1, max(params.y, 0.001));
	return mask * region_mask(region, u, up);
}

float apply_scale_region_layer(float current, int kind, int region, vec4 rect, vec4 params, float u, float up) {
	float mask = regional_layer_mask(kind, TYPE_SCALE_REGION, region, rect, params, u, up);
	return mix(current, clamp(params.x, 0.0, 1.0), mask);
}

float apply_iridescence_region_layer(float current, int kind, int region, vec4 rect, vec4 params, float u, float up) {
	float mask = regional_layer_mask(kind, TYPE_IRIDESCENCE_REGION, region, rect, params, u, up);
	return mix(current, clamp(params.x, 0.0, 1.0), mask);
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
	if (pattern_type != 0) {
		mask = mix(mask, 1.0 - mask, pattern_invert);
	}
	col = mix(col, pattern_color.rgb, mask * pattern_intensity);

	// 2b. Species markings. These are localized, high-readability marks such as
	// neon lateral lines, posterior bands, vertical bars, head masks, or spots.
	int count = min(marking_count, 8);
	if (count > 0) { apply_marking_layer(col, marking_type_0, marking_region_0, marking_blend_0, marking_color_0, marking_rect_0, marking_params_0, v_long, up); }
	if (count > 1) { apply_marking_layer(col, marking_type_1, marking_region_1, marking_blend_1, marking_color_1, marking_rect_1, marking_params_1, v_long, up); }
	if (count > 2) { apply_marking_layer(col, marking_type_2, marking_region_2, marking_blend_2, marking_color_2, marking_rect_2, marking_params_2, v_long, up); }
	if (count > 3) { apply_marking_layer(col, marking_type_3, marking_region_3, marking_blend_3, marking_color_3, marking_rect_3, marking_params_3, v_long, up); }
	if (count > 4) { apply_marking_layer(col, marking_type_4, marking_region_4, marking_blend_4, marking_color_4, marking_rect_4, marking_params_4, v_long, up); }
	if (count > 5) { apply_marking_layer(col, marking_type_5, marking_region_5, marking_blend_5, marking_color_5, marking_rect_5, marking_params_5, v_long, up); }
	if (count > 6) { apply_marking_layer(col, marking_type_6, marking_region_6, marking_blend_6, marking_color_6, marking_rect_6, marking_params_6, v_long, up); }
	if (count > 7) { apply_marking_layer(col, marking_type_7, marking_region_7, marking_blend_7, marking_color_7, marking_rect_7, marking_params_7, v_long, up); }

	// 2c. Operculum (gill cover). Painted in UV on the body shell's front region
	// (operculum_u sits in the whole-fish [0,1] UV, ~14-22% back), which is the
	// visible surface over the gill area -- the separate head cap mesh does not
	// show here, so this is intentionally NOT gated on is_head. Painting in UV
	// means it cannot float, wing out in front view, or fight shell depth. The
	// rear dark arc is the free gill opening; open widens/darkens that margin.
	if (operculum_enabled) {
		float au = operculum_u.x;
		float pu = operculum_u.y;
		float cup = operculum_up.x;
		float half_up = max(operculum_up.y, 0.001);
		float soft = 0.02;

		float ut = clamp((v_long - au) / max(pu - au, 0.001), 0.0, 1.0);
		float env = mix(0.62, 1.0, sin(ut * PI));
		float top = cup + half_up * env;
		float bot = cup - half_up * env;

		float u_mask = band_range(v_long, au, pu, soft);
		float v_mask = smoothstep(top + soft, top - soft, up) * smoothstep(bot - soft, bot + soft, up);
		float plate = u_mask * v_mask;

		col = mix(col, col * mix(0.96, 0.84, operculum_ridge), plate);

		float seam_curve = (up - cup) / half_up;
		float j_factor = seam_curve < 0.0 ? 0.03 : 0.01;
		float seam_x = au + 0.006 + (seam_curve * seam_curve) * j_factor;
		float seam_w = 0.010 + 0.010 * operculum_ridge;
		float seam = v_mask * (1.0 - smoothstep(0.0, seam_w, abs(v_long - seam_x)));
		col = mix(col, operculum_line_color.rgb, seam * mix(0.10, 0.28, operculum_ridge));

		float slit_x = pu + operculum_open * 0.010;
		float slit_w = (0.006 + 0.016 * operculum_ridge) * (1.0 + 0.8 * operculum_open);
		float slit = v_mask * (1.0 - smoothstep(0.0, slit_w, abs(v_long - slit_x)));
		col = mix(col, operculum_line_color.rgb, slit * mix(0.5, 0.85, operculum_ridge));

		float rim_x = slit_x - slit_w * 1.8;
		float rim = v_mask * (1.0 - smoothstep(0.0, slit_w * 0.8, abs(v_long - rim_x))) * operculum_open;
		col = mix(col, min(col * 1.6 + 0.10, vec3(1.0)), rim * 0.4);
	}

	// 2c-2. Neck / occiput seam. The head + operculum read as one continuous
	// surface, but the head breaks from the trunk at the occipital junction,
	// which sits *behind* the gill opening. Drawn as its own thin vertical
	// occlusion (not a wide soft field) so it never smears the rear slit. Sits
	// at neck_x just past the head cap's neck (HEAD_U_SPAN=0.25), so it only
	// lands on the body shell -- same surface as the operculum above.
	if (operculum_enabled && operculum_neck > 0.0) {
		// Anchor a short, fixed distance behind the posterior margin so the
		// crease never collides with the slit at operculum_u.y.
		float neck_x = operculum_u.y + 0.035 + operculum_open * 0.01;
		float neck_w = 0.012;
		float neck = 1.0 - smoothstep(0.0, neck_w, abs(v_long - neck_x));
		// Full flank, but fade out near the dorsal/ventral silhouette edges
		// (|up| -> 1) so it stays a crease rather than a hard ring.
		float neck_v = smoothstep(1.0, 0.7, abs(up));
		col = mix(col, col * 0.8, neck * neck_v * operculum_neck);
	}

	// 2d. Imbricated fish scales. Real cycloid/ctenoid scales overlap like roof
	// shingles in half-staggered rows, and only each scale's rounded trailing (posterior)
	// margin is exposed. So instead of a square sine lattice we tessellate the surface into
	// rounded scale cells (a regular Voronoi over a half-offset grid) and shade just the
	// tail-side arc of every cell with a soft shadow, plus a faint leading-face sheen. The
	// row count is forced even so the cells wrap seamlessly around the girth (v_circ).
	float scale_density = max(scale_size, 2.0) * 0.75;
	float scale_columns = scale_density;
	float scale_rows = max(2.0 * floor(scale_size * 0.5 + 0.5), 2.0);
	vec2 scale_p = vec2(UV2.x * scale_density, UV2.y * scale_density * 2.0);
	
	float scale_strength_local = is_head ? 0.0 : scale_strength;
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_0, marking_region_0, marking_rect_0, marking_params_0, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_1, marking_region_1, marking_rect_1, marking_params_1, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_2, marking_region_2, marking_rect_2, marking_params_2, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_3, marking_region_3, marking_rect_3, marking_params_3, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_4, marking_region_4, marking_rect_4, marking_params_4, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_5, marking_region_5, marking_rect_5, marking_params_5, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_6, marking_region_6, marking_rect_6, marking_params_6, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_7, marking_region_7, marking_rect_7, marking_params_7, v_long, up);
	
	float scale_r = 0.75;
	vec2 scale_aniso = vec2(1.0, 0.5);   // aspect ratio correction for vertical 2x density
	float scale_owner_x = 1e9;           // leftmost (anterior) disc covering this fragment
	for (int sy = -1; sy <= 1; sy++) {
		for (int sx = -1; sx <= 1; sx++) {
			vec2 cell = floor(scale_p) + vec2(float(sx), float(sy));
			vec2 center = vec2(cell.x + 0.5 + mod(cell.y, 2.0) * 0.5, cell.y + 0.5);
			
			bool is_inside = false;
			float dx = scale_p.x - center.x;
			float dy = scale_p.y - center.y;
			
			if (scale_type == 2) { // Ganoid
				is_inside = (abs(dx) + 0.5 * abs(dy)) < 0.5;
			} else if (scale_type == 3) { // Placoid
				float w = mix(0.1, 0.35, smoothstep(0.35, -0.35, dx));
				is_inside = dx > -0.35 && dx < 0.35 && (abs(dy) * scale_aniso.y) < w;
			} else { // Cycloid, Ctenoid, Pearlscale
				is_inside = length((scale_p - center) * scale_aniso) < scale_r;
			}
			
			if (is_inside) {
				scale_owner_x = min(scale_owner_x, center.x);
			}
		}
	}
	
	float scale_line = 0.0;
	float scale_crescent = 0.0;
	float circuli_contrib = 0.0;
	float ctenii_contrib = 0.0;
	float ganoid_bevel = 0.0;
	float ganoid_dist = 0.0;
	vec3 ganoid_normal = vec3(0.0, 0.0, 1.0);
	float placoid_ridges = 0.0;
	float placoid_spine_mask = 0.0;
	float pearlscale_dome = 0.0;
	float pearlscale_dist = 0.0;
	vec3 pearlscale_normal = vec3(0.0, 0.0, 1.0);
	vec3 scale_surface_normal = vec3(0.0, 0.0, 1.0); // for metallic specular shading
	bool has_owner = false;
	
	for (int sy = -1; sy <= 1; sy++) {
		for (int sx = -1; sx <= 1; sx++) {
			vec2 cell = floor(scale_p) + vec2(float(sx), float(sy));
			vec2 center = vec2(cell.x + 0.5 + mod(cell.y, 2.0) * 0.5, cell.y + 0.5);
			
			bool is_inside = false;
			float dx = scale_p.x - center.x;
			float dy = scale_p.y - center.y;
			float dist = 0.0;
			
			if (scale_type == 2) { // Ganoid
				dist = abs(dx) + 0.5 * abs(dy);
				is_inside = dist < 0.5;
			} else if (scale_type == 3) { // Placoid
				float w = mix(0.1, 0.35, smoothstep(0.35, -0.35, dx));
				is_inside = dx > -0.35 && dx < 0.35 && (abs(dy) * scale_aniso.y) < w;
				dist = (abs(dy) * scale_aniso.y) / max(0.001, w);
			} else { // Cycloid, Ctenoid, Pearlscale
				dist = length((scale_p - center) * scale_aniso);
				is_inside = dist < scale_r;
			}
			
			if (!is_inside) { continue; }
			if (center.x > scale_owner_x + 0.001) { continue; }
			
			has_owner = true;
			
			if (scale_type == 0) { // Cycloid
				scale_line = 1.0 - smoothstep(0.03, 0.09, abs(dist - scale_r));
				scale_crescent = smoothstep(scale_r - 0.30, scale_r, dist);
				
				// Growth rings (circuli)
				float circuli_mask = smoothstep(0.12, 0.32, dist) * smoothstep(scale_r, scale_r - 0.05, dist);
				circuli_contrib = (sin(dist * 64.0) * 0.5 + 0.5) * circuli_mask;
				
				// Tilt normal for metallic specular
				vec2 tilt = (scale_p - center) * scale_aniso * 0.3;
				scale_surface_normal = normalize(vec3(tilt, 1.0));
			}
			else if (scale_type == 1) { // Ctenoid
				scale_line = 1.0 - smoothstep(0.03, 0.09, abs(dist - scale_r));
				scale_crescent = smoothstep(scale_r - 0.30, scale_r, dist);
				
				// Radial comb-like teeth (ctenii)
				float angle = atan(dy, dx);
				float radial_stripes = sin(angle * 32.0) * 0.5 + 0.5;
				float ctenii_mask = smoothstep(scale_r - 0.18, scale_r, dist) * smoothstep(-0.1, 0.1, dx);
				ctenii_contrib = radial_stripes * ctenii_mask;
				
				// Tilt normal for metallic specular
				vec2 tilt = (scale_p - center) * scale_aniso * 0.3;
				scale_surface_normal = normalize(vec3(tilt, 1.0));
			}
			else if (scale_type == 2) { // Ganoid
				ganoid_dist = dist;
				float bevel_dist = dist / 0.5;
				ganoid_bevel = 1.0 - smoothstep(0.82, 0.96, bevel_dist);
				
				// Bevel normal mapping
				vec2 dir = sign(scale_p - center) * vec2(1.0, 0.5);
				ganoid_normal = normalize(vec3(dir * (1.0 - ganoid_bevel), 1.0));
				scale_surface_normal = ganoid_normal;
			}
			else if (scale_type == 3) { // Placoid
				placoid_spine_mask = 1.0;
				// Ridges running along the spine
				float ridge_pattern = sin(dy * scale_aniso.y * 36.0) * 0.5 + 0.5;
				float ridge_mask = smoothstep(0.95, 0.2, dist);
				placoid_ridges = ridge_pattern * ridge_mask;
				
				// Spine normal (rounded front to sharp tail)
				vec2 tilt = vec2(dx * 1.5, dy * 2.0);
				scale_surface_normal = normalize(vec3(tilt, 1.0));
			}
			else if (scale_type == 4) { // Pearlscale
				scale_line = 1.0 - smoothstep(0.03, 0.09, abs(dist - scale_r));
				scale_crescent = smoothstep(scale_r - 0.30, scale_r, dist);
				
				// Central pearl dome
				pearlscale_dist = dist;
				float dome_r = 0.38;
				pearlscale_dome = smoothstep(dome_r, dome_r - 0.06, dist);
				float h = sqrt(max(0.0, dome_r * dome_r - dist * dist));
				pearlscale_normal = normalize(vec3((scale_p - center) * scale_aniso * 1.2, h));
				
				vec2 tilt = (scale_p - center) * scale_aniso * 0.3;
				scale_surface_normal = normalize(vec3(tilt, 1.0));
			}
		}
	}
	
	if (has_owner && scale_strength_local > 0.0) {
		if (scale_type == 0) { // Cycloid
			col = mix(col, col * 0.64, scale_crescent * scale_strength_local * 0.4);
			col = mix(col, col * 0.52, scale_line * scale_strength_local * 0.6);
			col = mix(col, col * 0.88, circuli_contrib * scale_strength_local * 0.25);
		}
		else if (scale_type == 1) { // Ctenoid
			col = mix(col, col * 0.64, scale_crescent * scale_strength_local * 0.4);
			col = mix(col, col * 0.52, scale_line * scale_strength_local * 0.6);
			col = mix(col, col * 0.82, ctenii_contrib * scale_strength_local * 0.35);
		}
		else if (scale_type == 2) { // Ganoid
			vec3 L = normalize(vec3(0.3, 0.5, 0.8));
			float diffuse = max(0.0, dot(ganoid_normal, L));
			vec3 bevel_shading = col * (0.5 + 0.5 * diffuse);
			vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
			float spec = pow(max(0.0, dot(ganoid_normal, H)), 8.0);
			bevel_shading += vec3(1.0, 0.95, 0.85) * spec * 0.15;
			
			col = mix(bevel_shading, col, ganoid_bevel * (1.0 - scale_strength_local * 0.3));
			float gap = smoothstep(0.94, 0.98, ganoid_dist);
			col = mix(col, col * 0.35, gap * scale_strength_local * 0.85);
		}
		else if (scale_type == 3) { // Placoid
			vec3 spine_col = mix(col * 0.85, col * 1.15, placoid_ridges * 0.3);
			vec3 L = normalize(vec3(0.4, 0.4, 0.8));
			float diffuse = max(0.05, dot(scale_surface_normal, L));
			spine_col *= (0.7 + 0.35 * diffuse);
			
			col = mix(col, spine_col, placoid_spine_mask * scale_strength_local * 0.8);
		}
		else if (scale_type == 4) { // Pearlscale
			col = mix(col, col * 0.64, scale_crescent * scale_strength_local * 0.4);
			col = mix(col, col * 0.52, scale_line * scale_strength_local * 0.6);
			
			vec3 L = normalize(vec3(0.4, 0.5, 0.77));
			float diffuse = max(0.0, dot(pearlscale_normal, L));
			vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
			float specular = pow(max(0.0, dot(pearlscale_normal, H)), 24.0);
			
			vec3 pearl_base = vec3(0.96, 0.94, 0.88);
			vec3 dome_shading = pearl_base * (0.55 + 0.45 * diffuse) + vec3(0.95) * specular * 0.35;
			
			col = mix(col, dome_shading, pearlscale_dome * scale_strength_local * pearlscale_strength * 0.9);
		}
		
		if (metallic_scale_strength > 0.0) {
			vec3 L = normalize(vec3(0.3, 0.5, 0.8));
			vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
			float spec = pow(max(0.0, dot(scale_surface_normal, H)), 12.0);
			vec3 metallic_glow = vec3(1.0, 0.88, 0.62) * spec * metallic_scale_strength * 0.35;
			col += metallic_glow * scale_strength_local;
		}
	}
	
	if (scale_type != 4 && pearlscale_strength > 0.0) {
		float pearl_cell = pnoise(scale_p, scale_rows);
		float pearl = smoothstep(0.58, 0.9, pearl_cell) * pearlscale_strength;
		col += vec3(1.0, 0.94, 0.78) * pearl * 0.18 * scale_strength_local;
	}
	
	float metallic_band = 0.5 + 0.5 * sin((v_long * scale_columns * 0.5 + up * 0.35) * TAU);
	col += vec3(1.0, 0.88, 0.52) * metallic_band * metallic_scale_strength * 0.14 * (1.0 - scale_strength_local * 0.5);
	
	float lateral = 1.0 - smoothstep(0.035, 0.09, abs(up - 0.08));
	col += vec3(0.68, 0.9, 1.0) * lateral * lateral_line_strength * 0.26;

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
	float iridescence_strength_local = iridescence_strength;
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_0, marking_region_0, marking_rect_0, marking_params_0, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_1, marking_region_1, marking_rect_1, marking_params_1, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_2, marking_region_2, marking_rect_2, marking_params_2, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_3, marking_region_3, marking_rect_3, marking_params_3, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_4, marking_region_4, marking_rect_4, marking_params_4, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_5, marking_region_5, marking_rect_5, marking_params_5, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_6, marking_region_6, marking_rect_6, marking_params_6, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_7, marking_region_7, marking_rect_7, marking_params_7, v_long, up);
	float irid_phase = TAU * (v_long * iridescence_frequency + 0.5 * up);
	vec3 irid = 0.5 + 0.5 * cos(irid_phase + vec3(0.0, 2.094, 4.188));
	col += irid * iridescence_color.rgb * (iridescence_strength_local * (0.35 + 0.35 * fres));
	col += vec3(0.9, 0.95, 1.0) * (fres * wetness * 0.3);

	ALBEDO = clamp(col, 0.0, 1.0);
}
