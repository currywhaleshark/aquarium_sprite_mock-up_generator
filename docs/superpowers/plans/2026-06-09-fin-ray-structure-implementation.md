# Fin Ray Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add species-readable fin rays, rayless adipose fins, and tuna/mackerel finlets without regressing existing fin editing or legacy fin-ray presets.

**Architecture:** Keep ordinary fins on the existing shared fin material path, but add explicit material overrides for rayless adipose and finlet slots. Store all new controls in `BodyProfile` defaults and `fin_profile`; render the ray structure in `fish_fin_toon.gdshader`; generate adipose/finlet geometry in `FishRig` from sampled animated shell anchors.

**Tech Stack:** Godot 4 GDScript, Godot spatial shader, existing Godot CLI test runner `tools/run_godot_cli_tests.ps1`.

---

## File Structure

- Modify `scripts/creature/BodyProfile.gd`: add fin-ray, adipose, and finlet defaults; add option-name helpers; preserve all fields through `fin_profile`.
- Modify `scripts/materials/ToonMaterialFactory.gd`: bind new shader uniforms; add rayless/adipose/finlet material helpers using per-slot overrides.
- Modify `shaders/fish_fin_toon.gdshader`: add style, spread, spine, branching, segmentation, irregularity, body-color, and color-blend uniforms; keep legacy parallel rays when style is `none`.
- Modify `scripts/ui/ParameterPanel.gd`: expose `fin_ray_style` as an option and set exact ranges for new numeric controls.
- Modify `scripts/ui/UiText.gd`: add Korean labels for new parameters and fin-ray style options.
- Modify `scripts/creature/FishRig.gd`: add adipose and finlet slots, dedicated materials, sampled placement, and per-frame animated anchor updates.
- Modify `data/species_archetypes/betta.json` and `data/species_archetypes/guppy.json`: add required fan/threaded ray defaults.
- Modify or add tuna/mackerel/salmonid archetype data: use existing archetypes if present; otherwise add complete `tuna.json`, `mackerel.json`, and `trout.json` files with profile sections and non-empty `marking_layers`.
- Modify `scripts/tools/FinMaterialTest.gd`: cover new uniforms, rayless material overrides, and legacy fallback.
- Modify `scripts/tools/ParameterPanelRangeTest.gd`: cover option and slider ranges.
- Modify `scripts/tools/SpeciesArchetypeVisualSmokeTest.gd`: cover archetype defaults and node presence.
- Add `scenes/FinSpecialSlotTest.tscn` and `scripts/tools/FinSpecialSlotTest.gd`: cover adipose/finlet geometry, materials, and animated anchor updates.

---

### Task 1: Parameter Contract And Round Trip

**Files:**
- Modify: `scripts/creature/BodyProfile.gd`
- Modify: `scripts/tools/FinMaterialTest.gd`

- [ ] **Step 1: Write failing default and round-trip tests**

Add calls in `scripts/tools/FinMaterialTest.gd` `_ready()`:

```gdscript
	_test_fin_ray_defaults_are_injected()
	_test_new_fin_fields_round_trip_through_fin_profile()
```

Add these test functions:

```gdscript
func _test_fin_ray_defaults_are_injected() -> void:
	var params := {}
	BodyProfileScript.ensure_visual_parameters(params)
	assert(String(params.get("fin_ray_style", "")) == "none")
	assert(abs(float(params.get("fin_ray_count", -1.0)) - 0.0) < 0.001)
	assert(abs(float(params.get("fin_ray_spread", -1.0)) - 0.75) < 0.001)
	assert(abs(float(params.get("adipose_fin_position", 0.0)) - 0.82) < 0.001)
	assert(bool(params.get("finlet_enabled", true)) == false)

func _test_new_fin_fields_round_trip_through_fin_profile() -> void:
	var params := {
		"fin_ray_style": "fan",
		"fin_ray_root_bias": -0.2,
		"fin_ray_spread": 0.9,
		"fin_spine_count": 3.0,
		"fin_spine_strength": 0.4,
		"fin_ray_branching": 0.7,
		"fin_ray_segmentation": 0.5,
		"fin_ray_irregularity": 0.2,
		"adipose_fin_enabled": true,
		"adipose_fin_size": 0.32,
		"adipose_fin_position": 0.82,
		"adipose_fin_height": 0.18,
		"adipose_fin_roundness": 0.75,
		"adipose_fin_opacity": 0.72,
		"adipose_fin_rayed": 0.0,
		"finlet_enabled": true,
		"finlet_dorsal_count": 8.0,
		"finlet_ventral_count": 8.0,
		"finlet_size": 0.24,
		"finlet_taper": 0.35,
		"finlet_spacing": 0.72,
		"finlet_pitch": 0.25,
		"finlet_color_blend": 0.5
	}
	var split := BodyProfileScript.split_parameters_into_profiles(params, {"name": "new_fin_fields"})
	var fin_profile: Dictionary = split.get("fin_profile", {})
	assert(String(fin_profile.get("fin_ray_style", "")) == "fan")
	assert(abs(float(fin_profile.get("fin_ray_branching", 0.0)) - 0.7) < 0.001)
	assert(bool(fin_profile.get("adipose_fin_enabled", false)) == true)
	assert(abs(float(fin_profile.get("finlet_dorsal_count", 0.0)) - 8.0) < 0.001)
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	assert(String(rebuilt.get("fin_ray_style", "")) == "fan")
	assert(bool(rebuilt.get("adipose_fin_enabled", false)) == true)
	assert(abs(float(rebuilt.get("finlet_ventral_count", 0.0)) - 8.0) < 0.001)
```

- [ ] **Step 2: Run focused test to verify failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: FAIL because `fin_ray_style`, adipose, and finlet defaults/round-trip fields are not present.

- [ ] **Step 3: Add defaults and option helpers**

