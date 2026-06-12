# Creature Mode Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate ordinary fish, rays, and sharks into explicit top-level creature modes so presets, rig creation, editor controls, archetypes, overlays, and future species-specific behavior do not bleed into each other.

**Architecture:** Add a small mode registry and rig factory as the single source of truth for `fish`, `ray`, and `shark`. `Main.gd` keeps one workbench UI, but delegates mode selection, preset filtering, rig creation, and editor capability checks to mode-aware helpers. `SharkRig` starts as a thin `FishRig` subclass so shark work is fully separated at the app and preset level without duplicating the whole fish renderer on day one.

**Tech Stack:** Godot 4 GDScript, existing JSON presets, existing `tools/run_godot_cli_tests.ps1` Godot CLI runner.

---

## Context

- Current `Main.gd` loads all presets into one `OptionButton` through `PresetStore.load_all()`.
- Current rig selection is inline in `Main._load_preset`: `creature_type == "ray"` creates `RayRig`; every other type creates `FishRig`.
- Rays already have `RayRig.gd`, ray presets, ray camera, and ray parameters, but ray/fish UI controls still share one side panel and many mode checks are scattered as `_is_fish()` / `_is_ray()`.
- Sharks are not a real mode yet. Existing shark-like presets use `creature_type: "fish"`, `camera_preset: "shark_side_quarter"`, shark caudal shapes, and fish motion/body controls.
- `BodyProfile.split_parameters_into_profiles()` currently stores ray keys in fish presets when those keys exist in the parameter dictionary. That is one of the main sources of cross-mode pollution.
- The worktree currently has unrelated uncommitted pectoral-fin attachment fixes in `scripts/creature/FishRig.gd`, `scripts/tools/RingWidthFlatnessTest.gd`, and `scripts/tools/ShellRigTest.gd`. Finish, stash, or commit that work before executing this plan.

## Approach Options

**Recommended: Mode Registry + Factory + Thin SharkRig**

Create explicit mode metadata and route all top-level decisions through it. Add `SharkRig.gd` as a subclass of `FishRig.gd` for now. This gives separate presets, UI, save/load, and tests immediately while preserving existing shark-shaped fish rendering.

**Alternative A: Three Entirely Separate Main Scenes**

Create `FishMain.tscn`, `RayMain.tscn`, and `SharkMain.tscn`. This gives maximum isolation but duplicates UI/export/camera code and will make every future UX change three times more expensive.

**Alternative B: Keep Fish/Ray Mixed, Only Add Preset Filters**

Filter the dropdown by mode but leave rig creation and editor capability checks scattered in `Main.gd`. This is small but does not solve the real coupling; shark-specific work would still land in fish paths.

## Scope Contract

- Add top-level mode switching for `fish`, `ray`, and `shark`.
- Preset dropdown shows only presets for the active mode.
- Switching modes unloads the active rig from the previous mode root and loads the last selected preset for the new mode.
- One active rig exists per mode root at a time. Mode roots are separate nodes under `WorldRoot`: `FishModeRoot`, `RayModeRoot`, `SharkModeRoot`.
- Fish species archetypes remain fish-only. Hide or disable the archetype section outside fish mode.
- Shark mode uses `SharkRig` and shark presets, even if `SharkRig` initially inherits FishRig behavior.
- Ray mode uses `RayRig` and ray presets.
- Ordinary fish mode must not show ray-only parameters such as `disc_width`, `ray_disc_shape`, or `ray_tail_style`.
- Ray mode must not show fish-only fin/body controls that do not affect `RayRig`.
- Shark mode must not show ray-only controls. It may reuse fish body/head/fin controls where they directly affect `SharkRig`.
- Saving a user preset preserves the active `creature_type`.
- Normalization and profile splitting must stop writing irrelevant mode keys into saved presets.
- Existing fish/ray exports continue to work.

## Mode Slider Matrix

This matrix is the contract for which top-level mode owns which sliders. Implementation must encode these rules in a testable key schema instead of relying on loose category names.

### Shared by all modes

