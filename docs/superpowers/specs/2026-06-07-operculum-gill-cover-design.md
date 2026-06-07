# Operculum Gill Cover Design

## Goal

Implement an anatomical gill cover option for bony fish heads so the generator can show a readable operculum, not just a decorative gill line.

The first version should add `gill_mark = "operculum"` as a new head trait. Existing `none`, `line`, `crescent`, and `plate` options must continue to load and render unchanged.

## Research Summary

Teleost and other bony fish do not expose separate lateral gill slits like sharks. Their gills sit in a branchial/opercular chamber under a bony cover. The visible cover is an opercular series: preopercle, opercle, subopercle, and interopercle. The opercle is usually the largest, broad flat plate supporting most of the cover. The preopercle forms the anterior curved boundary and often carries a sensory canal. The subopercle and interopercle contribute to the lower cover and membrane support.

For this sprite generator, the visual priorities are:

- a broad, thin side plate behind the cheek;
- a curved anterior seam that reads as the preopercle boundary;
- a dark posterior/ventral slit where water exits the opercular chamber;
- optional small lower-panel seam so the cover reads as a series rather than a single sticker;
- a slight outward flare at the posterior edge for respiration, while the anterior edge remains attached to the head.

Primary references:

- [PLOS ONE: A rich diversity of opercle bone shape among teleost fishes](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0188888)
- [Bishop Museum Fish Remains Guide: opercular series bones](https://hbs.bishopmuseum.org/frc/types.html)
- [ScienceDirect: buccal pumping and opercular chamber motion](https://www.sciencedirect.com/topics/veterinary-science-and-veterinary-medicine/buccal-pumping)
- [GSMFC Practical Handbook, section 5.0 Opercles](https://www.gsmfc.org/publications/GSMFC%20Number%20300.pdf)

## Current System Fit

The project already has the correct attachment point:

- `scripts/creature/FishRig.gd` builds head features in `_add_head_features()` and dispatches `gill_mark` through `_add_gill_mark()`.
- `scripts/ui/HeadEditorPanel.gd` exposes the `GILL_MARKS` option list.
- `scripts/ui/UiText.gd` provides option and parameter labels.
- `scripts/creature/BodyProfile.gd` saves `gill_mark` inside `fin_profile`.
- `scripts/tools/HeadEditorModelTest.gd`, `HeadEditorPanelTest.gd`, and `PresetNormalizationTest.gd` already cover nearby head, UI, and preset behavior.

The new feature should reuse these paths. It should not create a separate head-profile save section yet.

One existing helper needs care: `FishRig._head_mesh_side_z()` currently ignores vertices with `v.x > 0.25`, because it was written for mouth-side aperture sampling on the front half of the head. The operculum reaches farther back than the mouth. Implementation must either add an optional `max_sample_x` argument that defaults to `0.25` for existing mouth callers, or create a separate operculum side sampler that accepts vertices up to at least `x = 0.42`.

## Feature Design

### New Option

Add:

```text
gill_mark: none | line | crescent | plate | operculum
```

`operculum` means an anatomical cover assembly. It should render both left and right sides of the head.

### New Numeric Controls

Add these fish-head numeric parameters:

```text
operculum_size      0.50..1.50, default 1.00
operculum_height    0.50..1.50, default 1.00
operculum_open      0.00..1.00, default 0.00
operculum_ridge     0.00..1.00, default 0.45
```

Meanings:

- `operculum_size`: anterior-posterior plate length.
- `operculum_height`: dorsal-ventral plate height.
- `operculum_open`: posterior edge flare, used first as a static pose control.
- `operculum_ridge`: seam and rim contrast/strength, not a bone thickness control.

The sliders appear only when `gill_mark == "operculum"`. All defaults should be visually conservative.

### Parameter Mapping

Every numeric control must feed a deterministic formula:

```gdscript
var size := clampf(param_float("operculum_size", 1.0), 0.5, 1.5)
var height := clampf(param_float("operculum_height", 1.0), 0.5, 1.5)
var open := clampf(param_float("operculum_open", 0.0), 0.0, 1.0)
var ridge := clampf(param_float("operculum_ridge", 0.45), 0.0, 1.0)

var center_x := 0.18
var half_len := 0.11 * size
var anterior_x := center_x - half_len
var posterior_x := center_x + half_len
var top_y := 0.16 * height
var bottom_y := -0.18 * height

var seam_width := lerpf(0.004, 0.014, ridge)
var slit_width := lerpf(0.008, 0.024, ridge)
var subopercle_width := lerpf(0.003, 0.010, ridge)
var plate_darken := lerpf(0.04, 0.18, ridge)
```

At the default `operculum_size = 1.0`, the plate spans `x = 0.07..0.29`, matching the intended cheek-to-rear-head range. At `0.5`, it spans `0.125..0.235`; at `1.5`, it spans `0.015..0.345`. The implementation may clamp generated sample points to the valid head-local range, but tests should assert that a larger size produces a larger opercle x extent.

`operculum_ridge` drives visible structure without requiring shader changes: seam width, gill-slit width, lower seam width, and plate darkening. It does not change plate size or flare.

### Node Structure

For each side, create these nodes under `BodyPivot/Head/GillMark_operculum`:

```text
OpercleL / OpercleR
PreopercleSeamL / PreopercleSeamR
GillSlitL / GillSlitR
SubopercleSeamL / SubopercleSeamR
```

Responsibilities:

- `Opercle*`: a thin curved mesh plate, colored as a slightly darkened/desaturated body surface.
- `PreopercleSeam*`: a dark curved narrow ribbon from upper cheek to lower cheek.
- `GillSlit*`: a darker posterior ribbon that sits at the rear edge of the cover.
- `SubopercleSeam*`: a lower short seam, subtle enough not to clutter small sprites.

### Geometry

The opercle should be generated as a custom mesh, not a scaled sphere. It needs to follow the actual head side surface.

Coordinate model in head-local units:

- anterior seam x: `anterior_x` from the parameter mapping, plus a shallow crescent curve up to `anterior_x + 0.035`;
- posterior edge x: `posterior_x` from the parameter mapping, plus local row taper no greater than `0.015`;
- top y: `top_y` from the parameter mapping;
- bottom y: `bottom_y` from the parameter mapping;
- z surface: sampled from the built head mesh through an operculum-safe side sampler that does not discard all vertices behind `x = 0.25`.

The plate should be an oval/trapezoid-like grid with soft edges:

- 5 to 7 rows and 5 to 7 columns are enough for the first version.
- Vertices outside the plate mask are skipped by building row widths that taper at top and bottom.
- Normals are generated by `SurfaceTool.generate_normals()`.
- The plate is offset slightly outward from the head surface to avoid z fighting.

`operculum_open` flares the posterior edge only:

```text
open_weight = smoothstep(0.35, 1.0, local_x_fraction)
z += side * open * 0.035 * open_weight
x += open * 0.015 * open_weight
```

The anterior seam remains attached, so the plate reads like a hinged cover, not a floating patch. The `side` sign follows current head-feature naming: `side < 0` is left and should move toward more negative z when opening; `side > 0` is right and should move toward more positive z when opening.

### Materials

Use existing material helpers:

- plate material: `TMF.make_surface(base_color)` with `albedo_color.darkened(plate_darken)`;
- seam and slit material: `TMF.make_dark("#15191b")`;
- culling disabled for seam/slit if needed, since these are thin ribbons visible from quarter angles.

No shader changes are needed for v1.

Existing `line`, `crescent`, and `plate` marks should keep using the same dark material behavior they have now. Only the new `operculum` branch uses the body-colored plate material.

### FishRig Plumbing

Current code calls:

```gdscript
_add_gill_mark(head, String(parameters.get("gill_mark", "none")), dark_mat)
```

The operculum implementation needs both a body-colored plate material and built head vertices. Update the call path explicitly:

```gdscript
var head_verts: PackedVector3Array = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
var opercle_mat := TMF.make_surface(parameters.get("base_color", "#46c6cf"))
opercle_mat.albedo_color = opercle_mat.albedo_color.darkened(plate_darken)
_add_gill_mark(head, String(parameters.get("gill_mark", "none")), dark_mat, opercle_mat, head_verts)
```

Then change the helper signature to:

```gdscript
func _add_gill_mark(head: MeshInstance3D, mark: String, seam_mat: Material, opercle_mat: Material, head_verts: PackedVector3Array) -> void:
```

The existing mark branches use `seam_mat`. The `"operculum"` branch uses `opercle_mat` for `Opercle*` and `seam_mat` for `PreopercleSeam*`, `GillSlit*`, and `SubopercleSeam*`.

### Interaction With Existing Head Features

The operculum is a head feature, so it must follow:

- head scale;
- head position;
- head shape;
- snout and mouth settings indirectly through the built head mesh;
- swim pose, because it is a child of the head node.

It should not:

- alter body shell geometry;
- influence fin anchors;
- change mouth/jaw behavior;
- add automatic breathing animation in v1.

Automatic breathing can be a later motion feature that animates `operculum_open` with a low amplitude.

## UI Design

Extend the head editor:

- add `"operculum"` to `GILL_MARKS`;
- add an `"아가미"` section after `"입"` or before `"눈"`;
- show operculum sliders only when the selected `gill_mark` is `"operculum"`;
- label the option `"아가미덮개"`.

Recommended labels:

```text
operculum_size   아가미덮개 길이
operculum_height 아가미덮개 높이
operculum_open   아가미덮개 열림
operculum_ridge  아가미덮개 경계
```

The existing `gill_mark` option row can remain where it is. The new sliders provide refinement after the option is selected.

Concrete edit points:

- add all four keys to `HeadEditorPanel.NUMERIC_KEYS`;
- add `{"title": "아가미", "keys": ["operculum_size", "operculum_height", "operculum_open", "operculum_ridge"]}` to `FISH_SECTIONS`;
- add an `_should_show_fish_numeric_key()` branch that returns true for `operculum_*` keys only when `String(parameters.get("gill_mark", "none")) == "operculum"`;
- add defaults for all four keys to `_default_numeric()`;
- add `"operculum": "아가미덮개"` to `UiText.OPTION_LABELS`;
- add the four Korean parameter labels to `UiText.PARAMETER_LABELS`.

## Data Model

Add the new keys to the same `fin_profile` pick list where head trait values already live:

```text
operculum_size
operculum_height
operculum_open
operculum_ridge
```

This keeps user preset save/load compatible with the current schema. Existing presets without these keys use runtime defaults.

No built-in preset needs to be edited for the first implementation. Later species/archetype presets can opt into `gill_mark = "operculum"`.

## Testing

Focused tests should be added or extended before implementation.

### HeadEditorPanelTest

Verify:

- `gill_mark = "operculum"` makes operculum sliders visible;
- selecting any other gill mark hides them;
- setting numeric operculum values emits them in `parameters_changed`.

### HeadEditorModelTest

Verify:

- a fish with `gill_mark = "operculum"` creates `OpercleL`, `OpercleR`, `PreopercleSeamL`, `PreopercleSeamR`, `GillSlitL`, `GillSlitR`, `SubopercleSeamL`, and `SubopercleSeamR`;
- the opercle mesh has nonzero x/y/z extents;
- left and right opercles are mirrored across z;
- `operculum_size` increases opercle x extent;
- `operculum_height` increases opercle y extent;
- increasing `operculum_open` moves the rear edge farther outward than the anterior edge;
- opening uses the correct side sign: left rear edge moves toward more negative z, right rear edge moves toward more positive z;
- `operculum_ridge` increases seam/slit mesh width or extent without changing the opercle plate x/y extent;
- non-operculum `gill_mark` values do not create opercle nodes.

### PresetNormalizationTest

Verify:

- new operculum keys round-trip through `BodyProfile.split_parameters_into_profiles()`;
- legacy presets without those keys still load without adding visible operculum nodes.

### Commands

Run the smallest relevant tests first:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Then run the full suite if the focused tests pass:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

## Acceptance Criteria

- Existing gill marks render as before.
- Selecting `"아가미덮개"` creates a clear side plate, anterior seam, posterior gill slit, and subtle lower seam on both sides of the head.
- The plate follows rounded, tapered, hump, and flattened head shapes without obvious floating or burying.
- `operculum_open` flares only the posterior edge.
- The feature does not alter body shell, fins, eyes, mouth, or export behavior when inactive.
- Focused Godot CLI tests pass through the project runner.

## Non-Goals

- Do not implement continuous breathing animation in this pass.
- Do not cut a real hole into the head mesh.
- Do not remodel the full skull or expose all four opercular bones as independent editable meshes.
- Do not add shader-level head markings for this feature.
- Do not migrate head parameters into a separate `head_profile` section.

## Implementation Notes

The most important implementation detail is surface sampling. The existing mouth work already showed that analytic sphere sampling can bury decorations on tapered or deformed heads. The operculum should therefore sample the real built head mesh using the same principle as `_head_mesh_side_z()`, with a small outward offset.

Do not call the existing mouth-tuned `_head_mesh_side_z()` unchanged for posterior opercle samples. Its `v.x > 0.25` cutoff can snap the rear edge toward the front rim when sampling `posterior_x` near `0.30..0.35`. Preserve the old cutoff for mouth callers by adding a parameter with a default, or use a separate operculum sampler.

Keep the feature surgical. The correct first slice is a static, anatomy-informed cover that reads well in side and quarter view. Motion can be layered later once the shape is stable.
