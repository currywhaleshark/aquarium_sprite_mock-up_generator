# Operculum Anatomical Revision (v2)

## Goal

The first operculum pass renders, loads, and tests green, but it does not read as a real
gill cover. This revision reshapes the existing `gill_mark = "operculum"` geometry so the
silhouette matches teleost anatomy. No new gill-mark option is added. The four existing
numeric controls keep their names and ranges; only the geometry they drive changes. Preset
schema stays compatible (the optional opercular-spot control in the last section is the only
additive key, and it is gated off by default).

This is a geometry/visual revision inside `FishRig.gd` plus test threshold updates. It does
not touch the shell, fins, eyes, mouth, UI option list, or material factory.

## Why the Current Version Looks Wrong

Current head-local layout (`x+` = posterior/rear, `y+` = up, head radius ~0.5):

- Cover spans only `x 0.07..0.29`, `y -0.18..0.16` — a small patch on the mid-cheek. The
  rear head (`x 0.29..0.5`) and the dorsal/throat bands stay bare.
- The dark `GillSlit` and `OpercleRim` ribbons sit at `posterior_x - 0.05..0.09`, i.e.
  **inset in the middle of the plate**, with body-colored plate continuing behind them. This
  reads as a vertical bar painted across the cheek, not a cover with a rear opening.
- `PreopercleSeam` is a nearly straight vertical ribbon — it lacks the J / boomerang hook of
  a real preopercle.
- The plate tapers symmetrically top and bottom, so it never reads as a dorsal opercle fan.

Real teleost anatomy (lateral view):

- The gill cover dominates the rear half of the head, from just behind the cheek back to the
  head/body boundary, and from near the dorsal contour down to the throat.
- The **gill opening is the posterior free margin** — a vertical curved slit at the very rear
  edge where the cover meets the body. It is the cover's edge, not an inset line.
- The **preopercle** is an L/J seam framing the anterior boundary, behind the cheek (cheek =
  eye-to-preopercle). It has a vertical limb that hooks forward-ventrally along the jaw line.
- The **opercle** is the large dorsal fan; the **subopercle** is the narrower ventral panel.