These controls may appear in fish, ray, and shark modes:

- Export/camera: `camera_*`, `orthographic_size`, `frame_count`, `frame_rate`, `padding_px`, `render_resolution`, `direction_count`.
- Basic playback and turn preview: `swim_speed` or mode-specific speed aliases, `turn_amount`, `turn_direction`, `turn_phase`, `turn_bank_roll`, `turn_tail_lag`.
- Core color/material where supported by the rig: `base_color`, `secondary_color`, `outline_color`, `highlight_strength`, `shadow_strength`, `pattern_type`, `pattern_color`, `pattern_scale_x`, `pattern_scale_y`, `pattern_intensity`, `pattern_invert`, `pattern_seed`, `pattern_size_lock`, `wetness`.
- Reference image and UI-only values are stored on the preset, not exposed as creature-shape sliders.

### Ordinary Fish Mode (`fish`)

Fish mode keeps the teleost-style editor:

- Body: `body_length`, `body_height`, `body_width`, `body_profile`, `shell_enabled`, `shell_expand`, `shell_color_mix`, `shell_opacity`, `shell_roundness`.
- Head and mouth: `head_shape`, `head_size`, `head_offset`, `snout_*`, `forehead_slope`, `jaw_*`, `mouth_*`, `barbel_style`, `eye_*`.
- Existing operculum/gill-cover controls: `gill_mark`, `operculum_*`. These are fish-only because rays and sharks need different gill anatomy.
- Paired/median/caudal fins: `dorsal_*`, `anal_*`, `pectoral_*`, `pelvic_*`, `caudal_*`, `tail_length`, `tail_fin_size`, `caudal_shape`, `caudal_height_scale`.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `fin_softness`, `fin_rigidity`, slot softness/rigidity keys, `adipose_fin_*`, `finlet_*`.
- Fish motion: `swim_mode`, `global_sway_amount`, `body_wave_*`, `tail_sway_multiplier`, `tail_fin_extra_swing`, `fin_flap_amount`, `fin_yaw_follow_strength`, `median_fin_flap_*`, `inside_pectoral_fold`, `outside_pectoral_brace`.

Fish mode must not expose:

- Ray-only shape controls: `disc_*`, `wing_*`, `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `ray_locomotion_mode`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`.

### Ray Mode (`ray`)

Ray mode uses disc and wing controls, not fish body-fin anatomy:

- Disc/body: `disc_width`, `disc_length`, `disc_thickness`, `wing_width`, `wing_length`, `wing_curve`, `shell_roundness`, `body_profile` only as ray cross-section/wing contour data.
- Ray head/tail: `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `cephalic_horns`.
- Ray eyes and underside: `eye_spacing`, `eye_size`, `base_color`, `underside_color`.
- Ray locomotion: `ray_locomotion_mode`, `wave_ripples`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`, `pectoral_flap_sync`.
- Ray pelvic lobes: `pelvic_length`, `pelvic_height` only when wired to `RayRig` pelvic lobes.

Ray mode must not expose:

- Existing fish operculum/gill-cover controls: `gill_mark`, `operculum_*`.
- Fish fin slots and fish fin placement controls: `dorsal_1_*`, `dorsal_2_*`, `dorsal_fin_*`, `anal_*`, `anal_fin_*`, `pectoral_attach_t`, `pectoral_fin_*`, `pectoral_shape`, `caudal_shape`, `caudal_height_scale`.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `adipose_fin_*`, `finlet_*`.
- Fish swim presets: `swim_mode`, `body_wave_*`, `tail_fin_extra_swing`, `median_fin_flap_*`, `inside_pectoral_fold`, `outside_pectoral_brace`.

### Shark Mode (`shark`)

Shark mode starts on a `FishRig`-derived body but has its own cartilaginous-fish slider contract:

- Body: `body_length`, `body_height`, `body_width`, `body_profile`, `shell_enabled`, `shell_expand`, `shell_color_mix`, `shell_opacity`, `shell_roundness`.
- Shark head and mouth: `head_shape`, `head_size`, `head_offset`, `snout_*`, `forehead_slope`, `jaw_*`, `mouth_*`, `eye_*`.
- Shark fins: `dorsal_1_*`, `dorsal_2_*`, `dorsal_fin_*`, `anal_*`, `pectoral_*`, `pelvic_*`, `tail_length`, `tail_fin_size`, `caudal_shape`, `caudal_height_scale`.
- Shark caudal shapes: `shark_heterocercal`, `thresher`, plus generic `pointed`, `lunate`, `forked_shallow`, and `forked_deep`.
- Shark motion: `swim_mode`, `global_sway_amount`, `body_wave_*`, `tail_sway_multiplier`, `tail_fin_extra_swing`, `fin_flap_amount`, `fin_yaw_follow_strength`, `turn_*`.

Shark mode must not expose:

- Existing fish operculum/gill-cover controls: `gill_mark`, `operculum_*`. Shark gill slits need a separate future `shark_gill_*` contract.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `adipose_fin_*`, `finlet_*`.
- Ray-only disc/wing controls: `disc_*`, `wing_*`, `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `cephalic_horns`, `ray_locomotion_mode`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`.
- Fish-only ornamentation that does not map to sharks: `barbel_style`, `adipose_fin_shape`, `finlet_shape`.

## File Structure

- Create `scripts/creature/CreatureMode.gd`: mode ids, labels, default preset names, camera defaults, capability flags, and helper methods.
- Create `scripts/creature/CreatureRigFactory.gd`: create `FishRig`, `RayRig`, or `SharkRig` from a mode id.
- Create `scripts/creature/SharkRig.gd`: thin subclass of `FishRig` that normalizes `creature_type` to `shark` and gives future shark-specific overrides a home.
- Create `scenes/creatures/SharkRig.tscn`: scene wrapper for parity with existing `FishRig.tscn` and `RayRig.tscn`.
- Modify `scripts/presets/PresetStore.gd`: mode-filtered loading, default selection helpers, and stricter mode normalization.
- Modify `scripts/creature/BodyProfile.gd`: mode-aware profile splitting and parameter reconstruction.
- Modify `scripts/ui/Main.gd`: add mode selector, mode roots, mode-aware rig loading, mode-aware editor capability checks, and per-mode last selection state.
- Modify `scripts/ui/ParameterPanel.gd`: add `creature_type` or `visible_keys` filtering so shared panels do not show irrelevant controls.
- Modify `scripts/ui/FinEditorPanel.gd`, `HeadEditorPanel.gd`, `BodyEditorPanel.gd`: add `set_creature_type(mode)` and use mode capabilities instead of hardcoded fish/ray assumptions.
- Modify `scripts/ui/UiText.gd`: labels for mode selector and shark mode.
- Modify `presets/장.json`: migrate to `creature_type: "shark"` and `type: "shark"`.
- Add `presets/basic_shark.json`: compact built-in shark preset used as the default shark mode preset.
- Add tests: `CreatureModeRegistryTest`, `PresetStoreModeFilterTest`, `MainCreatureModeTest`, `ParameterModeVisibilityTest`, and extend `PresetNormalizationTest` / `RigImmediateRebuildTest`.

---

### Task 1: Add Creature Mode Registry and Rig Factory

**Files:**
- Create: `scripts/creature/CreatureMode.gd`
- Create: `scripts/creature/CreatureRigFactory.gd`
- Create: `scripts/creature/SharkRig.gd`
- Create: `scenes/creatures/SharkRig.tscn`
- Create: `scripts/tools/CreatureModeRegistryTest.gd`
- Create: `scenes/CreatureModeRegistryTest.tscn`

- [ ] **Step 1: Write the failing registry test**

`CreatureModeRegistryTest.gd` should assert:

```gdscript
extends Node

const CreatureMode := preload("res://scripts/creature/CreatureMode.gd")
const CreatureRigFactory := preload("res://scripts/creature/CreatureRigFactory.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	assert(CreatureMode.mode_ids() == ["fish", "ray", "shark"])
	assert(CreatureMode.normalize("unknown") == "fish")
	assert(CreatureMode.label("shark") == "상어")
	assert(CreatureMode.default_camera("ray") == "ray_top_quarter")
	assert(CreatureMode.default_camera("shark") == "shark_side_quarter")
	assert(CreatureMode.supports_archetypes("fish"))
	assert(not CreatureMode.supports_archetypes("ray"))
	assert(not CreatureMode.supports_archetypes("shark"))
	assert(CreatureRigFactory.create("fish") is FishRigScript)
	assert(CreatureRigFactory.create("ray") is RayRigScript)
	assert(CreatureRigFactory.create("shark") is SharkRigScript)
	print("CREATURE_MODE_REGISTRY_TEST_OK")
	get_tree().quit(0)
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter CreatureModeRegistryTest`

Expected: fail because `CreatureMode.gd`, `CreatureRigFactory.gd`, and `SharkRig.gd` do not exist.

- [ ] **Step 3: Implement `CreatureMode.gd`**

Define:

```gdscript
class_name CreatureMode
extends RefCounted

const FISH := "fish"
const RAY := "ray"
const SHARK := "shark"

const MODES := {
	"fish": {
		"label": "물고기",
		"default_camera": "aquarium_side_quarter",
		"default_preset": "basic_fish",
		"supports_archetypes": true,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	},
	"ray": {
		"label": "가오리",
		"default_camera": "ray_top_quarter",
		"default_preset": "basic_ray",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": false,
		"supports_body_ring_editor": true
	},
	"shark": {
		"label": "상어",
		"default_camera": "shark_side_quarter",
		"default_preset": "basic_shark",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	}
}
```

Add `mode_ids()`, `normalize(value)`, `label(mode)`, `default_camera(mode)`, `default_preset(mode)`, `supports_archetypes(mode)`, `supports_fish_drag_overlay(mode)`, and `supports_body_ring_editor(mode)`.

- [ ] **Step 4: Implement `SharkRig.gd`**

Use inheritance, not copy-paste:

```gdscript
class_name SharkRig
extends "res://scripts/creature/FishRig.gd"

func set_parameters(new_parameters: Dictionary) -> void:
	var shark_parameters := new_parameters.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	super.set_parameters(shark_parameters)
```

- [ ] **Step 5: Implement `CreatureRigFactory.gd`**

Return the right node for each normalized mode. Unknown values return fish.

- [ ] **Step 6: Add `SharkRig.tscn`**

Mirror the existing creature rig scenes:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/creature/SharkRig.gd" id="1_shark"]

[node name="SharkRig" type="Node3D"]
script = ExtResource("1_shark")
```

- [ ] **Step 7: Verify**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter CreatureModeRegistryTest`

Expected: `CREATURE_MODE_REGISTRY_TEST_OK`, `PASS scenes/CreatureModeRegistryTest.tscn`.

---

### Task 2: Mode-Filtered Preset Loading and Shark Preset Migration

**Files:**
- Modify: `scripts/presets/PresetStore.gd`
- Modify: `presets/장.json`
- Create: `presets/basic_shark.json`
- Create: `scripts/tools/PresetStoreModeFilterTest.gd`
- Create: `scenes/PresetStoreModeFilterTest.tscn`
- Modify: `scripts/tools/PresetNormalizationTest.gd`

- [ ] **Step 1: Write failing preset filter test**

Assert:

```gdscript
var fish_presets := PresetStoreScript.load_all("fish")
var ray_presets := PresetStoreScript.load_all("ray")
var shark_presets := PresetStoreScript.load_all("shark")
assert(fish_presets.size() > 0)
assert(ray_presets.size() > 0)
assert(shark_presets.size() > 0)
for preset in fish_presets:
	assert(String(preset.get("creature_type", "")) == "fish")
for preset in ray_presets:
	assert(String(preset.get("creature_type", "")) == "ray")
for preset in shark_presets:
	assert(String(preset.get("creature_type", "")) == "shark")
assert(not PresetStoreScript.find_default_for_mode("shark").is_empty())
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetStoreModeFilterTest`

