# Regional Color Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add region-aware color, marking, scale, iridescence, and fin appearance layers so species can differ by dorsum, flank, belly, head, caudal peduncle, and fin groups.

**Architecture:** Use the existing `marking_layers` array as the single authoring model, extending each layer with `region`, `blend_mode`, and body/fin shader uniforms. Body/head rendering gets procedural region masks in `fish_body_toon.gdshader`; fins get a compact filtered layer pass in `fish_fin_toon.gdshader` keyed by grouped fin regions. Existing global colors, procedural patterns, scales, and legacy marking layers remain valid defaults.

**Tech Stack:** Godot 4 GDScript, Godot spatial shaders, JSON archetype data, existing Godot CLI test runner `tools/run_godot_cli_tests.ps1`.

---

## Scope Contract

This plan implements a data-driven regional layer system. It does not add bitmap texture painting, asset import/export, or per-vertex repaint tools.

The first shipped behavior must satisfy these contracts:

- Legacy `marking_layers` without `region` or `blend_mode` render as body/normal layers.
- Body shader regions use stable UV-derived coordinates: `u = UV.x` snout to tail, `up = sin(UV.y * TAU)` belly to back.
- Fins use grouped regions: `median_fin`, `paired_fin`, `caudal_fin`, and `special_fin`.
- `region_color` changes local body color.
- `scale_region` changes local scale strength.
- `iridescence_region` changes local iridescence strength.
- Existing `reticulated_zone` and `scale_grid` become useful by adding `region`, not by adding a second reticulation system.
- UI exposes layer editing without forcing users to edit JSON by hand.

---

## File Structure

- Modify `scripts/species/SpeciesMarkingLayer.gd`: add region IDs, blend IDs, new layer types, body uniform encoding, and fin uniform encoding.
- Modify `scripts/materials/ToonMaterialFactory.gd`: bind extended body marking uniforms and filtered fin marking uniforms.
- Modify `shaders/fish_body_toon.gdshader`: add region uniforms, blend uniforms, region masks, layer blending, `region_color`, `scale_region`, and `iridescence_region`.
- Modify `shaders/fish_fin_toon.gdshader`: add a small fin-layer pass for fin group colors, edge bands, spots, and stripes.
- Modify `scripts/creature/FishRig.gd`: pass grouped fin-region IDs through material overrides for dorsal/anal, pectoral/pelvic, caudal, adipose, and finlets.
- Modify `scripts/creature/BodyProfile.gd`: preserve `marking_layers` through presets; no new top-level visual defaults are required.
- Add `scripts/ui/MarkingLayerEditor.gd`: array editor for regional marking layers.
- Modify `scripts/ui/ParameterPanel.gd`: mount `MarkingLayerEditor` in `Pattern Settings` when `marking_layers` is present.
- Modify `scripts/ui/UiText.gd`: add Korean labels for the layer editor fields and option values.
- Modify `data/species_archetypes/neon_tetra.json`: target the blue stripe to `flank` and the red band to `ventral_flank`.
- Modify `data/species_archetypes/corydoras.json`: target the saddle to `dorsal_flank` and the scale grid to `flank`.
- Modify `data/species_archetypes/mackerel.json`: target dark bands to `dorsal_flank` and add a `scale_region` layer for flank scales.
- Modify `scripts/tools/MarkingLayerTest.gd`: cover normalization, new uniforms, shader contract strings, and fin filtering.
- Modify `scripts/tools/PatternTest.gd`: cover material binding, preset round-trip, and shader contract strings for regional scale/iridescence.
- Modify `scripts/tools/FinMaterialTest.gd`: cover fin-region material overrides and filtered fin uniforms.
- Add `scripts/tools/MarkingLayerEditorTest.gd`: cover UI editor creation and emitted dictionaries.
- Modify `scripts/tools/SpeciesArchetypeStoreTest.gd`: cover archetype region data preservation.

---

### Task 1: Extend Marking Layer Data Contract

**Files:**
- Modify: `scripts/species/SpeciesMarkingLayer.gd`
- Modify: `scripts/tools/MarkingLayerTest.gd`

- [ ] **Step 1: Write failing tests for region, blend, and new layer types**

Add calls in `scripts/tools/MarkingLayerTest.gd` `_ready()`:

```gdscript
	_test_marking_layer_region_and_blend_fields()
	_test_invalid_region_and_blend_use_safe_defaults()
```

Add these functions:

```gdscript
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
```

- [ ] **Step 2: Run focused test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
```

Expected: FAIL because `TYPE_REGION_COLOR`, `marking_region_0`, and `marking_blend_0` do not exist.

- [ ] **Step 3: Add constants and name maps**

In `scripts/species/SpeciesMarkingLayer.gd`, add these constants after the current type and zone constants:

```gdscript
const TYPE_REGION_COLOR := 13
const TYPE_SCALE_REGION := 14
const TYPE_IRIDESCENCE_REGION := 15

const REGION_BODY := 0
const REGION_DORSAL := 1
const REGION_FLANK := 2
const REGION_VENTRAL := 3
const REGION_DORSAL_FLANK := 4
const REGION_VENTRAL_FLANK := 5
const REGION_HEAD := 6
const REGION_CHEEK := 7
const REGION_OPERCULUM := 8
const REGION_CAUDAL_PEDUNCLE := 9
const REGION_MEDIAN_FIN := 10
const REGION_PAIRED_FIN := 11
const REGION_CAUDAL_FIN := 12
const REGION_SPECIAL_FIN := 13

