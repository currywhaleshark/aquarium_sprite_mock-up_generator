# Shark Head Morphology Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build head-only shark morphology controls and recipes for conical white-shark and blunt whale-shark head shapes without changing full creature presets.

**Architecture:** Keep the work inside the existing shark head pipeline: schema visibility owns save/load, `HeadEditorPanel` owns head-edit controls and recipe application, `ParameterPanel` mirrors numeric range metadata for the broad parameter view, and `SharkHeadProfile` owns mesh and analytic surface math. Recipes are editor actions with an explicit allowlist, separate from `PresetStore.gd`, so they can update common head keys while leaving body, fins, colors, motion, and gill settings intact.

**Tech Stack:** Godot 4.6 GDScript, existing `HeadEditorPanel`, `ParameterPanel`, `CreatureParameterSchema`, `SharkHeadProfile`, and `tools/run_godot_cli_tests.ps1`.

---

## File Map

- Modify: `scripts/creature/CreatureParameterSchema.gd`
  - Register new shark-only head keys and new shark mouth keys so save/load and mode filtering preserve them only for shark mode.
- Modify: `scripts/ui/HeadEditorPanel.gd`
  - Add shark head numeric slider metadata, section placement, no-op defaults, recipe button UI, and the recipe allowlist/application method.
- Modify: `scripts/ui/ParameterPanel.gd`
  - Add broad-panel ranges, steps, categories, and specialized-editor visibility for the new numeric keys.
- Modify: `scripts/ui/UiText.gd`
  - Add Korean labels for the new sliders and recipe buttons.
- Modify: `scripts/creature/SharkHeadProfile.gd`
  - Add rear-volume, snout-tip, mouth-angle, and mouth-arc geometry helpers.
  - Share the snout-tip shift across mesh points, surface depth, and mouth membership.
- Modify: `scripts/tools/HeadEditorPanelTest.gd`
  - Cover shark slider visibility, section placement, slider ranges, clamps, and recipe application allowlist.
- Modify: `scripts/tools/ParameterModeVisibilityTest.gd`
  - Cover broad-panel visibility for shark and hidden behavior for fish/ray.
- Modify: `scripts/tools/PresetNormalizationTest.gd`
  - Cover schema preservation for shark and stripping for ray.
- Modify: `scripts/tools/SharkHeadMeshTest.gd`
  - Cover new mesh controls, shared surface paths, neutral no-op behavior, and neck closure under rear volume.
- Modify: `scripts/tools/SharkMouthRenderingTest.gd`
  - Cover mouth attachments under strong mouth angle/arc plus snout-tip settings.

## Guardrails

- Do not edit `presets/basic_shark.json`.
- New parameter defaults are all `0.0`.
- `shark_mouth_curve` stays the existing wrap/half-angle control.
- `shark_mouth_arc` changes the side-view mouth seam line bow.
- Rear-volume weight must be zero at the neck rim.
- The Task 3 switch from `_shaped_point()` to `_base_point()` inside `_mouth_seam_point()` is intentional: the visible mesh uses `point_at()` to reach `_base_point()`, so the seam must also follow flatness to stay flush.
- `ParameterPanel` currently builds controls only for keys already present in `parameters`; do not add synthetic broad-panel defaults for the new keys. Neutral behavior is owned by `HeadEditorPanel._default_numeric()` and `SharkHeadProfile.parameters.get(key, 0.0)` fallbacks.
- Run Godot tests only through `tools/run_godot_cli_tests.ps1`.
- If Korean text appears garbled in terminal output, re-read the file with `Get-Content -Encoding UTF8` before editing.

### Task 1: Schema, Numeric Ranges, Labels, And UI Registration

**Files:**
- Modify: `scripts/creature/CreatureParameterSchema.gd`
- Modify: `scripts/ui/HeadEditorPanel.gd`
- Modify: `scripts/ui/ParameterPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Test: `scripts/tools/PresetNormalizationTest.gd`
- Test: `scripts/tools/ParameterModeVisibilityTest.gd`
- Test: `scripts/tools/HeadEditorPanelTest.gd`

- [ ] **Step 1: Add failing schema normalization assertions**

In `scripts/tools/PresetNormalizationTest.gd`, extend the `shark_sculpt` dictionary near the existing shark head-sculpt block:

```gdscript
	var shark_sculpt := BodyProfileScript.sanitize_parameters_for_mode({
		"creature_type": "shark",
		"head_top_curve": 0.8,
		"head_top_peak": 0.42,
		"head_belly_curve": 0.6,
		"head_bump_height": 0.35,
		"head_top_flatness": 0.5,
		"head_flattening": 0.2,
		"shark_head_rear_height": 0.55,
		"shark_head_rear_width": 0.75,
		"shark_snout_tip_y": -0.22,
		"shark_mouth_angle": 18.0,
		"shark_mouth_arc": 0.42
	}, "shark")
```

Add these assertions after the existing shark head-sculpt assertions:

```gdscript
	assert(abs(float(shark_sculpt.get("shark_head_rear_height", 0.0)) - 0.55) < 0.001)
	assert(abs(float(shark_sculpt.get("shark_head_rear_width", 0.0)) - 0.75) < 0.001)
	assert(abs(float(shark_sculpt.get("shark_snout_tip_y", 0.0)) + 0.22) < 0.001)
	assert(abs(float(shark_sculpt.get("shark_mouth_angle", 0.0)) - 18.0) < 0.001)
	assert(abs(float(shark_sculpt.get("shark_mouth_arc", 0.0)) - 0.42) < 0.001)
	var ray_sculpt := BodyProfileScript.sanitize_parameters_for_mode({
		"creature_type": "ray",
		"shark_head_rear_height": 0.55,
		"shark_head_rear_width": 0.75,
		"shark_snout_tip_y": -0.22,
		"shark_mouth_angle": 18.0,
		"shark_mouth_arc": 0.42
	}, "ray")
	assert(not ray_sculpt.has("shark_head_rear_height"))
	assert(not ray_sculpt.has("shark_head_rear_width"))
	assert(not ray_sculpt.has("shark_snout_tip_y"))
	assert(not ray_sculpt.has("shark_mouth_angle"))
	assert(not ray_sculpt.has("shark_mouth_arc"))
