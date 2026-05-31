# Realistic Fish Swim Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add biologically inspired swim-mode presets and fin/body motion controls so FishRig can produce more believable fish swimming loops.

**Architecture:** `BodyProfile.gd` owns swim-mode defaults and normalization. `FishRig.gd` consumes normalized motion parameters only, with no hardcoded per-mode constants. `ParameterPanel.gd` renders `swim_mode` as a dropdown that applies grouped motion values while leaving numeric sliders editable afterward.

**Tech Stack:** Godot 4.6, GDScript, JSON presets, existing headless scene tests.

---

## File Structure

- Modify: `scripts/creature/BodyProfile.gd`
  - Add `SWIM_MODE_PRESETS`.
  - Add helper methods for mode validation and applying grouped mode values.
  - Normalize new motion keys without overwriting explicit existing numeric values.
  - Persist new keys through `split_parameters_into_profiles()`.

- Modify: `scripts/creature/FishRig.gd`
  - Remove hardcoded `FIN_YAW_FOLLOW_STRENGTH` and `TAIL_FIN_EXTRA_SWING_STRENGTH` usage.
  - Read `fin_yaw_follow_strength`, `tail_fin_extra_swing`, `median_fin_flap_amount`, and `median_fin_flap_phase` from parameters.
  - Add conservative dorsal/anal fin flap on animated shell attachments.

- Modify: `scripts/ui/ParameterPanel.gd`
  - Render known option strings such as `swim_mode` with `OptionButton`.
  - Apply grouped swim-mode values when dropdown changes.
  - Keep existing numeric slider behavior.

- Modify: `scripts/ui/UiText.gd`
  - Add labels for new motion parameters and swim-mode option names.

- Modify: `scripts/tools/PresetNormalizationTest.gd`
  - Assert new normalized keys and mode helper behavior.

- Modify: `scripts/tools/ParameterPanelCategoryTest.gd`
  - Assert `swim_mode` is in Motion Settings and rendered as an option control.

- Modify: `scripts/tools/EditorParameterSyncTest.gd`
  - Assert changing `swim_mode` through the panel updates `current_preset` grouped values.

- Modify: `scripts/tools/ShellRigTest.gd`
  - Assert FishRig can rebuild and apply poses for all modes without tail/fin detachment.

---

### Task 1: Add Swim-Mode Data Model

**Files:**
- Modify: `scripts/tools/PresetNormalizationTest.gd`
- Modify: `scripts/creature/BodyProfile.gd`

- [ ] **Step 1: Write failing normalization tests**

Update `scripts/tools/PresetNormalizationTest.gd` so it preloads `BodyProfile.gd` and checks all new motion keys.

Add the preload near the top:

```gdscript
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
```

Add these assertions after `assert(parameters.has("body_wave_amount"))`:

```gdscript
	assert(String(parameters.get("swim_mode", "")) == "general")
	assert(parameters.has("tail_fin_extra_swing"))
	assert(parameters.has("fin_yaw_follow_strength"))
	assert(parameters.has("median_fin_flap_amount"))
	assert(parameters.has("median_fin_flap_phase"))

	var general_mode := BodyProfileScript.swim_mode_values("general")
	assert(abs(float(general_mode.get("body_wave_amount", 0.0)) - 0.35) < 0.001)
	assert(abs(float(general_mode.get("tail_fin_extra_swing", 0.0)) - 0.45) < 0.001)
	assert(abs(float(general_mode.get("fin_yaw_follow_strength", 0.0)) - 0.25) < 0.001)

	var fallback_mode := BodyProfileScript.swim_mode_values("not_a_mode")
	assert(abs(float(fallback_mode.get("body_wave_start", 0.0)) - 0.16) < 0.001)

	var applied := {"swim_speed": 1.0, "body_wave_amount": 0.77}
	BodyProfileScript.apply_swim_mode(applied, "tuna")
	assert(String(applied.get("swim_mode", "")) == "tuna")
	assert(abs(float(applied.get("body_wave_amount", 0.0)) - 0.12) < 0.001)
	assert(abs(float(applied.get("tail_sway_multiplier", 0.0)) - 1.55) < 0.001)

	var explicit := {"body_profile_shape": "elongated", "body_wave_amount": 0.66}
	BodyProfileScript.normalize_motion_parameters(explicit)
	assert(String(explicit.get("swim_mode", "")) == "eel")
	assert(abs(float(explicit.get("body_wave_amount", 0.0)) - 0.66) < 0.001)
	assert(explicit.has("tail_fin_extra_swing"))
	assert(explicit.has("fin_yaw_follow_strength"))
```