In `scripts/creature/BodyProfile.gd`, add constants near the existing visual constants:

```gdscript
const FIN_RAY_STYLE_NAMES := ["none", "soft", "spiny", "mixed", "fan", "threaded"]
const FIN_RAY_DEFAULTS := {
	"fin_ray_style": "none",
	"fin_ray_count": 0.0,
	"fin_ray_strength": 0.0,
	"fin_ray_root_bias": 0.0,
	"fin_ray_spread": 0.75,
	"fin_spine_count": 0.0,
	"fin_spine_strength": 0.0,
	"fin_ray_branching": 0.0,
	"fin_ray_segmentation": 0.0,
	"fin_ray_irregularity": 0.0
}
const ADIPOSE_FIN_DEFAULTS := {
	"adipose_fin_enabled": false,
	"adipose_fin_size": 0.0,
	"adipose_fin_position": 0.82,
	"adipose_fin_height": 0.18,
	"adipose_fin_roundness": 0.75,
	"adipose_fin_opacity": 0.72,
	"adipose_fin_rayed": 0.0
}
const FINLET_DEFAULTS := {
	"finlet_enabled": false,
	"finlet_dorsal_count": 0.0,
	"finlet_ventral_count": 0.0,
	"finlet_size": 0.25,
	"finlet_taper": 0.35,
	"finlet_spacing": 0.72,
	"finlet_pitch": 0.25,
	"finlet_color_blend": 0.5
}
```

Add this helper:

```gdscript
static func fin_ray_style_names() -> Array[String]:
	var names: Array[String] = []
	for name in FIN_RAY_STYLE_NAMES:
		names.append(String(name))
	return names
```

Extend `ensure_visual_parameters()`:

```gdscript
	for key in FIN_RAY_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = FIN_RAY_DEFAULTS[key]
	for key in ADIPOSE_FIN_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = ADIPOSE_FIN_DEFAULTS[key]
	for key in FINLET_DEFAULTS.keys():
		if not parameters.has(key):
			parameters[key] = FINLET_DEFAULTS[key]
```

Extend the `fin_profile` `_pick()` list with the new keys:

```gdscript
		"fin_ray_style", "fin_ray_root_bias", "fin_ray_spread",
		"fin_spine_count", "fin_spine_strength", "fin_ray_branching",
		"fin_ray_segmentation", "fin_ray_irregularity",
		"adipose_fin_enabled", "adipose_fin_size", "adipose_fin_position",
		"adipose_fin_height", "adipose_fin_roundness", "adipose_fin_opacity",
		"adipose_fin_rayed",
		"finlet_enabled", "finlet_dorsal_count", "finlet_ventral_count",
		"finlet_size", "finlet_taper", "finlet_spacing", "finlet_pitch",
		"finlet_color_blend",
```

- [ ] **Step 4: Run focused test to verify pass**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: PASS and output includes `FIN_MATERIAL_TEST_OK`.

- [ ] **Step 5: Commit**

```powershell
git add scripts\creature\BodyProfile.gd scripts\tools\FinMaterialTest.gd
git commit -m "Add fin structure parameter contract"
```

---

### Task 2: Shader And Material Contract

**Files:**
- Modify: `shaders/fish_fin_toon.gdshader`
- Modify: `scripts/materials/ToonMaterialFactory.gd`
- Modify: `scripts/tools/FinMaterialTest.gd`

- [ ] **Step 1: Write failing material tests**

Add calls in `FinMaterialTest.gd` `_ready()`:

```gdscript
	_test_fin_material_exposes_ray_structure_uniforms()
	_test_rayless_material_overrides_global_rays()
	_test_legacy_parallel_ray_fallback_contract()
```

Add tests:

```gdscript
func _test_fin_material_exposes_ray_structure_uniforms() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"fin_ray_style": "mixed",
		"fin_ray_count": 44.0,
		"fin_ray_strength": 0.8,
		"fin_ray_root_bias": -0.15,
		"fin_ray_spread": 0.9,
		"fin_spine_count": 4.0,
		"fin_spine_strength": 0.7,
		"fin_ray_branching": 0.45,
		"fin_ray_segmentation": 0.35,
		"fin_ray_irregularity": 0.2,
		"base_color": "#225566",
		"fin_color_blend": 0.4
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_style_id")) - 3.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 44.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_count")) - 4.0) < 0.001)
	assert(material.get_shader_parameter("fin_body_color") is Color)
	assert(abs(float(material.get_shader_parameter("fin_color_blend")) - 0.4) < 0.001)

func _test_rayless_material_overrides_global_rays() -> void:
	var material := ToonMaterialFactoryScript.make_rayless_fin_material({
		"fin_ray_style": "mixed",
		"fin_ray_count": 20.0,
		"fin_ray_strength": 0.9,
		"fin_spine_count": 6.0,
		"fin_spine_strength": 0.8
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_count")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_spine_strength")) - 0.0) < 0.001)

func _test_legacy_parallel_ray_fallback_contract() -> void:
	var material := ToonMaterialFactoryScript.make_fin_material({
		"fin_ray_style": "none",
		"fin_ray_count": 9.0,
		"fin_ray_strength": 0.5
	})
	assert(abs(float(material.get_shader_parameter("fin_ray_style_id")) - 0.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_count")) - 9.0) < 0.001)
	assert(abs(float(material.get_shader_parameter("fin_ray_strength")) - 0.5) < 0.001)
```

- [ ] **Step 2: Run focused test to verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: FAIL because the new uniforms and `make_rayless_fin_material()` are absent.

- [ ] **Step 3: Add material helpers**

In `ToonMaterialFactory.gd`, add:

```gdscript
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
```

Change the signature to accept overrides:

```gdscript
static func make_fin_material(parameters: Dictionary, overrides: Dictionary = {}) -> ShaderMaterial:
	var effective := _with_overrides(parameters, overrides)
```

Use `effective` for all parameter reads in `make_fin_material()`, expand `fin_ray_count` clamp to `48.0`, and bind:

```gdscript
	material.set_shader_parameter("fin_ray_style_id", _fin_ray_style_id(String(effective.get("fin_ray_style", "none"))))
	material.set_shader_parameter("fin_ray_count", clampf(float(effective.get("fin_ray_count", 0.0)), 0.0, 48.0))
	material.set_shader_parameter("fin_ray_root_bias", clampf(float(effective.get("fin_ray_root_bias", 0.0)), -1.0, 1.0))
	material.set_shader_parameter("fin_ray_spread", clampf(float(effective.get("fin_ray_spread", 0.75)), 0.0, 1.0))
	material.set_shader_parameter("fin_spine_count", clampf(float(effective.get("fin_spine_count", 0.0)), 0.0, 12.0))
	material.set_shader_parameter("fin_spine_strength", clampf(float(effective.get("fin_spine_strength", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_branching", clampf(float(effective.get("fin_ray_branching", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_segmentation", clampf(float(effective.get("fin_ray_segmentation", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_ray_irregularity", clampf(float(effective.get("fin_ray_irregularity", 0.0)), 0.0, 1.0))
	material.set_shader_parameter("fin_body_color", _as_color(effective.get("fin_body_color", effective.get("base_color", "#7ee1e8"))))
	material.set_shader_parameter("fin_color_blend", clampf(float(effective.get("fin_color_blend", 0.0)), 0.0, 1.0))
```

Add rayless helpers:

```gdscript
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
```

- [ ] **Step 4: Replace shader uniform ranges and add masks**

In `fish_fin_toon.gdshader`, replace the existing `fin_ray_count` uniform line:

```glsl
uniform float fin_ray_count : hint_range(0.0, 48.0) = 0.0;
```

Do not add a second `fin_ray_count` declaration; the existing `fin_ray_strength`
uniform remains in place. Then add these new uniforms near the fin-ray uniforms:

```glsl
uniform float fin_ray_style_id : hint_range(0.0, 5.0) = 0.0;
uniform float fin_ray_root_bias : hint_range(-1.0, 1.0) = 0.0;
uniform float fin_ray_spread : hint_range(0.0, 1.0) = 0.75;
uniform float fin_spine_count : hint_range(0.0, 12.0) = 0.0;
uniform float fin_spine_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_branching : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_segmentation : hint_range(0.0, 1.0) = 0.0;
uniform float fin_ray_irregularity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fin_body_color : source_color = vec4(0.49, 0.88, 0.91, 1.0);
uniform float fin_color_blend : hint_range(0.0, 1.0) = 0.0;
```

After the existing base color mix at the start of `fragment()`, apply the body/fin
blend required by finlets:

```glsl
	col = mix(col, fin_body_color.rgb, fin_color_blend * fin_body_color.a);
```

Then replace the current ray block with helper functions and this fragment block:

```glsl
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
	vec2 root = vec2(0.0, 0.5 + fin_ray_root_bias * 0.35);
	float angle = atan(uv.y - root.y, max(uv.x, 0.001));
	float radial_coord = clamp((angle / PI) + 0.5, 0.0, 1.0);
	return mix(uv.y, radial_coord, fin_ray_spread);
}
```

```glsl
	if (fin_ray_count > 0.5 && fin_ray_strength > 0.0) {
		float legacy_ray = pow(abs(sin(v_uv.y * fin_ray_count * TAU)), 18.0);
		float coord = ray_coordinate(v_uv);
		float organic = (hash11(floor(coord * fin_ray_count)) - 0.5) * fin_ray_irregularity * 0.06;
		float soft_ray = repeated_line(coord + organic, fin_ray_count, 0.45);
		float branch_offset = smoothstep(0.55, 1.0, v_uv.x) * fin_ray_branching * 0.035;
		float branch_ray = max(
			repeated_line(coord + branch_offset, fin_ray_count, 0.44),
			repeated_line(coord - branch_offset, fin_ray_count, 0.44)
		);
		float segment = repeated_line(v_uv.x, mix(8.0, 18.0, v_uv.x), 0.42) * fin_ray_segmentation;
		float ray = legacy_ray;
		if (fin_ray_style_id > 0.5) {
			ray = mix(soft_ray, branch_ray, fin_ray_branching);
			ray = max(ray, segment * ray * 0.45);
		}
		float ray_fade = smoothstep(0.05, 0.8, v_uv.x);
		col = mix(col, fin_edge_color.rgb, ray * ray_fade * fin_ray_strength);
	}
```

Add spine support after the soft-ray block:

```glsl
	if (fin_spine_count > 0.5 && fin_spine_strength > 0.0) {
		float coord = ray_coordinate(v_uv);
		float spine_zone = 1.0 - smoothstep(0.35, 0.85, coord);
		float spine = repeated_line(coord, fin_spine_count, 0.38) * spine_zone;
		col = mix(col, fin_edge_color.rgb, spine * fin_spine_strength);
	}
```

- [ ] **Step 5: Run focused material/shader test**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
```

Expected: PASS and no shader compile errors.

- [ ] **Step 6: Commit**

```powershell
git add shaders\fish_fin_toon.gdshader scripts\materials\ToonMaterialFactory.gd scripts\tools\FinMaterialTest.gd
git commit -m "Add fin ray shader and material contract"
```

---

### Task 3: Parameter Panel And Korean Labels

**Files:**
- Modify: `scripts/ui/ParameterPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Modify: `scripts/tools/ParameterPanelRangeTest.gd`

- [ ] **Step 1: Write failing UI range test**

In `ParameterPanelRangeTest.gd`, extend `panel.set_parameters()`:

```gdscript
		"fin_ray_style": "fan",
		"fin_ray_count": 48.0,
		"fin_ray_root_bias": -0.25,
		"fin_ray_spread": 0.75,
		"fin_spine_count": 12.0,
		"fin_spine_strength": 0.5,
		"fin_ray_branching": 0.5,
		"fin_ray_segmentation": 0.5,
		"fin_ray_irregularity": 0.5,
		"adipose_fin_position": 0.82,
		"finlet_pitch": 0.25,
		"finlet_dorsal_count": 9.0
```

Add assertions:

```gdscript
	var fin_ray_count_slider := _find_slider_for_label(panel, UiText.parameter("fin_ray_count"))
	var fin_root_bias_slider := _find_slider_for_label(panel, UiText.parameter("fin_ray_root_bias"))
	var fin_spine_count_slider := _find_slider_for_label(panel, UiText.parameter("fin_spine_count"))
	var adipose_position_slider := _find_slider_for_label(panel, UiText.parameter("adipose_fin_position"))
	var finlet_pitch_slider := _find_slider_for_label(panel, UiText.parameter("finlet_pitch"))
	assert(fin_ray_count_slider != null)
	assert(absf(fin_ray_count_slider.max_value - 48.0) < 0.0001)
	assert(fin_root_bias_slider != null)
	assert(fin_root_bias_slider.min_value <= -1.0)
	assert(fin_root_bias_slider.max_value >= 1.0)
	assert(fin_spine_count_slider != null)
	assert(absf(fin_spine_count_slider.max_value - 12.0) < 0.0001)
	assert(adipose_position_slider != null)
	assert(absf(adipose_position_slider.min_value - 0.0) < 0.0001)
	assert(absf(adipose_position_slider.max_value - 1.0) < 0.0001)
	assert(finlet_pitch_slider != null)
	assert(finlet_pitch_slider.min_value <= -1.0)
	assert(finlet_pitch_slider.max_value >= 1.0)
	assert(UiText.parameter("fin_ray_style") == "기조 스타일")
	assert(UiText.option("threaded") == "실지느러미형")
```

- [ ] **Step 2: Run focused UI test to verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelRangeTest
```

Expected: FAIL because ranges and labels are not present.

- [ ] **Step 3: Update option/range logic**

In `ParameterPanel.gd`, extend `_is_option_parameter()`:

```gdscript
	return key == "swim_mode" or key == "pattern_type" or key == "palette_scheme" or key == "scale_type" or key == "pectoral_flap_sync" or key == "cephalic_horns" or key == "ray_locomotion_mode" or key == "ray_head_shape" or key == "ray_disc_shape" or key == "ray_tail_style" or key == "fin_ray_style"
```

Extend `_options_for_key()`:

```gdscript
	if key == "fin_ray_style":
		return BodyProfileScript.fin_ray_style_names()
```

Extend `_min_for_key()` before `_is_signed_parameter()`:

```gdscript
	if key == "adipose_fin_position":
		return 0.0
	if key == "fin_ray_root_bias" or key == "finlet_pitch":
		return -1.0
```

Extend `_max_for_key()` before `_is_signed_parameter()` and before generic string
matching. This order is required because `adipose_fin_position` contains
`position` and would otherwise be treated as a signed slider:

```gdscript
	if key == "fin_ray_count":
		return 48.0
	if key == "fin_spine_count" or key == "finlet_dorsal_count" or key == "finlet_ventral_count":
		return 12.0
	if key == "fin_ray_root_bias" or key == "finlet_pitch":
		return 1.0
	if key == "adipose_fin_position":
		return 1.0
	if key.begins_with("fin_ray_") or key.begins_with("adipose_fin_") or key.begins_with("finlet_") or key == "fin_spine_strength":
		return 1.0
```

- [ ] **Step 4: Add labels**

In `UiText.gd`, ensure `OPTION_LABELS` contains all six fin-ray style labels. Keep
existing entries such as `none`, `spiny`, or `fan` if they already exist; add only
the missing keys:

```gdscript
	"none": "없음",
	"soft": "연조형",
	"spiny": "가시형",
	"mixed": "혼합형",
	"fan": "부채형",
	"threaded": "실지느러미형",
```

Add parameter labels:

```gdscript
	"fin_ray_style": "기조 스타일",
	"fin_ray_root_bias": "기조 중심",
	"fin_ray_spread": "기조 펼침",
	"fin_spine_count": "가시 기조 수",
	"fin_spine_strength": "가시 기조 선명도",
	"fin_ray_branching": "기조 갈라짐",
	"fin_ray_segmentation": "기조 마디",
	"fin_ray_irregularity": "기조 불규칙성",
	"adipose_fin_enabled": "기름지느러미",
	"adipose_fin_size": "기름지느러미 크기",
	"adipose_fin_position": "기름지느러미 위치",
	"adipose_fin_height": "기름지느러미 높이",
	"adipose_fin_roundness": "기름지느러미 둥글기",
	"adipose_fin_opacity": "기름지느러미 투명도",
	"adipose_fin_rayed": "기름지느러미 기조 예외",
	"finlet_enabled": "토막지느러미",
	"finlet_dorsal_count": "등쪽 토막 개수",
	"finlet_ventral_count": "배쪽 토막 개수",
	"finlet_size": "토막 크기",
	"finlet_taper": "토막 작아짐",
	"finlet_spacing": "토막 간격",
	"finlet_pitch": "토막 기울기",
	"finlet_color_blend": "토막 색 섞임",
```

- [ ] **Step 5: Run focused UI test**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelRangeTest
```

Expected: PASS and output includes `PARAMETER_PANEL_RANGE_TEST_OK`.

- [ ] **Step 6: Commit**