```

- [ ] **Step 2: Run normalization test and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalization
```

Expected: FAIL because at least one of `shark_head_rear_height`, `shark_head_rear_width`, `shark_snout_tip_y`, `shark_mouth_angle`, or `shark_mouth_arc` is stripped.

- [ ] **Step 3: Add failing broad-panel visibility assertions**

In `scripts/tools/ParameterModeVisibilityTest.gd`, add these keys to the fish parameters dictionary:

```gdscript
		"shark_head_rear_height": 0.4,
		"shark_snout_tip_y": -0.12,
		"shark_mouth_angle": 12.0,
		"shark_mouth_arc": 0.4,
```

Add these fish assertions after the existing shark mouth negative assertions:

```gdscript
	assert(_find_slider_for_key(fish_panel, "shark_head_rear_height") == null)
	assert(_find_slider_for_key(fish_panel, "shark_snout_tip_y") == null)
	assert(_find_slider_for_key(fish_panel, "shark_mouth_angle") == null)
	assert(_find_slider_for_key(fish_panel, "shark_mouth_arc") == null)
```

Add the same four keys to the ray parameters dictionary and add these ray assertions after the existing shark mouth negative assertions:

```gdscript
	assert(_find_slider_for_key(ray_panel, "shark_head_rear_height") == null)
	assert(_find_slider_for_key(ray_panel, "shark_snout_tip_y") == null)
	assert(_find_slider_for_key(ray_panel, "shark_mouth_angle") == null)
	assert(_find_slider_for_key(ray_panel, "shark_mouth_arc") == null)
```

Add these keys to the shark parameters dictionary:

```gdscript
		"shark_head_rear_height": 0.4,
		"shark_head_rear_width": 0.6,
		"shark_snout_tip_y": -0.12,
		"shark_mouth_angle": 12.0,
		"shark_mouth_arc": 0.4,
```

Add these shark assertions after the existing shark mouth assertions:

```gdscript
	assert(_find_slider_for_key(shark_panel, "shark_head_rear_height") != null)
	assert(_find_slider_for_key(shark_panel, "shark_head_rear_width") != null)
	assert(_find_slider_for_key(shark_panel, "shark_snout_tip_y") != null)
	assert(_find_slider_for_key(shark_panel, "shark_mouth_angle") != null)
	assert(_find_slider_for_key(shark_panel, "shark_mouth_arc") != null)
```

- [ ] **Step 4: Run visibility test and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibility
```

Expected: FAIL because broad-panel shark visibility and ranges are not registered.

- [ ] **Step 5: Add failing head-editor slider assertions**

In `scripts/tools/HeadEditorPanelTest.gd`, add these shark parameters to the shark panel setup:

```gdscript
		"shark_head_rear_height": 0.0,
		"shark_head_rear_width": 0.0,
		"shark_snout_tip_y": 0.0,
		"shark_mouth_angle": 0.0,
		"shark_mouth_arc": 0.0,
```

Add these assertions after the current shark mouth slider assertions:

```gdscript
	assert(_has_numeric_slider(shark_panel, "shark_head_rear_height"))
	assert(_has_numeric_slider(shark_panel, "shark_head_rear_width"))
	assert(_has_numeric_slider(shark_panel, "shark_snout_tip_y"))
	assert(_has_numeric_slider(shark_panel, "shark_mouth_angle"))
	assert(_has_numeric_slider(shark_panel, "shark_mouth_arc"))
	var rear_height_slider := _slider_for_key(shark_panel, "shark_head_rear_height")
	var rear_width_slider := _slider_for_key(shark_panel, "shark_head_rear_width")
	var snout_tip_slider := _slider_for_key(shark_panel, "shark_snout_tip_y")
	var mouth_angle_slider := _slider_for_key(shark_panel, "shark_mouth_angle")
	var mouth_arc_slider := _slider_for_key(shark_panel, "shark_mouth_arc")
	assert(absf(rear_height_slider.min_value + 0.4) < 0.001)
	assert(absf(rear_height_slider.max_value - 0.8) < 0.001)
	assert(absf(rear_width_slider.min_value + 0.4) < 0.001)
	assert(absf(rear_width_slider.max_value - 1.0) < 0.001)
	assert(absf(snout_tip_slider.min_value + 0.35) < 0.001)
	assert(absf(snout_tip_slider.max_value - 0.35) < 0.001)
	assert(absf(mouth_angle_slider.min_value + 45.0) < 0.001)
	assert(absf(mouth_angle_slider.max_value - 45.0) < 0.001)
	assert(absf(mouth_arc_slider.min_value + 1.0) < 0.001)
	assert(absf(mouth_arc_slider.max_value - 1.0) < 0.001)
	var shark_head_body := _section_body_for_title(shark_panel, "머리 본체")
	var shark_snout_body := _section_body_for_title(shark_panel, "주둥이")
	assert(_control_parent(shark_panel, "shark_head_rear_height") == shark_head_body)
	assert(_control_parent(shark_panel, "shark_head_rear_width") == shark_head_body)
	assert(_control_parent(shark_panel, "shark_snout_tip_y") == shark_snout_body)
	assert(_control_parent(shark_panel, "shark_mouth_angle") == shark_mouth_body)
	assert(_control_parent(shark_panel, "shark_mouth_arc") == shark_mouth_body)
	shark_panel.set_numeric_parameter("shark_mouth_angle", 90.0)
	assert(abs(float(shark_seen[0].get("shark_mouth_angle", 0.0)) - 45.0) < 0.001)
	shark_panel.set_numeric_parameter("shark_mouth_arc", -2.0)
	assert(abs(float(shark_seen[0].get("shark_mouth_arc", 0.0)) + 1.0) < 0.001)
```

- [ ] **Step 6: Run head-editor test and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
```

Expected: FAIL because the sliders, labels, and ranges are absent.

- [ ] **Step 7: Register schema keys**

In `scripts/creature/CreatureParameterSchema.gd`, add this constant after `SHARK_GILL_KEYS`:

```gdscript
const SHARK_HEAD_KEYS := {
	"shark_head_rear_height": true,
	"shark_head_rear_width": true,
	"shark_snout_tip_y": true
}
```