Expected: fail because `load_all(mode)` and shark presets do not exist.

- [ ] **Step 3: Update `PresetStore.load_all`**

Change signature to `static func load_all(creature_type: String = "") -> Array[Dictionary]`. Normalize each loaded preset, then include it only when `creature_type == ""` or `preset.creature_type == CreatureMode.normalize(creature_type)`.

- [ ] **Step 4: Add `find_default_for_mode(mode)`**

Return the preset whose `name` matches `CreatureMode.default_preset(mode)`. If missing, return the first preset in `load_all(mode)`.

- [ ] **Step 5: Normalize mode fields**

In `normalize_preset`, set both:

```gdscript
var mode := CreatureMode.normalize(String(normalized.get("creature_type", normalized.get("type", "fish"))))
normalized["creature_type"] = mode
normalized["type"] = mode
```

Use this `mode` for fish/ray/shark-specific normalization.

- [ ] **Step 6: Migrate shark built-ins**

Update `presets/장.json` top-level `creature_type` and `type` to `"shark"`. Add `presets/basic_shark.json` using the same core shark silhouette parameters but a clear `name: "basic_shark"`, `creature_type: "shark"`, `type: "shark"`, `camera_preset: "shark_side_quarter"`, and shark-tail-friendly defaults.

- [ ] **Step 7: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetStoreModeFilterTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

Expected: both pass.

---

### Task 3: Mode Selector, Separate Mode Roots, and Rig Lifecycle

**Files:**
- Modify: `scripts/ui/Main.gd`
- Modify: `scripts/ui/UiText.gd`
- Create: `scripts/tools/MainCreatureModeTest.gd`
- Create: `scenes/MainCreatureModeTest.tscn`
- Modify: `scripts/tools/RigImmediateRebuildTest.gd`

- [ ] **Step 1: Write failing Main mode test**

Assert:

```gdscript
var main := MainScript.new()
add_child(main)
await get_tree().process_frame
var mode_option: OptionButton = main.get("creature_mode_option")
assert(mode_option != null)
assert(mode_option.item_count == 3)
main.call("_select_creature_mode", "ray")
await get_tree().process_frame
assert(String(main.get("active_creature_mode")) == "ray")
assert(main.get("current_rig") is RayRigScript)
assert(_only_mode_root_visible(main, "RayModeRoot"))
main.call("_select_creature_mode", "shark")
await get_tree().process_frame
assert(String(main.get("active_creature_mode")) == "shark")
assert(main.get("current_rig") is SharkRigScript)
assert(_only_mode_root_visible(main, "SharkModeRoot"))
var presets: Array = main.get("presets")
for preset in presets:
	assert(String(preset.get("creature_type", "")) == "shark")
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MainCreatureModeTest`

Expected: fail because mode selector and mode roots do not exist.

- [ ] **Step 3: Add mode state to `Main.gd`**

Add:

```gdscript
const CreatureMode := preload("res://scripts/creature/CreatureMode.gd")
const CreatureRigFactory := preload("res://scripts/creature/CreatureRigFactory.gd")

var active_creature_mode := CreatureMode.FISH
var creature_mode_option: OptionButton
var mode_roots := {}
var last_preset_path_by_mode := {}
var last_session_preset_by_mode := {}
```

- [ ] **Step 4: Build mode selector UI**

Place an `OptionButton` above or beside the preset dropdown. Add three items with metadata `fish`, `ray`, `shark`. Connect `item_selected` to `_select_creature_mode(String(metadata))`.

- [ ] **Step 5: Create separate mode roots**

In `_build_preview_world`, after `world_root` is created, add three child `Node3D`s named `FishModeRoot`, `RayModeRoot`, and `SharkModeRoot`. Store them in `mode_roots`.

- [ ] **Step 6: Replace inline rig construction**

In `_load_preset`, use:

```gdscript
var creature_type := CreatureMode.normalize(String(current_preset.get("creature_type", active_creature_mode)))
active_creature_mode = creature_type
current_rig = CreatureRigFactory.create(creature_type)
mode_roots[creature_type].add_child(current_rig)
```

Call `_set_active_mode_root(creature_type)` before adding the rig.

- [ ] **Step 7: Implement `_select_creature_mode(mode)`**

Before switching, save the current preset duplicate to `last_session_preset_by_mode[active_creature_mode]`. Then set `active_creature_mode`, reload only that mode's presets, and select the last path or default preset for the mode.

- [ ] **Step 8: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MainCreatureModeTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RigImmediateRebuildTest`

Expected: both pass and each mode root has at most one `ActiveRig`.

---

### Task 4: Mode-Aware Editor Capabilities and Parameter Visibility

**Files:**
- Modify: `scripts/ui/Main.gd`
- Modify: `scripts/ui/ParameterPanel.gd`
- Modify: `scripts/ui/FinEditorPanel.gd`
- Modify: `scripts/ui/HeadEditorPanel.gd`
- Modify: `scripts/ui/BodyEditorPanel.gd`
- Create: `scripts/tools/ParameterModeVisibilityTest.gd`
- Create: `scenes/ParameterModeVisibilityTest.tscn`

- [ ] **Step 1: Write failing visibility test**

Create three panels with fish, ray, and shark parameter dictionaries. Assert:

```gdscript
fish_panel.set_creature_type("fish")
fish_panel.set_parameters({
	"body_length": 1.4,
	"disc_width": 1.2,
	"ray_disc_shape": "diamond",
	"gill_mark": "operculum",
	"operculum_size": 1.0,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(fish_panel, "body_length") != null)
assert(_find_slider_for_key(fish_panel, "disc_width") == null)
assert(_find_option_for_key(fish_panel, "ray_disc_shape") == null)
assert(_find_option_for_key(fish_panel, "gill_mark") != null)
assert(_find_slider_for_key(fish_panel, "operculum_size") != null)
assert(_find_slider_for_key(fish_panel, "fin_ray_count") != null)
assert(_find_checkbox_for_key(fish_panel, "adipose_fin_enabled") != null)
assert(_find_checkbox_for_key(fish_panel, "finlet_enabled") != null)

ray_panel.set_creature_type("ray")
ray_panel.set_parameters({
	"disc_width": 1.2,
	"ray_disc_shape": "manta",
	"swim_mode": "eel",
	"gill_mark": "operculum",
	"operculum_size": 1.0,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(ray_panel, "disc_width") != null)
assert(_find_option_for_key(ray_panel, "ray_disc_shape") != null)
assert(_find_option_for_key(ray_panel, "swim_mode") == null)
assert(_find_option_for_key(ray_panel, "gill_mark") == null)
assert(_find_slider_for_key(ray_panel, "operculum_size") == null)
assert(_find_slider_for_key(ray_panel, "fin_ray_count") == null)
assert(_find_checkbox_for_key(ray_panel, "adipose_fin_enabled") == null)
assert(_find_checkbox_for_key(ray_panel, "finlet_enabled") == null)

shark_panel.set_creature_type("shark")
shark_panel.set_parameters({
	"body_length": 5.8,
	"ray_disc_shape": "diamond",
	"caudal_shape": "shark_heterocercal",
	"gill_mark": "operculum",
	"operculum_size": 1.0,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(shark_panel, "body_length") != null)
assert(_find_option_for_key(shark_panel, "ray_disc_shape") == null)
assert(_find_option_for_key(shark_panel, "caudal_shape") != null)
assert(_find_option_for_key(shark_panel, "gill_mark") == null)
assert(_find_slider_for_key(shark_panel, "operculum_size") == null)
assert(_find_slider_for_key(shark_panel, "fin_ray_count") == null)
assert(_find_checkbox_for_key(shark_panel, "adipose_fin_enabled") == null)
assert(_find_checkbox_for_key(shark_panel, "finlet_enabled") == null)
```

The test file must define `_find_slider_for_key(panel, key)`, `_find_option_for_key(panel, key)`, and `_find_checkbox_for_key(panel, key)` by using `panel.control_rows` and checking the row's second child type (`HSlider`, `OptionButton`, or `CheckBox`). This keeps the test keyed to parameter ids rather than translated label text.

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest`

Expected: fail because `ParameterPanel` does not have mode filtering.

- [ ] **Step 3: Add mode filtering API**

In `ParameterPanel.gd`, add `var creature_type := "fish"` and `func set_creature_type(mode: String) -> void`. Rebuild controls when mode changes.

- [ ] **Step 4: Encode the mode slider matrix**

Add a mode schema dictionary in `CreatureMode.gd` or a new `CreatureParameterSchema.gd`. It must expose:

```gdscript
static func is_parameter_visible(mode: String, key: String) -> bool
static func is_option_value_visible(mode: String, key: String, value: String) -> bool
static func allowed_fin_slots(mode: String) -> Array[String]
```

The functions must implement the full `Mode Slider Matrix` above. Do not infer visibility only by category text; use explicit key groups and prefix checks so ray keys cannot leak into fish/shark panels, and fish operculum/fin-ray/adipose/finlet controls cannot leak into ray or shark panels.

- [ ] **Step 5: Filter option values by mode**

For `caudal_shape`, fish may show all existing fish caudal shapes. Shark may show only `shark_heterocercal`, `thresher`, `pointed`, `lunate`, `forked_shallow`, and `forked_deep`. Ray must not show `caudal_shape` at all.

- [ ] **Step 6: Main capability routing**

Replace `_is_fish()` and `_is_ray()` checks where possible with:

```gdscript
func _current_mode() -> String:
	return CreatureMode.normalize(active_creature_mode)
```

Use `CreatureMode.supports_archetypes`, `supports_fish_drag_overlay`, and `supports_body_ring_editor` to enable/disable sections and overlays.

- [ ] **Step 7: Hide fish-only archetypes outside fish mode**

When active mode is not fish, set the archetype controls container invisible and clear any pending archetype selection. `_apply_selected_archetype` must no-op unless the active mode supports archetypes.

- [ ] **Step 8: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinEditorPanelTest`

Expected: all pass.

---

### Task 5: Mode-Aware Save/Normalize/Profile Split

**Files:**
- Modify: `scripts/creature/BodyProfile.gd`
- Modify: `scripts/presets/PresetStore.gd`
- Modify: `scripts/tools/PresetNormalizationTest.gd`
- Modify: `scripts/tools/UserPresetStoreTest.gd`
- Modify: `scripts/tools/UserPresetMainTest.gd`

- [ ] **Step 1: Extend failing normalization tests**

Add assertions:

```gdscript
var fish_split := BodyProfileScript.split_parameters_into_profiles({
	"creature_type": "fish",
	"body_length": 1.4,
	"ray_disc_shape": "manta",
	"ray_tail_style": "whip"
}, {"name": "fish_split_check", "creature_type": "fish"})
assert(not (fish_split.get("fin_profile", {}) as Dictionary).has("ray_disc_shape"))
assert(not (fish_split.get("tail_profile", {}) as Dictionary).has("ray_tail_style"))

var shark_split := BodyProfileScript.split_parameters_into_profiles({
	"creature_type": "shark",
	"body_length": 5.8,
	"caudal_shape": "shark_heterocercal",
	"ray_disc_shape": "diamond",
	"gill_mark": "operculum",
	"operculum_size": 1.0,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
}, {"name": "shark_split_check", "creature_type": "shark"})
assert(String(shark_split.get("creature_type", "")) == "shark")
assert(String(shark_split.get("type", "")) == "shark")
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("ray_disc_shape"))
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("gill_mark"))
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("operculum_size"))
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("fin_ray_count"))
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("adipose_fin_enabled"))
assert(not (shark_split.get("fin_profile", {}) as Dictionary).has("finlet_enabled"))

