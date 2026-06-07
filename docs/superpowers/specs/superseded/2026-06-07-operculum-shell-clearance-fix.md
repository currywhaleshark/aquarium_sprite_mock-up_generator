# Operculum Shell-Clearance Fix (v3)

## Status of v2

The v2 anatomical revision (`2026-06-07-operculum-anatomical-revision.md`) is implemented and
all 38 CLI tests pass. But a side/quarter render shows the cover still reads wrong: the dark
gill slit floats as a **detached vertical bar** behind the opercle plate, with a body-colored
gap between them. The plate's rear half is faint and looks like it ends mid-cheek; only the
slit and a faint preopercle line stand out. The four-bone read does not hold.

This revision explains the mechanism and fixes it. It does **not** change the silhouette math
from v2 (envelope, J preopercle, anchored rear) — it fixes **how far the parts stand off the
surface** so they all sit on the *visible* body together.

## Why It Looks Detached (root cause)

The bug is not the slit shape. It is that **the operculum is placed against the head surface,
but in the cheek/gill region the visible surface is the body shell, which stands well outside
the head there.** Decoration outsets tuned to the head (0.07–0.12, copied from the mouth work)
never reach the shell, so the plate sinks *inside* the opaque body and is occluded, while the
one part with a large outset (the slit, 0.33) is the only thing that pokes through — alone,
detached, floating.

### The geometry, in numbers

`_head_mesh_side_z(verts, x, y, side, outset, ...)` returns `head_surface_z + side*outset` in
**head-local** units (unit head, radius ~0.5). The operculum is a child of the Head node,
whose scale is roughly `head.scale ≈ (0.44, 0.48, 0.31)` for a default rounded head. So a
head-local z-outset `O` renders as `O * head.scale.z ≈ O * 0.31` in world units.

Head side surface (world z), along the cover's x range (unit x 0.06→0.40):

```text
unit x = 0.00 (center) : z = 0.50 * 0.31 = 0.155 world
unit x = 0.40 (rear)   : z = 0.30 * 0.31 = 0.093 world   (head recedes toward the tail)
```

Body shell side surface (world z) near the cheek, from `_head_shell_metrics`
(`radius_z = head.scale.z*0.5 + shell_expand*~0.72`, `shell_expand` default 0.08):

```text
shell side z ≈ 0.155 + 0.058 .. 0.080 = 0.21 .. 0.235 world   (and the shell stays out here
                                                               while the head curves inward)
```

Now place the two parts:

```text
plate, outset 0.12 -> world z = head_z + 0.12*0.31 = 0.093..0.155 + 0.037 = 0.13 .. 0.19 world
slit,  outset 0.33 -> world z = head_z + 0.33*0.31 = 0.093..0.155 + 0.102 = 0.20 .. 0.26 world
```

Compare to the shell at **0.21–0.235 world**:

- **Plate (≤0.19) < shell (≥0.21)** → the opaque body shell renders *over* the plate,
  especially toward the rear where the head recedes. The plate's rear is buried, so the cover
  appears to stop mid-cheek.
- **Slit (0.20–0.26) ≳ shell** → the slit just clears the shell, so it is the only part you
  see — sitting on the body by itself, detached from the buried plate. The body-colored gap is
  the strip of shell between "plate sank here" and "slit poked out there."

So the inequality that breaks the read is:

```text
plate_outset_world (0.037) < shell_standoff (~0.05–0.10) < slit_outset_world (0.102)
```

The mouth decorations never hit this because they sit on the **snout**, which protrudes
*forward of* the shell; the operculum sits on the **cheek**, which the shell covers. The v1/v2
specs reused mouth-style head-surface outsets without accounting for the shell. That is the
whole bug.

## Fix Design

Make **every** operculum part clear the shell by the **same** amount, so the plate, slit, and
seams sit coplanar on the visible body surface and read as one cover. Two coupled changes:

### 1. Shell-clearing outset, graduated front→rear, shared by all parts

Compute a clearance from the actual shell/head scale instead of magic numbers, then graduate
it (the head recedes toward the rear, so the rear needs more clearance than the front):

```gdscript
# In _add_head_features (head.scale is available here) — pass into the operculum builders:
var head_scale_z: float = maxf(head.scale.z, 0.05)
var shell_expand: float = param_float("shell_expand", 0.08)
# World standoff we must beat, expressed back in head-local z:
var shell_clear := clampf(shell_expand * 0.95 / head_scale_z, 0.18, 0.46)   # ~0.24 default
```

Provide a per-column/per-vertex outset that rides this value:

```text
operculum_outset(u) = shell_clear * lerp(0.86, 1.28, u) + 0.02
                      # front ~0.84*shell_clear, rear ~1.30*shell_clear, +small proud margin
```

- Plate (`_operculum_plate_mesh`): replace the constant `0.12` with `operculum_outset(u_t)`.
- Ribbons (`_operculum_ribbon_mesh`): replace the `surface_outset` argument with
  `operculum_outset(local_u)` evaluated per vertex (it already computes `local_u`), so the
  slit (local_u≈1) and the plate rear (u=1) land at the **same** depth.
- Pass `shell_clear` (or `head_scale_z` + `shell_expand`) into `_operculum_params` /
  the builders via `cfg` so all helpers share one value.