References: see `2026-06-07-operculum-gill-cover-design.md` Research Summary, plus
[Fish anatomy — Wikipedia](https://en.wikipedia.org/wiki/Fish_anatomy) and
[PLOS ONE opercle shape](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0188888).

## Coordinate Model (unchanged)

All operculum geometry is built in head-local space and sampled to the real head side
surface with `_head_mesh_side_z(verts, x, y, side, outset, max_sample_x)`. `x+` is posterior.
`side` is `-1.0` (left, `z<0`) or `+1.0` (right, `z>0`).

## Parameter Remap (`_operculum_params`, FishRig.gd ~2401)

Replace the current `center_x`/`half_len`/`top_y`/`bottom_y` block. Anchor the **posterior
edge** (the gill-opening location is anatomically stable) and let `operculum_size` grow the
cover **forward** (cheek extent), not symmetrically.

```text
posterior_x   = 0.40                      # fixed rear free-margin x
cover_length  = 0.34 * size               # size 0.5 -> 0.17, size 1.5 -> 0.51
anterior_x    = posterior_x - cover_length

top_y_base    =  0.30 * height
bottom_y_base = -0.28 * height
```

Keep the ridge-driven widths but retune for the larger cover:

```text
seam_width        = lerp(0.004, 0.012, ridge)   # preopercle / subopercle ribbons
slit_width        = lerp(0.012, 0.055, ridge)   # rear gill opening
subopercle_width  = lerp(0.003, 0.011, ridge)
```

Drop `rim_width` (the OpercleRim ribbon is removed — see Node Structure).

Return these plus `size, height, open, ridge, anterior_x, posterior_x, top_y_base,
bottom_y_base, seam_width, slit_width, subopercle_width`.

## Cover Silhouette (`_operculum_plate_mesh`, FishRig.gd ~2423)

Re-grid the plate as **u (along cover, anterior→posterior) × v (top→bottom)** instead of the
current row-over-y / col-over-x scheme. This makes the posterior free margin a clean `u=1`
edge that the gill slit can follow, and lets the dorsal/ventral envelopes form a fan.

Add a small envelope helper (top of the operculum block):

```gdscript
func _operculum_envelope(u: float, v0: float, v_mid: float, v1: float) -> float:
    if u <= 0.5:
        return lerpf(v0, v_mid, smoothstep(0.0, 1.0, u / 0.5))
    return lerpf(v_mid, v1, smoothstep(0.0, 1.0, (u - 0.5) / 0.5))
```

Envelope multipliers (narrow hinge at front, broad opercle fan mid/rear):

```text
top envelope    multipliers: u0 = 0.40, umid = 1.00, u1 = 0.66
bottom envelope multipliers: u0 = 0.36, umid = 1.00, u1 = 0.78
```

Plate build (rows = 6, cols = 6):

```text
for ci in 0..cols:
    u  = ci / cols
    x_col = lerp(anterior_x, posterior_x, u)
    ty = top_y_base    * _operculum_envelope(u, 0.40, 1.00, 0.66)
    by = bottom_y_base * _operculum_envelope(u, 0.36, 1.00, 0.78)
    open_w = smoothstep(0.35, 1.0, u)          # rear free margin only
    for ri in 0..rows:
        v = ri / rows
        y = lerp(ty, by, v)
        x = x_col
        z = _head_mesh_side_z(verts, x, y, side, 0.072, 0.48)
        z += side * open * 0.035 * open_w
        x += open * 0.045 * open_w
        add_vertex(Vector3(x, y, z))
```

- Index/winding stays per-side as it is now (the `if side > 0.0` branch), then
  `generate_normals()`.
- `max_sample_x` rises `0.42 -> 0.48` here because the rear edge now reaches `x ≈ 0.40`
  plus flare. Also bump the **default** `max_sample_x` on `_head_mesh_side_z` if any other
  operculum caller relies on it; pass `0.48` explicitly from every operculum sampler.

Result: a leaf/fan plate, narrow at the anterior hinge, broad through the opercle body, with
a tall rounded posterior free margin.

## Ribbons (`_operculum_ribbon_mesh` unchanged; point lists in `_add_operculum_side`)

`_operculum_ribbon_mesh` keeps its current signature and logic (per-vertex tangent normal,
optional open flare, `_head_mesh_side_z` sampling). Only the point lists and which nodes
exist change.

### PreopercleSeam{L,R} — anterior J/boomerang (front frame, no flare)

```text
points (×, with top_y_base = T, bottom_y_base = B):
  (anterior_x + 0.030, T * 0.82)
  (anterior_x + 0.006, T * 0.30)
  (anterior_x + 0.000, B * 0.10)      # midline, just below center
  (anterior_x + 0.022, B * 0.55)
  (anterior_x + 0.075, B * 0.92)      # ventral hook curves FORWARD along the jaw
width = seam_width   apply_open = false   surface_outset = 0.088
material = opercle_seam_mat (soft, body-darkened)
```

The last two points push `x` forward as `y` drops, producing the forward jaw hook that the
straight v1 seam was missing.

### GillSlit{L,R} — posterior free margin (the gill opening)

Move the slit OUT to the rear edge so it reads as the cover opening, not a mid-cheek bar.

```text
points:
  (posterior_x + 0.004, T * 0.60)
  (posterior_x + 0.012, 0.0)
  (posterior_x + 0.004, B * 0.66)
width = slit_width   apply_open = true   surface_outset = 0.17
material = seam_mat (dark "#15191b")
```

Because `apply_open = true`, the slit flares outward with the plate's rear margin, so opening
the operculum lifts the free edge — the correct hinge motion.

### SubopercleSeam{L,R} — lower panel seam (mild flare)

```text
points:
  (anterior_x + 0.090, B * 0.70)
  ((anterior_x + posterior_x) * 0.5, B * 0.92)
  (posterior_x - 0.080, B * 0.70)
width = subopercle_width   apply_open = true   surface_outset = 0.088
material = opercle_seam_mat (soft)
```

### OpercleRim{L,R} — REMOVE

Delete the `rim` MeshInstance and its point list. It was the inset dark vertical that, with
the inset slit, produced the mid-cheek bar artifact. The preopercle (front) + gill slit
(rear) + subopercle (lower) now carry the four-bone read without a central bar.

## Node Structure (per side, under `BodyPivot/Head/GillMark_operculum`)

```text
OpercleL / OpercleR              (plate, opercle_mat)
PreopercleSeamL / PreopercleSeamR(soft seam)
GillSlitL / GillSlitR            (dark, at posterior margin)
SubopercleSeamL / SubopercleSeamR(soft seam)
```

`OpercleRim*` no longer exists. (`OpercularSpot*` only when the optional control is added.)

## Materials (unchanged)

- `opercle_mat`: `TMF.make_surface(base_color)` darkened by `lerp(0.06, 0.30, ridge)` — as
  built today in `_add_head_features`.
- `opercle_seam_mat`: body color darkened by `lerp(0.01, 0.06, ridge)` (soft seam).
- `seam_mat` (dark `#15191b`): the gill slit. `CULL_DISABLED` already holds via `make_dark`.

No material-factory edits.

## Behavior Constraints (unchanged from v1)

The operculum still follows head scale/position/shape and swim pose (child of head), and must
not alter shell, fins, eyes, mouth, or export. No breathing animation in this pass.

## Tests (HeadEditorModelTest.gd — update existing operculum block)

The operculum assertions added in commit `3327637` must be retuned for the new geometry.

Remove:

- All `OpercleRim*` lookups and assertions (`high_rim_l`, `high_rim_r`, `high_rim_extent`).

Update extent expectations (new plate is larger):

```text
opercle_l_extent.x > 0.30          # was 0.16
opercle_l_extent.y > 0.46          # was 0.24
opercle_l_extent.z > 0.01          # keep
```

Size effect (anchored rear, grows forward):

```text
large_plate_extent.x > small_plate_extent.x + 0.20    # was + 0.14
```

Height effect:

```text
tall_plate_extent.y > short_plate_extent.y + 0.30     # was + 0.22
```

Open effect (rear margin flares, front stays) — keep `_mesh_rear_edge_average_z` /
`_mesh_front_edge_abs_z` helpers and thresholds (`±0.025` rear, `<0.014` front).

Ridge effect — keep slit-width-grows and plate-color-darker assertions; plate extent stays
within `±0.012`.

Add a NEW assertion that the gill slit sits at the posterior margin (the core fix). Add a
helper:

```gdscript
func _mesh_average_x(node: MeshInstance3D) -> float:
    var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var total := 0.0
    for v in verts: total += v.x
    return total / float(maxi(verts.size(), 1))
```

Then, with the default operculum params, assert the slit is clearly rear of the plate center:

```text
slit_x  = _mesh_average_x(GillSlitL)
plate_x = _mesh_average_x(OpercleL)
assert(slit_x > plate_x + 0.08)       # slit lives at the free margin, not mid-plate
```

Keep the existing mirror-across-z assertions, the `gill_mark = "line"` teardown assertion,
and the non-operculum no-node assertions.

`HeadEditorPanelTest.gd` and `PresetNormalizationTest.gd` need no changes (option list and
the four keys are unchanged) unless the optional control below is added.

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

## Acceptance Criteria

- The cover dominates the rear head: posterior edge near `x ≈ 0.40`, vertical span from near
  the dorsal contour to the throat. No bare mid-cheek-patch look.
- The dark gill slit sits at the posterior free margin (cover edge), not inset in the plate.
  No vertical bar across the middle of the cheek.
- The preopercle reads as a J/boomerang with a forward ventral hook.
- The plate reads as a dorsal fan (broad mid/rear, narrow front hinge).
- `operculum_open` lifts the posterior free margin (and the slit with it); the anterior seam
  stays attached.
- Cover still follows rounded/tapered/hump/flattened heads without floating or burying.
- Inactive `gill_mark` values are unaffected; shell/fins/eyes/mouth/export unchanged.
- Focused Godot CLI tests pass.

## Non-Goals

- No breathing animation, no real hole cut into the head mesh, no per-bone editable meshes,
  no shader changes, no migration to a `head_profile` section.
- Do not change the `GILL_MARKS` option list or the four numeric control names/ranges.

## Optional / Phase 2 — Opercular Spot

Many readable fish (sunfish, cichlids, bettas) carry a dark opercular spot at the upper-rear
of the cover. It is a strong "this is a gill cover" identifier. Implement only if requested;
it adds one preset key.

- New control `operculum_spot` (`0.00..1.00`, default `0.00`).
- When `> 0.5`, add `OpercularSpot{L,R}`: a small flattened ellipsoid
  (`Vector3(0.05, 0.07, 0.015)`) at `x = posterior_x - 0.12`, `y = top_y_base * 0.50`,
  `z = side * _head_side_surface_z(...)` or sampled, using `seam_mat` (dark) or
  `secondary_color` accent. Scale opacity/size by the control value.
- Wiring if added: append `operculum_spot` to the `fin_profile` pick list in
  `BodyProfile.gd`, to `NUMERIC_KEYS` and `_default_numeric` and `_should_show_fish_numeric_key`
  (`operculum_` prefix already gates it) in `HeadEditorPanel.gd`, and a `PARAMETER_LABELS`
  entry `"operculum_spot": "아가미덮개 반점"` in `UiText.gd`. Extend
  `PresetNormalizationTest` round-trip and `HeadEditorPanelTest` visibility to include it.
```
