# Shark Head Mesh With Integrated Mouth/Jaw Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current shark mouth overlay with a shark-specific head mesh that includes the rostrum, recessed crescent mouth, lower jaw drop, mouth interior shadow, teeth anchors, labial furrows, and eye/gill compatibility. The result should not depend on fixed body-pivot offsets or floating helper geometry.

**Architecture:** FishRig keeps owning rebuild order, shell generation, materials, and common feature plumbing. SharkRig overrides the head factory and existing contour hook with a new analytic SharkHeadProfile, while SharkMouthMarking becomes an attachment helper that consumes SharkHeadProfile anchors instead of inventing positions.

**Tech Stack:** Godot 4 GDScript, ArrayMesh/SurfaceTool, existing Godot CLI test runner.

---

**Current Branch:** `codex/shark-gill-plan-fix`

**Primary Files:**
- `scripts/creature/FishRig.gd`
- `scripts/creature/SharkRig.gd`
- `scripts/creature/PrimitiveFactory.gd`
- `scripts/creature/SharkMouthMarking.gd`
- `scripts/creature/SharkGillSlitMarking.gd`
- `scripts/ui/HeadEditorPanel.gd`
- `scripts/ui/ParameterPanel.gd`
- `scripts/ui/UiText.gd`
- `scripts/tools/SharkMouthRenderingTest.gd`
- `scripts/tools/SharkGillSlitRenderingTest.gd`
- `scripts/tools/HeadEditorPanelTest.gd`
- `scripts/tools/ParameterModeVisibilityTest.gd`

**New Files:**
- `scripts/creature/SharkHeadProfile.gd`
- `scripts/tools/SharkHeadMeshTest.gd`
- `scenes/SharkHeadMeshTest.tscn`

## Non-Goals

- Do not redesign ray or fish head generation.
- Do not reintroduce fish mouth nodes for shark mode.
- Do not solve unrelated material, pattern, or animation issues.
- Do not rely on screenshot-only validation for the core geometry contracts.

## Hard Constraints From Review

- The mouth recess test must not measure broad `x` range over a head underside band. It must compare matching mesh vertices or a mouth-local analytic baseline.
- Task ordering must not declare green while tests assert `Head/SharkMouth/*` before the attachment helper is moved under `Head`.
- The rostrum and neck ends must not leave open rings. Use pole/tapered rings and/or explicit caps, and verify winding/normals.
- Any helper attached under `Head` must avoid non-uniform scale distortion by using an inverse-scale socket, matching the existing `SnoutSocket` pattern.
- Surface placement helpers must come from `SharkHeadProfile` analytic functions, not from undocumented `_positive_head_surface_z(...)` style helpers.
- Shark eyes must be adapted to the shark head contour or explicitly verified so they are not floating or buried.
- Exposed shark sliders must affect visible geometry or be hidden in shark mode. `shark_lower_jaw_drop` must deform the mesh.
- `MouthInteriorShadow` is required geometry, not a placeholder box or old crescent overlay.
- The mouth line needs concentrated mesh rings/creases around `mouth_u`; uniform `u` sampling is not acceptable.
- The mouth corners must be analytic anchors derived from the mouth-weight zero boundary.
- Side-visible mouth geometry must not be hard-coded to `+z` only. Use a `side` parameter for `+1/-1` and mirror anchors/attachments where the feature should appear on both sides.
- FishRig hook snippets must match real APIs. `PF.deformed_head(parameters)` and `HeadProfile.contour_radius_at_x(...)` do not exist.
- Inverse-scale attachment sockets require explicit coordinate conversion: socket-child positions use `anchor * head.scale`, because the socket cancels the parent scale.
- `MouthInteriorShadow` must stay in head-scaled space, not inside the inverse-scale socket.
- `shark_lower_jaw_drop` range is `0.0..0.4` unless Task 7 deliberately widens both UI panels and tests.
- Existing gill fixes should remain intact; this plan is not allowed to regress shell-sampled gill placement.

## Geometry Model

`SharkHeadProfile.gd` owns the shared analytic model for:

- `u_samples(parameters)`: non-uniform samples with concentrated rings around the mouth center and mouth edges.
- `point_at(parameters, u, theta)`: final head mesh vertex in head-local space.
- `surface_z_at(parameters, u, y, side := 1.0)`: exact side surface used by mouth attachments, eyes, and tests.
- `mouth_weight(parameters, u, y, z)`: recess strength in the crescent mouth band.
- `mouth_anchor(parameters, side := 1.0)`: midpoint of the visible mouth line for teeth/interior placement.
- `mouth_corners(parameters, side := 1.0)`: analytic front/rear corners on the requested side where the mouth-weight boundary reaches zero.
- `build_mouth_interior_shadow(parameters, material)`: dark ribbon mesh that sits inside the dented mouth recess.

Coordinate contract:

- Head-local `x` runs from rostrum tip to neck.
- `u = 0.0` is the rostrum tip; `u = 1.0` is the neck/body seam.
- UV `u` must map to the same scale as fish heads: `u * HEAD_U_SPAN`, where `HEAD_U_SPAN` remains `0.25`.
- Shark mouth parameters are normalized to head dimensions where practical; raw body-pivot offsets must not control final placement.

## Task 1: Red Tests For Integrated Shark Head Geometry

Create `scripts/tools/SharkHeadMeshTest.gd` and `scenes/SharkHeadMeshTest.tscn`.

The first tests must verify head mesh geometry only. Do not assert teeth, furrow, or `Head/SharkMouth/*` attachments here; those become green after Task 5.

Expected initial state: **FAIL**, because current shark mode still uses the fish head mesh plus floating mouth helper.

Test cases:

1. `test_shark_uses_integrated_head_mesh`
   - Build a shark rig with `shark_mouth_gape = 0.28`, `shark_jaw_projection = 0.14`, `shark_lower_jaw_drop = 0.35`.
   - Assert `BodyPivot/Head` exists.
   - Assert `Head.get_meta("head_profile_type") == "shark"`.
   - Assert fish mouth geometry is absent:
     - `Head/Mouth`
     - `Head/MouthLowerJaw`
     - `Head/MouthCavity`
     - `Head/MouthFloor`
     - `Head/MouthLipUpper`
     - `Head/MouthDetail_*`
   - Assert old overlay-only mouth pieces are absent:
     - `Head/SharkMouth/MouthCrescent`
     - `Head/SharkMouth/LowerJaw`
     - `Head/SharkMouth/ProjectedUpperJaw`

2. `test_mouth_gape_changes_mouth_local_vertices`
   - Build two shark heads with identical parameters except `shark_mouth_gape = 0.0` and `0.36`.
   - Extract vertices from the head mesh in stable array order.
   - Compare matching vertex indices, not min/max `x` ranges.
   - Select mouth-local vertices from the closed mesh using a narrow analytic window:
     - `x` around the planned `mouth_u` region after converting `x -> u`.
     - `y` near `shark_mouth_position_y`.
     - `abs(z)` near the side surface band, not the whole underside.
   - Assert max mouth-window displacement is greater than `0.012`.
   - Assert the lower-mouth half moves downward more than the upper half moves upward when `shark_lower_jaw_drop > 0`.
   - Assert non-mouth vertices have substantially smaller displacement.

3. `test_lower_jaw_drop_is_not_noop`
   - Build two shark heads with identical `shark_mouth_gape = 0.28`, one with `shark_lower_jaw_drop = 0.0`, one with `0.4`.
   - Compare matching mouth-lower vertices whose analytic `mouth_weight >= 0.6`; do not average weak edge vertices into the metric.
   - Assert their average `y` delta is downward by at least `0.004`.

4. `test_rostrum_and_neck_are_closed`
   - Assert the front tip has no visible open ring:
     - Either the minimum-`x` ring radius is below `0.006`, or the cap triangles close the ring to a center vertex.
   - Assert the neck end has a cap or overlaps the body seam without an exposed hole.
   - Assert generated normals are non-zero and mostly outward by checking average normal dot product against normalized vertex radial direction is positive.