```powershell
git add scripts\ui\ParameterPanel.gd scripts\ui\UiText.gd scripts\tools\ParameterPanelRangeTest.gd
git commit -m "Expose fin structure controls"
```

---

### Task 4: Adipose Fin Slot

**Files:**
- Modify: `scripts/creature/FishRig.gd`
- Add: `scenes/FinSpecialSlotTest.tscn`
- Add: `scripts/tools/FinSpecialSlotTest.gd`

- [ ] **Step 1: Add failing special-slot test scene**

Create `scenes/FinSpecialSlotTest.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tools/FinSpecialSlotTest.gd" id="1"]

[node name="FinSpecialSlotTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Write failing adipose tests**

Create `scripts/tools/FinSpecialSlotTest.gd`:

```gdscript
extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")

func _ready() -> void:
	_test_adipose_fin_uses_rayless_material_and_safe_position()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_special_slot.ok", FileAccess.WRITE)
	file.store_string("special fin slots verified")
	file.close()
	print("FIN_SPECIAL_SLOT_TEST_OK")
	get_tree().quit(0)

func _test_adipose_fin_uses_rayless_material_and_safe_position() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"fin_ray_style": "mixed",
		"fin_ray_count": 24.0,
		"fin_ray_strength": 0.8,
		"dorsal_2_enabled": true,
		"dorsal_2_attach_t": 0.68,
		"adipose_fin_enabled": true,
		"adipose_fin_size": 0.25,
		"adipose_fin_position": 0.70,
		"adipose_fin_rayed": 0.0
	})
	await get_tree().process_frame
	var adipose := fish.get_node_or_null("BodyPivot/AdiposeFin") as MeshInstance3D
	assert(adipose != null)
	assert(adipose.material_override is ShaderMaterial)
	assert(abs(float(adipose.material_override.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	assert(adipose.position.x > 0.0)
	fish.queue_free()
```

- [ ] **Step 3: Run special-slot test to verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinSpecialSlotTest
```

Expected: FAIL because the scene or `AdiposeFin` node does not exist.

- [ ] **Step 4: Add adipose node fields and builder**

In `FishRig.gd`, add a field near other fin node fields:

```gdscript
var adipose_fin: MeshInstance3D = null
```

Reset it in `build()` with the other node resets:

```gdscript
	adipose_fin = null
```

Add helpers:

```gdscript
func _effective_adipose_attach_t() -> float:
	var requested := clampf(param_float("adipose_fin_position", 0.82), 0.0, 1.0)
	var min_t := 0.72
	if bool(parameters.get("dorsal_2_enabled", false)):
		min_t = maxf(min_t, param_float("dorsal_2_attach_t", 0.68) + 0.08)
	else:
		min_t = maxf(min_t, param_float("dorsal_1_attach_t", 0.45) + 0.18)
	return clampf(maxf(requested, min_t), 0.0, 0.92)

func _build_adipose_fin(fin_mat: Material) -> void:
	if not bool(parameters.get("adipose_fin_enabled", false)):
		return
	var size := param_float("adipose_fin_size", 0.0)
	if size <= 0.001:
		return
	var height := param_float("adipose_fin_height", 0.18) * size
	var length := size * mix(0.55, 0.85, param_float("adipose_fin_roundness", 0.75))
	var points := PackedVector3Array([
		Vector3(-length * 0.45, 0.0, 0.0),
		Vector3(-length * 0.10, height, 0.0),
		Vector3(length * 0.45, height * 0.25, 0.0),
		Vector3(length * 0.40, 0.0, 0.0)
	])
	adipose_fin = PF.polygon_fin("AdiposeFin", points, fin_mat)
	body_pivot.add_child(adipose_fin)
	var attach_t := _effective_adipose_attach_t()
	adipose_fin.position = _surface_position("dorsal", attach_t, 0.02)
	adipose_fin.rotation_degrees.z = _surface_tangent_angle_degrees("dorsal", attach_t)
```

Call it after dorsal fins are built:

```gdscript
	var adipose_mat := TMF.make_rayless_fin_material(parameters, {
		"fin_opacity": clampf(param_float("adipose_fin_opacity", 0.72), 0.0, 1.0)
	})
	if float(parameters.get("adipose_fin_rayed", 0.0)) > 0.001:
		adipose_mat = TMF.make_fin_material(parameters, {
			"fin_ray_strength": clampf(float(parameters.get("adipose_fin_rayed", 0.0)), 0.0, 1.0)
		})
	_build_adipose_fin(adipose_mat)
```

- [ ] **Step 5: Animate adipose anchor**

In `_apply_animated_fins()`, add after dorsal fin updates:

```gdscript
	if adipose_fin:
		var adipose_attach_t := _effective_adipose_attach_t()
		adipose_fin.position = _animated_surface_position("dorsal", adipose_attach_t, 0.02, 0.0, 0.0, centers, yaws)
		adipose_fin.rotation_degrees = Vector3(_median_fin_flap(loop_phase, 0.18) * 0.25, 0.0, _surface_tangent_angle_degrees("dorsal", adipose_attach_t))
```

- [ ] **Step 6: Run special-slot test**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinSpecialSlotTest
```

Expected: PASS and output includes `FIN_SPECIAL_SLOT_TEST_OK`.

- [ ] **Step 7: Commit**

```powershell
git add scenes\FinSpecialSlotTest.tscn scripts\tools\FinSpecialSlotTest.gd scripts\creature\FishRig.gd
git commit -m "Add rayless adipose fin slot"
```

---

### Task 5: Finlet Arrays

**Files:**
- Modify: `scripts/creature/FishRig.gd`
- Modify: `scripts/tools/FinSpecialSlotTest.gd`

- [ ] **Step 1: Add failing finlet tests**

Extend `_ready()` in `FinSpecialSlotTest.gd`:

```gdscript
	_test_finlets_use_rayless_material_and_animated_anchors()
```

Add:

```gdscript
func _test_finlets_use_rayless_material_and_animated_anchors() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = true
	fish.set_parameters({
		"body_wave_amount": 0.35,
		"fin_ray_style": "fan",
		"fin_ray_count": 24.0,
		"fin_ray_strength": 0.8,
		"finlet_enabled": true,
		"finlet_dorsal_count": 4.0,
		"finlet_ventral_count": 4.0,
		"finlet_size": 0.22,
		"finlet_pitch": 0.25
	})
	await get_tree().process_frame
	var first := fish.get_node_or_null("BodyPivot/FinletDorsal_0") as MeshInstance3D
	var ventral := fish.get_node_or_null("BodyPivot/FinletVentral_0") as MeshInstance3D
	assert(first != null)
	assert(ventral != null)
	assert(first.material_override is ShaderMaterial)
	assert(abs(float(first.material_override.get_shader_parameter("fin_ray_count")) - 0.0) < 0.001)
	var before := first.global_position
	fish._process(0.2)
	await get_tree().process_frame
	var after := first.global_position
	assert(before.distance_to(after) > 0.0001)
	fish.queue_free()
```

- [ ] **Step 2: Run special-slot test to verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinSpecialSlotTest
```

Expected: FAIL because finlet nodes are not created.

- [ ] **Step 3: Add finlet fields and builders**

In `FishRig.gd`, add:

```gdscript
var finlet_nodes: Array[MeshInstance3D] = []
var finlet_specs: Array[Dictionary] = []
```

Reset them in `build()`:

```gdscript
	finlet_nodes.clear()
	finlet_specs.clear()
```

Add:

```gdscript
func _finlet_attach_t(index: int, count: int) -> float:
	if count <= 1:
		return 0.82
	var start_t := 0.70
	var end_t := 0.90
	var span := end_t - start_t
	var ratio := float(index) / float(count - 1)
	return start_t + span * ratio

func _build_finlets(finlet_mat: Material) -> void:
	if not bool(parameters.get("finlet_enabled", false)):
		return
	var dorsal_count := clampi(int(round(param_float("finlet_dorsal_count", 0.0))), 0, 12)
	var ventral_count := clampi(int(round(param_float("finlet_ventral_count", 0.0))), 0, 12)
	_build_finlet_side("dorsal", dorsal_count, finlet_mat)
	_build_finlet_side("ventral", ventral_count, finlet_mat)

func _build_finlet_side(side: String, count: int, finlet_mat: Material) -> void:
	var base_size := param_float("finlet_size", 0.25)
	var taper := clampf(param_float("finlet_taper", 0.35), 0.0, 1.0)
	for i in range(count):
		var ratio := 0.0 if count <= 1 else float(i) / float(count - 1)
		var scale := base_size * mix(1.0, 0.65, ratio * taper)
		var height := scale * 0.42
		var length := scale * 0.36
		var y_sign := 1.0 if side == "dorsal" else -1.0
		var points := PackedVector3Array([
			Vector3(-length * 0.45, 0.0, 0.0),
			Vector3(0.0, height * y_sign, 0.0),
			Vector3(length * 0.45, 0.0, 0.0)
		])
		var node_name := "FinletDorsal_%d" % i if side == "dorsal" else "FinletVentral_%d" % i
		var finlet := PF.polygon_fin(node_name, points, finlet_mat)
		body_pivot.add_child(finlet)
		var attach_t := _finlet_attach_t(i, count)
		var margin := 0.012
		finlet.position = _surface_position(side, attach_t, margin)
		finlet.rotation_degrees.z = _surface_tangent_angle_degrees(side, attach_t) + param_float("finlet_pitch", 0.25) * 15.0
		finlet_nodes.append(finlet)
		finlet_specs.append({"node": finlet, "side": side, "attach_t": attach_t, "margin": margin})
```

Call it after median fins are built:

```gdscript
	_build_finlets(TMF.make_finlet_material(parameters))
```

- [ ] **Step 4: Add animated finlet update**

In `_apply_animated_fins()`, add:

```gdscript
	for spec in finlet_specs:
		var finlet := spec.get("node") as MeshInstance3D
		if finlet == null:
			continue
		var side := String(spec.get("side", "dorsal"))
		var attach_t := float(spec.get("attach_t", 0.82))
		var margin := float(spec.get("margin", 0.012))
		finlet.position = _animated_surface_position(side, attach_t, margin, 0.0, 0.0, centers, yaws)
		var flap := _median_fin_flap(loop_phase, attach_t) * 0.08
		finlet.rotation_degrees = Vector3(flap, 0.0, _surface_tangent_angle_degrees(side, attach_t) + param_float("finlet_pitch", 0.25) * 15.0)
```

- [ ] **Step 5: Run special-slot test**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinSpecialSlotTest
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts\creature\FishRig.gd scripts\tools\FinSpecialSlotTest.gd
git commit -m "Add animated finlet arrays"
```

---

### Task 6: Archetype Defaults

**Files:**
- Modify: `data/species_archetypes/betta.json`
- Modify: `data/species_archetypes/guppy.json`
- Create or Modify: `data/species_archetypes/trout.json`
- Create or Modify: `data/species_archetypes/tuna.json`
- Create or Modify: `data/species_archetypes/mackerel.json`
- Modify: `scripts/tools/SpeciesArchetypeVisualSmokeTest.gd`

- [ ] **Step 1: Write failing archetype assertions**

In `SpeciesArchetypeVisualSmokeTest.gd`, extend `REQUIRED_IDS` with existing or newly added ids:

```gdscript
	"trout",
	"tuna",
	"mackerel"
```

Extend `_check_signature_nodes()`:

```gdscript
		"guppy":
			assert(String(applied.get("fin_ray_style", "")) == "threaded")
			assert(float(applied.get("fin_ray_branching", 0.0)) > 0.3)
		"trout":
			assert(bool(applied.get("adipose_fin_enabled", false)) == true)
			assert(fish.get_node_or_null("BodyPivot/AdiposeFin") != null)
		"tuna":
			assert(String(applied.get("caudal_shape", "")) == "lunate")
			assert(bool(applied.get("finlet_enabled", false)) == true)
			assert(fish.get_node_or_null("BodyPivot/FinletDorsal_0") != null)
			assert(fish.get_node_or_null("BodyPivot/FinletVentral_0") != null)
		"mackerel":
			assert(String(applied.get("caudal_shape", "")) == "lunate")
			assert(bool(applied.get("finlet_enabled", false)) == true)
			assert(fish.get_node_or_null("BodyPivot/FinletDorsal_0") != null)
			assert(fish.get_node_or_null("BodyPivot/FinletVentral_0") != null)
```

- [ ] **Step 2: Run archetype smoke to verify failure**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeVisualSmokeTest
```

Expected: FAIL because the required defaults and possibly archetype files are not present.

- [ ] **Step 3: Add betta and guppy ray defaults in `fin_profile`**

In `data/species_archetypes/betta.json`, update the existing `profile_overrides.fin_profile`
entries in place. Replace the current `fin_ray_count` and `fin_ray_strength`
values, and add the new ray keys in the same `fin_profile` dictionary:

```json
"fin_ray_style": "fan",
"fin_ray_count": 28,
"fin_ray_strength": 0.65,
"fin_ray_spread": 0.95,
"fin_ray_branching": 0.65,
"fin_ray_segmentation": 0.35,
"fin_ray_irregularity": 0.12
```

In `data/species_archetypes/guppy.json`, update the existing `profile_overrides.fin_profile`
entries in place. Replace the current `fin_ray_count` and `fin_ray_strength`
values, and add the new ray keys in the same `fin_profile` dictionary:

```json
"fin_ray_style": "threaded",
"fin_ray_count": 22,
"fin_ray_strength": 0.5,
"fin_ray_spread": 0.9,
"fin_ray_branching": 0.45,
"fin_ray_segmentation": 0.25,
"fin_ray_irregularity": 0.18
```

- [ ] **Step 4: Add complete salmonid and scombrid archetype files**

Create `data/species_archetypes/trout.json` with a complete archetype, including
non-empty `marking_layers`:

```json
{
	"id": "trout",
	"label": "Trout",
	"creature_type": "fish",
	"readability_priority": ["salmonid profile", "small adipose fin", "speckled body"],
	"profile_overrides": {
		"global": {
			"body_length": 1.48,
			"body_height": 0.42,
			"body_width": 0.26,
			"head_size": 0.38,
			"head_offset": -0.52,
			"eye_size": 0.045
		},
		"body_profile": {
			"shape": "slender_lateral"
		},
		"tail_profile": {
			"tail_length": 0.34,
			"tail_fin_size": 0.36,
			"caudal_shape": "forked_shallow",
			"caudal_height_scale": 0.72
		},
		"fin_profile": {
			"dorsal_1_shape": "single",
			"dorsal_1_length": 0.28,
			"dorsal_1_height": 0.16,
			"anal_shape": "single",
			"anal_length": 0.24,
			"anal_height": 0.12,
			"fin_ray_style": "soft",
			"fin_ray_count": 10,
			"fin_ray_strength": 0.22,
			"adipose_fin_enabled": true,
			"adipose_fin_size": 0.24,
			"adipose_fin_position": 0.82,
			"adipose_fin_height": 0.18,
			"adipose_fin_roundness": 0.8,
			"adipose_fin_opacity": 0.72,
			"adipose_fin_rayed": 0,
			"fin_softness": 0.35,
			"fin_rigidity": 0.25
		},
		"visual_profile": {
			"base_color": "#6b7f55",
			"belly_color": "#e7e0c4",
			"fin_color": "#c78f53",
			"outline_color": "#1f2933",
			"pattern_type": "spots",
			"pattern_color": "#2b1f18",
			"pattern_intensity": 0.55,
			"wetness": 0.24
		},
		"motion_profile": {
			"swim_mode": "general",
			"global_sway_amount": 8.0,
			"tail_sway_multiplier": 1.1
		}
	},
	"marking_layers": [
		{
			"type": "spots",
			"zone": "body",
			"color": "#2b1f18",
			"x_start": 0.12,
			"x_end": 0.88,
			"y": 0.12,
			"thickness": 0.06,
			"emissive": 0.0
		}
	],
	"variant_controls": {
		"color_jitter": 0.1,
		"spot_density_variation": 0.2
	}
}
```

Create `data/species_archetypes/tuna.json` with a complete archetype. `lunate` is
supported by `PrimitiveFactory.caudal_fin_points()`, so use it directly:

```json
{
	"id": "tuna",
	"label": "Tuna",
	"creature_type": "fish",
	"readability_priority": ["torpedo body", "lunate tail", "posterior finlets"],
	"profile_overrides": {
		"global": {
			"body_length": 1.78,
			"body_height": 0.38,
			"body_width": 0.3,
			"head_size": 0.36,
			"head_offset": -0.54,
			"eye_size": 0.038
		},
		"body_profile": {
			"shape": "slender_lateral"
		},
		"tail_profile": {
			"tail_length": 0.42,
			"tail_fin_size": 0.5,
			"caudal_shape": "lunate",
			"caudal_height_scale": 1.0
		},
		"fin_profile": {
			"dorsal_1_shape": "trigger",
			"dorsal_1_length": 0.22,
			"dorsal_1_height": 0.13,
			"dorsal_2_enabled": true,
			"dorsal_2_attach_t": 0.66,
			"dorsal_2_shape": "single",
			"dorsal_2_length": 0.18,
			"dorsal_2_height": 0.09,
			"anal_shape": "single",
			"anal_length": 0.2,
			"anal_height": 0.09,
			"fin_ray_style": "soft",
			"fin_ray_count": 8,
			"fin_ray_strength": 0.18,
			"finlet_enabled": true,
			"finlet_dorsal_count": 9,
			"finlet_ventral_count": 9,
			"finlet_size": 0.22,
			"finlet_taper": 0.35,
			"finlet_spacing": 0.72,
			"finlet_pitch": 0.25,
			"finlet_color_blend": 0.55,
			"fin_softness": 0.18,
			"fin_rigidity": 0.6
		},
		"visual_profile": {
			"base_color": "#1d4f73",
			"belly_color": "#d9e6ef",
			"fin_color": "#f0c453",
			"outline_color": "#101923",
			"metallic_scale_strength": 0.25,
			"wetness": 0.35
		},
		"motion_profile": {
			"swim_mode": "tuna",
			"global_sway_amount": 4.0,
			"tail_sway_multiplier": 1.55
		}
	},
	"marking_layers": [
		{
			"type": "countershade_band",
			"zone": "body",
			"color": "#0f2f47",
			"x_start": 0.0,
			"x_end": 1.0,
			"y": 0.24,
			"thickness": 0.16,
			"emissive": 0.0
		}
	],
	"variant_controls": {
		"body_length_variation": 0.08,
		"metallic_variation": 0.12
	}
}
```

Create `data/species_archetypes/mackerel.json` with a complete archetype:

```json
{
	"id": "mackerel",
	"label": "Mackerel",
	"creature_type": "fish",
	"readability_priority": ["striped fast swimmer", "forked/lunate tail", "posterior finlets"],
	"profile_overrides": {
		"global": {
			"body_length": 1.58,
			"body_height": 0.36,
			"body_width": 0.25,
			"head_size": 0.34,
			"head_offset": -0.52,
			"eye_size": 0.04
		},
		"body_profile": {
			"shape": "slender_lateral"
		},
		"tail_profile": {
			"tail_length": 0.36,
			"tail_fin_size": 0.42,
			"caudal_shape": "lunate",
			"caudal_height_scale": 0.88
		},
		"fin_profile": {
			"dorsal_1_shape": "single",
			"dorsal_1_length": 0.24,
			"dorsal_1_height": 0.13,
			"dorsal_2_enabled": true,
			"dorsal_2_attach_t": 0.64,
			"dorsal_2_shape": "single",
			"dorsal_2_length": 0.16,
			"dorsal_2_height": 0.08,
			"anal_shape": "single",
			"anal_length": 0.18,
			"anal_height": 0.08,
			"fin_ray_style": "soft",
			"fin_ray_count": 8,
			"fin_ray_strength": 0.16,
			"finlet_enabled": true,
			"finlet_dorsal_count": 7,
			"finlet_ventral_count": 7,
			"finlet_size": 0.18,
			"finlet_taper": 0.4,
			"finlet_spacing": 0.72,
			"finlet_pitch": 0.22,
			"finlet_color_blend": 0.6,
			"fin_softness": 0.2,
			"fin_rigidity": 0.55
		},
		"visual_profile": {
			"base_color": "#315f7d",
			"belly_color": "#e5edf2",
			"fin_color": "#b7c6c9",
			"outline_color": "#111827",
			"pattern_type": "horizontal_stripes",
			"pattern_color": "#102a3a",
			"pattern_intensity": 0.65,
			"wetness": 0.3
		},
		"motion_profile": {
			"swim_mode": "mackerel",
			"global_sway_amount": 5.5,
			"tail_sway_multiplier": 1.4
		}
	},
	"marking_layers": [
		{
			"type": "horizontal_stripes",
			"zone": "body",
			"color": "#102a3a",
			"x_start": 0.06,
			"x_end": 0.9,
			"y": 0.2,
			"thickness": 0.08,
			"emissive": 0.0
		}
	],
	"variant_controls": {
		"stripe_variation": 0.18,
		"color_jitter": 0.08
	}
}
```

- [ ] **Step 5: Run archetype smoke**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeVisualSmokeTest
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add data\species_archetypes scripts\tools\SpeciesArchetypeVisualSmokeTest.gd
git commit -m "Tune archetypes for fin structure"
```

---

### Task 7: Final Verification

**Files:**
- Verify all touched files.

- [ ] **Step 1: Run focused tests**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinMaterialTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelRangeTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinSpecialSlotTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeVisualSmokeTest
```

Expected: all PASS.

- [ ] **Step 2: Run full Godot CLI suite**

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

Expected: all test scenes pass. Treat `Failed to read the root certificate store` as non-fatal and use the runner exit code as the source of truth.

- [ ] **Step 3: Review git diff**

```powershell
git status --short
git diff --stat
```

Expected: clean working tree after all task commits.

- [ ] **Step 4: Push implementation branch**

```powershell
git push -u origin fin-ray-structure-implementation
```

Expected: branch is available on origin for review.

---

## Self-Review

- Spec coverage: the plan covers defaults, shader AA/legacy behavior, `adipose_fin_position` slider bounds, UI ranges/options/labels, dedicated materials, body/fin color blending for finlets, adipose placement, finlet animated anchors, complete archetype files, and focused/full tests.
- Scope: this is one feature branch with three connected surfaces: ordinary fin rays, adipose special slot, and finlet special slots. They share material/default/archetype plumbing, so one plan is acceptable.
- Ambiguity resolved: adipose and finlets use dedicated rayless materials by default; finlets use sampled animated shell anchors from v1; legacy `style == "none"` keeps parallel rays; new trout/tuna/mackerel archetypes must be complete JSON files with non-empty `marking_layers`.