Add the mouth keys to `SHARK_MOUTH_KEYS`:

```gdscript
	"shark_mouth_angle": true,
	"shark_mouth_arc": true,
```

Add this branch in `is_parameter_visible()` before the shark gill branch:

```gdscript
	if SHARK_HEAD_KEYS.has(key):
		return normalized_mode == CreatureModeScript.SHARK
```

- [ ] **Step 8: Register head-editor numeric keys and sections**

In `scripts/ui/HeadEditorPanel.gd`, add this constant after `SHARK_GILL_NUMERIC_KEYS`:

```gdscript
const SHARK_HEAD_NUMERIC_KEYS := {
	"shark_head_rear_height": {"min": -0.4, "max": 0.8, "step": 0.005},
	"shark_head_rear_width": {"min": -0.4, "max": 1.0, "step": 0.005},
	"shark_snout_tip_y": {"min": -0.35, "max": 0.35, "step": 0.005}
}
```

Add these entries to `SHARK_MOUTH_NUMERIC_KEYS`:

```gdscript
	"shark_mouth_angle": {"min": -45.0, "max": 45.0, "step": 1.0},
	"shark_mouth_arc": {"min": -1.0, "max": 1.0, "step": 0.005},
```

Update the relevant `FISH_SECTIONS` key lists:

```gdscript
{"title": "머리 본체", "keys": ["head_size", "head_length", "head_offset", "head_flattening", "shark_head_rear_height", "shark_head_rear_width"]},
{"title": "주둥이", "keys": ["snout_length", "snout_base", "snout_thickness", "snout_taper", "snout_curve", "shark_snout_tip_y", "snout_appendage_length"]},
{"title": "입", "keys": ["jaw_offset", "mouth_size", "mouth_open", "lower_jaw_length", "lower_jaw_angle", "lower_jaw_thickness", "lower_jaw_tip", "jaw_hinge_x", "jaw_hinge_y", "jaw_protrusion", "lower_upper_ratio", "lip_darken", "shark_mouth_position_x", "shark_mouth_position_y", "shark_mouth_width", "shark_mouth_curve", "shark_mouth_angle", "shark_mouth_arc", "shark_mouth_gape", "shark_jaw_projection", "shark_lower_jaw_drop", "shark_tooth_visible_count", "shark_tooth_size", "shark_tooth_angle", "shark_labial_furrow_length"]},
```

In `_numeric_source_for_mode()`, add shark head keys before shark mouth keys:

```gdscript
		for key in SHARK_HEAD_NUMERIC_KEYS.keys():
			source[key] = SHARK_HEAD_NUMERIC_KEYS[key]
```

In `_should_show_fish_numeric_key()`, add this shark branch before the shark gill branch:

```gdscript
		if key.begins_with("shark_head_") or key == "shark_snout_tip_y":
			return true
```

In `_default_numeric()`, add these cases before the shark mouth defaults:

```gdscript
		"shark_head_rear_height":
			return 0.0
		"shark_head_rear_width":
			return 0.0
		"shark_snout_tip_y":
			return 0.0
		"shark_mouth_angle":
			return 0.0
		"shark_mouth_arc":
			return 0.0
```

- [ ] **Step 9: Register broad-panel ranges and categories**

In `scripts/ui/ParameterPanel.gd`, add new keys to `SPECIALIZED_EDITOR_KEYS` near the existing head keys:

```gdscript
	"shark_head_rear_height": true,
	"shark_head_rear_width": true,
	"shark_snout_tip_y": true,
	"shark_mouth_angle": true,
	"shark_mouth_arc": true,
```

In `_min_for_key()`, add these branches before the generic shark mouth branch:

```gdscript
	if key == "shark_head_rear_height" or key == "shark_head_rear_width":
		return -0.4
	if key == "shark_snout_tip_y":
		return -0.35
	if key == "shark_mouth_angle":
		return -45.0
	if key == "shark_mouth_arc":
		return -1.0
```

In `_max_for_key()`, add these branches before the generic shark mouth branch:

```gdscript
	if key == "shark_head_rear_height":
		return 0.8
	if key == "shark_head_rear_width":
		return 1.0
	if key == "shark_snout_tip_y":
		return 0.35
	if key == "shark_mouth_angle":
		return 45.0
	if key == "shark_mouth_arc":
		return 1.0
```

In `_step_for_key()`, add this branch before the generic shark mouth branch:

```gdscript
	if key == "shark_mouth_angle":
		return 1.0
	if key == "shark_head_rear_height" or key == "shark_head_rear_width" or key == "shark_snout_tip_y" or key == "shark_mouth_arc":
		return 0.005
```

In `_category_for_key()`, add this branch before the shark mouth branch:

```gdscript
	if key.begins_with("shark_head_") or key == "shark_snout_tip_y":
		return "Head"
```

In `_should_show_specialized_key()`, extend the shark key array:

```gdscript
	if creature_type == CreatureModeScript.SHARK and key in ["head_size", "head_length", "head_offset", "snout_length", "forehead_slope", "eye_size", "eye_position_x", "eye_position_y", "eye_bulge", "eye_pupil_scale", "shark_head_rear_height", "shark_head_rear_width", "shark_snout_tip_y", "shark_mouth_angle", "shark_mouth_arc"]:
		return true
```

Keep the separate `caudal_shape` branch immediately below this membership check:

```gdscript
	if creature_type == CreatureModeScript.SHARK and key == "caudal_shape":
		return true
```

- [ ] **Step 10: Add Korean labels**

In `scripts/ui/UiText.gd`, add these labels to `PARAMETER_LABELS` near the shark labels:

```gdscript
	"shark_head_rear_height": "상어 머리 뒤쪽 높이",
	"shark_head_rear_width": "상어 머리 뒤쪽 폭",
	"shark_snout_tip_y": "주둥이 끝 높이",
	"shark_mouth_angle": "상어 입선 각도",
	"shark_mouth_arc": "상어 입선 호",
```