5. `test_mouth_line_has_crease_rings`
   - Inspect head mesh ring metadata or generated `u_samples`.
   - Assert at least three samples fall within the mouth band:
     - mouth front edge
     - mouth center
     - mouth rear edge
   - Assert adjacent spacing near `mouth_u` is smaller than ordinary body/neck spacing.

Implementation note for test helpers:

```gdscript
func _max_mouth_window_delta(closed_vertices: PackedVector3Array, open_vertices: PackedVector3Array) -> float:
    var max_delta := 0.0
    for i in range(min(closed_vertices.size(), open_vertices.size())):
        var p := closed_vertices[i]
        if _is_mouth_window_vertex(p):
            max_delta = maxf(max_delta, p.distance_to(open_vertices[i]))
    return max_delta
```

Do not re-add the broken `_mouth_region_recess_depth` metric.

## Task 2: Add Stable FishRig Hooks

Keep FishRig behavior unchanged, but create override points so SharkRig can replace only the head and dependent placement.

In `scripts/creature/FishRig.gd`:

1. Extract only the existing head factory call from `rebuild()` into a virtual method. Match the real `PrimitiveFactory.deformed_head(...)` signature:

```gdscript
func _create_head_node(
    name: String,
    shape: String,
    head_scale: Vector3,
    snout_length: float,
    forehead_slope: float,
    material: Material,
    sculpt: Dictionary = {}
) -> MeshInstance3D:
    return PF.deformed_head(name, shape, head_scale, snout_length, forehead_slope, material, sculpt)
```

2. Replace only the direct call in `rebuild()`:

```gdscript
head_node = _create_head_node("Head", head_shape, head_scale, snout_len, forehead_slope, head_mat, _head_sculpt_params())
```

3. Do not invent `HeadProfile.contour_radius_at_x(...)`. The existing contour hook is `FishRig._get_head_contour_radius(...)`; keep its seven-argument signature so SharkRig can override it:

```gdscript
func _get_head_contour_radius(
    x_local_unscaled: float,
    shape: String,
    forehead_slope: float,
    snout_length: float,
    snout_base: float = HeadProfile.SNOUT_BLEND_HALF,
    snout_thickness: float = 1.0,
    snout_taper: float = 0.0
) -> Vector2:
    # Existing fish implementation stays here.
```

4. Keep `_add_head_features(head, material)` virtual enough for SharkRig to skip fish mouth construction. Do not move eye creation into this hook; eyes are created by `_add_eyes(...)` later in rebuild and are handled in Task 6.

5. Confirm existing fish tests still pass before SharkRig overrides are added.

Expected state after Task 2: existing fish/ray behavior remains green; new shark tests remain red.

## Task 3: Implement SharkHeadProfile

Create `scripts/creature/SharkHeadProfile.gd`.

The profile must be deterministic and analytic. Attachments and tests must not guess surface positions independently.

Required constants:

```gdscript
const HEAD_U_SPAN := 0.25
const ROSTRUM_FRONT_X := -0.72
const NECK_X := 0.50
const DEFAULT_THETA_SEGMENTS := 32
const BASE_U_RINGS := 24
const MOUTH_EDGE_HALF_WIDTH_U := 0.055
const MOUTH_CREASE_EPSILON_U := 0.012
```

Required functions:

```gdscript
static func build_head(name: String, parameters: Dictionary, head_scale: Vector3, snout_length: float, forehead_slope: float, material: Material, sculpt: Dictionary = {}) -> MeshInstance3D
static func u_samples(parameters: Dictionary) -> PackedFloat32Array
static func point_at(parameters: Dictionary, u: float, theta: float, snout_length: float = 0.0, forehead_slope: float = 0.35, sculpt: Dictionary = {}) -> Vector3
static func surface_z_at(parameters: Dictionary, u: float, y: float, side: float = 1.0) -> float
static func mouth_anchor(parameters: Dictionary, side: float = 1.0) -> Vector3
static func mouth_corners(parameters: Dictionary, side: float = 1.0) -> Array[Vector3]
static func build_mouth_interior_shadow(parameters: Dictionary, material: Material = null) -> MeshInstance3D
static func contour_radius_at_x(parameters: Dictionary, local_x: float, snout_length: float = 0.0, forehead_slope: float = 0.35, sculpt: Dictionary = {}) -> Vector2
```

