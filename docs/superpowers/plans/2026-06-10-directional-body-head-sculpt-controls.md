# Directional Body and Head Sculpt Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent upper/lower body-ring width controls and directional flatness controls for body rings and fish heads.

**Implementation status (2026-06-10):** Implemented on branch `codex/directional-body-head-sculpt-controls` as a batched working-tree change. After clarification, body split width uses `top_width`/`bottom_width` instead of left/right width so fish remain bilaterally symmetric. The upper/lower width transition is blended across the side midline to avoid a vertical step. Pectoral fins use the side-midline average width, pelvic fins use ventral width, and operculum shell anchors sample the same blended vertical width. Focused regressions passed, and the full Godot CLI suite passed with `Godot CLI tests passed: 44`.

**Architecture:** Preserve the existing body ring model and extend each ring with optional split width and directional flatness fields. The shell mesh builder remains the single body geometry path, with new per-ring upper/lower z-radius shaping and flat-cap shaping. Head flatness uses the existing head sculpt pipeline by adding four neutral head parameters that are applied in `PrimitiveFactory.deformed_head_mesh` and surfaced in `HeadEditorPanel`.

**Tech Stack:** Godot 4 GDScript, existing Godot CLI test runner `tools/run_godot_cli_tests.ps1`, current editor panels under `scripts/ui`.

---

## Scope Contract

This plan implements sculpt controls only. It does not add texture painting, vertex brush editing, ray-disc flattening, export format changes, or new species archetype art direction.

The shipped behavior must satisfy these contracts:

- Legacy rings with only `width` render exactly as before.
- New ring fields are optional: `top_width`, `bottom_width`, `top_flatness`, `bottom_flatness`, `left_flatness`, and `right_flatness`.
- `top_width` applies to the upper/dorsal half of the selected body ring and expands/contracts both left and right sides equally.
- `bottom_width` applies to the lower/ventral half of the selected body ring and expands/contracts both left and right sides equally.
- Body width controls preserve left/right symmetry; no body-ring width field intentionally makes one side of the fish wider than the other.
- Existing `upper_height` and `lower_height` independence remains unchanged.
- Directional flatness values are `0.0..1.0`, default to `0.0`, and preserve the current silhouette when set to `0.0`.
- Body flatness is per ring, because body shape is already authored ring-by-ring.
- Head flatness is head-wide, using four parameters: `head_top_flatness`, `head_bottom_flatness`, `head_left_flatness`, and `head_right_flatness`.
- Existing `head_flattening`, `head_top_curve`, and `head_belly_curve` remain valid and keep their current meaning.
- Presets and user presets round-trip the new fields without requiring hand edits to JSON.

## Approach Decision

Recommended approach: extend the current ring and head sculpt parameters in place.

Alternative 1 was a custom cross-section point editor for each body/head ring. That would be more powerful, but it is too broad for the requested controls and would require a new authoring model.

Alternative 2 was only adding global `body_top_width` and `body_bottom_width`. That would solve upper/lower width for a whole fish, but it would not match the existing ring editor where height is already local per body station.

The selected approach is narrower: body controls stay per ring, head controls stay in the head editor, and legacy presets render unchanged.

---

## File Structure

- Modify `scripts/creature/BodyProfile.gd`: normalize and preserve split body-ring width and directional ring flatness.
- Modify `scripts/creature/FishRig.gd`: compute average z radius, upper/lower z-radius split, and per-ring flatness profiles; pass them to the shell mesh builder and bent-shell updater; use the ventral z radius for pelvic fin spacing.
- Modify `scripts/creature/PrimitiveFactory.gd`: extend fish shell mesh construction with upper/lower z radii and directional flat-cap shaping; apply head directional flatness in `deformed_head_mesh`.
- Modify `scripts/creature/HeadProfile.gd`: add a shared helper for directional flat-cap shaping so head and body use the same falloff behavior.
- Modify `scripts/ui/BodyEditorPanel.gd`: expose split width and body flatness sliders; keep `width` as a symmetric width shortcut.
- Modify `scripts/ui/HeadEditorPanel.gd`: expose four head flatness sliders in a dedicated section.
- Modify `scripts/ui/UiText.gd`: add Korean labels for new ring and head controls.
- Modify `scripts/tools/BodyEditorPanelTest.gd`: cover emitted split width and flatness values.
- Modify `scripts/tools/HeadEditorPanelTest.gd`: cover new head flatness sliders and clamping.
- Add `scripts/tools/RingWidthFlatnessTest.gd`: focused geometry regression test for split width and body directional flatness.
- Add `scenes/RingWidthFlatnessTest.tscn`: test scene for the new script.
- Modify `scripts/tools/HeadEditorModelTest.gd`: focused geometry assertions for head directional flatness.
- Modify `scripts/tools/HeadShellSeamTest.gd`: cover head directional flatness with the existing shell-envelope regression.
- Modify `scripts/tools/PresetNormalizationTest.gd`: verify new head flatness parameters round-trip through structured presets.

---

### Task 1: Extend Body Ring Data Contract

**Files:**
- Modify: `scripts/creature/BodyProfile.gd`
- Test: `scripts/tools/RingWidthFlatnessTest.gd`
- Test: `scenes/RingWidthFlatnessTest.tscn`

- [ ] **Step 1: Add the focused failing test script**

Create `scripts/tools/RingWidthFlatnessTest.gd`:

```gdscript
extends Node

const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

const RING := 3
const SEG := 28

func _ring_sample(fish: Node, segment_index: int) -> Vector3:
	var shell := fish.get_node_or_null("BodyPivot/OuterShell") as MeshInstance3D
	assert(shell != null)
	var verts: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var base := RING * (SEG + 1)
	return verts[base + segment_index]

func _shape_span(fish: Node) -> Dictionary:
	return {
		"right_mid": _ring_sample(fish, 0).z,
		"top": _ring_sample(fish, int(SEG / 4)).y,
		"left_mid": _ring_sample(fish, int(SEG / 2)).z,
		"bottom": _ring_sample(fish, int(3 * SEG / 4)).y,
		"upper_right": _ring_sample(fish, int(SEG / 8)),
		"upper_left": _ring_sample(fish, int(3 * SEG / 8)),
		"lower_left": _ring_sample(fish, int(5 * SEG / 8)),
		"lower_right": _ring_sample(fish, int(7 * SEG / 8)),
	}

func _mutate_ring(fish: Node, updates: Dictionary) -> void:
	var rings: Array = fish.parameters["body_profile"]["rings"]
	var ring: Dictionary = rings[RING].duplicate(true)
	for key in updates.keys():
		ring[key] = updates[key]
	rings[RING] = ring
	fish.parameters["body_profile"]["rings"] = rings
	fish.set_parameters(fish.parameters)

func _ready() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	var params := {"shell_enabled": 1.0, "pelvic_enabled": 1.0}
	params["body_profile"] = BodyProfileScript.ensure_body_profile({})
	fish.set_parameters(params)
	await get_tree().process_frame

	var neutral := _shape_span(fish)

	_mutate_ring(fish, {"top_width": 0.72})
	await get_tree().process_frame
	var wide_top := _shape_span(fish)
	assert(wide_top["upper_right"].z > neutral["upper_right"].z + 0.04)
	assert(wide_top["upper_left"].z < neutral["upper_left"].z - 0.04)
	assert(absf(wide_top["lower_right"].z - neutral["lower_right"].z) < 0.0005)
	assert(absf(wide_top["lower_left"].z - neutral["lower_left"].z) < 0.0005)

	fish.set_parameters(params)
	await get_tree().process_frame
	_mutate_ring(fish, {"bottom_width": 0.72})
	await get_tree().process_frame
	var wide_bottom := _shape_span(fish)
	assert(wide_bottom["lower_right"].z > neutral["lower_right"].z + 0.04)
	assert(wide_bottom["lower_left"].z < neutral["lower_left"].z - 0.04)
	assert(absf(wide_bottom["upper_right"].z - neutral["upper_right"].z) < 0.0005)
	assert(absf(wide_bottom["upper_left"].z - neutral["upper_left"].z) < 0.0005)

	fish.set_parameters(params)
	await get_tree().process_frame
	_mutate_ring(fish, {"top_flatness": 1.0})
	await get_tree().process_frame
	var flat_top := _shape_span(fish)
	assert(flat_top["upper_right"].y > neutral["upper_right"].y + 0.01)
	assert(flat_top["upper_left"].y > neutral["upper_left"].y + 0.01)
	assert(absf(flat_top["bottom"] - neutral["bottom"]) < 0.0005)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/ring_width_flatness.ok", FileAccess.WRITE)
	file.store_string("body ring upper/lower width and directional flatness applied")
	file.close()
	print("RING_WIDTH_FLATNESS_TEST_OK")
	get_tree().quit(0)
```

- [ ] **Step 2: Add the test scene**

Create `scenes/RingWidthFlatnessTest.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tools/RingWidthFlatnessTest.gd" id="1_ring_width_flatness"]

[node name="RingWidthFlatnessTest" type="Node"]
script = ExtResource("1_ring_width_flatness")
```

- [ ] **Step 3: Run the focused test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingWidthFlatnessTest
```

Expected: fail because `bottom_width`, `top_width`, and `top_flatness` do not affect the shell yet.

- [ ] **Step 4: Extend ring normalization**

In `scripts/creature/BodyProfile.gd`, update ring defaults without rewriting the preset row arrays:

```gdscript
const RING_KEYS := [
	"x", "y_offset",
	"upper_height", "lower_height",
	"width", "top_width", "bottom_width",
	"top_flatness", "bottom_flatness", "left_flatness", "right_flatness",
	"roundness", "sway_weight"
]
const RING_EXTRA_DEFAULTS := {
	"top_flatness": 0.0,
	"bottom_flatness": 0.0,
	"left_flatness": 0.0,
	"right_flatness": 0.0,
}
```

Then replace the numeric-copy block in `normalize_ring` with this pattern:

```gdscript
var legacy_width := float(raw_ring.get("width", defaults.get("width", 0.5)))
for key in RING_KEYS:
	var fallback: float = float(defaults.get(key, RING_EXTRA_DEFAULTS.get(key, 0.0)))
	if key == "top_width" or key == "bottom_width":
		fallback = legacy_width
	ring[key] = float(raw_ring.get(key, fallback))