const BLEND_NORMAL := 0
const BLEND_MULTIPLY := 1
const BLEND_SCREEN := 2
const BLEND_ADD := 3
```

Extend `TYPE_BY_NAME` with:

```gdscript
	"region_color": TYPE_REGION_COLOR,
	"scale_region": TYPE_SCALE_REGION,
	"iridescence_region": TYPE_IRIDESCENCE_REGION
```

Add maps after `ZONE_BY_NAME`:

```gdscript
const REGION_BY_NAME := {
	"body": REGION_BODY,
	"dorsal": REGION_DORSAL,
	"flank": REGION_FLANK,
	"ventral": REGION_VENTRAL,
	"dorsal_flank": REGION_DORSAL_FLANK,
	"ventral_flank": REGION_VENTRAL_FLANK,
	"head": REGION_HEAD,
	"cheek": REGION_CHEEK,
	"operculum": REGION_OPERCULUM,
	"caudal_peduncle": REGION_CAUDAL_PEDUNCLE,
	"median_fin": REGION_MEDIAN_FIN,
	"paired_fin": REGION_PAIRED_FIN,
	"caudal_fin": REGION_CAUDAL_FIN,
	"special_fin": REGION_SPECIAL_FIN
}

const BLEND_BY_NAME := {
	"normal": BLEND_NORMAL,
	"multiply": BLEND_MULTIPLY,
	"screen": BLEND_SCREEN,
	"add": BLEND_ADD
}
```

- [ ] **Step 4: Encode `marking_region_%d` and `marking_blend_%d`**

In `encode_uniforms`, inside the filled-slot branch, add:

```gdscript
			encoded["marking_region_%d" % i] = int(layer["region_id"])
			encoded["marking_blend_%d" % i] = int(layer["blend_id"])
```

In the empty-slot branch, add:

```gdscript
			encoded["marking_region_%d" % i] = REGION_BODY
			encoded["marking_blend_%d" % i] = BLEND_NORMAL
```

In `_normalize_layers`, after `zone_id` is assigned, add:

```gdscript
		var region_name := String(raw_layer.get("region", zone_name))
		var blend_name := String(raw_layer.get("blend_mode", "normal"))
		layer["region_id"] = int(REGION_BY_NAME.get(region_name, REGION_BODY))
		layer["blend_id"] = int(BLEND_BY_NAME.get(blend_name, BLEND_NORMAL))
		layer["region"] = String(REGION_BY_NAME.has(region_name) ? region_name : "body")
		layer["blend_mode"] = String(BLEND_BY_NAME.has(blend_name) ? blend_name : "normal")
```

- [ ] **Step 5: Run focused test and verify it passes**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
```

Expected: PASS and output includes `MARKING_LAYER_TEST_OK`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add scripts/species/SpeciesMarkingLayer.gd scripts/tools/MarkingLayerTest.gd
git commit -m "Add regional marking layer contract"
```

---

### Task 2: Add Body Shader Region Masks And Blend Modes

**Files:**
- Modify: `shaders/fish_body_toon.gdshader`
- Modify: `scripts/tools/MarkingLayerTest.gd`

- [ ] **Step 1: Write failing shader contract tests**

Extend `_test_shader_contains_marking_mask_path()` in `scripts/tools/MarkingLayerTest.gd`:

```gdscript
	assert(code.contains("uniform int marking_region_0"))
	assert(code.contains("uniform int marking_blend_0"))
	assert(code.contains("float region_mask"))
	assert(code.contains("vec3 blend_marking_color"))
	assert(code.contains("TYPE_REGION_COLOR"))
	assert(code.contains("apply_marking_layer(col, marking_type_0, marking_region_0, marking_blend_0"))
```

- [ ] **Step 2: Run focused test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
```

Expected: FAIL because the body shader has no regional uniforms or helper functions.

- [ ] **Step 3: Add shader constants and uniforms**

In `shaders/fish_body_toon.gdshader`, after the existing marking zone uniforms, add:

```glsl
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
```

- [ ] **Step 4: Add body region and blend helpers**

Add these helpers after `band_range`:

```glsl
float region_mask(int region, float u, float up) {
	if (region == 0) { return 1.0; }
	if (region == 1) { return smoothstep(0.22, 0.62, up); }
	if (region == 2) { return 1.0 - smoothstep(0.28, 0.72, abs(up)); }
	if (region == 3) { return 1.0 - smoothstep(-0.72, -0.28, up); }
	if (region == 4) { return smoothstep(0.04, 0.44, up); }
	if (region == 5) { return smoothstep(-0.04, -0.44, -up); }
	if (region == 6) { return 1.0 - smoothstep(0.20, 0.28, u); }
	if (region == 7) { return (1.0 - smoothstep(0.10, 0.22, u)) * (1.0 - smoothstep(0.55, 0.9, abs(up))); }
	if (region == 8) { return band_range(u, 0.14, 0.25, 0.025) * (1.0 - smoothstep(0.18, 0.62, abs(up))); }
	if (region == 9) { return band_range(u, 0.72, 0.94, 0.04) * (1.0 - smoothstep(0.34, 0.82, abs(up))); }
	return 0.0;
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
```

- [ ] **Step 5: Gate marking masks by region and blend mode**

Replace the current `apply_marking_layer` signature and body with:

```glsl
void apply_marking_layer(inout vec3 col, int kind, int region, int blend_mode, vec4 color, vec4 rect, vec4 params, float u, float up) {
	if (kind == TYPE_SCALE_REGION || kind == TYPE_IRIDESCENCE_REGION) {
		return;
	}
	float mask = marking_layer_mask(kind, rect, params, u, up);
	if (kind == TYPE_REGION_COLOR) {
		mask = band_range(u, min(rect.x, rect.y), max(rect.x, rect.y), max(params.y, 0.001));
	}
	mask *= region_mask(region, u, up) * clamp(params.x, 0.0, 1.0);
	col = blend_marking_color(col, color.rgb, blend_mode, mask * color.a);
	col += color.rgb * mask * clamp(params.z + emissive_marking_strength, 0.0, 1.0) * 0.35;
}
```

Update the eight call sites in `fragment()`:

```glsl
if (count > 0) { apply_marking_layer(col, marking_type_0, marking_region_0, marking_blend_0, marking_color_0, marking_rect_0, marking_params_0, v_long, up); }
if (count > 1) { apply_marking_layer(col, marking_type_1, marking_region_1, marking_blend_1, marking_color_1, marking_rect_1, marking_params_1, v_long, up); }
if (count > 2) { apply_marking_layer(col, marking_type_2, marking_region_2, marking_blend_2, marking_color_2, marking_rect_2, marking_params_2, v_long, up); }
if (count > 3) { apply_marking_layer(col, marking_type_3, marking_region_3, marking_blend_3, marking_color_3, marking_rect_3, marking_params_3, v_long, up); }
if (count > 4) { apply_marking_layer(col, marking_type_4, marking_region_4, marking_blend_4, marking_color_4, marking_rect_4, marking_params_4, v_long, up); }
if (count > 5) { apply_marking_layer(col, marking_type_5, marking_region_5, marking_blend_5, marking_color_5, marking_rect_5, marking_params_5, v_long, up); }
if (count > 6) { apply_marking_layer(col, marking_type_6, marking_region_6, marking_blend_6, marking_color_6, marking_rect_6, marking_params_6, v_long, up); }
if (count > 7) { apply_marking_layer(col, marking_type_7, marking_region_7, marking_blend_7, marking_color_7, marking_rect_7, marking_params_7, v_long, up); }
```

- [ ] **Step 6: Run focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
```

Expected: PASS and output includes `MARKING_LAYER_TEST_OK`.

- [ ] **Step 7: Commit Task 2**

```powershell
git add shaders/fish_body_toon.gdshader scripts/tools/MarkingLayerTest.gd
git commit -m "Add body regional marking masks"
```

---

### Task 3: Add Regional Scale And Iridescence Effects

**Files:**
- Modify: `shaders/fish_body_toon.gdshader`
- Modify: `scripts/tools/PatternTest.gd`

- [ ] **Step 1: Write failing shader contract tests**

In `_test_shader_compiles_and_uniforms()` in `scripts/tools/PatternTest.gd`, after the existing shader code assertion, add:

```gdscript
	var shader_code := String(shader.code)
	assert(shader_code.contains("apply_scale_region_layer"))
	assert(shader_code.contains("apply_iridescence_region_layer"))
	assert(shader_code.contains("scale_strength_local = apply_scale_region_layer"))
	assert(shader_code.contains("iridescence_strength_local = apply_iridescence_region_layer"))
```

- [ ] **Step 2: Run focused test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
```

Expected: FAIL because the shader has no regional scale or iridescence helpers.

- [ ] **Step 3: Add region effect helper functions**

Add these functions after `apply_marking_layer`:

```glsl
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
```

- [ ] **Step 4: Apply scale region layers before scale rendering**

Replace:

```glsl
	float scale_strength_local = is_head ? 0.0 : scale_strength;
```

with:

```glsl
	float scale_strength_local = is_head ? 0.0 : scale_strength;
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_0, marking_region_0, marking_rect_0, marking_params_0, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_1, marking_region_1, marking_rect_1, marking_params_1, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_2, marking_region_2, marking_rect_2, marking_params_2, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_3, marking_region_3, marking_rect_3, marking_params_3, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_4, marking_region_4, marking_rect_4, marking_params_4, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_5, marking_region_5, marking_rect_5, marking_params_5, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_6, marking_region_6, marking_rect_6, marking_params_6, v_long, up);
	scale_strength_local = apply_scale_region_layer(scale_strength_local, marking_type_7, marking_region_7, marking_rect_7, marking_params_7, v_long, up);
```

- [ ] **Step 5: Apply iridescence region layers before iridescence rendering**

Before the current iridescence phase code, add:

```glsl
	float iridescence_strength_local = iridescence_strength;
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_0, marking_region_0, marking_rect_0, marking_params_0, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_1, marking_region_1, marking_rect_1, marking_params_1, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_2, marking_region_2, marking_rect_2, marking_params_2, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_3, marking_region_3, marking_rect_3, marking_params_3, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_4, marking_region_4, marking_rect_4, marking_params_4, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_5, marking_region_5, marking_rect_5, marking_params_5, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_6, marking_region_6, marking_rect_6, marking_params_6, v_long, up);
	iridescence_strength_local = apply_iridescence_region_layer(iridescence_strength_local, marking_type_7, marking_region_7, marking_rect_7, marking_params_7, v_long, up);
```

Replace:

```glsl
	col += irid * iridescence_color.rgb * (iridescence_strength * (0.35 + 0.35 * fres));
```

with:

```glsl
	col += irid * iridescence_color.rgb * (iridescence_strength_local * (0.35 + 0.35 * fres));
```