- [ ] **Step 11: Run focused UI/schema tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalization
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibility
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
```

Expected: all three filters PASS and print `PRESET_NORMALIZATION_TEST_OK`, `PARAMETER_MODE_VISIBILITY_TEST_OK`, and `HEAD_EDITOR_PANEL_TEST_OK`.

- [ ] **Step 12: Commit Task 1**

Run:

```powershell
git add scripts/creature/CreatureParameterSchema.gd scripts/ui/HeadEditorPanel.gd scripts/ui/ParameterPanel.gd scripts/ui/UiText.gd scripts/tools/PresetNormalizationTest.gd scripts/tools/ParameterModeVisibilityTest.gd scripts/tools/HeadEditorPanelTest.gd
git commit -m "Add shark head morphology parameter registration"
```

Expected: commit succeeds with only the listed files staged.

### Task 2: Rear Volume And Shared Snout-Tip Geometry

**Files:**
- Modify: `scripts/creature/SharkHeadProfile.gd`
- Test: `scripts/tools/SharkHeadMeshTest.gd`

- [ ] **Step 1: Add failing mesh tests for rear volume and snout tip**

In `scripts/tools/SharkHeadMeshTest.gd`, add these calls in `_ready()` after `_test_snout_sculpt_controls_affect_shark_head_geometry(base)`:

```gdscript
	await _test_rear_volume_controls_affect_midrear_without_opening_neck(base)
	if _failed:
		return
	await _test_snout_tip_y_uses_shared_surface_paths(base)
	if _failed:
		return
```

Add these test methods before `_test_rostrum_and_neck_are_closed()`:

```gdscript
func _test_rear_volume_controls_affect_midrear_without_opening_neck(parameters: Dictionary) -> void:
	var neutral_params := parameters.duplicate(true)
	neutral_params["shark_head_rear_height"] = 0.0
	neutral_params["shark_head_rear_width"] = 0.0
	var full_params := neutral_params.duplicate(true)
	full_params["shark_head_rear_height"] = 0.8
	full_params["shark_head_rear_width"] = 1.0
	var neutral := await _build_shark(neutral_params)
	var full := await _build_shark(full_params)
	var neutral_head := _head(neutral)
	var full_head := _head(full)
	var neutral_vertices := _vertices(neutral_head)
	var full_vertices := _vertices(full_head)
	if not _require(neutral_vertices.size() == full_vertices.size(), "rear volume controls must keep stable vertex order"):
		return
	var rear_delta := _max_u_window_delta(neutral_vertices, full_vertices, neutral_params, 0.58, 0.88)
	var tip_delta := _max_u_window_delta(neutral_vertices, full_vertices, neutral_params, 0.02, 0.16)
	if not _require(rear_delta > 0.018, "rear height/width must visibly affect the rear head volume"):
		return
	if not _require(tip_delta < rear_delta * 0.45, "rear height/width must stay out of the rostrum tip"):
		return
	if not _require(_extreme_ring_radius(full_vertices, false) <= 0.006, "rear height/width must not open the neck cap"):
		return
	neutral.queue_free()
	full.queue_free()

func _test_snout_tip_y_uses_shared_surface_paths(parameters: Dictionary) -> void:
	var low_params := parameters.duplicate(true)
	low_params["snout_length"] = 0.42
	low_params["snout_base"] = 0.46
	low_params["shark_snout_tip_y"] = -0.35
	var high_params := low_params.duplicate(true)
	high_params["shark_snout_tip_y"] = 0.35
	var low_tip := SharkHeadProfile.point_at(low_params, 0.035, PI * 0.5, float(low_params.get("snout_length", 0.0)), float(low_params.get("forehead_slope", 0.35)), {})
	var high_tip := SharkHeadProfile.point_at(high_params, 0.035, PI * 0.5, float(high_params.get("snout_length", 0.0)), float(high_params.get("forehead_slope", 0.35)), {})
	if not _require(high_tip.y - low_tip.y > 0.09, "shark_snout_tip_y must raise and lower the rostrum tip"):
		return
	high_params["shark_mouth_position_x"] = -1.28
	high_params["shark_mouth_position_y"] = -0.10
	var frame := SharkHeadProfile.mouth_path_frame(high_params, 0.5)
	var pos: Vector3 = frame["pos"]
	var u := _u_for_x_with_snout(pos.x, high_params)
	var expected_z := SharkHeadProfile.surface_z_at(high_params, u, pos.y, signf(pos.z))
	if not _require(absf(absf(pos.z) - absf(expected_z)) <= 0.08, "mouth path and analytic surface must share snout tip height"):
		return
```

Add this helper near `_max_rostrum_window_delta()`:

```gdscript
func _max_u_window_delta(a_vertices: PackedVector3Array, b_vertices: PackedVector3Array, parameters: Dictionary, min_u: float, max_u: float) -> float:
	var max_delta := 0.0
	for i in range(mini(a_vertices.size(), b_vertices.size())):
		var vertex := a_vertices[i]
		var u := _u_for_x_with_snout(vertex.x, parameters)
		if u >= min_u and u <= max_u and Vector2(vertex.y, vertex.z).length() > 0.012:
			max_delta = maxf(max_delta, vertex.distance_to(b_vertices[i]))
	return max_delta
```

- [ ] **Step 2: Run shark mesh test and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
```

Expected: FAIL because `shark_head_rear_height`, `shark_head_rear_width`, and `shark_snout_tip_y` do not yet affect the mesh/surface paths.

- [ ] **Step 3: Implement shared geometry helpers**

In `scripts/creature/SharkHeadProfile.gd`, replace this line in `_shaped_point()`:

```gdscript
	y += _snout_curve_y_shift(parameters, u, snout_length, sculpt)
```

with:

```gdscript
	y += _snout_y_shift(parameters, u, snout_length, sculpt)
```

Replace this line in `surface_z_at()`:

```gdscript
	var center_y := _snout_curve_y_shift(parameters, u, snout_length, {})
```

with:

```gdscript
	var center_y := _snout_y_shift(parameters, u, snout_length, {})
```

Replace this line in `mouth_weight()`:

```gdscript
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y + _snout_curve_y_shift(parameters, u, float(parameters.get("snout_length", 0.0)), {})
```

with:

```gdscript
	var snout_length := float(parameters.get("snout_length", 0.0))
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y + _snout_y_shift(parameters, u, snout_length, {})
```

Add these helpers after `_snout_curve_y_shift()`:

```gdscript
static func _snout_y_shift(parameters: Dictionary, u: float, snout_length: float, sculpt: Dictionary) -> float:
	return _snout_curve_y_shift(parameters, u, snout_length, sculpt) + _snout_tip_y_shift(parameters, u, snout_length, sculpt)

static func _snout_tip_y_shift(parameters: Dictionary, u: float, snout_length: float, sculpt: Dictionary) -> float:
	var snout_base := _snout_base(parameters, sculpt)
	if snout_length <= 0.0 or u >= snout_base:
		return 0.0
	var tip_y := clampf(_snout_sculpt_value(parameters, sculpt, "shark_snout_tip_y", 0.0), -0.35, 0.35)
	if absf(tip_y) <= 0.0001:
		return 0.0
	var t := 1.0 - clampf(u / maxf(snout_base, 0.001), 0.0, 1.0)
	return tip_y * 0.30 * smoothstep(0.0, 1.0, t)

static func _rear_volume_weight(u: float) -> float:
	var enter := smoothstep(0.46, 0.66, clampf(u, 0.0, 1.0))
	var exit := 1.0 - smoothstep(0.86, 1.0, clampf(u, 0.0, 1.0))
	return clampf(enter * exit, 0.0, 1.0)
```

- [ ] **Step 4: Apply rear volume through radii**

In `_base_radii()`, insert this block after `var radius_z := base * lerpf(0.72, 0.98, smoothstep(0.12, 0.62, u))` and before the forehead slope line:

```gdscript
	var rear_w := _rear_volume_weight(u)
	if rear_w > 0.0:
		var rear_height := clampf(_snout_sculpt_value(parameters, sculpt, "shark_head_rear_height", 0.0), -0.4, 0.8)
		var rear_width := clampf(_snout_sculpt_value(parameters, sculpt, "shark_head_rear_width", 0.0), -0.4, 1.0)
		radius_y *= maxf(0.35, 1.0 + rear_height * 0.22 * rear_w)
		radius_z *= maxf(0.35, 1.0 + rear_width * 0.26 * rear_w)
```

- [ ] **Step 5: Run mesh and shell seam tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeam
```

Expected: both filters PASS. `SharkHeadMesh` confirms rear volume, snout tip, and stable caps; `HeadShellSeam` confirms the existing neck seam coverage still passes.

- [ ] **Step 6: Commit Task 2**

Run:

```powershell
git add scripts/creature/SharkHeadProfile.gd scripts/tools/SharkHeadMeshTest.gd
git commit -m "Add shark rear volume and snout tip geometry"
```

Expected: commit succeeds with only the listed files staged.

### Task 3: Mouth Angle And Mouth Arc Geometry

**Files:**
- Modify: `scripts/creature/SharkHeadProfile.gd`
- Test: `scripts/tools/SharkHeadMeshTest.gd`
- Test: `scripts/tools/SharkMouthRenderingTest.gd`

- [ ] **Step 1: Add failing mouth path shape assertions**

In `scripts/tools/SharkHeadMeshTest.gd`, add this call in `_ready()` after `_test_mouth_line_has_crease_rings(base)`:

```gdscript
	await _test_mouth_angle_and_arc_shape_the_path(base)
	if _failed:
		return
```

Add this test method before `_build_shark()`:

```gdscript
func _test_mouth_angle_and_arc_shape_the_path(parameters: Dictionary) -> void:
	var down_params := parameters.duplicate(true)
	down_params["shark_mouth_angle"] = -35.0
	down_params["shark_mouth_arc"] = 0.0
	var up_params := parameters.duplicate(true)
	up_params["shark_mouth_angle"] = 35.0
	up_params["shark_mouth_arc"] = 0.0
	var down_mid: Vector3 = SharkHeadProfile.mouth_path_frame(down_params, 0.5)["pos"]
	var up_mid: Vector3 = SharkHeadProfile.mouth_path_frame(up_params, 0.5)["pos"]
	if not _require(absf(up_mid.y - down_mid.y) > 0.015, "shark_mouth_angle must tilt the side-view mouth line"):
		return
	var flat_params := parameters.duplicate(true)
	flat_params["shark_mouth_arc"] = -1.0
	var bowed_params := parameters.duplicate(true)
	bowed_params["shark_mouth_arc"] = 1.0
	var flat_center: Vector3 = SharkHeadProfile.mouth_path_frame(flat_params, 0.5)["pos"]
	var flat_edge: Vector3 = SharkHeadProfile.mouth_path_frame(flat_params, 0.0)["pos"]
	var bowed_center: Vector3 = SharkHeadProfile.mouth_path_frame(bowed_params, 0.5)["pos"]
	var bowed_edge: Vector3 = SharkHeadProfile.mouth_path_frame(bowed_params, 0.0)["pos"]
	var flat_bow := flat_edge.y - flat_center.y
	var strong_bow := bowed_edge.y - bowed_center.y
	if not _require(strong_bow - flat_bow > 0.04, "shark_mouth_arc must increase the U-shaped bow independently of shark_mouth_curve"):
		return
```

- [ ] **Step 2: Add failing rendering attachment scenario**

In `scripts/tools/SharkMouthRenderingTest.gd`, after the second `_assert_attachments_near_head_mesh(shark)` block, add this strong-shape rebuild:

```gdscript
	parameters["snout_length"] = 0.42
	parameters["snout_base"] = 0.46
	parameters["shark_snout_tip_y"] = 0.35
	parameters["shark_mouth_angle"] = 32.0
	parameters["shark_mouth_arc"] = 1.0
	parameters["head_top_flatness"] = 0.55
	parameters["head_bottom_flatness"] = 0.45
	shark.set_parameters(parameters)
	await get_tree().process_frame
	_assert_shark_mouth_attachment_contract(shark)
	if _failed:
		return
	_assert_attachments_near_head_mesh(shark)
	if _failed:
		return
```

- [ ] **Step 3: Run mouth-related tests and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRendering
```