`build_head(...)` must create a `MeshInstance3D`, assign `node.name = name`, assign the generated mesh, set `node.scale = head_scale`, set `node.material_override = material`, and set `node.set_meta("head_profile_type", "shark")`.

### Ring Distribution

`u_samples(parameters)` must concentrate rings around the visible mouth line:

- Include `0.0` and `1.0`.
- Include base monotonic samples across the head.
- Insert mouth crease samples:
  - `mouth_u - MOUTH_EDGE_HALF_WIDTH_U`
  - `mouth_u - MOUTH_CREASE_EPSILON_U`
  - `mouth_u`
  - `mouth_u + MOUTH_CREASE_EPSILON_U`
  - `mouth_u + MOUTH_EDGE_HALF_WIDTH_U`
- Sort and deduplicate with a small epsilon.
- Clamp all samples to `[0.0, 1.0]`.
- Keep sample count/order stable for `gape` and `lower_jaw_drop` changes so tests can compare matching vertex indices.

This makes the crescent edge a real mesh feature instead of a blurred depression across large quads.

### Head Point Formula

`point_at(...)` should:

- Use a tapered rostrum profile; the `u = 0` tip must converge or be capped.
- Use an elliptical body-compatible neck near `u = 1`.
- Apply `snout_length` and `forehead_slope` so exposed shark sliders are not no-ops.
- Apply jaw projection in the lower-front mouth region.
- Apply mouth recess in `x` and `z`, using `mouth_weight(...)`.
- Apply lower jaw drop:
  - For vertices below mouth center, move `y` downward based on `shark_lower_jaw_drop * shark_mouth_gape`.
  - For vertices above mouth center, move `y` upward only lightly.
  - The side silhouette should show a real jaw notch when gape/drop are high.

Recommended deformation shape:

```gdscript
var mouth := mouth_weight(parameters, u, y, z)
var gape := clampf(float(parameters.get("shark_mouth_gape", 0.16)), 0.0, 1.0)
var drop := clampf(float(parameters.get("shark_lower_jaw_drop", 0.28)), 0.0, 0.4)
var drop_norm := drop / 0.4

if mouth > 0.0:
    x += mouth * (0.018 + 0.055 * gape)
    z *= 1.0 - mouth * (0.22 + 0.18 * gape)
    if y < mouth_center_y:
        y -= mouth * (0.020 + 0.050 * gape * drop_norm)
    else:
        y += mouth * (0.006 + 0.018 * gape)
```

Exact constants may be tuned, but the tests must prove `gape` and `drop` both produce visible, localized vertex displacement.

### Caps And Normals

- Add explicit front and rear caps, or taper the front to a pole and cap the rear.
- Keep triangle winding consistent with Godot outward normals.
- Call `SurfaceTool.generate_normals()`.
- Add test coverage for non-zero outward normals so an inverted mesh fails.

### UVs

Use fish-compatible UV density:

```gdscript
st.set_uv(Vector2(u * HEAD_U_SPAN, v))
```

Do not map shark head `u` directly to `0..1`, because that causes pattern scale discontinuity at the body seam.

### Contour And Surface Functions

`contour_radius_at_x(...)` must conservatively include dorsal/ventral bias used by `point_at(...)`, so seam and eye placement do not under-estimate the visible mesh envelope.

`surface_z_at(parameters, u, y, side)` must use the same ellipse, taper, mouth recess, and bias math as `point_at(...)`. This is the only accepted source for side-surface placement.

### Mouth Corners

`mouth_corners(parameters, side)` must solve the mouth-weight boundary analytically:

- Use `mouth_u`, mouth width, curve, and vertical mouth center.
- Find the side-surface points where the mouth band fades to zero.
- Return head-local left/right corner anchors.
- Support `side = 1.0` and `side = -1.0`; do not assume the mouth is only on the positive-z side.