ring["x"] = clampf(float(ring["x"]), 0.0, 1.0)
ring["upper_height"] = maxf(float(ring["upper_height"]), 0.01)
ring["lower_height"] = maxf(float(ring["lower_height"]), 0.01)
ring["top_width"] = maxf(float(ring["top_width"]), 0.01)
ring["bottom_width"] = maxf(float(ring["bottom_width"]), 0.01)
ring["width"] = (float(ring["top_width"]) + float(ring["bottom_width"])) * 0.5
ring["top_flatness"] = clampf(float(ring["top_flatness"]), 0.0, 1.0)
ring["bottom_flatness"] = clampf(float(ring["bottom_flatness"]), 0.0, 1.0)
ring["left_flatness"] = clampf(float(ring["left_flatness"]), 0.0, 1.0)
ring["right_flatness"] = clampf(float(ring["right_flatness"]), 0.0, 1.0)
ring["roundness"] = clampf(float(ring["roundness"]), 0.0, 1.0)
ring["sway_weight"] = clampf(float(ring["sway_weight"]), 0.0, 1.5)
```

In `_rings`, inject split width and flatness after creating each dictionary:

```gdscript
var ring := {
	"id": row[0],
	"label": row[1],
	"x": row[2],
	"y_offset": row[3],
	"upper_height": row[4],
	"lower_height": row[5],
	"width": row[6],
	"roundness": row[7],
	"sway_weight": row[8]
}
ring["top_width"] = ring["width"]
ring["bottom_width"] = ring["width"]
ring["top_flatness"] = 0.0
ring["bottom_flatness"] = 0.0
ring["left_flatness"] = 0.0
ring["right_flatness"] = 0.0
rings.append(ring)
```

In `sample_rings`, interpolate the new fields alongside `width`:

```gdscript
"width": lerpf(float(r1.get("width", 0.5)), float(r2.get("width", 0.5)), t),
"top_width": lerpf(float(r1.get("top_width", r1.get("width", 0.5))), float(r2.get("top_width", r2.get("width", 0.5))), t),
"bottom_width": lerpf(float(r1.get("bottom_width", r1.get("width", 0.5))), float(r2.get("bottom_width", r2.get("width", 0.5))), t),
"top_flatness": lerpf(float(r1.get("top_flatness", 0.0)), float(r2.get("top_flatness", 0.0)), t),
"bottom_flatness": lerpf(float(r1.get("bottom_flatness", 0.0)), float(r2.get("bottom_flatness", 0.0)), t),
"left_flatness": lerpf(float(r1.get("left_flatness", 0.0)), float(r2.get("left_flatness", 0.0)), t),
"right_flatness": lerpf(float(r1.get("right_flatness", 0.0)), float(r2.get("right_flatness", 0.0)), t),
```

- [ ] **Step 5: Run the focused test and confirm the same geometry failure remains**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingWidthFlatnessTest
```

Expected: fail because normalization now preserves fields, but mesh generation has not consumed them.

- [ ] **Step 6: Commit the data contract and failing test**

```powershell
git add scripts/creature/BodyProfile.gd scripts/tools/RingWidthFlatnessTest.gd scenes/RingWidthFlatnessTest.tscn
if (Test-Path scripts/tools/RingWidthFlatnessTest.gd.uid) { git add scripts/tools/RingWidthFlatnessTest.gd.uid }
if (Test-Path scenes/RingWidthFlatnessTest.tscn.uid) { git add scenes/RingWidthFlatnessTest.tscn.uid }
git commit -m "Add directional body ring sculpt contract"
```

---

### Task 2: Apply Split Width and Flatness to Body Shell Geometry

**Files:**
- Modify: `scripts/creature/FishRig.gd`
- Modify: `scripts/creature/PrimitiveFactory.gd`
- Test: `scripts/tools/RingWidthFlatnessTest.gd`

- [ ] **Step 1: Add shell state arrays in `FishRig.gd`**

Near `shell_radius_half_diff`, add:

```gdscript
var shell_radius_z_half_diff: Array[float] = []
var shell_flatness_profiles: Array[Vector4] = []
```

Clear both arrays in `rebuild()` and `_build_shell_profile_from_rings()` together with the existing shell arrays:

```gdscript
shell_radius_z_half_diff = []
shell_flatness_profiles = []
```

- [ ] **Step 2: Compute split z radius and flatness profiles from normalized rings**

In `_build_shell_profile_from_rings`, replace the single-width radius calculation with:

```gdscript
var width_scale := lerpf(0.62, 1.0, float(ring["roundness"]))
var shell_z_expand := shell_expand * lerpf(1.0, 0.18, float(ring["x"]))
var top_width := float(ring.get("top_width", ring["width"]))
var bottom_width := float(ring.get("bottom_width", ring["width"]))
var average_width := (top_width + bottom_width) * 0.5
var radius_z := body_width * body_z_scale * average_width * width_scale + shell_z_expand
var radius_z_top := body_width * body_z_scale * top_width * width_scale + shell_z_expand
var radius_z_bottom := body_width * body_z_scale * bottom_width * width_scale + shell_z_expand
```

After `_apply_head_shell_metrics`, keep the head/body blended average radius but preserve split upper/lower intent:

```gdscript
var adjusted_top := _apply_head_shell_metrics(ring, radius_y, radius_z_top, head_shell)
var adjusted_bottom := _apply_head_shell_metrics(ring, radius_y, radius_z_bottom, head_shell)
var adjusted_top_z := float(adjusted_top["radius_z"])
var adjusted_bottom_z := float(adjusted_bottom["radius_z"])
radius_z = (adjusted_top_z + adjusted_bottom_z) * 0.5
var radius_z_half := (adjusted_top_z - adjusted_bottom_z) * 0.5
shell_radius_z_half_diff.append(radius_z_half)
shell_flatness_profiles.append(Vector4(
	float(ring.get("top_flatness", 0.0)),
	float(ring.get("bottom_flatness", 0.0)),
	float(ring.get("left_flatness", 0.0)),
	float(ring.get("right_flatness", 0.0))
))
```