Result: the whole cover floats out to the shell surface as a unit. Because the operculum is a
child of the head and the rig already aligns the shell's head rings to the head kinematics
(`_apply_animated_head`), sitting at shell depth still follows head pose correctly.

### 2. Gill opening = darkened posterior margin of the plate (contiguous), not a floating ribbon

Even at equal depth, a separate slit ribbon can drift. The robust fix is to make the opening
**part of the plate's rear edge**, so it can never detach:

- Keep the `GillSlit{L,R}` node, but build it from the **plate's own u=1 column line**
  (same x, same envelope y from `top_env(1)` to `bottom_env(1)`, same `operculum_outset(1)`),
  as a narrow dark band hugging that edge — not at `posterior_x + 0.004/0.012` with a
  separate 0.33 outset.
- Drop the independent `0.33` outset entirely; the slit inherits `operculum_outset(1)` like
  the plate rim.
- Optionally darken the plate's rear-margin vertices directly (vertex color or a thin dark
  quad strip along u∈[0.9,1.0]) so the opening is literally the cover's edge.

The anterior seam stays attached (no flare); the posterior margin (now carrying the slit)
flares with `operculum_open` as before — so opening lifts the real free edge.

### 3. Seam contrast so the four-bone read survives at sprite scale

The preopercle/subopercle soft seams (`base_color` darkened only 0.01–0.06) are invisible.
Raise their darkening so the J preopercle and the lower subopercle actually read:

```text
opercle_seam_darken = lerp(0.14, 0.30, ridge)     # was lerp(0.01, 0.06, ridge)
```

Keep them as soft (body-tone) seams, just darker, so they read as grooves without becoming
hard black lines like the gill opening.

### Alternative (not required this pass)

A cleaner long-term option is to sample the **shell** side surface for placement instead of
outsetting from the head (the rig has body-surface samplers like `_surface_radius_z`). That
removes the scale-coupled magic entirely but means mixing body-space sampling into a
head-local, head-child node. Defer it; the shared shell-clearing outset above is sufficient
and surgical.

## Files / Edit Points

- `FishRig.gd`
  - `_add_head_features` (~1807): compute `shell_clear` from `head.scale.z` and `shell_expand`;
    pass it into the operculum path.
  - `_operculum_params` (~2401): accept/store `shell_clear`; expose `operculum_outset` (a small
    helper or inline lerp).
  - `_operculum_plate_mesh` (~2427): per-column outset = `operculum_outset(u_t)` (drop 0.12).
  - `_operculum_ribbon_mesh` (~2467): per-vertex outset = `operculum_outset(local_u)` (drop the
    `surface_outset` constant / the 0.33 call site).
  - `_add_operculum_side` (~2503): rebuild `GillSlit` from the plate's u=1 edge; raise seam
    darkening (item 3, set in `_add_head_features` where `opercle_seam_mat` is built ~1812).
- No UI, option-list, material-factory, shell, fin, eye, or mouth changes.

## Tests (HeadEditorModelTest.gd)

Add regression guards for the two failure modes (unit tests can't see occlusion, but they can
pin the coplanarity that prevents the floating-bar look).

Add helper:

```gdscript
func _mesh_rear_edge_max_z(node: MeshInstance3D) -> float:
    var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var max_x := -INF
    for v in verts: max_x = maxf(max_x, v.x)
    var best := -INF
    for v in verts:
        if v.x >= max_x - 0.02: best = maxf(best, absf(v.z))
    return best
```

New assertions (default operculum, right side where z>0):

```text
# 1. Slit sits on the cover, not floating past it: coplanar with the plate's rear edge.
assert(absf(_mesh_max_z(slit_r) - _mesh_rear_edge_max_z(opercle_r)) < 0.03)

# 2. The whole cover clears enough to be on the body shell, not buried in the head:
#    plate rear |z| is meaningfully larger than a raw head-surface sample would give.
assert(_mesh_rear_edge_max_z(opercle_r) > 0.18)     # head rear side z is ~0.093 unscaled

# 3. Seams are now visibly darker than near-body tone (contrast guard).
var pre_mat := (PreopercleSeamL.material_override) as BaseMaterial3D
assert(_color_luma(pre_mat.albedo_color) < _color_luma(Color.html("#46c6cf")) - 0.06)
```

Keep all existing v2 operculum assertions. Update the open-flare slit assertions if the slit's
z baseline changes (it should still move outward on open; the rear-edge delta logic still holds).

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

After tests pass, render a visual check (side + three-quarter, closed + open) and confirm the
slit is the cover's rear edge with no body-colored gap.

## Acceptance Criteria

- The gill slit is the cover's posterior edge — no body-colored gap, no floating dark bar in
  side or quarter view.
- The opercle plate reads as one continuous cover from the preopercle seam back to the slit
  (its rear half is no longer buried by the body shell).
- Preopercle (J) and subopercle seams are visible at normal sprite zoom.
- `operculum_open` lifts the posterior free margin; the anterior seam stays attached.
- The cover follows rounded/tapered/hump/flattened heads without floating or burying, because
  the clearance is derived from `head.scale.z` and `shell_expand`, not a fixed number.
- Inactive `gill_mark` values unchanged; shell/fins/eyes/mouth/export untouched. CLI tests pass.

## Non-Goals

- No shell geometry changes, no breathing animation, no real hole in the head mesh, no shader
  changes, no `head_profile` migration, no new gill-mark option or numeric control.
```