Extend the existing `long_fish` and `goldfish` assertions:

```gdscript
	assert(String(long_parameters.get("swim_mode", "")) == "eel")
	assert(long_parameters.has("tail_fin_extra_swing"))
	assert(long_parameters.has("fin_yaw_follow_strength"))

	assert(String(goldfish_parameters.get("swim_mode", "")) == "puffer")
	assert(goldfish_parameters.has("median_fin_flap_amount"))
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest.tscn
```

Expected: FAIL because `swim_mode_values()` and `apply_swim_mode()` do not exist yet.

- [ ] **Step 3: Add swim-mode helpers**

In `scripts/creature/BodyProfile.gd`, add this constant below `RING_KEYS`:

```gdscript
const SWIM_MODE_PRESETS := {
	"eel": {
		"body_wave_amount": 0.90,
		"body_wave_start": 0.02,
		"body_wave_falloff": 0.35,
		"tail_sway_multiplier": 1.05,
		"tail_fin_extra_swing": 0.35,
		"fin_flap_amount": 3.0,
		"fin_yaw_follow_strength": 0.15,
		"median_fin_flap_amount": 1.0,
		"median_fin_flap_phase": 0.50
	},
	"general": {
		"body_wave_amount": 0.35,
		"body_wave_start": 0.16,
		"body_wave_falloff": 0.75,
		"tail_sway_multiplier": 1.20,
		"tail_fin_extra_swing": 0.45,
		"fin_flap_amount": 6.0,
		"fin_yaw_follow_strength": 0.25,
		"median_fin_flap_amount": 1.5,
		"median_fin_flap_phase": 0.50
	},
	"mackerel": {
		"body_wave_amount": 0.26,
		"body_wave_start": 0.36,
		"body_wave_falloff": 1.05,
		"tail_sway_multiplier": 1.35,
		"tail_fin_extra_swing": 0.50,
		"fin_flap_amount": 4.5,
		"fin_yaw_follow_strength": 0.20,
		"median_fin_flap_amount": 1.0,
		"median_fin_flap_phase": 0.50
	},
	"tuna": {
		"body_wave_amount": 0.12,
		"body_wave_start": 0.56,
		"body_wave_falloff": 1.45,
		"tail_sway_multiplier": 1.55,
		"tail_fin_extra_swing": 0.42,
		"fin_flap_amount": 2.5,
		"fin_yaw_follow_strength": 0.12,
		"median_fin_flap_amount": 0.6,
		"median_fin_flap_phase": 0.50
	},
	"puffer": {
		"body_wave_amount": 0.08,
		"body_wave_start": 0.68,
		"body_wave_falloff": 1.60,
		"tail_sway_multiplier": 0.85,
		"tail_fin_extra_swing": 0.20,
		"fin_flap_amount": 12.0,
		"fin_yaw_follow_strength": 0.10,
		"median_fin_flap_amount": 8.0,
		"median_fin_flap_phase": 0.25
	},
	"boxfish": {
		"body_wave_amount": 0.03,
		"body_wave_start": 0.82,
		"body_wave_falloff": 1.80,
		"tail_sway_multiplier": 0.75,
		"tail_fin_extra_swing": 0.32,
		"fin_flap_amount": 8.0,
		"fin_yaw_follow_strength": 0.08,
		"median_fin_flap_amount": 5.0,
		"median_fin_flap_phase": 0.25
	}
}

const MOTION_MODE_KEYS := [
	"body_wave_amount",
	"body_wave_start",
	"body_wave_falloff",
	"tail_sway_multiplier",
	"tail_fin_extra_swing",
	"fin_flap_amount",
	"fin_yaw_follow_strength",
	"median_fin_flap_amount",
	"median_fin_flap_phase"
]
```

