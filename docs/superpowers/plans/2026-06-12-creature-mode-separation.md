# Creature Mode Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate ordinary fish, rays, and sharks into explicit top-level creature modes so presets, rig creation, editor controls, archetypes, overlays, and future species-specific behavior do not bleed into each other.

**Architecture:** Add a small mode registry and rig factory as the single source of truth for `fish`, `ray`, and `shark`. `Main.gd` keeps one workbench UI, but delegates mode selection, preset filtering, rig creation, and editor capability checks to mode-aware helpers. `SharkRig` starts as a thin `FishRig` subclass so shark work is fully separated at the app and preset level without duplicating the whole fish renderer on day one, while shark-only gill slits are rendered outside the existing fish operculum path.

**Tech Stack:** Godot 4 GDScript, existing JSON presets, existing `tools/run_godot_cli_tests.ps1` Godot CLI runner.

---

## Context

- Current `Main.gd` loads all presets into one `OptionButton` through `PresetStore.load_all()`.
- Current rig selection is inline in `Main._load_preset`: `creature_type == "ray"` creates `RayRig`; every other type creates `FishRig`.
- Rays already have `RayRig.gd`, ray presets, ray camera, and ray parameters, but ray/fish UI controls still share one side panel and many mode checks are scattered as `_is_fish()` / `_is_ray()`.
- Sharks are not a real mode yet. Existing shark-like presets use `creature_type: "fish"`, `camera_preset: "shark_side_quarter"`, shark caudal shapes, and fish motion/body controls.
- `BodyProfile.split_parameters_into_profiles()` currently stores ray keys in fish presets when those keys exist in the parameter dictionary. That is one of the main sources of cross-mode pollution.

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
- Mode switching clears all children from inactive mode roots and sets inactive roots `visible = false`; the active root is `visible = true` and contains exactly one child named `ActiveRig`.
- Fish species archetypes remain fish-only. Hide or disable the archetype section outside fish mode.
- Shark mode uses `SharkRig` and shark presets, even if `SharkRig` initially inherits FishRig behavior.
- Ray mode uses `RayRig` and ray presets.
- Ordinary fish mode must not show ray-only parameters such as `disc_width`, `ray_disc_shape`, or `ray_tail_style`.
- Ray mode must not show fish-only fin/body controls that do not affect `RayRig`.
- Shark mode must not show ray-only controls. It may reuse fish body/head/fin controls where they directly affect `SharkRig`.
- Saving a user preset preserves the active `creature_type`.
- Normalization and profile splitting must stop writing irrelevant mode keys into saved presets.
- Existing fish/ray exports continue to work.

## Anatomy Basis

Research summary for shark/ray gill handling:

- NOAA Fisheries notes that most shark species have the usual five gill slits, while sixgill/sevengill cow sharks and frilled sharks are among the limited living exceptions with more than five gill slits. Source: [NOAA Fisheries, "Revealing the Unknowns of an Unusual Catch"](https://www.fisheries.noaa.gov/feature-story/revealing-unknowns-unusual-catch).
- Florida Museum's bluntnose sixgill shark profile lists six gill slits and explicitly contrasts that with most sharks having five. Source: [Florida Museum, Bluntnose Sixgill Shark](https://www.floridamuseum.ufl.edu/discover-fish/species-profiles/bluntnose-sixgill-shark/).
- Florida Museum's sharpnose sevengill shark profile says this exception has seven pairs of gill slits instead of the usual five. Source: [Florida Museum, Sharpnose Sevengill Shark](https://www.floridamuseum.ufl.edu/discover-fish/species-profiles/sharpnose-sevengill-shark/).
- UCMP Berkeley describes elasmobranchs, including sharks, skates, and rays, as having separate slitlike gill openings; that supports separating shark/ray external gill slits from fish-style operculum/gill-cover controls. Source: [UCMP Berkeley, Systematics of the Chondrichthyes](https://ucmp.berkeley.edu/vertebrates/basalfish/chondrosy.html).
- Britannica groups sharks with rays and skates in Elasmobranchii and describes shark gill clefts on each side of the head. Source: [Britannica, Shark](https://www.britannica.com/animal/shark).
- Manta Trust's reef manta guide describes ventral markings around branchial gill slits, which supports treating ray gills as a ventral ray-specific renderer instead of sharing shark lateral gill controls. Source: [Manta Trust, Reef Manta Ray](https://www.mantatrust.org/mobula-alfredi).

Implementation conclusions:

- Shark mode default gill anatomy is `shark_gill_slit_count = 5`.
- Shark rendering shows five dark external slits on the lateral head/body area, drawn as vertical or slightly diagonal marks behind the head.
- Sixgill/sevengill support is not part of the first implementation, but the count slider/schema must allow future 6 or 7 slit presets without reusing fish operculum controls.
- Fish `gill_mark` and `operculum_*` remain fish-only. Shark and ray modes use external gill slit anatomy instead of the existing fish gill-cover path.
- Ray mode must not reuse fish `operculum_*`, and must not share the shark lateral five-slit renderer directly. Ray gills stay as a separate future ventral gill slit plan because ray/skate gill slits are displayed on the underside of a flattened disc body, not as shark-style lateral slits.

## Mode Slider Matrix

This matrix is the contract for which top-level mode owns which sliders. Implementation must encode these rules in a testable key schema instead of relying on loose category names.

### Shared by all modes

These controls may appear in fish, ray, and shark modes:

- Export/camera: `camera_*`, `orthographic_size`, `frame_count`, `frame_rate`, `padding_px`, `render_resolution`, `direction_count`.
- Basic playback and turn preview: `swim_speed` for fish/shark, `flap_speed` for ray, plus `turn_amount`, `turn_direction`, `turn_phase`, `turn_bank_roll`, `turn_tail_lag`, `turn_curve_bias`, and `turn_median_fin_bias`.
- Core color/material where supported by the rig: `base_color`, `secondary_color`, `outline_color`, `highlight_strength`, `shadow_strength`, `pattern_type`, `pattern_color`, `pattern_scale_x`, `pattern_scale_y`, `pattern_intensity`, `pattern_invert`, `pattern_seed`, `pattern_size_lock`, `wetness`.
- Reference image and UI-only values are stored on the preset, not exposed as creature-shape sliders.

### Ordinary Fish Mode (`fish`)

Fish mode keeps the teleost-style editor:

- Body: `body_length`, `body_height`, `body_width`, `shell_enabled`, `shell_expand`, `shell_color_mix`, `shell_opacity`, `shell_roundness`. `body_profile` remains stored rig/editor data and is handled by `BodyEditorPanel`, not as a generic `ParameterPanel` slider row.
- Head and mouth: `head_shape`, `head_size`, `head_offset`, `snout_*`, `forehead_slope`, `jaw_*`, `mouth_*`, `barbel_style`, `eye_*`.
- Existing operculum/gill-cover controls: `gill_mark`, `operculum_*`. These are fish-only because rays and sharks need different gill anatomy.
- Paired/median/caudal fins: `dorsal_*`, `anal_*`, `pectoral_*`, `pelvic_*`, `caudal_*`, `tail_length`, `tail_fin_size`, `caudal_shape`, `caudal_height_scale`.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `fin_softness`, `fin_rigidity`, slot softness/rigidity keys, `adipose_fin_*`, `finlet_*`.
- Fish motion: `swim_mode`, `global_sway_amount`, `body_wave_*`, `tail_sway_multiplier`, `tail_fin_extra_swing`, `fin_flap_amount`, `fin_yaw_follow_strength`, `median_fin_flap_*`, `inside_pectoral_fold`, `outside_pectoral_brace`.

Fish mode must not expose:

- Ray-only shape controls: `disc_*`, `wing_*`, `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `ray_locomotion_mode`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`.
- Shark-only gill controls: `shark_gill_*`.

### Ray Mode (`ray`)

Ray mode uses disc and wing controls, not fish body-fin anatomy:

- Disc/body: `disc_width`, `disc_length`, `disc_thickness`, `wing_width`, `wing_length`, `wing_curve`, `shell_roundness`. `body_profile` remains stored ray cross-section data and is handled by `BodyEditorPanel`, not as a generic `ParameterPanel` slider row.
- Ray head/tail: `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `cephalic_horns`.
- Ray eyes and underside: `eye_spacing`, `eye_size`, `base_color`, `underside_color`.
- Ray gills: keep as a separate future `ray_ventral_gill_slit_*` plan; do not show fish `operculum_*` and do not share shark lateral `shark_gill_*` controls.
- Ray locomotion: `ray_locomotion_mode`, `wave_ripples`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`, `pectoral_flap_sync`.
- Ray pelvic lobes: `pelvic_length`, `pelvic_height`. `RayRig` already reads these as pelvic lobe dimensions, so `CreatureParameterSchema.is_parameter_visible("ray", key)` must return `true` for both keys when they are present.

Ray mode must not expose:

- Existing fish operculum/gill-cover controls: `gill_mark`, `operculum_*`.
- Shark-only lateral gill controls: `shark_gill_*`.
- Fish fin slots and fish fin placement controls: `dorsal_1_*`, `dorsal_2_*`, `dorsal_fin_*`, `anal_*`, `anal_fin_*`, `pectoral_attach_t`, `pectoral_fin_*`, `pectoral_shape`, `caudal_shape`, `caudal_height_scale`.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `adipose_fin_*`, `finlet_*`.
- Fish swim presets: `swim_mode`, `body_wave_*`, `tail_fin_extra_swing`, `median_fin_flap_*`, `inside_pectoral_fold`, `outside_pectoral_brace`.

### Shark Mode (`shark`)

Shark mode starts on a `FishRig`-derived body but has its own cartilaginous-fish slider contract:

- Body: `body_length`, `body_height`, `body_width`, `shell_enabled`, `shell_expand`, `shell_color_mix`, `shell_opacity`, `shell_roundness`. `body_profile` remains stored rig/editor data and is handled by `BodyEditorPanel`, not as a generic `ParameterPanel` slider row.
- Shark head and mouth: `head_shape`, `head_size`, `head_offset`, `snout_*`, `forehead_slope`, `jaw_*`, `mouth_*`, `eye_*`.
- Shark gill slits: `shark_gill_slit_count`, `shark_gill_slit_length`, `shark_gill_slit_spacing`, `shark_gill_slit_angle`, `shark_gill_slit_depth`, `shark_gill_slit_position_x`, `shark_gill_slit_position_y`. The default count is `5`; the renderer draws dark vertical or slightly diagonal external slits on the lateral head/body surface instead of an operculum.
- Shark fins: `dorsal_1_*`, `dorsal_2_*`, `dorsal_fin_*`, `anal_*`, `pectoral_*`, `pelvic_*`, `tail_length`, `tail_fin_size`, `caudal_shape`, `caudal_height_scale`.
- Shark caudal shapes: `shark_heterocercal`, `thresher`, plus generic `pointed`, `lunate`, `forked_shallow`, and `forked_deep`.
- Shark motion: `swim_mode`, `global_sway_amount`, `body_wave_*`, `tail_sway_multiplier`, `tail_fin_extra_swing`, `fin_flap_amount`, `fin_yaw_follow_strength`, `turn_*`.

Shark mode must not expose:

- Existing fish operculum/gill-cover controls: `gill_mark`, `operculum_*`. Shark gill slits are owned by the `shark_gill_*` contract above.
- Teleost-only fin structures: `fin_ray_*`, `fin_spine_*`, `adipose_fin_*`, `finlet_*`.
- Ray-only disc/wing controls: `disc_*`, `wing_*`, `ray_head_shape`, `ray_disc_shape`, `ray_tail_style`, `ray_tail_spine_enabled`, `ray_dorsal_tail_fins`, `cephalic_horns`, `ray_locomotion_mode`, `flap_amplitude`, `flap_speed`, `wing_phase_offset`, `tail_follow_amount`, `glide_bob_amount`.
- Fish-only ornamentation that does not map to sharks: `barbel_style`, `adipose_fin_shape`, `finlet_shape`.

## File Structure

- Create `scripts/creature/CreatureMode.gd`: mode ids, default preset names, camera defaults, capability flags, and helper methods. UI labels stay in `UiText.gd`.
- Create `scripts/creature/CreatureRigFactory.gd`: create `FishRig`, `RayRig`, or `SharkRig` from a mode id.
- Create `scripts/creature/SharkRig.gd`: thin subclass of `FishRig` that normalizes `creature_type` to `shark` and owns shark-only lateral gill slit markings through `SharkRig` or a shark-only helper, without reusing the `FishRig` operculum mesh.
- Create `scripts/creature/SharkGillSlitMarking.gd`: shark-only helper that draws lateral gill slit mesh/marking nodes from `shark_gill_slit_*` parameters.
- Create `scenes/creatures/SharkRig.tscn`: scene wrapper for parity with existing `FishRig.tscn` and `RayRig.tscn`.
- Modify `scripts/presets/PresetStore.gd`: mode-filtered loading, default selection helpers, and stricter mode normalization.
- Modify `scripts/creature/BodyProfile.gd`: mode-aware profile splitting and parameter reconstruction.
- Create `scripts/creature/CreatureParameterSchema.gd`: explicit mode-key visibility schema, including shark-only `shark_gill_*` controls and fish/ray denial rules.
- Modify `scripts/ui/Main.gd`: add mode selector, mode roots, mode-aware rig loading, mode-aware editor capability checks, and per-mode last selection state.
- Modify `scripts/ui/ParameterPanel.gd`: add `creature_type` or `visible_keys` filtering so shared panels do not show irrelevant controls.
- Modify `scripts/ui/FinEditorPanel.gd`, `HeadEditorPanel.gd`, `BodyEditorPanel.gd`: add `set_creature_type(mode)` and use mode capabilities instead of hardcoded fish/ray assumptions.
- Modify `scripts/ui/UiText.gd`: labels for mode selector, shark mode, `basic_shark`, and shark gill slit parameters.
- Modify `presets/장.json`: migrate to `creature_type: "shark"` and `type: "shark"`.
- Add `presets/basic_shark.json`: compact built-in shark preset used as the default shark mode preset.
- Add tests: `CreatureModeRegistryTest`, `PresetStoreModeFilterTest`, `MainCreatureModeTest`, `ParameterModeVisibilityTest`, `SharkGillSlitRenderingTest`, and extend `PresetNormalizationTest` / `RigImmediateRebuildTest`.

---

### Task 1: Add Creature Mode Registry and Rig Factory

**Files:**
- Create: `scripts/creature/CreatureMode.gd`
- Create: `scripts/creature/CreatureRigFactory.gd`
- Create: `scripts/creature/SharkRig.gd`
- Create: `scenes/creatures/SharkRig.tscn`
- Modify: `scripts/ui/UiText.gd`
- Create: `scripts/tools/CreatureModeRegistryTest.gd`
- Create: `scenes/CreatureModeRegistryTest.tscn`

- [ ] **Step 1: Write the failing registry test**

`CreatureModeRegistryTest.gd` should assert:

```gdscript
extends Node

const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const CreatureRigFactoryScript := preload("res://scripts/creature/CreatureRigFactory.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const RayRigScript := preload("res://scripts/creature/RayRig.gd")
const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	assert(CreatureModeScript.mode_ids() == ["fish", "ray", "shark"])
	assert(CreatureModeScript.normalize("unknown") == "fish")
	assert(UiText.creature_type("shark") == "상어")
	assert(CreatureModeScript.default_camera("ray") == "ray_top_quarter")
	assert(CreatureModeScript.default_camera("shark") == "shark_side_quarter")
	assert(CreatureModeScript.supports_archetypes("fish"))
	assert(not CreatureModeScript.supports_archetypes("ray"))
	assert(not CreatureModeScript.supports_archetypes("shark"))
	assert(CreatureRigFactoryScript.create("fish").get_script() == FishRigScript)
	assert(CreatureRigFactoryScript.create("ray").get_script() == RayRigScript)
	assert(CreatureRigFactoryScript.create("shark").get_script() == SharkRigScript)
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
		"default_camera": "aquarium_side_quarter",
		"default_preset": "basic_fish",
		"supports_archetypes": true,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	},
	"ray": {
		"default_camera": "ray_top_quarter",
		"default_preset": "basic_ray",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": false,
		"supports_body_ring_editor": true
	},
	"shark": {
		"default_camera": "shark_side_quarter",
		"default_preset": "basic_shark",
		"supports_archetypes": false,
		"supports_fish_drag_overlay": true,
		"supports_body_ring_editor": true
	}
}
```

Add `mode_ids()`, `normalize(value)`, `default_camera(mode)`, `default_preset(mode)`, `supports_archetypes(mode)`, `supports_fish_drag_overlay(mode)`, and `supports_body_ring_editor(mode)`. Do not duplicate mode labels here; `UiText.creature_type(mode)` is the label source. `normalize(value)` returns `"fish"` for unknown values, but must call `push_warning("Unknown creature mode: %s" % value)` before falling back when `value` is not empty.

- [ ] **Step 4: Update `UiText.gd` mode labels**

Add shark labels to the existing dictionaries:

```gdscript
const PRESET_NAMES := {
	...
	"basic_shark": "기본 상어"
}

const CREATURE_TYPES := {
	"fish": "물고기",
	"ray": "가오리",
	"shark": "상어"
}
```

- [ ] **Step 5: Implement `SharkRig.gd` shell**

Use inheritance, not copy-paste:

```gdscript
class_name SharkRig
extends FishRig

func set_parameters(new_parameters: Dictionary) -> void:
	var shark_parameters := new_parameters.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	for key in shark_parameters.keys():
		var text_key := String(key)
		if text_key == "gill_mark" or text_key.begins_with("operculum_"):
			shark_parameters.erase(key)
	super.set_parameters(shark_parameters)
```

This shell strips fish `gill_mark` / `operculum_*` keys before calling `FishRig`; Task 5 adds shark-specific gill rendering through `SharkRig` and a helper loaded only by `SharkRig`.

- [ ] **Step 6: Implement `CreatureRigFactory.gd`**

Return the right node for each normalized mode. Unknown values return fish.

- [ ] **Step 7: Add `SharkRig.tscn`**

Mirror the existing creature rig scenes:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/creature/SharkRig.gd" id="1_shark"]

[node name="SharkRig" type="Node3D"]
script = ExtResource("1_shark")
```

- [ ] **Step 8: Verify**

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

Add `const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")` at the top of `PresetStore.gd`. Change signature to `static func load_all(creature_type: String = "") -> Array[Dictionary]`. Normalize each loaded preset, then include it only when `creature_type == ""` or `preset.creature_type == CreatureModeScript.normalize(creature_type)`.

- [ ] **Step 4: Add `find_default_for_mode(mode)`**

Return the preset whose `name` matches `CreatureModeScript.default_preset(mode)`. If missing, return the first preset in `load_all(mode)`.

- [ ] **Step 5: Normalize mode fields**

In `normalize_preset`, set both:

```gdscript
var mode := CreatureModeScript.normalize(String(normalized.get("creature_type", normalized.get("type", "fish"))))
normalized["creature_type"] = mode
normalized["type"] = mode
```

Use this `mode` for fish/ray/shark-specific normalization. Do not prune cross-mode parameter keys in Task 2, because the explicit `CreatureParameterSchema` does not exist until Task 4. The intentional interim behavior is: mode filtering prevents wrong presets from appearing, panel filtering later hides irrelevant keys, and Task 6 adds in-memory pruning for already polluted preset data.

- [ ] **Step 6: Migrate shark built-ins**

Update `presets/장.json` top-level `creature_type` and `type` to `"shark"`. Add `presets/basic_shark.json` using the same core shark silhouette parameters but a clear `name: "basic_shark"`, `creature_type: "shark"`, `type: "shark"`, `camera_preset: "shark_side_quarter"`, shark-tail-friendly defaults, and these shark gill defaults inside the preset parameter dictionary:

```json
"shark_gill_slit_count": 5,
"shark_gill_slit_length": 0.22,
"shark_gill_slit_spacing": 0.055,
"shark_gill_slit_angle": -8.0,
"shark_gill_slit_depth": 0.65,
"shark_gill_slit_position_x": -0.28,
"shark_gill_slit_position_y": 0.08
```

- [ ] **Step 7: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetStoreModeFilterTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

Expected: both pass.

---

### Task 3: Mode Selector, Separate Mode Roots, and Rig Lifecycle

**Files:**
- Modify: `scripts/ui/Main.gd`
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
assert((main.get("current_rig") as Node).get_script() == RayRigScript)
assert(_only_mode_root_visible(main, "RayModeRoot"))
main.call("_select_creature_mode", "shark")
await get_tree().process_frame
assert(String(main.get("active_creature_mode")) == "shark")
assert((main.get("current_rig") as Node).get_script() == SharkRigScript)
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
const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")
const CreatureRigFactoryScript := preload("res://scripts/creature/CreatureRigFactory.gd")

var active_creature_mode := CreatureModeScript.FISH
var creature_mode_option: OptionButton
var mode_roots := {}
var last_preset_path_by_mode := {}
var last_session_preset_by_mode := {}
```

- [ ] **Step 4: Build mode selector UI**

Place an `OptionButton` above or beside the preset dropdown. Add three items with metadata `fish`, `ray`, `shark`. Keep `_select_creature_mode(mode: String) -> void` as the string-based API used by tests, and connect the `OptionButton.item_selected(int)` signal through an index-to-metadata lambda:

```gdscript
creature_mode_option.item_selected.connect(func(index: int) -> void:
	var mode := String(creature_mode_option.get_item_metadata(index))
	_select_creature_mode(mode)
)
```

- [ ] **Step 5: Create separate mode roots**

In `_build_preview_world`, after `world_root` is created, add three child `Node3D`s named `FishModeRoot`, `RayModeRoot`, and `SharkModeRoot`. Store them in `mode_roots`.

`_only_mode_root_visible(main, active_root_name)` in `MainCreatureModeTest.gd` must assert all of the following:

```gdscript
func _only_mode_root_visible(main: Node, active_root_name: String) -> bool:
	var roots: Dictionary = main.get("mode_roots")
	for mode in roots.keys():
		var root := roots[mode] as Node3D
		var should_be_active := root.name == active_root_name
		if root.visible != should_be_active:
			return false
		if should_be_active and root.get_child_count() != 1:
			return false
		if should_be_active and root.get_child(0).name != "ActiveRig":
			return false
		if not should_be_active and root.get_child_count() != 0:
			return false
	return true
```

- [ ] **Step 6: Replace inline rig construction**

In `_load_preset`, use:

```gdscript
var creature_type := CreatureModeScript.normalize(String(current_preset.get("creature_type", active_creature_mode)))
active_creature_mode = creature_type
current_rig = CreatureRigFactoryScript.create(creature_type)
current_rig.name = "ActiveRig"
mode_roots[creature_type].add_child(current_rig)
```

Call `_set_active_mode_root(creature_type)` before adding the rig. `_set_active_mode_root(mode)` must remove and `queue_free()` children from all mode roots, then set only the selected root `visible = true`; all other roots are `visible = false`.

- [ ] **Step 7: Implement `_select_creature_mode(mode: String)`**

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
- Modify: `scripts/ui/UiText.gd`
- Create: `scripts/creature/CreatureParameterSchema.gd`
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
	"shark_gill_slit_count": 5,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(fish_panel, "body_length") != null)
assert(_find_slider_for_key(fish_panel, "disc_width") == null)
assert(_find_option_for_key(fish_panel, "ray_disc_shape") == null)
assert(_find_option_for_key(fish_panel, "gill_mark") != null)
assert(_find_slider_for_key(fish_panel, "operculum_size") != null)
assert(_find_slider_for_key(fish_panel, "shark_gill_slit_count") == null)
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
	"shark_gill_slit_count": 5,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(ray_panel, "disc_width") != null)
assert(_find_option_for_key(ray_panel, "ray_disc_shape") != null)
assert(_find_option_for_key(ray_panel, "swim_mode") == null)
assert(_find_option_for_key(ray_panel, "gill_mark") == null)
assert(_find_slider_for_key(ray_panel, "operculum_size") == null)
assert(_find_slider_for_key(ray_panel, "shark_gill_slit_count") == null)
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
	"shark_gill_slit_count": 5,
	"shark_gill_slit_length": 0.22,
	"shark_gill_slit_spacing": 0.055,
	"shark_gill_slit_angle": -8.0,
	"shark_gill_slit_depth": 0.65,
	"shark_gill_slit_position_x": -0.28,
	"shark_gill_slit_position_y": 0.08,
	"fin_ray_count": 12.0,
	"adipose_fin_enabled": true,
	"finlet_enabled": true
})
assert(_find_slider_for_key(shark_panel, "body_length") != null)
assert(_find_option_for_key(shark_panel, "ray_disc_shape") == null)
assert(_find_option_for_key(shark_panel, "caudal_shape") != null)
assert(_find_option_for_key(shark_panel, "gill_mark") == null)
assert(_find_slider_for_key(shark_panel, "operculum_size") == null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_count") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_length") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_spacing") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_angle") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_depth") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_position_x") != null)
assert(_find_slider_for_key(shark_panel, "shark_gill_slit_position_y") != null)
assert(_find_slider_for_key(shark_panel, "fin_ray_count") == null)
assert(_find_checkbox_for_key(shark_panel, "adipose_fin_enabled") == null)
assert(_find_checkbox_for_key(shark_panel, "finlet_enabled") == null)
```

The test file must define `_find_slider_for_key(panel, key)`, `_find_option_for_key(panel, key)`, and `_find_checkbox_for_key(panel, key)` by reading `panel.sliders` and `panel.option_buttons` directly. This keeps the test keyed to parameter ids and avoids brittle assumptions about row child order:

```gdscript
func _find_slider_for_key(panel: Control, key: String) -> HSlider:
	var sliders: Dictionary = panel.get("sliders")
	return sliders.get(key, null) as HSlider

func _find_option_for_key(panel: Control, key: String) -> OptionButton:
	var option_buttons: Dictionary = panel.get("option_buttons")
	return option_buttons.get(key, null) as OptionButton

func _find_checkbox_for_key(panel: Control, key: String) -> CheckBox:
	var sliders: Dictionary = panel.get("sliders")
	return sliders.get(key, null) as CheckBox
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest`

Expected: fail because `ParameterPanel` does not have mode filtering.

- [ ] **Step 3: Add mode filtering API**

In `ParameterPanel.gd`, add `var creature_type := "fish"` and `func set_creature_type(mode: String) -> void`. Rebuild controls when mode changes, and skip any row where `CreatureParameterSchema.is_parameter_visible(creature_type, key)` returns `false`.

- [ ] **Step 4: Encode the mode slider matrix**

Add the mode schema dictionary in `scripts/creature/CreatureParameterSchema.gd`. It must expose:

```gdscript
static func is_parameter_visible(mode: String, key: String) -> bool
static func is_option_value_visible(mode: String, key: String, value: String) -> bool
static func allowed_fin_slots(mode: String) -> Array[String]
```

The functions must implement the full `Mode Slider Matrix` above. Do not infer visibility only by category text; use explicit key groups and prefix checks so ray keys cannot leak into fish/shark panels, shark `shark_gill_*` keys cannot leak into fish/ray panels, and fish operculum/fin-ray/adipose/finlet controls cannot leak into ray or shark panels. Shark mode must allow exactly the shark gill keys listed in the matrix and use `shark_gill_slit_count = 5` as the default baseline.

- [ ] **Step 5: Add shark gill UI labels**

Add labels in `UiText.PARAMETER_LABELS`:

```gdscript
"shark_gill_slit_count": "상어 아가미틈 수",
"shark_gill_slit_length": "상어 아가미틈 길이",
"shark_gill_slit_spacing": "상어 아가미틈 간격",
"shark_gill_slit_angle": "상어 아가미틈 각도",
"shark_gill_slit_depth": "상어 아가미틈 진하기",
"shark_gill_slit_position_x": "상어 아가미틈 X 위치",
"shark_gill_slit_position_y": "상어 아가미틈 Y 위치",
```

- [ ] **Step 6: Filter option values by mode**

For `caudal_shape`, fish may show all existing fish caudal shapes. Shark may show only `shark_heterocercal`, `thresher`, `pointed`, `lunate`, `forked_shallow`, and `forked_deep`. Ray must not show `caudal_shape` at all.

- [ ] **Step 7: Main capability routing**

Replace `_is_fish()` and `_is_ray()` checks where possible with:

```gdscript
func _current_mode() -> String:
	return CreatureModeScript.normalize(active_creature_mode)
```

Use `CreatureModeScript.supports_archetypes`, `CreatureModeScript.supports_fish_drag_overlay`, and `CreatureModeScript.supports_body_ring_editor` to enable/disable sections and overlays.

- [ ] **Step 8: Hide fish-only archetypes outside fish mode**

When active mode is not fish, set the archetype controls container invisible and clear any pending archetype selection. `_apply_selected_archetype` must no-op unless the active mode supports archetypes.

- [ ] **Step 9: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterPanelCategoryTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinEditorPanelTest`

Expected: all pass.

---

### Task 5: Shark Gill Slit Rendering

**Files:**
- Modify: `scripts/creature/SharkRig.gd`
- Create: `scripts/creature/SharkGillSlitMarking.gd`
- Create: `scripts/tools/SharkGillSlitRenderingTest.gd`
- Create: `scenes/SharkGillSlitRenderingTest.tscn`

- [ ] **Step 1: Write failing shark gill rendering test**

`SharkGillSlitRenderingTest.gd` should assert that shark gill sliders produce visible shark-only nodes:

```gdscript
extends Node

const SharkRigScript := preload("res://scripts/creature/SharkRig.gd")

func _ready() -> void:
	var shark := SharkRigScript.new()
	add_child(shark)
	var parameters := {
		"creature_type": "shark",
		"body_length": 5.8,
		"body_height": 0.72,
		"body_width": 0.42,
		"head_size": 0.62,
		"head_offset": -0.58,
		"shark_gill_slit_count": 5,
		"shark_gill_slit_length": 0.22,
		"shark_gill_slit_spacing": 0.055,
		"shark_gill_slit_angle": -8.0,
		"shark_gill_slit_depth": 0.65,
		"shark_gill_slit_position_x": -0.28,
		"shark_gill_slit_position_y": 0.08,
		"gill_mark": "operculum",
		"operculum_size": 1.0
	}
	shark.set_parameters(parameters)
	await get_tree().process_frame
	var root := shark.get_node_or_null("BodyPivot/SharkGillSlits")
	assert(root != null)
	assert(_slit_nodes(root).size() == 5)
	assert(shark.get_node_or_null("BodyPivot/GillMark_operculum") == null)
	for slit in _slit_nodes(root):
		assert(slit is MeshInstance3D)
		assert(String(slit.name).begins_with("SharkGillSlit"))

	parameters["shark_gill_slit_count"] = 7
	parameters["shark_gill_slit_angle"] = -18.0
	parameters["shark_gill_slit_position_x"] = -0.18
	shark.set_parameters(parameters)
	await get_tree().process_frame
	root = shark.get_node_or_null("BodyPivot/SharkGillSlits")
	var slits := _slit_nodes(root)
	assert(slits.size() == 7)
	var first := slits[0] as Node3D
	assert(abs(first.rotation_degrees.z - -18.0) < 0.01)
	assert(abs(first.position.x - -0.18) < 0.001)
	print("SHARK_GILL_SLIT_RENDERING_TEST_OK")
	get_tree().quit(0)

func _slit_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	for child in root.get_children():
		if String(child.name).begins_with("SharkGillSlit"):
			result.append(child)
	return result
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkGillSlitRenderingTest`

Expected: fail because `SharkGillSlitMarking.gd` does not exist and `SharkRig` does not add `BodyPivot/SharkGillSlits`.

- [ ] **Step 3: Create `SharkGillSlitMarking.gd`**

Implement the helper as shark-only rendering code:

```gdscript
class_name SharkGillSlitMarking
extends RefCounted

static func rebuild(parent: Node3D, parameters: Dictionary) -> Node3D:
	var root := parent.get_node_or_null("SharkGillSlits") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "SharkGillSlits"
		parent.add_child(root)
	for child in root.get_children():
		child.free()

	var count := clampi(int(round(float(parameters.get("shark_gill_slit_count", 5)))), 1, 7)
	var length := maxf(float(parameters.get("shark_gill_slit_length", 0.22)), 0.01)
	var spacing := maxf(float(parameters.get("shark_gill_slit_spacing", 0.055)), 0.0)
	var angle := float(parameters.get("shark_gill_slit_angle", -8.0))
	var depth := clampf(float(parameters.get("shark_gill_slit_depth", 0.65)), 0.0, 1.0)
	var position_x := float(parameters.get("shark_gill_slit_position_x", -0.28))
	var position_y := float(parameters.get("shark_gill_slit_position_y", 0.08))
	var body_width := maxf(float(parameters.get("body_width", 0.42)), 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.025, 0.03, depth)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var center_offset := float(count - 1) * 0.5
	for index in range(count):
		var slit := MeshInstance3D.new()
		slit.name = "SharkGillSlit%d" % [index + 1]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.012, length, 0.018)
		slit.mesh = mesh
		slit.material_override = mat
		slit.position = Vector3(position_x, position_y + (float(index) - center_offset) * spacing, body_width * 0.52)
		slit.rotation_degrees.z = angle
		root.add_child(slit)
	return root
```

- [ ] **Step 4: Call helper from `SharkRig`**

Extend the shell without copying `FishRig` rendering:

```gdscript
class_name SharkRig
extends FishRig

const SharkGillSlitMarkingScript := preload("res://scripts/creature/SharkGillSlitMarking.gd")

func set_parameters(new_parameters: Dictionary) -> void:
	var shark_parameters := new_parameters.duplicate(true)
	shark_parameters["creature_type"] = "shark"
	for key in shark_parameters.keys():
		var text_key := String(key)
		if text_key == "gill_mark" or text_key.begins_with("operculum_"):
			shark_parameters.erase(key)
	super.set_parameters(shark_parameters)

func rebuild() -> void:
	super.rebuild()
	if body_pivot != null:
		SharkGillSlitMarkingScript.rebuild(body_pivot, parameters)
```

Do not call or reuse fish `gill_mark`, `operculum_*`, `_build_operculum_*`, or `OperculumRoot` code from this shark path.

- [ ] **Step 5: Verify**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkGillSlitRenderingTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest`

Expected: both pass. Shark mode now exposes seven shark gill sliders because they affect rendered `SharkGillSlits` nodes.

---

### Task 6: Mode-Aware Save/Normalize/Profile Split

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
	"ray_tail_style": "whip",
	"shark_gill_slit_count": 5
}, {"name": "fish_split_check", "creature_type": "fish"})
assert(not (fish_split.get("fin_profile", {}) as Dictionary).has("ray_disc_shape"))
assert(not (fish_split.get("tail_profile", {}) as Dictionary).has("ray_tail_style"))
assert(not (fish_split.get("parameters", {}) as Dictionary).has("shark_gill_slit_count"))