`LabialFurrowLeft` and `LabialFurrowRight` must attach to these anchors. Side-visible mouth length is defined by these corners, not by arbitrary helper scale.

### Mouth Interior Shadow

`build_mouth_interior_shadow(...)` creates a real ribbon mesh inside the dent:

- Follow the same `mouth_weight` isoline used by the head recess.
- Sit slightly inside the side surface, not in body-pivot space.
- Use dark material with no large floating box, crescent plane, or fixed z offset.
- Span from one analytic mouth corner to the other.
- Follow the lower-jaw drop so the dark interior opens with gape.

The intended visual is a dark crescent/ribbon embedded in the recessed mouth, not a separate black prop hovering near the snout.

Expected state after Task 3: profile unit-level helpers can be called, but rig-level shark tests may still be red until Task 4.

## Task 4: Integrate Shark Head In SharkRig

In `scripts/creature/SharkRig.gd`:

1. Preload `SharkHeadProfile.gd`.

2. Override `_create_head_node(...)`:

```gdscript
func _create_head_node(
    name: String,
    shape: String,
    head_scale: Vector3,
    snout_length: float,
    forehead_slope: float,
    material: Material,
    sculpt: Dictionary = {}
) -> MeshInstance3D:
    return SharkHeadProfile.build_head(name, parameters, head_scale, snout_length, forehead_slope, material, sculpt)
```

3. Override the existing seven-argument `_get_head_contour_radius(...)` to call `SharkHeadProfile.contour_radius_at_x(parameters, x_local_unscaled, snout_length, forehead_slope, _head_sculpt_params())` and return unscaled radii, because `_apply_head_shell_metrics(...)` multiplies the returned contour by `head_scale`.

4. Override `_add_head_features(...)` to skip fish head ornaments/gill marks/barbels/snout appendages and fish mouth creation. This hook should create only the shark mouth root or shark mouth attachments. Do not add shark eyes here; eye placement belongs to Task 6 through `_eye_layout()` or `_add_eyes(...)`.

   If `SharkMouthMarking.gd` still emits old overlay nodes at this point, skip attaching it until Task 5 or create only an empty `Head/SharkMouth` root. `SharkHeadMeshTest` must not require teeth yet, but it must require old overlay nodes to be absent.

5. Remove the old defensive `_remove_fish_mouth_nodes()` cleanup once fish mouth nodes are never created for shark mode.

6. Rebuild shark features from `rebuild()`:
   - Keep the existing fix where gill markings survive direct `rebuild()`.
   - Reattach the shark mouth helper after the new head exists.

7. Verify `SharkHeadMeshTest` now passes.

Expected state after Task 4: integrated head mesh tests green; attachment rendering tests may still fail until Task 5.

## Task 5: Convert SharkMouthMarking To Attachments Only

`scripts/creature/SharkMouthMarking.gd` should no longer draw the crescent mouth, lower jaw box, or projected upper jaw overlay.

It should build only:

- `Head/SharkMouth/AttachmentSocket`
- `UpperTeeth`
- `LowerTeeth`
- `LabialFurrowLeft`
- `LabialFurrowRight`
- `MouthInteriorShadow` directly under `Head/SharkMouth` or another non-inverse-scaled child

### Inverse-Scale Socket

Because `Head` uses non-uniform scale, direct children would distort teeth and furrows. Add an inverse-scale socket for teeth and furrows:

```gdscript
var socket := Node3D.new()
socket.name = "AttachmentSocket"
socket.scale = Vector3(
    1.0 / maxf(absf(head.scale.x), 0.001),
    1.0 / maxf(absf(head.scale.y), 0.001),
    1.0 / maxf(absf(head.scale.z), 0.001)
)
root.add_child(socket)
```

Add teeth and furrows under this socket. Do not add `MouthInteriorShadow` under this socket.

### Socket Coordinate Conversion

`SharkHeadProfile` returns unscaled Head-local anchors, matching the mesh vertex coordinate system before `Head.scale` is applied.