Add these methods before `default_fish_rings()`:

```gdscript
static func swim_mode_names() -> Array[String]:
	return ["eel", "general", "mackerel", "tuna", "puffer", "boxfish"]

static func valid_swim_mode(swim_mode: String) -> String:
	if SWIM_MODE_PRESETS.has(swim_mode):
		return swim_mode
	return "general"

static func swim_mode_values(swim_mode: String) -> Dictionary:
	return SWIM_MODE_PRESETS[valid_swim_mode(swim_mode)].duplicate(true)

static func apply_swim_mode(parameters: Dictionary, swim_mode: String) -> void:
	var valid_mode := valid_swim_mode(swim_mode)
	parameters["swim_mode"] = valid_mode
	var values := swim_mode_values(valid_mode)
	for key in values.keys():
		parameters[key] = values[key]
```

- [ ] **Step 4: Update normalization and persistence**

In `split_parameters_into_profiles()`, extend the `motion_profile` `_pick()` list:

```gdscript
	updated["motion_profile"] = _pick(normalized_parameters, [
		"swim_mode", "swim_speed", "global_sway_amount", "phase_delay", "tail_sway_multiplier",
		"body_wave_amount", "body_wave_start", "body_wave_falloff",
		"tail_fin_extra_swing", "fin_flap_amount", "pectoral_flap_amount",
		"fin_yaw_follow_strength", "median_fin_flap_amount", "median_fin_flap_phase",
		"idle_bob_amount"
	])
```

Replace the middle of `normalize_motion_parameters()` after legacy sway normalization with:

```gdscript
	var default_mode := _default_swim_mode(parameters)
	parameters["swim_mode"] = valid_swim_mode(String(parameters.get("swim_mode", default_mode)))
	var mode_values := swim_mode_values(String(parameters["swim_mode"]))
	for key in MOTION_MODE_KEYS:
		if not parameters.has(key):
			parameters[key] = mode_values[key]
```

Keep the existing legacy erases at the end of the method.

Add this helper below `_default_motion_distribution()`:

```gdscript
static func _default_swim_mode(parameters: Dictionary) -> String:
	var shape := String(parameters.get("body_profile_shape", ""))
	var body_length := float(parameters.get("body_length", 1.28))
	var body_height := maxf(float(parameters.get("body_height", 0.5)), 0.001)
	var slenderness := body_length / body_height
	if shape == "elongated" or shape == "eel_like" or shape == "narrow_peduncle" or slenderness > 3.2:
		return "eel"
	if shape == "deep_compressed" or slenderness < 1.6:
		return "puffer"
	return "general"
```

Leave `_default_motion_distribution()` in place for compatibility if other code still calls it during this task.

- [ ] **Step 5: Run test to verify it passes**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest.tscn
```

Expected: PASS and output includes `PRESET_NORMALIZATION_TEST_OK`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/creature/BodyProfile.gd scripts/tools/PresetNormalizationTest.gd
git commit -m "Add swim mode motion profiles"
```

---

### Task 2: Consume Motion Parameters in FishRig

**Files:**
- Modify: `scripts/tools/ShellRigTest.gd`
- Modify: `scripts/creature/FishRig.gd`

- [ ] **Step 1: Write failing rig coverage**

In `scripts/tools/ShellRigTest.gd`, add the preload near the top:

```gdscript
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
```

Add this block after the existing first fish attachment assertions and before the ray test:

```gdscript
	for mode in BodyProfileScript.swim_mode_names():
		var mode_fish: FishRig = FishRigScript.new()
		add_child(mode_fish)
		var mode_parameters := {
			"shell_enabled": 1.0,
			"shell_expand": 0.12,
			"base_color": "#46c6cf",
			"secondary_color": "#d6fbff"
		}
		BodyProfileScript.apply_swim_mode(mode_parameters, mode)
		mode_fish.set_parameters(mode_parameters)
		await get_tree().process_frame
		mode_fish.apply_pose(0.25)
		var mode_tail := mode_fish.get_node("BodyPivot/TailPivot1/TailPivot2/TailFinPivot") as Node3D
		var mode_dorsal := mode_fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
		var mode_anal := mode_fish.get_node_or_null("BodyPivot/AnalFin") as MeshInstance3D
		assert(mode_tail != null)
		assert(mode_dorsal != null)
		assert(mode_anal != null)
		assert(is_finite(mode_tail.rotation_degrees.y))
		assert(is_finite(mode_dorsal.rotation_degrees.x))
		assert(is_finite(mode_anal.rotation_degrees.x))
		if mode == "puffer":
			assert(abs(mode_dorsal.rotation_degrees.x) > 0.1)
			assert(abs(mode_anal.rotation_degrees.x) > 0.1)
		mode_fish.queue_free()
```

- [ ] **Step 2: Run test to verify it fails or exposes missing behavior**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ShellRigTest.tscn
```

Expected: FAIL because median fin flap is not applied yet, or because FishRig still ignores the new parameterized gains.

- [ ] **Step 3: Replace hardcoded gain reads**

In `scripts/creature/FishRig.gd`, remove these constants:

```gdscript
const FIN_YAW_FOLLOW_STRENGTH := 0.25
const TAIL_FIN_EXTRA_SWING_STRENGTH := 0.55
```

In `_apply_animated_tail()`, replace:

```gdscript
	var tail_fin_yaw := sin(loop_phase * TAU - phase_delay * 2.4) * global_sway * tail_multiplier * tail_stem_weight * TAIL_FIN_EXTRA_SWING_STRENGTH
```

with:

```gdscript
	var tail_extra_swing := param_float("tail_fin_extra_swing", 0.45)
	var tail_fin_yaw := sin(loop_phase * TAU - phase_delay * 2.4) * global_sway * tail_multiplier * tail_stem_weight * tail_extra_swing
```

In `_fin_follow_yaw()`, replace:

```gdscript
	return _sample_animated_shell_yaw(attach_t, yaws) * FIN_YAW_FOLLOW_STRENGTH
```

with:

```gdscript
	return _sample_animated_shell_yaw(attach_t, yaws) * param_float("fin_yaw_follow_strength", 0.25)
```

- [ ] **Step 4: Add median fin flap helper**

Add this helper near `_fin_follow_yaw()`:

```gdscript
func _median_fin_flap(loop_phase: float, phase_offset: float = 0.0) -> float:
	var flap_amount := param_float("median_fin_flap_amount", 1.5)
	var flap_phase := param_float("median_fin_flap_phase", 0.5)
	return sin(loop_phase * TAU * 2.0 - (flap_phase + phase_offset) * TAU) * flap_amount
```

In `_apply_animated_fins()`, update dorsal and anal rotations.

For `dorsal_fin`, replace:

```gdscript
		dorsal_fin.rotation_degrees = Vector3(0.0, _fin_follow_yaw(dorsal_attach_t, yaws), _surface_tangent_angle_degrees("dorsal", dorsal_attach_t))
```

with:

```gdscript
		dorsal_fin.rotation_degrees = Vector3(_median_fin_flap(loop_phase), _fin_follow_yaw(dorsal_attach_t, yaws), _surface_tangent_angle_degrees("dorsal", dorsal_attach_t))
```

For `dorsal_2_fin`, replace:

```gdscript
		dorsal_2_fin.rotation_degrees = Vector3(0.0, _fin_follow_yaw(dorsal_2_attach_t, yaws), _surface_tangent_angle_degrees("dorsal", dorsal_2_attach_t))