var ray_split := BodyProfileScript.split_parameters_into_profiles({
	"creature_type": "ray",
	"disc_width": 1.2,
	"ray_disc_shape": "manta",
	"gill_mark": "operculum",
	"operculum_size": 1.0,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
}, {"name": "ray_split_check", "creature_type": "ray"})
assert(String(ray_split.get("creature_type", "")) == "ray")
assert(not (ray_split.get("fin_profile", {}) as Dictionary).has("gill_mark"))
assert(not (ray_split.get("fin_profile", {}) as Dictionary).has("operculum_size"))
assert(not (ray_split.get("fin_profile", {}) as Dictionary).has("fin_ray_count"))
assert(not (ray_split.get("fin_profile", {}) as Dictionary).has("adipose_fin_enabled"))
assert(not (ray_split.get("fin_profile", {}) as Dictionary).has("finlet_enabled"))
assert(String((ray_split.get("fin_profile", {}) as Dictionary).get("ray_disc_shape", "")) == "manta")
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

Expected: fail because fish/shark split still keeps ray keys.

- [ ] **Step 3: Split profile key lists by mode**

In `BodyProfile.gd`, extract arrays:

- `COMMON_GLOBAL_KEYS`
- `FISH_HEAD_FIN_KEYS`
- `FISH_TAIL_KEYS`
- `FISH_MOTION_KEYS`
- `RAY_BODY_KEYS`
- `RAY_FIN_KEYS`
- `RAY_TAIL_KEYS`
- `RAY_MOTION_KEYS`
- `SHARK_HEAD_FIN_KEYS`
- `SHARK_TAIL_KEYS`
- `SHARK_MOTION_KEYS`
- `COMMON_VISUAL_KEYS`