- [ ] **Step 3: Pass new arrays to shell construction and updates**

In `rebuild()`, update shell creation:

```gdscript
outer_shell = PF.fish_outer_shell(
	"OuterShell",
	shell_profile,
	body_mat,
	shell_segments,
	PackedFloat32Array(shell_center_y_offsets),
	PackedFloat32Array(shell_radius_half_diff),
	PackedFloat32Array(shell_radius_z_half_diff),
	shell_flatness_profiles
)
```

In `apply_pose`, update the bent-shell call:

```gdscript
PF.update_fish_outer_shell_bent(
	outer_shell,
	shell_profile,
	centers,
	yaws,
	shell_segments,
	PackedFloat32Array(shell_center_y_offsets),
	PackedFloat32Array(shell_radius_half_diff),
	PackedFloat32Array(shell_radius_z_half_diff),
	shell_flatness_profiles
)
```

- [ ] **Step 4: Extend PrimitiveFactory shell signatures**

In `scripts/creature/PrimitiveFactory.gd`, update the fish shell functions:

```gdscript
static func fish_outer_shell(
	name: String,
	profile: Array[Vector3],
	material: Material,
	segments: int = 28,
	center_y_offsets: PackedFloat32Array = PackedFloat32Array(),
	radius_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	flatness_profiles: Array[Vector4] = []
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, PackedVector3Array(), PackedFloat32Array(), center_y_offsets, radius_half_diffs, radius_z_half_diffs, flatness_profiles)
	node.material_override = material
	return node

static func update_fish_outer_shell_bent(
	node: MeshInstance3D,
	profile: Array[Vector3],
	centers: PackedVector3Array,
	yaw_degrees: PackedFloat32Array,
	segments: int = 28,
	center_y_offsets: PackedFloat32Array = PackedFloat32Array(),
	radius_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(),
	flatness_profiles: Array[Vector4] = []
) -> void:
	node.mesh = build_fish_outer_shell_mesh(profile, PackedFloat32Array(), segments, centers, yaw_degrees, center_y_offsets, radius_half_diffs, radius_z_half_diffs, flatness_profiles)
```

Keep `update_fish_outer_shell` backward-compatible by calling the builder with default arrays.

- [ ] **Step 5: Add a directional flatness helper**

In `PrimitiveFactory.gd`, add this helper near the shell builder:

```gdscript
static func _apply_flat_cap(value: float, radius: float, side_sign: float, amount: float) -> float:
	var flat := clampf(amount, 0.0, 1.0)
	if flat <= 0.0 or radius <= 0.001:
		return value
	var signed := value * side_sign
	if signed <= 0.0:
		return value
	var t := clampf(signed / radius, 0.0, 1.0)
	var weight := smoothstep(0.35, 1.0, t) * flat
	return lerpf(value, side_sign * radius, weight)
```

- [ ] **Step 6: Use split z radius and flatness in shell vertex generation**

Extend `build_fish_outer_shell_mesh` parameters:

```gdscript
radius_z_half_diffs: PackedFloat32Array = PackedFloat32Array(),
flatness_profiles: Array[Vector4] = []
```

Inside the ring loop, after `r_up` and `r_lo`:

```gdscript
var zd := radius_z_half_diffs[ring_index] if ring_index < radius_z_half_diffs.size() else 0.0
zd = clampf(zd, -point.z * 0.9, point.z * 0.9)
var r_z_top := maxf(point.z + zd, 0.001)
var r_z_bottom := maxf(point.z - zd, 0.001)
var flat := flatness_profiles[ring_index] if ring_index < flatness_profiles.size() else Vector4.ZERO
```

Inside the segment loop, replace the current `z` calculation with:

```gdscript
var upper_half := sin_a >= 0.0
var cos_a := cos(angle)
var r_y := r_up if upper_half else r_lo
var z_radius := lerpf(r_z_bottom, r_z_top, HeadProfile.vertical_half_blend(sin_a))
var y := (center_true_y - center.y) + sin_a * r_y
var z := cos_a * z_radius
y = _apply_flat_cap(y, point.y, 1.0, flat.x)
y = _apply_flat_cap(y, point.y, -1.0, flat.y)
z = _apply_flat_cap(z, z_radius, -1.0, flat.z)
z = _apply_flat_cap(z, z_radius, 1.0, flat.w)
var local_vertex := Vector3(0.0, y, z)
```

Update the local normal to use the selected upper/lower z radius:

```gdscript
var local_normal := Vector3(0.0, sin_a / maxf(r_y, 0.001), z / maxf(z_radius, 0.001)).normalized()
```

- [ ] **Step 7: Add ventral z-radius sampling for paired pelvic fin anchors**

In `scripts/creature/FishRig.gd`, add an interpolated helper beside `_sample_shell_profile`:

```gdscript
func _sample_shell_radius_z_half_diff(attach_t: float) -> float:
	if shell_radius_z_half_diff.is_empty():
		return 0.0
	var scaled := clampf(attach_t, 0.0, 1.0) * float(shell_radius_z_half_diff.size() - 1)
	var index := int(floor(scaled))
	var next_index := mini(index + 1, shell_radius_z_half_diff.size() - 1)
	var local_t := scaled - float(index)
	return lerpf(shell_radius_z_half_diff[index], shell_radius_z_half_diff[next_index], local_t)

func _surface_radius_z_for_vertical_half(attach_t: float, vertical_sign: float) -> float:
	return _surface_radius_z_for_vertical_fraction(attach_t, -1.0 if vertical_sign < 0.0 else 1.0)

func _surface_radius_z_for_vertical_fraction(attach_t: float, vertical_fraction: float) -> float:
	var sample := _sample_shell_profile(attach_t)
	var half_diff := _sample_shell_radius_z_half_diff(attach_t)
	var blend := HeadProfile.vertical_half_blend(vertical_fraction)
	return maxf(sample.z + half_diff * lerpf(-1.0, 1.0, blend), 0.001)
```