For any child under `AttachmentSocket`, convert anchor coordinates before assigning `position`:

```gdscript
static func _socket_position_for_head_anchor(anchor: Vector3, head: MeshInstance3D) -> Vector3:
    return Vector3(anchor.x * head.scale.x, anchor.y * head.scale.y, anchor.z * head.scale.z)
```

Reason: `AttachmentSocket.scale = 1.0 / head.scale`, so setting `child.position = anchor` would cancel the head scale and place the child too close to the origin. Setting `child.position = anchor * head.scale` produces the same global location as a mesh vertex at `anchor`.

`MouthInteriorShadow` is the opposite case: it is generated from the same profile coordinates as the head mesh and must receive `Head.scale`. Add it under `Head/SharkMouth` without inverse-scale compensation, or keep its mesh vertices in the parent head-local coordinate system with no inverse-scaled ancestor.

### Placement

- Use `SharkHeadProfile.mouth_anchor(...)`, `mouth_corners(...)`, and `surface_z_at(...)`.
- Never use `body_width * 0.5x` or a fixed body-pivot z offset.
- Generate mirrored side anchors/attachments where the mouth detail should be visible on both sides.
- `MouthInteriorShadow` comes from `SharkHeadProfile.build_mouth_interior_shadow(...)`.
- `MouthInteriorShadow` must be head-scaled geometry; it should line up with the recess after `Head.scale` is applied.
- Teeth sit on the embedded mouth line and follow gape/drop.
- Labial furrows attach to analytic mouth corners.

### Tests

Update `scripts/tools/SharkMouthRenderingTest.gd`:

- Assert `BodyPivot/Head/SharkMouth/AttachmentSocket` exists.
- Assert `UpperTeeth`, `LowerTeeth`, `LabialFurrowLeft`, and `LabialFurrowRight` exist under `AttachmentSocket`.
- Assert `MouthInteriorShadow` exists outside `AttachmentSocket` under a head-scaled root.
- Assert old overlay nodes are absent:
  - `MouthCrescent`
  - `LowerJaw`
  - `ProjectedUpperJaw`
- Assert all attachment global positions are close to sampled head surface, using `SharkHeadProfile` or mesh vertex distance.
- Assert teeth are not visibly distorted by head non-uniform scale:
  - compare socket global basis scale components, or compare tooth mesh local AABB ratios.

Expected state after Task 5: `SharkMouthRenderingTest` green.

## Task 6: Shark Eye Placement

Current fish eye placement is based on fish ellipsoid/head-profile assumptions. Shark head geometry changes the rostrum and side surface enough that eyes can float or bury.

Add a SharkRig eye placement override or hook. Prefer overriding `_eye_layout()` because `_add_eyes(...)` and `_reposition_eyes()` already route through it:

- Use `SharkHeadProfile.surface_z_at(...)` at the chosen eye `u/y`.
- Keep eyes outside the side surface by a small outward inset.
- Keep existing eye style, color, and user parameters where possible.
- Preserve fish/ray behavior.
- Do not route eye placement through `_add_head_features(...)`; fish eyes are not created there.

Add or extend a test:

- Build a shark with default eyes.
- Assert eye nodes exist.
- Assert eye global/local positions are within a small offset from shark head side surface.
- Assert changing shark rostrum/snout parameters does not leave eyes inside the mesh or detached from it.

Expected state after Task 6: eye placement verified against shark head surface.

## Task 7: UI Slider Contract

Prevent no-op controls in shark mode.

Controls that must affect shark head mesh:

- `head_size`
- `head_offset`
- `snout_length`
- `forehead_slope`
- `shark_mouth_position_x`
- `shark_mouth_position_y`
- `shark_mouth_width`
- `shark_mouth_curve`
- `shark_mouth_gape`
- `shark_jaw_projection`
- `shark_lower_jaw_drop`
- shark tooth controls

Keep `shark_lower_jaw_drop` at `0.0..0.4` unless this task deliberately widens both `HeadEditorPanel.SLIDER_RANGES` and `ParameterPanel` signed/range logic, then updates all tests to the same range.