```

with:

```gdscript
		dorsal_2_fin.rotation_degrees = Vector3(_median_fin_flap(loop_phase, 0.12), _fin_follow_yaw(dorsal_2_attach_t, yaws), _surface_tangent_angle_degrees("dorsal", dorsal_2_attach_t))
```

For `anal_fin`, replace:

```gdscript
		anal_fin.rotation_degrees = Vector3(0.0, anal_yaw, _surface_tangent_angle_degrees("ventral", anal_attach_t))
```

with:

```gdscript
		anal_fin.rotation_degrees = Vector3(-_median_fin_flap(loop_phase, 0.5), anal_yaw, _surface_tangent_angle_degrees("ventral", anal_attach_t))
```

- [ ] **Step 5: Run rig test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ShellRigTest.tscn
```

Expected: PASS and output includes `SHELL_RIG_TEST_OK`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/creature/FishRig.gd scripts/tools/ShellRigTest.gd
git commit -m "Use motion profile gains in fish rig"
```

---

### Task 3: Add Swim Mode Dropdown to Parameter Panel

**Files:**
- Modify: `scripts/tools/ParameterPanelCategoryTest.gd`
- Modify: `scripts/ui/ParameterPanel.gd`
- Modify: `scripts/ui/UiText.gd`

- [ ] **Step 1: Write failing UI category test**

In `scripts/tools/ParameterPanelCategoryTest.gd`, add `swim_mode` and the new numeric keys to the sample parameters:

```gdscript
		"swim_mode": "general",
		"tail_fin_extra_swing": 0.45,
		"fin_yaw_follow_strength": 0.25,
		"median_fin_flap_amount": 1.5,
		"median_fin_flap_phase": 0.5,
```

Add these assertions after the Motion Settings section assertions:

```gdscript
	assert(_find_option_for_label(panel, UiText.parameter("swim_mode")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("tail_fin_extra_swing")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("fin_yaw_follow_strength")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("median_fin_flap_amount")) != null)
	assert(_find_slider_for_label(panel, UiText.parameter("median_fin_flap_phase")) != null)
```

Add this helper below `_find_slider_for_label()`:

```gdscript
func _find_option_for_label(panel: Control, label_text: String) -> OptionButton:
	var rows := panel.get_node("ParameterRows")
	for section in rows.get_children():
		var body := section.get_node_or_null("Body")
		if body == null:
			continue
		for row in body.get_children():
			var label := row.get_child(0) as Label
			if label and label.text == label_text:
				return row.get_child(1) as OptionButton
	return null
```

- [ ] **Step 2: Run category test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest.tscn
```

Expected: FAIL because string values that are not colors are ignored by `ParameterPanel`.

- [ ] **Step 3: Add labels**

In `scripts/ui/UiText.gd`, add option labels:

```gdscript
	"eel": "장어형",
	"general": "일반형",
	"mackerel": "고등어형",
	"tuna": "참치형",
	"puffer": "복어형",
	"boxfish": "박스피시형",
```

Add parameter labels:

```gdscript
	"swim_mode": "헤엄 방식",
	"tail_fin_extra_swing": "꼬리지느러미 추가 회전",
	"fin_yaw_follow_strength": "지느러미 몸통 추적",
	"median_fin_flap_amount": "등/뒷지느러미 추진",
	"median_fin_flap_phase": "등/뒷지느러미 위상",
```

- [ ] **Step 4: Render known string options**

In `scripts/ui/ParameterPanel.gd`, add:

```gdscript
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
```

In `set_parameters()`, replace:

```gdscript
		elif typeof(value) == TYPE_STRING and String(value).begins_with("#"):
			_add_color_row(section_body, String(key), Color.html(String(value)))
```

with:

```gdscript
		elif typeof(value) == TYPE_STRING and String(value).begins_with("#"):
			_add_color_row(section_body, String(key), Color.html(String(value)))
		elif typeof(value) == TYPE_STRING and _is_option_parameter(String(key)):
			_add_option_row(section_body, String(key), String(value))
```