Update pelvic fin placement to use the ventral z radius while preserving left/right symmetry:

```gdscript
var pelvic_z := _surface_radius_z_for_vertical_half(pelvic_attach_t, -1.0) * 0.32
pelvic_l_base_position = pelvic_center + Vector3(0.0, 0.0, -pelvic_z)
pelvic_r_base_position = pelvic_center + Vector3(0.0, 0.0, pelvic_z)
```

Pectoral fins remain symmetric and use the average side radius:

```gdscript
var pectoral_z := _surface_radius_z(pectoral_attach_t) + shell_expand * 0.18
pectoral_l_base_position = Vector3(pectoral_center.x, -0.02, -pectoral_z)
pectoral_r_base_position = Vector3(pectoral_center.x, -0.02, pectoral_z)
```

Run `rg -n "_surface_radius_z\\(" scripts/creature/FishRig.gd` and update the duplicate rebuild/offset paths for pectoral and pelvic fins. Leave median fin callers alone because they anchor on the dorsal/ventral midline.

- [ ] **Step 8: Extend the geometry test to cover paired-fin anchors**

In `scripts/tools/RingWidthFlatnessTest.gd`, add a helper:

```gdscript
func _pelvic_positions(fish: Node) -> Dictionary:
	var left := fish.get_node_or_null("BodyPivot/PelvicFinL") as Node3D
	var right := fish.get_node_or_null("BodyPivot/PelvicFinR") as Node3D
	assert(left != null)
	assert(right != null)
	return {"left_z": left.position.z, "right_z": right.position.z}
```

Before the final success file write, add a body-wide split-width case so the pelvic attach station is definitely affected:

```gdscript
fish.set_parameters(params)
await get_tree().process_frame
var neutral_fins := _pelvic_positions(fish)
var rings: Array = fish.parameters["body_profile"]["rings"]
for i in rings.size():
	var ring: Dictionary = rings[i].duplicate(true)
	ring["bottom_width"] = float(ring.get("width", 0.34)) + 0.20
	ring["top_width"] = float(ring.get("width", 0.34))
	rings[i] = ring
fish.parameters["body_profile"]["rings"] = rings
fish.set_parameters(fish.parameters)
await get_tree().process_frame
var split_fins := _pelvic_positions(fish)
assert(split_fins["right_z"] > neutral_fins["right_z"] + 0.012)
assert(split_fins["left_z"] < neutral_fins["left_z"] - 0.012)
assert(absf(absf(split_fins["left_z"]) - absf(split_fins["right_z"])) < 0.002)
```

- [ ] **Step 9: Run the focused geometry test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingWidthFlatnessTest
```

Expected: pass and print `RING_WIDTH_FLATNESS_TEST_OK`.

- [ ] **Step 10: Run the existing height decoupling regression**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingHeightDecoupleTest
```

Expected: pass and print `RING_HEIGHT_DECOUPLE_TEST_OK`.

- [ ] **Step 11: Commit body shell geometry**

```bash
git add scripts/creature/FishRig.gd scripts/creature/PrimitiveFactory.gd scripts/tools/RingWidthFlatnessTest.gd
git commit -m "Apply directional body ring sculpting"
```

---

### Task 3: Expose Body Split Width and Flatness in the Body Editor

**Files:**
- Modify: `scripts/ui/BodyEditorPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Modify: `scripts/tools/BodyEditorPanelTest.gd`

- [ ] **Step 1: Extend the body editor panel test**

In `scripts/tools/BodyEditorPanelTest.gd`, after selecting `mid_body`, add:

```gdscript
panel.set_ring_parameter("top_width", 0.71)
panel.set_ring_parameter("bottom_width", 0.29)
panel.set_ring_parameter("top_flatness", 0.8)
panel.set_ring_parameter("right_flatness", 0.55)
```

After the existing ring assertions, add:

```gdscript
assert(abs(float(rings[3].get("top_width", 0.0)) - 0.71) < 0.001)
assert(abs(float(rings[3].get("bottom_width", 0.0)) - 0.29) < 0.001)
assert(abs(float(rings[3].get("width", 0.0)) - 0.5) < 0.001)
assert(abs(float(rings[3].get("top_flatness", 0.0)) - 0.8) < 0.001)
assert(abs(float(rings[3].get("right_flatness", 0.0)) - 0.55) < 0.001)
```

- [ ] **Step 2: Run the panel test and verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BodyEditorPanelTest
```

Expected: fail because the panel does not accept the new keys yet.

- [ ] **Step 3: Add body editor slider keys**

In `scripts/ui/BodyEditorPanel.gd`, update `RING_NUMERIC_KEYS`:

```gdscript
"width": {"min": 0.02, "max": 1.2, "step": 0.005},
"top_width": {"min": 0.02, "max": 1.2, "step": 0.005},
"bottom_width": {"min": 0.02, "max": 1.2, "step": 0.005},
"top_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"bottom_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"left_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"right_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
```

In `set_ring_parameter`, keep symmetric width as a shortcut:

```gdscript
if key == "width":
	rings[index]["width"] = clamped
	rings[index]["top_width"] = clamped
	rings[index]["bottom_width"] = clamped
else:
	rings[index][key] = clamped
	if key == "top_width" or key == "bottom_width":
		rings[index]["width"] = (float(rings[index].get("top_width", clamped)) + float(rings[index].get("bottom_width", clamped))) * 0.5
```

Use a local `clamped` value:

```gdscript
var clamped := clampf(value, float(config["min"]), float(config["max"]))
```

- [ ] **Step 4: Add Korean ring labels**

In `scripts/ui/UiText.gd`, update `RING_PARAMETER_LABELS`:

```gdscript
"width": "전체 폭",
"top_width": "위쪽 폭",
"bottom_width": "아래쪽 폭",
"top_flatness": "위쪽 평평함",
"bottom_flatness": "아래쪽 평평함",
"left_flatness": "왼쪽 평평함",
"right_flatness": "오른쪽 평평함",
```

- [ ] **Step 5: Run the panel test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BodyEditorPanelTest
```

Expected: pass and print `BODY_EDITOR_PANEL_TEST_OK`.

- [ ] **Step 6: Run body geometry tests together**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingWidthFlatnessTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingHeightDecoupleTest
```

Expected: all three pass.

- [ ] **Step 7: Commit body editor controls**

```bash
git add scripts/ui/BodyEditorPanel.gd scripts/ui/UiText.gd scripts/tools/BodyEditorPanelTest.gd
git commit -m "Expose directional body ring controls"
```

---

### Task 4: Add Directional Head Flatness Controls

**Files:**
- Modify: `scripts/creature/HeadProfile.gd`
- Modify: `scripts/creature/PrimitiveFactory.gd`
- Modify: `scripts/creature/FishRig.gd`
- Modify: `scripts/ui/HeadEditorPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Modify: `scripts/tools/HeadEditorPanelTest.gd`
- Modify: `scripts/tools/HeadEditorModelTest.gd`
- Modify: `scripts/tools/HeadShellSeamTest.gd`

- [ ] **Step 1: Extend the head panel test**

In `scripts/tools/HeadEditorPanelTest.gd`, after the first `set_parameters` block, assert the sliders exist:

```gdscript
assert(_has_numeric_slider(panel, "head_top_flatness"))
assert(_has_numeric_slider(panel, "head_bottom_flatness"))
assert(_has_numeric_slider(panel, "head_left_flatness"))
assert(_has_numeric_slider(panel, "head_right_flatness"))
```

Near the other numeric setter assertions, add:

```gdscript
panel.set_numeric_parameter("head_top_flatness", 0.66)
panel.set_numeric_parameter("head_bottom_flatness", 0.44)
panel.set_numeric_parameter("head_left_flatness", 0.33)
panel.set_numeric_parameter("head_right_flatness", 0.22)
assert(abs(float(seen[0].get("head_top_flatness", 0.0)) - 0.66) < 0.001)
assert(abs(float(seen[0].get("head_bottom_flatness", 0.0)) - 0.44) < 0.001)
assert(abs(float(seen[0].get("head_left_flatness", 0.0)) - 0.33) < 0.001)
assert(abs(float(seen[0].get("head_right_flatness", 0.0)) - 0.22) < 0.001)
panel.set_numeric_parameter("head_top_flatness", 2.0)
assert(abs(float(seen[0].get("head_top_flatness", 0.0)) - 1.0) < 0.001)
```

- [ ] **Step 2: Add head mesh model assertions**

In `scripts/tools/HeadEditorModelTest.gd`, add a focused helper that samples the head mesh vertices and compares neutral vs flat-cap shapes:

```gdscript
func _mesh_max_y(mesh_instance: MeshInstance3D) -> float:
	var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_y := -INF
	for v in verts:
		max_y = maxf(max_y, v.y)
	return max_y

func _mesh_upper_quadrant_average_y(mesh_instance: MeshInstance3D) -> float:
	var verts: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var total := 0.0
	var count := 0
	for v in verts:
		if v.y > 0.0 and absf(v.z) > 0.12:
			total += v.y
			count += 1
	return total / maxf(float(count), 1.0)
```

Add this test body in `_ready()` after the existing head sculpt assertions:

```gdscript
var neutral_flatness := neutral_jaw.duplicate(true)
neutral_flatness["head_top_flatness"] = 0.0
fish.set_parameters(neutral_flatness)
await get_tree().process_frame
var neutral_head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
var neutral_top := _mesh_max_y(neutral_head)
var neutral_upper_avg := _mesh_upper_quadrant_average_y(neutral_head)

var top_flat := neutral_flatness.duplicate(true)
top_flat["head_top_flatness"] = 1.0
fish.set_parameters(top_flat)
await get_tree().process_frame
var top_flat_head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
assert(absf(_mesh_max_y(top_flat_head) - neutral_top) < 0.01)
assert(_mesh_upper_quadrant_average_y(top_flat_head) > neutral_upper_avg + 0.01)
```

- [ ] **Step 3: Run the head tests and verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
```

Expected: panel test fails because keys are missing; model test fails because the mesh is unchanged.

- [ ] **Step 4: Add shared head flatness values to FishRig**

In `_head_sculpt_params()` in `scripts/creature/FishRig.gd`, add:

```gdscript
"head_top_flatness": param_float("head_top_flatness", 0.0),
"head_bottom_flatness": param_float("head_bottom_flatness", 0.0),
"head_left_flatness": param_float("head_left_flatness", 0.0),
"head_right_flatness": param_float("head_right_flatness", 0.0),
```