- [ ] **Step 6: Run focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
```

Expected: PASS and output includes `PATTERN_TEST_OK`.

- [ ] **Step 7: Commit Task 3**

```powershell
git add shaders/fish_body_toon.gdshader scripts/tools/PatternTest.gd
git commit -m "Add regional scale and iridescence layers"
```

---

### Task 4: Add Fin Group Marking Layers

**Files:**
- Modify: `scripts/species/SpeciesMarkingLayer.gd`
- Modify: `scripts/materials/ToonMaterialFactory.gd`
- Modify: `shaders/fish_fin_toon.gdshader`
- Modify: `scripts/creature/FishRig.gd`
- Modify: `scripts/tools/MarkingLayerTest.gd`
- Modify: `scripts/tools/FinMaterialTest.gd`

- [ ] **Step 1: Write failing fin-uniform tests**

Add a call in `scripts/tools/MarkingLayerTest.gd` `_ready()`:

```gdscript
	_test_fin_uniform_encoder_filters_by_region()
```

Add this function:

```gdscript
func _test_fin_uniform_encoder_filters_by_region() -> void:
	var encoded := SpeciesMarkingLayerScript.encode_fin_uniforms([
		{"type": "fin_edge", "region": "median_fin", "color": "#223344", "intensity": 0.7},
		{"type": "fin_spots", "region": "paired_fin", "color": "#aa8844", "intensity": 0.5},
		{"type": "horizontal_band", "region": "median_fin", "color": "#66ccff", "x_start": 0.1, "x_end": 0.8}
	], "median_fin")
	assert(int(encoded.get("fin_marking_count", 0)) == 2)
	assert(int(encoded.get("fin_marking_type_0", 0)) == SpeciesMarkingLayerScript.TYPE_FIN_EDGE)
	assert(int(encoded.get("fin_marking_type_1", 0)) == SpeciesMarkingLayerScript.TYPE_HORIZONTAL_BAND)
	assert(encoded.get("fin_marking_color_0") is Color)
	assert(encoded.get("fin_marking_rect_0") is Vector4)
	assert(encoded.get("fin_marking_params_0") is Vector4)
```

Add a call in `scripts/tools/FinMaterialTest.gd` `_ready()`:

```gdscript
	_test_fin_material_receives_filtered_marking_uniforms()
```

Add this function:

```gdscript
func _test_fin_material_receives_filtered_marking_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"marking_layers": [
			{"type": "fin_edge", "region": "median_fin", "color": "#223344", "intensity": 0.7},
			{"type": "fin_spots", "region": "paired_fin", "color": "#aa8844", "intensity": 0.5}
		]
	}, {"fin_region": "paired_fin"})
	assert(int(material.get_shader_parameter("fin_marking_count")) == 1)
	assert(int(material.get_shader_parameter("fin_marking_type_0")) == SpeciesMarkingLayerScript.TYPE_FIN_SPOTS)
	assert(material.get_shader_parameter("fin_marking_color_0") is Color)
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: FAIL because `encode_fin_uniforms` and fin shader uniforms do not exist.

- [ ] **Step 3: Add `encode_fin_uniforms`**

In `scripts/species/SpeciesMarkingLayer.gd`, add:

```gdscript
const MAX_FIN_MARKING_LAYERS := 4

static func encode_fin_uniforms(raw_layers: Variant, fin_region: String) -> Dictionary:
	var normalized := _normalize_layers(raw_layers)
	var region_id := int(REGION_BY_NAME.get(fin_region, REGION_MEDIAN_FIN))
	var filtered: Array[Dictionary] = []
	for layer in normalized:
		if filtered.size() >= MAX_FIN_MARKING_LAYERS:
			break
		if int(layer.get("region_id", REGION_BODY)) != region_id:
			continue
		var type_id := int(layer.get("type_id", TYPE_NONE))
		if not [TYPE_FIN_EDGE, TYPE_FIN_SPOTS, TYPE_HORIZONTAL_BAND, TYPE_VERTICAL_BAR, TYPE_REGION_COLOR].has(type_id):
			continue
		filtered.append(layer)
	var encoded := {"fin_marking_count": filtered.size()}
	for i in MAX_FIN_MARKING_LAYERS:
		if i < filtered.size():
			var layer: Dictionary = filtered[i]
			encoded["fin_marking_type_%d" % i] = int(layer["type_id"])
			encoded["fin_marking_blend_%d" % i] = int(layer["blend_id"])
			encoded["fin_marking_color_%d" % i] = _as_color(layer.get("color", "#ffffff"))
			encoded["fin_marking_rect_%d" % i] = Vector4(
				float(layer.get("x_start", 0.0)),
				float(layer.get("x_end", 1.0)),
				float(layer.get("y", 0.0)),
				float(layer.get("thickness", 0.08))
			)
			encoded["fin_marking_params_%d" % i] = Vector4(
				float(layer.get("intensity", 1.0)),
				float(layer.get("softness", 0.025)),
				float(layer.get("emissive", 0.0)),
				float(layer.get("seed", i))
			)
		else:
			encoded["fin_marking_type_%d" % i] = TYPE_NONE
			encoded["fin_marking_blend_%d" % i] = BLEND_NORMAL
			encoded["fin_marking_color_%d" % i] = Color(1, 1, 1, 1)
			encoded["fin_marking_rect_%d" % i] = Vector4(0.0, 1.0, 0.0, 0.08)
			encoded["fin_marking_params_%d" % i] = Vector4(0.0, 0.025, 0.0, float(i))
	return encoded
```

- [ ] **Step 4: Bind fin marking uniforms**

In `scripts/materials/ToonMaterialFactory.gd`, near the end of `make_fin_material`, add:

```gdscript
	var fin_marking_uniforms := SpeciesMarkingLayerScript.encode_fin_uniforms(
		effective.get("marking_layers", []),
		String(effective.get("fin_region", "median_fin"))
	)
	for key in fin_marking_uniforms.keys():
		material.set_shader_parameter(String(key), fin_marking_uniforms[key])
```

- [ ] **Step 5: Add fin shader uniforms and mask helpers**

In `shaders/fish_fin_toon.gdshader`, after the existing uniforms, add:

```glsl
const int FIN_TYPE_REGION_COLOR = 13;
const int FIN_TYPE_HORIZONTAL_BAND = 2;
const int FIN_TYPE_VERTICAL_BAR = 3;
const int FIN_TYPE_FIN_EDGE = 9;
const int FIN_TYPE_FIN_SPOTS = 10;
const int FIN_BLEND_MULTIPLY = 1;
const int FIN_BLEND_SCREEN = 2;
const int FIN_BLEND_ADD = 3;

uniform int fin_marking_count = 0;
uniform int fin_marking_type_0 = 0;
uniform int fin_marking_type_1 = 0;
uniform int fin_marking_type_2 = 0;
uniform int fin_marking_type_3 = 0;
uniform int fin_marking_blend_0 = 0;
uniform int fin_marking_blend_1 = 0;
uniform int fin_marking_blend_2 = 0;
uniform int fin_marking_blend_3 = 0;
uniform vec4 fin_marking_color_0 : source_color = vec4(1.0);
uniform vec4 fin_marking_color_1 : source_color = vec4(1.0);
uniform vec4 fin_marking_color_2 : source_color = vec4(1.0);
uniform vec4 fin_marking_color_3 : source_color = vec4(1.0);
uniform vec4 fin_marking_rect_0 = vec4(0.0, 1.0, 0.0, 0.08);
uniform vec4 fin_marking_rect_1 = vec4(0.0, 1.0, 0.0, 0.08);
uniform vec4 fin_marking_rect_2 = vec4(0.0, 1.0, 0.0, 0.08);
uniform vec4 fin_marking_rect_3 = vec4(0.0, 1.0, 0.0, 0.08);
uniform vec4 fin_marking_params_0 = vec4(0.0, 0.025, 0.0, 0.0);
uniform vec4 fin_marking_params_1 = vec4(0.0, 0.025, 0.0, 1.0);
uniform vec4 fin_marking_params_2 = vec4(0.0, 0.025, 0.0, 2.0);
uniform vec4 fin_marking_params_3 = vec4(0.0, 0.025, 0.0, 3.0);
```

Add helpers before `fragment()`:

```glsl
float fin_band_range(float value, float start_value, float end_value, float softness) {
	float a = smoothstep(start_value - softness, start_value + softness, value);
	float b = 1.0 - smoothstep(end_value - softness, end_value + softness, value);
	return clamp(a * b, 0.0, 1.0);
}

float fin_marking_mask(int kind, vec4 rect, vec4 params, vec2 uv) {
	float soft = max(params.y, 0.001);
	if (kind == FIN_TYPE_REGION_COLOR) {
		return fin_band_range(uv.x, min(rect.x, rect.y), max(rect.x, rect.y), soft);
	}
	if (kind == FIN_TYPE_FIN_EDGE) {
		float edge_y = 1.0 - smoothstep(rect.w, rect.w + soft, min(uv.y, 1.0 - uv.y));
		float edge_x = smoothstep(1.0 - rect.w - soft, 1.0 - rect.w, uv.x);
		return max(edge_y, edge_x);
	}
	if (kind == FIN_TYPE_HORIZONTAL_BAND) {
		return fin_band_range(uv.x, min(rect.x, rect.y), max(rect.x, rect.y), soft) * (1.0 - smoothstep(rect.w, rect.w + soft, abs(uv.y - (rect.z * 0.5 + 0.5))));
	}
	if (kind == FIN_TYPE_VERTICAL_BAR) {
		float center = (rect.x + rect.y) * 0.5;
		float half_width = max((rect.y - rect.x) * 0.5, rect.w * 0.5);
		return 1.0 - smoothstep(half_width, half_width + soft, abs(uv.x - center));
	}
	if (kind == FIN_TYPE_FIN_SPOTS) {
		vec2 cell = fract(vec2(uv.x * 6.0 + params.w, uv.y * 4.0)) - vec2(0.5);
		return smoothstep(0.22, 0.05, length(cell)) * fin_band_range(uv.x, min(rect.x, rect.y), max(rect.x, rect.y), soft);
	}
	return 0.0;
}

vec3 fin_blend(vec3 base, vec3 layer, int blend_mode, float amount) {
	vec3 blended = layer;
	if (blend_mode == FIN_BLEND_MULTIPLY) {
		blended = base * layer;
	} else if (blend_mode == FIN_BLEND_SCREEN) {
		blended = 1.0 - (1.0 - base) * (1.0 - layer);
	} else if (blend_mode == FIN_BLEND_ADD) {
		blended = min(base + layer, vec3(1.0));
	}
	return mix(base, blended, amount);
}

void apply_fin_marking(inout vec3 col, int kind, int blend_mode, vec4 color, vec4 rect, vec4 params, vec2 uv) {
	float mask = fin_marking_mask(kind, rect, params, uv) * clamp(params.x, 0.0, 1.0);
	col = fin_blend(col, color.rgb, blend_mode, mask * color.a);
}
```

In `fragment()`, after the base gradient and before the existing edge pass, add:

```glsl
	int fcount = min(fin_marking_count, 4);
	if (fcount > 0) { apply_fin_marking(col, fin_marking_type_0, fin_marking_blend_0, fin_marking_color_0, fin_marking_rect_0, fin_marking_params_0, v_uv); }
	if (fcount > 1) { apply_fin_marking(col, fin_marking_type_1, fin_marking_blend_1, fin_marking_color_1, fin_marking_rect_1, fin_marking_params_1, v_uv); }
	if (fcount > 2) { apply_fin_marking(col, fin_marking_type_2, fin_marking_blend_2, fin_marking_color_2, fin_marking_rect_2, fin_marking_params_2, v_uv); }
	if (fcount > 3) { apply_fin_marking(col, fin_marking_type_3, fin_marking_blend_3, fin_marking_color_3, fin_marking_rect_3, fin_marking_params_3, v_uv); }
```

- [ ] **Step 6: Pass fin-region overrides from FishRig**

In `scripts/creature/FishRig.gd`, update `_make_fin_material` to preserve caller overrides and pass `fin_region`:

```gdscript
func _make_fin_material(ray_axis: float, overrides: Dictionary = {}) -> ShaderMaterial:
	var axis_overrides := overrides.duplicate(true)
	axis_overrides["fin_ray_axis"] = ray_axis
	if not axis_overrides.has("fin_region"):
		axis_overrides["fin_region"] = "median_fin"
	return TMF.make_fin_material(parameters, axis_overrides)
```

Update material creation sites:

```gdscript
var dorsal_fin_mat := _make_fin_material(FIN_RAY_AXIS_VERTICAL_UP, {"fin_region": "median_fin"})
var ventral_fin_mat := _make_fin_material(FIN_RAY_AXIS_VERTICAL_DOWN, {"fin_region": "median_fin"})
var horizontal_fin_mat := _make_fin_material(FIN_RAY_AXIS_HORIZONTAL, {"fin_region": "caudal_fin"})
```

Use paired regions for pectoral and pelvic material calls:

```gdscript
_make_fin_material(FIN_RAY_AXIS_HORIZONTAL, {"fin_region": "paired_fin"})
_make_fin_material(FIN_RAY_AXIS_VERTICAL_DOWN, {"fin_region": "paired_fin"})
```

Use special regions for adipose and finlets:

```gdscript
"fin_region": "special_fin"
```

- [ ] **Step 7: Run focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: PASS with `MARKING_LAYER_TEST_OK` and fin material test success output.

- [ ] **Step 8: Commit Task 4**

```powershell
git add scripts/species/SpeciesMarkingLayer.gd scripts/materials/ToonMaterialFactory.gd shaders/fish_fin_toon.gdshader scripts/creature/FishRig.gd scripts/tools/MarkingLayerTest.gd scripts/tools/FinMaterialTest.gd
git commit -m "Add grouped fin marking layers"
```

---

### Task 5: Preserve Regional Layers In Presets And Archetypes

**Files:**
- Modify: `scripts/tools/PatternTest.gd`
- Modify: `scripts/tools/SpeciesArchetypeStoreTest.gd`
- Modify: `data/species_archetypes/neon_tetra.json`
- Modify: `data/species_archetypes/corydoras.json`
- Modify: `data/species_archetypes/mackerel.json`

- [ ] **Step 1: Write failing preset round-trip assertions**

In `_test_preset_round_trip()` in `scripts/tools/PatternTest.gd`, add `marking_layers` to `params`:

```gdscript
		"marking_layers": [
			{"type": "region_color", "region": "dorsal", "blend_mode": "multiply", "color": "#223344", "x_start": 0.0, "x_end": 1.0, "intensity": 0.5},
			{"type": "scale_region", "region": "flank", "intensity": 0.8}
		],
```

After `split` is created, add:

```gdscript
	var split_layers: Array = split.get("marking_layers", [])
	assert(split_layers.size() == 2)
	assert(String((split_layers[0] as Dictionary).get("region", "")) == "dorsal")
	assert(String((split_layers[0] as Dictionary).get("blend_mode", "")) == "multiply")
	assert(String((split_layers[1] as Dictionary).get("type", "")) == "scale_region")
```

After `rebuilt` is created, add:

```gdscript
	var rebuilt_layers: Array = rebuilt.get("marking_layers", [])
	assert(rebuilt_layers.size() == 2)
	assert(String((rebuilt_layers[0] as Dictionary).get("region", "")) == "dorsal")
```

- [ ] **Step 2: Write failing archetype assertions**

In `scripts/tools/SpeciesArchetypeStoreTest.gd`, in `_test_applies_archetype_profiles_and_markings()`, after existing layer type assertions, add:

```gdscript
	assert(String((layers[0] as Dictionary).get("region", "")) == "flank")
	assert(String((layers[1] as Dictionary).get("region", "")) == "ventral_flank")
	assert(String((layers[0] as Dictionary).get("blend_mode", "")) == "screen")
```