var shark_split := BodyProfileScript.split_parameters_into_profiles({
	"creature_type": "shark",
	"body_length": 5.8,
	"caudal_shape": "shark_heterocercal",
	"shark_gill_slit_count": 5,
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
assert(float((shark_split.get("parameters", {}) as Dictionary).get("shark_gill_slit_count", 0.0)) == 5.0)

var ray_split := BodyProfileScript.split_parameters_into_profiles({
	"creature_type": "ray",
	"disc_width": 1.2,
	"ray_disc_shape": "manta",
	"shark_gill_slit_count": 5,
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
assert(not (ray_split.get("parameters", {}) as Dictionary).has("shark_gill_slit_count"))
assert(String((ray_split.get("fin_profile", {}) as Dictionary).get("ray_disc_shape", "")) == "manta")

var polluted_loaded := PresetStoreScript.normalize_preset({
	"name": "polluted_fish_load_check",
	"creature_type": "fish",
	"type": "fish",
	"parameters": {
		"body_length": 1.4,
		"disc_width": 1.2,
		"ray_disc_shape": "manta",
		"shark_gill_slit_count": 5,
		"body_profile": {"rings": BodyProfileScript.default_fish_rings()}
	}
})
var loaded_params: Dictionary = polluted_loaded.get("parameters", {})
assert(loaded_params.has("body_profile"))
assert(not loaded_params.has("disc_width"))
assert(not loaded_params.has("ray_disc_shape"))
assert(not loaded_params.has("shark_gill_slit_count"))
```

- [ ] **Step 2: Run test and verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

Expected: fail because fish/shark split still keeps ray keys and `normalize_preset` does not yet prune polluted cross-mode keys from loaded preset copies.

- [ ] **Step 3: Split profile key lists by mode**

In `BodyProfile.gd`, add `const CreatureModeScript := preload("res://scripts/creature/CreatureMode.gd")` and extract arrays:

- `COMMON_GLOBAL_KEYS`
- `FISH_HEAD_FIN_KEYS`
- `FISH_TAIL_KEYS`
- `FISH_MOTION_KEYS`
- `RAY_BODY_KEYS`
- `RAY_FIN_KEYS`
- `RAY_TAIL_KEYS`
- `RAY_MOTION_KEYS`
- `SHARK_HEAD_FIN_KEYS`
- `SHARK_GILL_KEYS`
- `SHARK_TAIL_KEYS`
- `SHARK_MOTION_KEYS`
- `COMMON_VISUAL_KEYS`

Use the active mode to choose which arrays `_pick` uses. `SHARK_GILL_KEYS` contains the seven `shark_gill_slit_*` keys from the matrix and is selected only for shark mode.

- [ ] **Step 4: Preserve mode in saved presets**

At the end of `split_parameters_into_profiles`, set:

```gdscript
var mode := CreatureModeScript.normalize(String(parameters.get("creature_type", preset.get("creature_type", "fish"))))
updated["creature_type"] = mode
updated["type"] = mode
normalized_parameters["creature_type"] = mode
updated["parameters"] = normalized_parameters
```

- [ ] **Step 5: Prune polluted loaded preset copies**

In `PresetStore.normalize_preset`, after mode normalization and parameter reconstruction, remove cross-mode keys from the returned dictionary's `parameters`, `fin_profile`, `tail_profile`, and `motion_profile`. This must sanitize the in-memory copy only; do not rewrite the JSON file during load. Preserve valid non-slider data such as `body_profile`, `marking_layers`, `export_settings`, `display_target_size`, and `reference_image`.

Use the same mode key arrays as `BodyProfile.split_parameters_into_profiles` so load and save agree. The decision is:

- Existing polluted fish presets load without ray/shark shape keys.
- Existing polluted ray presets load without fish operculum, fish fin-ray/adipose/finlet, or shark lateral gill keys.
- Existing polluted shark presets load without ray keys or fish `gill_mark` / `operculum_*`, but keep `shark_gill_slit_*`.

- [ ] **Step 6: Verify user save tests**

Run:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UserPresetStoreTest`

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UserPresetMainTest`

Expected: all pass.

---

### Task 7: Export and End-to-End Mode Smoke Tests

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
5. `Render shark gill slits`
6. `Split preset profiles by creature mode`
7. `Add end-to-end creature mode smoke coverage`

## Final Verification

Run the full Godot CLI suite:

`powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`

Expected: all tests pass. If the full suite is too slow during development, run it before the final commit or PR.