Add this method near `_add_color_row()`:

```gdscript
func _add_option_row(parent: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	var label := Label.new()
	label.text = UiText.parameter(key)
	label.custom_minimum_size = Vector2(150, 0)
	label.clip_text = true
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := _options_for_key(key)
	for option_value in options:
		option.add_item(UiText.option(option_value))
		option.set_item_metadata(option.item_count - 1, option_value)
	var selected_index := options.find(value)
	option.select(maxi(selected_index, 0))
	row.add_child(option)
	option.item_selected.connect(func(index: int) -> void:
		var selected := String(option.get_item_metadata(index))
		parameters[key] = selected
		if key == "swim_mode":
			BodyProfileScript.apply_swim_mode(parameters, selected)
		parameters_changed.emit(parameters.duplicate(true))
	)
	parent.add_child(row)
```

Add these helpers near `_should_hide_key()`:

```gdscript
func _is_option_parameter(key: String) -> bool:
	return key == "swim_mode"

func _options_for_key(key: String) -> Array[String]:
	if key == "swim_mode":
		return BodyProfileScript.swim_mode_names()
	return []
```

Update `_category_for_key()` so `swim_mode` lands in Motion Settings:

```gdscript
	if key == "swim_mode" or key.contains("speed") or key.contains("sway") or key.contains("flap") or key.contains("phase") or key.contains("bob") or key.contains("follow") or key.contains("glide"):
		return "Motion Settings"
```

- [ ] **Step 5: Run category test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest.tscn
```

Expected: PASS and output includes `PARAMETER_PANEL_CATEGORY_TEST_OK`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/ui/ParameterPanel.gd scripts/ui/UiText.gd scripts/tools/ParameterPanelCategoryTest.gd
git commit -m "Add swim mode selector to parameter panel"
```

---

### Task 4: Verify Editor Parameter Sync

**Files:**
- Modify: `scripts/tools/EditorParameterSyncTest.gd`

- [ ] **Step 1: Write sync test for dropdown changes**

In `scripts/tools/EditorParameterSyncTest.gd`, add this helper at the bottom:

```gdscript
func _find_option_for_label(panel: Control, label_text: String) -> OptionButton:
	var rows := panel.get_node("ParameterRows")
	for section in rows.get_children():
		var body := section.get_node_or_null("Body")
		if body == null:
			continue
		for row in body.get_children():
			var label := row.get_child(0) as Label
			if label and label.text == label_text:
				return row.get_child(1) as OptionButton
	return null
```

Add this block before writing the ok file:

```gdscript
	var parameter_panel: Control = main.get("parameter_panel")
	assert(parameter_panel != null)
	var swim_mode_option := _find_option_for_label(parameter_panel, "헤엄 방식")
	assert(swim_mode_option != null)
	var tuna_index := -1
	for i in swim_mode_option.item_count:
		if String(swim_mode_option.get_item_metadata(i)) == "tuna":
			tuna_index = i
	assert(tuna_index >= 0)
	swim_mode_option.select(tuna_index)
	swim_mode_option.item_selected.emit(tuna_index)
	await get_tree().process_frame
	var after_swim_mode: Dictionary = main.get("current_preset")
	var swim_parameters: Dictionary = after_swim_mode.get("parameters", {})
	assert(String(swim_parameters.get("swim_mode", "")) == "tuna")
	assert(abs(float(swim_parameters.get("body_wave_amount", 0.0)) - 0.12) < 0.001)
	assert(abs(float(swim_parameters.get("tail_sway_multiplier", 0.0)) - 1.55) < 0.001)
	assert(abs(float(after_swim_mode.get("motion_profile", {}).get("fin_yaw_follow_strength", 0.0)) - 0.12) < 0.001)
```