- [ ] **Step 5: Add a shared flat-cap helper to HeadProfile**

In `scripts/creature/HeadProfile.gd`, add:

```gdscript
static func flat_cap_value(value: float, target: float, side_sign: float, amount: float) -> float:
	var flat := clampf(amount, 0.0, 1.0)
	var extent := absf(target)
	if flat <= 0.0 or extent <= 0.001:
		return value
	var signed := value * side_sign
	if signed <= 0.0:
		return value
	var t := clampf(signed / extent, 0.0, 1.0)
	var weight := smoothstep(0.35, 1.0, t) * flat
	return lerpf(value, target, weight)
```

Then replace the body helper from Task 2 with a thin wrapper so both code paths use the same function:

```gdscript
static func _apply_flat_cap(value: float, radius: float, side_sign: float, amount: float) -> float:
	return HeadProfile.flat_cap_value(value, side_sign * radius, side_sign, amount)
```

- [ ] **Step 6: Apply flat caps in the head mesh without moving the shell envelope**

In `PrimitiveFactory.deformed_head_mesh`, read sculpt values near the existing head curve values:

```gdscript
var head_top_flatness := clampf(float(sculpt.get("head_top_flatness", 0.0)), 0.0, 1.0)
var head_bottom_flatness := clampf(float(sculpt.get("head_bottom_flatness", 0.0)), 0.0, 1.0)
var head_left_flatness := clampf(float(sculpt.get("head_left_flatness", 0.0)), 0.0, 1.0)
var head_right_flatness := clampf(float(sculpt.get("head_right_flatness", 0.0)), 0.0, 1.0)
```

Refactor the pre-jaw head deformation into a small helper so cap targets are sampled from the actual post-profile, post-bump surface instead of from the raw sphere radius. The helper must include the existing shape, snout, taper, dorsal/ventral profile, bump, and snout-y-shift steps, but must stop before upper-jaw carve, protrusion, and mouth-pit edits.

Use the helper in the vertex loop like this:

```gdscript
var p := _head_point_before_flatness(shape, phi, theta, snout_length, forehead_slope, sculpt)
var top_target := _head_point_before_flatness(shape, phi, PI * 0.5, snout_length, forehead_slope, sculpt).y
var bottom_target := _head_point_before_flatness(shape, phi, PI * 1.5, snout_length, forehead_slope, sculpt).y
var left_target := _head_point_before_flatness(shape, phi, PI, snout_length, forehead_slope, sculpt).z
var right_target := _head_point_before_flatness(shape, phi, 0.0, snout_length, forehead_slope, sculpt).z
var x := p.x
var y := p.y
var z := p.z
if shape != "cephalofoil" and sin(phi) > 0.001:
	y = HeadProfile.flat_cap_value(y, top_target, 1.0, head_top_flatness)
	y = HeadProfile.flat_cap_value(y, bottom_target, -1.0, head_bottom_flatness)
	z = HeadProfile.flat_cap_value(z, left_target, -1.0, head_left_flatness)
	z = HeadProfile.flat_cap_value(z, right_target, 1.0, head_right_flatness)
```

This preserves the actual crown, belly, left, and right extrema for each longitudinal head ring, so the existing shell-contour assumptions remain valid. Apply the cap block only when `shape != "cephalofoil"`. Hammerhead-specific side flattening is outside this plan because the cephalofoil branch already uses a distinct lateral expansion model.

- [ ] **Step 7: Add head editor controls**

In `scripts/ui/HeadEditorPanel.gd`, add to `NUMERIC_KEYS`:

```gdscript
"head_top_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"head_bottom_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"head_left_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
"head_right_flatness": {"min": 0.0, "max": 1.0, "step": 0.005},
```

Add a new fish section after `"머리 본체"`:

```gdscript
{"title": "평면화", "keys": ["head_top_flatness", "head_bottom_flatness", "head_left_flatness", "head_right_flatness"]},
```

In `_default_numeric`, return `0.0` for all four keys by relying on the existing fallback.

- [ ] **Step 8: Add Korean labels**

In `scripts/ui/UiText.gd`, add to `PARAMETER_LABELS`:

```gdscript
"head_top_flatness": "머리 위쪽 평평함",
"head_bottom_flatness": "머리 아래쪽 평평함",
"head_left_flatness": "머리 왼쪽 평평함",
"head_right_flatness": "머리 오른쪽 평평함",
```

- [ ] **Step 9: Extend the head/shell seam regression**

In `scripts/tools/HeadShellSeamTest.gd`, add this case after the existing `arowana-extreme` assertion:

```gdscript
var flat_extreme := extreme.duplicate(true)
flat_extreme["head_top_flatness"] = 1.0
flat_extreme["head_bottom_flatness"] = 0.6
flat_extreme["head_left_flatness"] = 0.8
flat_extreme["head_right_flatness"] = 0.8
fish.set_parameters(flat_extreme)
await get_tree().process_frame
assert(_max_escape(fish, "arowana-extreme-flatness") <= 1.02)
```