Expected: FAIL because `shark_mouth_angle` and `shark_mouth_arc` are not used by `SharkHeadProfile`.

- [ ] **Step 4: Implement mouth path helpers**

In `scripts/creature/SharkHeadProfile.gd`, replace `_mouth_seam_point()` with:

```gdscript
static func _mouth_seam_point(parameters: Dictionary, s: float) -> Vector3:
	var snout := float(parameters.get("snout_length", 0.0))
	var u := _mouth_seam_u(parameters, s)
	var theta := _mouth_seam_theta(parameters, s)
	var forehead_slope := float(parameters.get("forehead_slope", 0.35))
	var surface := _base_point(parameters, u, theta, snout, forehead_slope, {})
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y + _mouth_path_y_shift(parameters, u, s)
	var y := surface.y + y_shift
	var ang_w := 1.0 - clampf(absf(theta + PI * 0.5) / _mouth_half_ang(parameters), 0.0, 1.0)
	var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
	var groove := ang_w * (0.07 + 0.10 * gape)
	var z := surface.z * (1.0 - groove)
	y *= 1.0 - groove * 0.30
	return Vector3(surface.x, y, z)
```

Add these helpers after `_mouth_seam_u()`:

```gdscript
static func _mouth_path_y_shift(parameters: Dictionary, u: float, s: float) -> float:
	return _mouth_angle_y_shift(parameters, u) + _mouth_arc_y_shift(parameters, s)

static func _mouth_angle_y_shift(parameters: Dictionary, u: float) -> float:
	var angle := deg_to_rad(clampf(float(parameters.get("shark_mouth_angle", 0.0)), -45.0, 45.0))
	if absf(angle) <= 0.0001:
		return 0.0
	var span := maxf(_mouth_half_u(parameters), 0.001)
	var signed_u := clampf((u - _mouth_u(parameters)) / span, -1.0, 1.0)
	return -signed_u * tan(angle) * 0.045

static func _mouth_arc_y_shift(parameters: Dictionary, s: float) -> float:
	var arc := clampf(float(parameters.get("shark_mouth_arc", 0.0)), -1.0, 1.0)
	if absf(arc) <= 0.0001:
		return 0.0
	return -arc * sin(clampf(s, 0.0, 1.0) * PI) * 0.040
```

- [ ] **Step 5: Include mouth angle in mouth membership**

In `mouth_weight()`, update the `y_shift` assignment from Task 2:

```gdscript
	var y_shift := _mouth_center_y(parameters) - MOUTH_DEFAULT_Y + _snout_y_shift(parameters, u, snout_length, {}) + _mouth_angle_y_shift(parameters, u)
```

This keeps the mesh groove and mouth shadow aligned when the line is tilted. Keep `shark_mouth_arc` out of `mouth_weight()` because arc is a seam-path bow across the visible wrapped line, while `shark_mouth_curve` remains the cross-section wrap control.

- [ ] **Step 6: Run mouth tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRendering
```

Expected: both filters PASS and the `shark_mouth_curve` tests still pass through existing crease-ring and mouth-local deformation checks.

- [ ] **Step 7: Commit Task 3**

Run:

```powershell
git add scripts/creature/SharkHeadProfile.gd scripts/tools/SharkHeadMeshTest.gd scripts/tools/SharkMouthRenderingTest.gd
git commit -m "Add shark mouth angle and arc controls"
```

Expected: commit succeeds with only the listed files staged.

### Task 4: Shark Head Recipe UI And Allowlist

**Files:**
- Modify: `scripts/ui/HeadEditorPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Modify: `scripts/tools/SharkMouthShot.gd`
- Test: `scripts/tools/HeadEditorPanelTest.gd`

- [ ] **Step 1: Add failing recipe UI and allowlist assertions**

In `scripts/tools/HeadEditorPanelTest.gd`, add these assertions after the shark panel basic slider assertions and before shark numeric parameter mutations:

```gdscript
	var recipe_buttons: Dictionary = shark_panel.get("shark_head_recipe_buttons")
	assert(recipe_buttons.has("white_shark_conical"))
	assert(recipe_buttons.has("whale_shark_blunt"))
	var before_recipe_body_length := 5.8
	var before_recipe_gill_count := 5.0
	var before_recipe_color := "#101820"
	shark_panel.set_parameters(shark_panel.get("parameters").merged({
		"body_length": before_recipe_body_length,
		"base_color": before_recipe_color,
		"fin_color": "#334455",
		"swim_speed": 1.7,
		"caudal_shape": "shark_heterocercal",
		"shark_gill_slit_count": before_recipe_gill_count
	}, true))
	shark_panel.apply_shark_head_recipe("white_shark_conical")
	assert(abs(float(shark_seen[0].get("snout_taper", 0.0)) - 0.18) < 0.001)
	assert(abs(float(shark_seen[0].get("shark_head_rear_height", 0.0)) - 0.62) < 0.001)
	assert(abs(float(shark_seen[0].get("body_length", 0.0)) - before_recipe_body_length) < 0.001)
	assert(String(shark_seen[0].get("base_color", "")) == before_recipe_color)
	assert(String(shark_seen[0].get("fin_color", "")) == "#334455")
	assert(abs(float(shark_seen[0].get("swim_speed", 0.0)) - 1.7) < 0.001)
	assert(String(shark_seen[0].get("caudal_shape", "")) == "shark_heterocercal")
	assert(abs(float(shark_seen[0].get("shark_gill_slit_count", 0.0)) - before_recipe_gill_count) < 0.001)
	shark_panel.apply_shark_head_recipe("whale_shark_blunt")
	assert(abs(float(shark_seen[0].get("snout_taper", 0.0)) - 0.0) < 0.001)
	assert(abs(float(shark_seen[0].get("shark_mouth_arc", 0.0)) - 0.35) < 0.001)
	var fish_recipe_buttons: Dictionary = panel.get("shark_head_recipe_buttons")
	assert(fish_recipe_buttons.is_empty())
```