- [ ] **Step 2: Run sync test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter EditorParameterSyncTest.tscn
```

Expected: PASS and output includes `EDITOR_PARAMETER_SYNC_TEST_OK`.

- [ ] **Step 3: Commit**

```powershell
git add scripts/tools/EditorParameterSyncTest.gd scripts/ui/ParameterPanel.gd scripts/creature/BodyProfile.gd
git commit -m "Sync swim mode selection through editor"
```

---

### Task 5: Run Focused Regression Suite

**Files:**
- No source changes expected.

- [ ] **Step 1: Run focused headless tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter EditorParameterSyncTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ShellRigTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinEditorModelTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BodyEditorModelTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinDragTest.tscn
```

Expected outputs:

```text
PRESET_NORMALIZATION_TEST_OK
PARAMETER_PANEL_CATEGORY_TEST_OK
EDITOR_PARAMETER_SYNC_TEST_OK
SHELL_RIG_TEST_OK
FIN_EDITOR_MODEL_TEST_OK
BODY_EDITOR_MODEL_TEST_OK
FIN_DRAG_TEST_OK
```

- [ ] **Step 2: Run whitespace check**

Run:

```powershell
git diff --check
```

Expected: no output.

- [ ] **Step 3: Record regression result**

If every command passed and `git status --short` shows no new changes, continue to the manual preview task without a commit.

If a regression exposed a real defect, stop this task and fix the defect in the task that owns the failing file before repeating the focused suite.

---

### Task 6: Manual Preview Tuning Pass

**Files:**
- Modify only if visual tuning is needed: `scripts/creature/BodyProfile.gd`

- [ ] **Step 1: Launch the editor**

Run:

```powershell
godot --path .
```

Expected: main scene opens with the procedural sprite generator.

- [ ] **Step 2: Compare modes in the Motion Settings dropdown**

For a fish preset, switch through:

```text
eel
general
mackerel
tuna
puffer
boxfish
```

Visual acceptance:

- `eel`: body wave starts near the head and travels through the whole body.
- `general`: front body is calmer than the rear body.
- `mackerel`: rear third drives the motion.
- `tuna`: body remains stiff and tail action carries most movement.
- `puffer`: body stays stiff while pectoral/median fins visibly flap.
- `boxfish`: body stays rigid with restrained tail and fin-driven control.

- [ ] **Step 3: Tune data based on the visual comparison**

When a mode is too stiff or too exaggerated, edit only the corresponding values inside `SWIM_MODE_PRESETS` in `scripts/creature/BodyProfile.gd`.

Do not change FishRig code for pure tuning.

- [ ] **Step 4: Re-run focused tests after tuning**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest.tscn
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ShellRigTest.tscn
git diff --check
```

Expected: both tests pass and `git diff --check` has no output.

- [ ] **Step 5: Commit tuning changes**

```powershell
git add scripts/creature/BodyProfile.gd
git commit -m "Tune swim mode motion presets"
```

When no tuning values changed, confirm `git status --short` is clean and continue to the handoff task.

---

### Task 7: Update Handoff

**Files:**
- Modify: `docs/2026-05-31-motion-handoff.md`

- [ ] **Step 1: Add a short completion note**

Append this section:

```markdown
## Swim Mode Implementation Update

- Added `swim_mode` motion presets for eel, general, mackerel, tuna, puffer, and boxfish.
- Moved tail-fin extra swing and fin yaw-follow strength into normalized motion parameters.
- Added Motion Settings dropdown behavior that applies grouped swim-mode values while preserving manual slider tuning afterward.
- Added conservative dorsal/anal fin flap support for MPF-heavy modes.
- Verified focused Godot tests:
  - `PresetNormalizationTest.tscn`
  - `ParameterPanelCategoryTest.tscn`
  - `EditorParameterSyncTest.tscn`
  - `ShellRigTest.tscn`
  - `FinEditorModelTest.tscn`
  - `BodyEditorModelTest.tscn`
  - `FinDragTest.tscn`
```

Only list tests that actually passed in the current run.

- [ ] **Step 2: Commit handoff update**

```powershell
git add docs/2026-05-31-motion-handoff.md
git commit -m "Update motion handoff for swim modes"
```