Use the active mode to choose which arrays `_pick` uses.

- [ ] **Step 4: Preserve mode in saved presets**

At the end of `split_parameters_into_profiles`, set:

```gdscript
var mode := CreatureMode.normalize(String(parameters.get("creature_type", preset.get("creature_type", "fish"))))
updated["creature_type"] = mode
updated["type"] = mode
normalized_parameters["creature_type"] = mode
updated["parameters"] = normalized_parameters
```

- [ ] **Step 5: Verify user save tests**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UserPresetStoreTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UserPresetMainTest`

Expected: all pass.

---

### Task 6: Export and End-to-End Mode Smoke Tests

**Files:**
- Modify: `scripts/tools/ExportSmokeTest.gd`
- Modify: `scripts/tools/RigImmediateRebuildTest.gd`
- Modify: `scripts/tools/MainCreatureModeTest.gd`

- [ ] **Step 1: Add mode switch smoke assertions**

Extend `MainCreatureModeTest` to switch fish -> ray -> shark -> fish and assert:

- preset list changes for each mode
- `current_preset.creature_type` matches the selected mode
- `current_rig.parameters.creature_type` matches the selected mode
- `creature_type_label` text uses the mode label
- archetype controls visible only in fish mode
- `export_panel.get_direction_count()` does not reset unexpectedly unless preset export settings require it

- [ ] **Step 2: Add export framing smoke**

For one preset in each mode, instantiate the rig, call `SpriteExporter.compute_fit_framing(current_rig, Vector2i(256, 256))`, and assert radius and orthographic size are positive.

- [ ] **Step 3: Run focused suite**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MainCreatureModeTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RigImmediateRebuildTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportSmokeTest`

Expected: all pass.

- [ ] **Step 4: Run broader affected suite**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter Preset`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanel`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ShellRigTest`

Expected: all pass. Treat `Failed to read the root certificate store` as non-fatal per AGENTS.md.

---

## Commit Plan

1. `Add creature mode registry and shark rig shell`
2. `Filter presets by creature mode`
3. `Add mode selector and separate mode roots`
4. `Filter editor controls by creature mode`
5. `Split preset profiles by creature mode`
6. `Add end-to-end creature mode smoke coverage`

## Final Verification

Run the full Godot CLI suite:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`

Expected: all tests pass. If the full suite is too slow during development, run it before the final commit or PR.