- [ ] **Step 2: Run head-editor test and confirm failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
```

Expected: FAIL because recipe state and `apply_shark_head_recipe()` do not exist.

- [ ] **Step 3: Add recipe data and state**

In `scripts/ui/HeadEditorPanel.gd`, add these constants after `MOUTH_DETAILS`:

```gdscript
const SHARK_HEAD_RECIPE_KEYS := {
	"head_size": true,
	"head_length": true,
	"head_offset": true,
	"head_flattening": true,
	"shark_head_rear_height": true,
	"shark_head_rear_width": true,
	"snout_length": true,
	"snout_base": true,
	"snout_thickness": true,
	"snout_taper": true,
	"snout_curve": true,
	"shark_snout_tip_y": true,
	"forehead_slope": true,
	"head_top_curve": true,
	"head_top_peak": true,
	"head_belly_curve": true,
	"head_bump_height": true,
	"head_bump_pos": true,
	"head_bump_width": true,
	"head_bump_angle": true,
	"head_bump_round": true,
	"head_top_flatness": true,
	"head_bottom_flatness": true,
	"head_left_flatness": true,
	"head_right_flatness": true,
	"eye_size": true,
	"eye_position_x": true,
	"eye_position_y": true,
	"eye_bulge": true,
	"eye_pupil_scale": true,
	"shark_mouth_profile": true,
	"shark_mouth_position_x": true,
	"shark_mouth_position_y": true,
	"shark_mouth_width": true,
	"shark_mouth_curve": true,
	"shark_mouth_angle": true,
	"shark_mouth_arc": true,
	"shark_mouth_gape": true,
	"shark_jaw_projection": true,
	"shark_lower_jaw_drop": true,
	"shark_tooth_visible_count": true,
	"shark_tooth_size": true,
	"shark_tooth_angle": true,
	"shark_labial_furrow_length": true
}

const SHARK_HEAD_RECIPES := {
	"white_shark_conical": {
		"head_size": 0.46,
		"head_length": 0.50,
		"head_offset": -0.78,
		"head_flattening": 0.08,
		"shark_head_rear_height": 0.62,
		"shark_head_rear_width": 0.48,
		"snout_length": 0.20,
		"snout_base": 0.40,
		"snout_thickness": 0.82,
		"snout_taper": 0.18,
		"snout_curve": -0.18,
		"shark_snout_tip_y": 0.02,
		"forehead_slope": 0.18,
		"head_top_curve": 0.24,
		"head_top_peak": 0.58,
		"head_belly_curve": 0.18,
		"eye_size": 0.052,
		"eye_position_x": -0.86,
		"eye_position_y": 0.10,
		"eye_bulge": 0.25,
		"eye_pupil_scale": 0.60,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_position_x": -1.06,
		"shark_mouth_position_y": -0.16,
		"shark_mouth_width": 0.20,
		"shark_mouth_curve": 0.62,
		"shark_mouth_angle": -8.0,
		"shark_mouth_arc": 0.25,
		"shark_mouth_gape": 0.18,
		"shark_jaw_projection": 0.10,
		"shark_lower_jaw_drop": 0.12,
		"shark_tooth_visible_count": 13.0,
		"shark_tooth_size": 0.020,
		"shark_tooth_angle": -8.0,
		"shark_labial_furrow_length": 0.05
	},
	"whale_shark_blunt": {
		"head_size": 0.56,
		"head_length": 0.52,
		"head_offset": -0.74,
		"head_flattening": 0.22,
		"shark_head_rear_height": 0.38,
		"shark_head_rear_width": 0.95,
		"snout_length": 0.10,
		"snout_base": 0.50,
		"snout_thickness": 1.00,
		"snout_taper": 0.0,
		"snout_curve": -0.06,
		"shark_snout_tip_y": -0.03,
		"forehead_slope": 0.08,
		"head_top_curve": 0.08,
		"head_top_peak": 0.62,
		"head_belly_curve": 0.10,
		"head_top_flatness": 0.18,
		"head_bottom_flatness": 0.08,
		"head_left_flatness": 0.28,
		"head_right_flatness": 0.28,
		"eye_size": 0.040,
		"eye_position_x": -0.72,
		"eye_position_y": 0.06,
		"eye_bulge": 0.16,
		"eye_pupil_scale": 0.55,
		"shark_mouth_profile": "predatory_u",
		"shark_mouth_position_x": -1.16,
		"shark_mouth_position_y": -0.10,
		"shark_mouth_width": 0.42,
		"shark_mouth_curve": 0.72,
		"shark_mouth_angle": 0.0,
		"shark_mouth_arc": 0.35,
		"shark_mouth_gape": 0.08,
		"shark_jaw_projection": 0.04,
		"shark_lower_jaw_drop": 0.06,
		"shark_tooth_visible_count": 0.0,
		"shark_tooth_size": 0.010,
		"shark_tooth_angle": 0.0,
		"shark_labial_furrow_length": 0.10
	}
}
```

Add this variable near the option-grid variables:

```gdscript
var shark_head_recipe_buttons := {}
```

- [ ] **Step 4: Add recipe UI row**

In `_rebuild_controls_for_mode()`, clear recipe state with the other state:

```gdscript
	shark_head_recipe_buttons.clear()
```

In the non-ray branch, before the eye-style grid, add:

```gdscript
		if creature_type == CreatureModeScript.SHARK:
			_add_shark_head_recipe_row(options_container)
```

Add this helper after `_add_option_row()`:

```gdscript
func _add_shark_head_recipe_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = UiText.parameter("shark_head_recipe")
	label.custom_minimum_size = Vector2(96, 0)
	row.add_child(label)
	for recipe_id in ["white_shark_conical", "whale_shark_blunt"]:
		var button := Button.new()
		button.text = UiText.option(recipe_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if not _updating:
				apply_shark_head_recipe(recipe_id)
		)
		row.add_child(button)
		shark_head_recipe_buttons[recipe_id] = button
	parent.add_child(row)
```

- [ ] **Step 5: Add allowlisted recipe application method**

In `scripts/ui/HeadEditorPanel.gd`, add this public method after `set_boolean_parameter()`:

```gdscript
func apply_shark_head_recipe(recipe_id: String) -> void:
	if creature_type != CreatureModeScript.SHARK:
		return
	if not SHARK_HEAD_RECIPES.has(recipe_id):
		return
	var recipe: Dictionary = SHARK_HEAD_RECIPES[recipe_id]
	for key in recipe.keys():
		var text_key := String(key)
		if not SHARK_HEAD_RECIPE_KEYS.has(text_key):
			continue
		parameters[text_key] = recipe[key]
	_emit_and_refresh()