- [ ] **Step 3: Run focused tests and verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeStoreTest
```

Expected: `PatternTest` should pass if top-level `marking_layers` already round-trip; `SpeciesArchetypeStoreTest` should FAIL until JSON data includes `region` and `blend_mode`.

- [ ] **Step 4: Update neon tetra archetype layers**

In `data/species_archetypes/neon_tetra.json`, update the two existing layer dictionaries:

```json
{
	"type": "lateral_line",
	"zone": "body",
	"region": "flank",
	"blend_mode": "screen",
	"color": "#22d8ff",
	"x_start": 0.04,
	"x_end": 0.84,
	"y": 0.1,
	"thickness": 0.035,
	"emissive": 0.75
},
{
	"type": "horizontal_band",
	"zone": "body",
	"region": "ventral_flank",
	"blend_mode": "normal",
	"color": "#e93a3a",
	"x_start": 0.48,
	"x_end": 0.96,
	"y": -0.12,
	"thickness": 0.08,
	"emissive": 0.15
}
```

- [ ] **Step 5: Update corydoras archetype layers**

In `data/species_archetypes/corydoras.json`, update the two existing layer dictionaries:

```json
{
	"type": "saddle",
	"zone": "body",
	"region": "dorsal_flank",
	"blend_mode": "multiply",
	"color": "#4a4538",
	"x_start": 0.2,
	"x_end": 0.72,
	"y": 0.18,
	"thickness": 0.18,
	"emissive": 0.0
},
{
	"type": "scale_grid",
	"zone": "body",
	"region": "flank",
	"blend_mode": "screen",
	"color": "#f5f5dc",
	"x_start": 0.1,
	"x_end": 0.9,
	"y": -0.04,
	"thickness": 0.035,
	"emissive": 0.0
}
```

- [ ] **Step 6: Update mackerel archetype layers**

In `data/species_archetypes/mackerel.json`, replace the current single layer with:

```json
{
	"type": "horizontal_band",
	"zone": "body",
	"region": "dorsal_flank",
	"blend_mode": "multiply",
	"color": "#102a3a",
	"x_start": 0.06,
	"x_end": 0.9,
	"y": 0.2,
	"thickness": 0.08,
	"emissive": 0.0
},
{
	"type": "scale_region",
	"zone": "body",
	"region": "flank",
	"blend_mode": "normal",
	"color": "#ffffff",
	"x_start": 0.12,
	"x_end": 0.92,
	"y": 0.0,
	"thickness": 0.65,
	"intensity": 0.42,
	"emissive": 0.0
}
```

- [ ] **Step 7: Run focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeStoreTest
```

Expected: PASS with `PATTERN_TEST_OK` and `SPECIES_ARCHETYPE_STORE_TEST_OK`.

- [ ] **Step 8: Commit Task 5**

```powershell
git add scripts/tools/PatternTest.gd scripts/tools/SpeciesArchetypeStoreTest.gd data/species_archetypes/neon_tetra.json data/species_archetypes/corydoras.json data/species_archetypes/mackerel.json
git commit -m "Apply regional marking data to archetypes"
```

---

### Task 6: Add Regional Layer Editor UI

**Files:**
- Add: `scripts/ui/MarkingLayerEditor.gd`
- Modify: `scripts/ui/ParameterPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Add: `scripts/tools/MarkingLayerEditorTest.gd`
- Modify: `scripts/tools/ParameterPanelCategoryTest.gd`

- [ ] **Step 1: Write failing editor test**

Create `scripts/tools/MarkingLayerEditorTest.gd`:

```gdscript
extends Node

const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")

func _ready() -> void:
	_test_editor_emits_layer_changes()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/marking_layer_editor.ok", FileAccess.WRITE)
	file.store_string("regional marking layer editor verified")
	file.close()
	print("MARKING_LAYER_EDITOR_TEST_OK")
	get_tree().quit(0)

func _test_editor_emits_layer_changes() -> void:
	var editor := MarkingLayerEditorScript.new()
	add_child(editor)
	var seen := [[]]
	editor.layers_changed.connect(func(layers: Array) -> void:
		seen[0] = layers
	)
	editor.set_layers([
		{"type": "region_color", "region": "dorsal", "blend_mode": "multiply", "color": "#223344", "intensity": 0.5}
	])
	await get_tree().process_frame
	assert(editor.get_child_count() > 0)
	editor.call("_set_layer_field", 0, "region", "flank")
	await get_tree().process_frame
	assert((seen[0] as Array).size() == 1)
	assert(String(((seen[0] as Array)[0] as Dictionary).get("region", "")) == "flank")
```

- [ ] **Step 2: Write failing ParameterPanel integration assertion**

In `scripts/tools/ParameterPanelCategoryTest.gd`, after `panel.set_parameters(...)`, add `marking_layers` to the parameter dictionary:

```gdscript
		"marking_layers": [
			{"type": "region_color", "region": "dorsal", "blend_mode": "multiply", "color": "#223344", "intensity": 0.5}
		],
```

After existing Color Settings assertions, add:

```gdscript
	assert(_find_node_by_name(panel, "RegionalMarkingLayerEditor") != null)
```

Add this helper at the end of the file:

```gdscript
func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null
```

- [ ] **Step 3: Run focused tests and verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerEditorTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest
```

Expected: FAIL because `MarkingLayerEditor.gd` does not exist and `ParameterPanel` does not mount it.

- [ ] **Step 4: Add `MarkingLayerEditor.gd`**

Create `scripts/ui/MarkingLayerEditor.gd`:

```gdscript
class_name MarkingLayerEditor
extends VBoxContainer

signal layers_changed(layers: Array)

const LAYER_TYPES := ["lateral_line", "horizontal_band", "vertical_bar", "caudal_spot", "head_mask", "saddle", "ocellus", "calico_patch", "fin_edge", "fin_spots", "scale_grid", "reticulated_zone", "region_color", "scale_region", "iridescence_region"]
const REGIONS := ["body", "dorsal", "flank", "ventral", "dorsal_flank", "ventral_flank", "head", "cheek", "operculum", "caudal_peduncle", "median_fin", "paired_fin", "caudal_fin", "special_fin"]
const BLEND_MODES := ["normal", "multiply", "screen", "add"]

var layers: Array = []
var _updating := false

func set_layers(new_layers: Array) -> void:
	layers = new_layers.duplicate(true)
	_rebuild()

func _rebuild() -> void:
	_updating = true
	for child in get_children():
		child.queue_free()
	for i in layers.size():
		_add_layer_row(i, layers[i] as Dictionary)
	var add_button := Button.new()
	add_button.text = "+"
	add_button.tooltip_text = "Add regional layer"
	add_button.pressed.connect(func() -> void:
		layers.append({"type": "region_color", "region": "body", "blend_mode": "normal", "color": "#ffffff", "intensity": 1.0, "x_start": 0.0, "x_end": 1.0, "y": 0.0, "thickness": 0.2})
		_emit_and_rebuild()
	)
	add_child(add_button)
	_updating = false

func _add_layer_row(index: int, layer: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Layer_%d" % index
	_add_option(row, index, "type", LAYER_TYPES, String(layer.get("type", "region_color")))
	_add_option(row, index, "region", REGIONS, String(layer.get("region", "body")))
	_add_option(row, index, "blend_mode", BLEND_MODES, String(layer.get("blend_mode", "normal")))
	var intensity := SpinBox.new()
	intensity.min_value = 0.0
	intensity.max_value = 1.0
	intensity.step = 0.01
	intensity.value = float(layer.get("intensity", 1.0))
	intensity.value_changed.connect(func(value: float) -> void:
		_set_layer_field(index, "intensity", value)
	)
	row.add_child(intensity)
	add_child(row)

func _add_option(row: HBoxContainer, index: int, field: String, options: Array, value: String) -> void:
	var option := OptionButton.new()
	for item in options:
		option.add_item(String(item))
	var selected := options.find(value)
	option.select(maxi(selected, 0))
	option.item_selected.connect(func(item_index: int) -> void:
		_set_layer_field(index, field, option.get_item_text(item_index))
	)
	row.add_child(option)

func _set_layer_field(index: int, field: String, value: Variant) -> void:
	if _updating or index < 0 or index >= layers.size():
		return
	var layer := (layers[index] as Dictionary).duplicate(true)
	layer[field] = value
	layers[index] = layer
	layers_changed.emit(layers.duplicate(true))

func _emit_and_rebuild() -> void:
	layers_changed.emit(layers.duplicate(true))
	_rebuild()
```

- [ ] **Step 5: Mount editor in ParameterPanel**

In `scripts/ui/ParameterPanel.gd`, add a preload:

```gdscript
const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")
```

In `_build_controls()`, before the generic type checks inside the key loop, add:

```gdscript
		if String(key) == "marking_layers" and typeof(value) == TYPE_ARRAY:
			var section_body := _ensure_section("Pattern Settings")
			_add_marking_layer_editor(section_body, value as Array)
			continue
```

Add this method:

```gdscript
func _add_marking_layer_editor(parent: VBoxContainer, layers_value: Array) -> void:
	var editor := MarkingLayerEditorScript.new()
	editor.name = "RegionalMarkingLayerEditor"
	editor.set_layers(layers_value)
	editor.layers_changed.connect(func(new_layers: Array) -> void:
		if _updating_values:
			return
		parameters["marking_layers"] = new_layers.duplicate(true)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(editor)
```

- [ ] **Step 6: Add UI text labels**

In `scripts/ui/UiText.gd`, add keys to the parameter map:

```gdscript
	"marking_layers": "부위별 무늬 레이어",
	"marking_layer_type": "레이어 종류",
	"marking_layer_region": "부위",
	"marking_layer_blend_mode": "합성 방식",
	"marking_layer_intensity": "강도",
```

- [ ] **Step 7: Run focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerEditorTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest
```

Expected: PASS with `MARKING_LAYER_EDITOR_TEST_OK` and `PARAMETER_PANEL_CATEGORY_TEST_OK`.

- [ ] **Step 8: Commit Task 6**

```powershell
git add scripts/ui/MarkingLayerEditor.gd scripts/ui/ParameterPanel.gd scripts/ui/UiText.gd scripts/tools/MarkingLayerEditorTest.gd scripts/tools/ParameterPanelCategoryTest.gd
git commit -m "Add regional marking layer editor"
```

---

### Task 7: Verification And Visual QA

**Files:**
- Modify only files that fail the checks below.

- [ ] **Step 1: Run regional focused tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerEditorTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeStoreTest
```

Expected: each command exits 0 and prints its test-specific `_OK` marker.

- [ ] **Step 2: Run archetype smoke test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeVisualSmokeTest
```

Expected: PASS and all required archetypes still load.

- [ ] **Step 3: Run full Godot CLI suite**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

Expected: PASS with the full suite count. Treat `Failed to read the root certificate store` as non-fatal and use the runner exit code as source of truth.

- [ ] **Step 4: Run whitespace check**

Run:

```powershell
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 5: Manual visual QA**

In the running Godot editor or existing preview workflow, inspect these presets:

- `neon_tetra`: blue stripe stays on flank, red band stays lower rear flank, belly remains pale.
- `corydoras`: saddle is concentrated on dorsal flank, scale grid reads on flank, belly remains light.
- `mackerel`: dark banding stays dorsal-flank biased, flank scales read without tinting the belly.
- A default fish with no `marking_layers`: appearance matches the current default.
- A fin layer with `region = "paired_fin"`: pectoral/pelvic material receives it; dorsal/anal/caudal do not.

- [ ] **Step 6: Commit verification fixes**

If any verification step required code or data fixes, commit them:

```powershell
git add scripts shaders data
git commit -m "Stabilize regional appearance verification"
```

Skip this commit when Task 7 made no file changes.