Controls to hide in shark mode unless implemented in `SharkHeadProfile`:

- `head_shape`
- `head_bump_height`
- `head_bump_pos`
- `head_bump_width`
- `head_bump_angle`
- `head_bump_round`
- `head_top_flatness`
- `head_bottom_flatness`
- `head_left_flatness`
- `head_right_flatness`
- fish-specific `snout_*` controls not mapped to shark rostrum geometry
- fish `mouth_*`, `jaw_*`, `lower_jaw_*` controls

Update:

- `HeadEditorPanel.gd`
- `ParameterPanel.gd`
- `UiText.gd`
- `HeadEditorPanelTest.gd`
- `ParameterModeVisibilityTest.gd`

Expected state after Task 7: shark mode exposes only controls that either affect the shark mesh or attachments.

## Task 8: Seam And Gill Regression

Add/extend tests to prove the new head does not break existing shark body features.

1. `test_shark_head_neck_matches_shell`
   - Compare `SharkHeadProfile.contour_radius_at_x(...)` near `NECK_X` to the first body shell contour.
   - Allow small tolerance, but fail obvious gaps/overlaps.

2. `test_rebuild_preserves_shark_head_mouth_and_gills`
   - Call `shark.rebuild()` directly.
   - Assert `Head` remains shark profile.
   - Assert `Head/SharkMouth` exists.
   - Assert `SharkGillSlits` exists.

3. Keep current gill rendering tests green:
   - Slits sample shell/body surface.
   - Slit length and spacing do not collapse into one vertical column.
   - No fixed `body_width * 0.52` placement regression.

Expected state after Task 8: new head, mouth attachments, and existing gills survive direct rebuilds.

## Task 9: Presets And Defaults

Revisit shark defaults after integrated mesh exists.

Defaults should be normalized and robust across `basic_shark.json` and `장.json`:

- `shark_mouth_position_x`
- `shark_mouth_position_y`
- `shark_mouth_width`
- `shark_mouth_curve`
- `shark_mouth_gape`
- `shark_jaw_projection`
- `shark_lower_jaw_drop`
- shark tooth controls
- gill length/spacing defaults already changed by prior gill fix

Rules:

- Do not tune by fixed body-pivot z offsets.
- Defaults must work on the slimmer shark presets, not only on the old test body.
- Fish presets must still remove `shark_mouth_*` during normalization.
- Shark presets must preserve `shark_mouth_*`.

Expected state after Task 9: preset normalization and default visual placement agree.

## Task 10: Verification

Run focused tests first:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMeshTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRenderingTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkGillSlitRenderingTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter RigImmediateRebuildTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibilityTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Then run the full Godot CLI suite:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

Run:

```powershell
git diff --check
```

Manual visual review:

- Default `basic_shark`.
- `장` preset.
- High gape + high lower jaw drop.
- Long rostrum / short rostrum.
- Ring editor direct rebuild path.
- Side and three-quarter camera angles.

## Review Checklist

- [ ] No shark fish-mouth nodes are created.
- [ ] No old floating `MouthCrescent`, lower-jaw box, or projected-upper-jaw overlay remains.
- [ ] Mouth line is created by dense mesh rings/crease samples around `mouth_u`.
- [ ] Lower jaw drop visibly moves lower mouth vertices.
- [ ] Mouth interior shadow is an embedded ribbon following the same recess contour.
- [ ] Mouth corners are analytic anchors and furrows attach there.
- [ ] Side-visible mouth features are not hard-coded to `+z` only.
- [ ] Teeth and furrows are protected from non-uniform `Head` scale by an inverse-scale socket.
- [ ] Rostrum and neck do not expose holes.
- [ ] Normals face outward.
- [ ] UV density matches fish head `HEAD_U_SPAN`.
- [ ] Shark eyes sit on the shark head surface.
- [ ] Shark mode has no exposed no-op head/mouth sliders.
- [ ] Direct `rebuild()` preserves shark head, mouth attachments, and gills.
- [ ] Gill shell-sampling regression tests remain green.
- [ ] Fish and ray tests remain green.