```

- [ ] **Step 6: Add recipe labels**

In `scripts/ui/UiText.gd`, add this entry to `PARAMETER_LABELS`:

```gdscript
	"shark_head_recipe": "상어 머리 레시피",
```

Add these entries to `OPTION_LABELS`:

```gdscript
	"white_shark_conical": "백상아리형",
	"whale_shark_blunt": "고래상어형",
```

- [ ] **Step 7: Run recipe test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
```

Expected: PASS and print `HEAD_EDITOR_PANEL_TEST_OK`.

- [ ] **Step 8: Extend shark mouth shot variants for recipe visual QA**

In `scripts/tools/SharkMouthShot.gd`, add this preload near the existing shark rig preload:

```gdscript
const HeadEditorPanelScript := preload("res://scripts/ui/HeadEditorPanel.gd")
```

Replace the `sets` block with:

```gdscript
	var sets := [
		{"tag": "default", "params": default_params},
		{"tag": "open", "params": wide_open},
		{"tag": "white_shark_conical", "params": _merged(default_params, HeadEditorPanelScript.SHARK_HEAD_RECIPES["white_shark_conical"])},
		{"tag": "whale_shark_blunt", "params": _merged(default_params, HeadEditorPanelScript.SHARK_HEAD_RECIPES["whale_shark_blunt"])},
	]
```

- [ ] **Step 9: Run recipe visual capture**

Run:

```powershell
& "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --disable-crash-handler --path . --log-file tmp\godot-logs\SharkMouthShot-visual.log scenes/SharkMouthShot.tscn
```

Expected: `exports/_shots/shark/white_shark_conical_side.png`, `exports/_shots/shark/white_shark_conical_front.png`, `exports/_shots/shark/whale_shark_blunt_side.png`, and `exports/_shots/shark/whale_shark_blunt_front.png` are saved. Inspect the side and front images: white-shark recipe should read as a short blunt cone with rear head mass, and whale-shark recipe should read as broader, flatter, and blunter at the front.

- [ ] **Step 10: Commit Task 4**

Run:

```powershell
git add scripts/ui/HeadEditorPanel.gd scripts/ui/UiText.gd scripts/tools/HeadEditorPanelTest.gd scripts/tools/SharkMouthShot.gd
git commit -m "Add shark head recipe controls"
```

Expected: commit succeeds with only the listed files staged.

### Task 5: Neutral No-Op And Focused Regression Suite

**Files:**
- Modify: `scripts/tools/SharkHeadMeshTest.gd`

- [ ] **Step 1: Add failing neutral no-op geometry test**

In `scripts/tools/SharkHeadMeshTest.gd`, add this call in `_ready()` after `_test_rostrum_and_neck_are_closed(base)`:

```gdscript
	await _test_new_controls_default_to_neutral_noop(base)
	if _failed:
		return
```

Add this method before `_test_mouth_line_has_crease_rings()`:

```gdscript
func _test_new_controls_default_to_neutral_noop(parameters: Dictionary) -> void:
	var absent_params := parameters.duplicate(true)
	for key in ["shark_head_rear_height", "shark_head_rear_width", "shark_snout_tip_y", "shark_mouth_angle", "shark_mouth_arc"]:
		absent_params.erase(key)
	var neutral_params := absent_params.duplicate(true)
	neutral_params["shark_head_rear_height"] = 0.0
	neutral_params["shark_head_rear_width"] = 0.0
	neutral_params["shark_snout_tip_y"] = 0.0
	neutral_params["shark_mouth_angle"] = 0.0
	neutral_params["shark_mouth_arc"] = 0.0
	var absent := await _build_shark(absent_params)
	var neutral := await _build_shark(neutral_params)
	var absent_vertices := _vertices(_head(absent))
	var neutral_vertices := _vertices(_head(neutral))
	if not _require(absent_vertices.size() == neutral_vertices.size(), "neutral new controls must keep stable vertex order"):
		return
	if not _require(_max_all_vertex_delta(absent_vertices, neutral_vertices) <= 0.0005, "explicit neutral new controls must match absent-key geometry"):
		return
	absent.queue_free()
	neutral.queue_free()
```

Add this helper near `_max_u_window_delta()`:

```gdscript
func _max_all_vertex_delta(a_vertices: PackedVector3Array, b_vertices: PackedVector3Array) -> float:
	var max_delta := 0.0
	for i in range(mini(a_vertices.size(), b_vertices.size())):
		max_delta = maxf(max_delta, a_vertices[i].distance_to(b_vertices[i]))
	return max_delta
```

- [ ] **Step 2: Run neutral test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
```

Expected: PASS. If it fails, inspect each new `parameters.get(key, default)` and UI default in `HeadEditorPanel._default_numeric()` until absent keys and explicit zero keys match.

- [ ] **Step 3: Run focused suite**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalization
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibility
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRendering
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeam
```

Expected: every filter PASS. Treat `Failed to read the root certificate store` as non-fatal and use the runner exit code plus test marker lines as the source of truth.

- [ ] **Step 4: Check working tree**

Run:

```powershell
git status --short --branch
```

Expected: only intended files are modified before the final commit.

- [ ] **Step 5: Commit Task 5**

Run:

```powershell
git add scripts/tools/SharkHeadMeshTest.gd
git commit -m "Test neutral shark head morphology defaults"
```

Expected: commit succeeds with only the neutral no-op test staged.

## Final Verification

- [ ] **Step 1: Run the same focused suite once more after all commits**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalization
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibility
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRendering
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeam
```

Expected: all filters PASS.

- [ ] **Step 2: Confirm no preset mutation**

Run:

```powershell
git diff -- presets/basic_shark.json
```

Expected: no output.

- [ ] **Step 3: Summarize commits and tests**

Run:

```powershell
git log --oneline -5
git status --short --branch
```

Expected: recent commits include the task commits, and working tree is clean except for user-owned unrelated changes.