- [ ] **Step 10: Run focused head tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeamTest
```

Expected: all three pass.

- [ ] **Step 11: Commit head flatness controls**

```bash
git add scripts/creature/HeadProfile.gd scripts/creature/PrimitiveFactory.gd scripts/creature/FishRig.gd scripts/ui/HeadEditorPanel.gd scripts/ui/UiText.gd scripts/tools/HeadEditorPanelTest.gd scripts/tools/HeadEditorModelTest.gd scripts/tools/HeadShellSeamTest.gd
git commit -m "Add directional head flatness controls"
```

---

### Task 5: Preserve New Controls Through Presets

**Files:**
- Modify: `scripts/creature/BodyProfile.gd`
- Modify: `scripts/tools/PresetNormalizationTest.gd`

- [ ] **Step 1: Add preset round-trip assertions**

In `scripts/tools/PresetNormalizationTest.gd`, add a focused case in `_ready()`:

```gdscript
var sculpt_split := BodyProfileScript.split_parameters_into_profiles({
	"head_shape": "rounded",
	"head_top_flatness": 0.7,
	"head_bottom_flatness": 0.2,
	"head_left_flatness": 0.3,
	"head_right_flatness": 0.4,
	"body_profile": {
		"rings": [
			{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.24, "lower_height": 0.20, "width": 0.18, "top_width": 0.16, "bottom_width": 0.21, "top_flatness": 0.5, "bottom_flatness": 0.0, "left_flatness": 0.0, "right_flatness": 0.25, "roundness": 0.65, "sway_weight": 0.0},
			{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.42, "lower_height": 0.36, "width": 0.34, "top_width": 0.32, "bottom_width": 0.36, "top_flatness": 0.0, "bottom_flatness": 0.0, "left_flatness": 0.2, "right_flatness": 0.2, "roundness": 0.82, "sway_weight": 0.05},
			{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.52, "lower_height": 0.48, "width": 0.46, "top_width": 0.42, "bottom_width": 0.50, "top_flatness": 0.0, "bottom_flatness": 0.3, "left_flatness": 0.0, "right_flatness": 0.0, "roundness": 0.9, "sway_weight": 0.15}
		]
	}
}, {"name": "directional_sculpt"})
var rebuilt_sculpt := BodyProfileScript.make_parameters_from_structured_preset(sculpt_split)
assert(abs(float(rebuilt_sculpt.get("head_top_flatness", 0.0)) - 0.7) < 0.001)
var rebuilt_rings: Array = rebuilt_sculpt.get("body_profile", {}).get("rings", [])
assert(abs(float(rebuilt_rings[0].get("top_width", 0.0)) - 0.16) < 0.001)
assert(abs(float(rebuilt_rings[0].get("bottom_width", 0.0)) - 0.21) < 0.001)
assert(abs(float(rebuilt_rings[0].get("top_flatness", 0.0)) - 0.5) < 0.001)
```

- [ ] **Step 2: Run the preset test and verify it fails for head keys**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Expected: fail because head flatness keys are not included in the structured profile split yet.

- [ ] **Step 3: Preserve head flatness keys in structured presets**

In `BodyProfile.split_parameters_into_profiles`, add the four head keys to the existing `fin_profile` pick list near `head_flattening`:

```gdscript
"head_flattening", "head_top_flatness", "head_bottom_flatness", "head_left_flatness", "head_right_flatness",
```

Body ring fields are already preserved through the `body_profile` dictionary, so no extra split logic is needed for ring values.

- [ ] **Step 4: Run preset test**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Expected: pass.

- [ ] **Step 5: Commit preset preservation**

```bash
git add scripts/creature/BodyProfile.gd scripts/tools/PresetNormalizationTest.gd
git commit -m "Preserve directional sculpt controls in presets"
```

---

### Task 6: Final Validation

**Files:**
- Verify only.

- [ ] **Step 1: Run focused sculpt and editor tests**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingWidthFlatnessTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RingHeightDecoupleTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BodyEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeamTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Expected: all pass.

- [ ] **Step 2: Run the full Godot CLI suite**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

Expected: full suite passes. Treat `Failed to read the root certificate store` as non-fatal and use the runner exit code as the source of truth.

- [ ] **Step 3: Inspect changed files**

Run:

```bash
git status --short
git diff --stat
```

Expected: only files listed in this plan changed.

- [ ] **Step 4: Final commit if earlier task commits were batched**

If the task commits were intentionally batched, create one final commit:

```powershell
git add scripts/creature/BodyProfile.gd scripts/creature/FishRig.gd scripts/creature/PrimitiveFactory.gd scripts/creature/HeadProfile.gd scripts/ui/BodyEditorPanel.gd scripts/ui/HeadEditorPanel.gd scripts/ui/UiText.gd scripts/tools/RingWidthFlatnessTest.gd scenes/RingWidthFlatnessTest.tscn scripts/tools/BodyEditorPanelTest.gd scripts/tools/HeadEditorPanelTest.gd scripts/tools/HeadEditorModelTest.gd scripts/tools/HeadShellSeamTest.gd scripts/tools/PresetNormalizationTest.gd
if (Test-Path scripts/tools/RingWidthFlatnessTest.gd.uid) { git add scripts/tools/RingWidthFlatnessTest.gd.uid }
if (Test-Path scenes/RingWidthFlatnessTest.tscn.uid) { git add scenes/RingWidthFlatnessTest.tscn.uid }
git commit -m "Add directional body and head sculpt controls"
```

---

## Self-Review

- Spec coverage: body split width, body directional flatness, head directional flatness, UI exposure, preset preservation, and focused regression tests are covered.
- Placeholder scan: no undefined implementation phases, no deferred behavior, and no ambiguous test expectations remain.
- Type consistency: body ring fields use snake_case float keys; head flatness keys use `head_*_flatness`; flatness values are consistently `0.0..1.0`.
- Scope check: ray-disc sculpt controls, custom cross-section point editing, and visual asset changes are excluded from this plan.

