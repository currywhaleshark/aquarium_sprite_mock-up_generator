# Operculum Shader-Marking Refactor (v4 — full rewrite)

## Why a full rewrite

The operculum has been chased through three geometry revisions (v1 decals, v2 anatomical
shape, v3 shell clearance) and still fights us: it floats, wings out in front view, z-fights,
gets buried under the shell, and intrudes on the eye. **Every one of those is an artifact of
the representation: separate outset meshes pasted on top of the head surface.**

Research into how stylized fish are actually built (ABZU/Giant Squid shader fish, PolyStyle
mobile fish using gradients + material IDs, Substance-textured stylized fish, low-poly edge-
loop topology) shows nobody floats decal meshes for gills or mouth lines. They either **paint
the marking onto the surface** (texture / vertex color / shader) or **model it into the base
mesh topology**. Our own mouth already does the topology approach (the head IS the upper jaw,
carved in `deformed_head_mesh`). The operculum is the last feature still floating decals.

Decisive fact: **we already have the right tool.** `shaders/fish_body_toon.gdshader` is a
UV-driven surface-marking engine (countershading, patterns, an 8-slot species-marking system,
lateral line, scales, iridescence). Its header states the principle we keep violating: *"All
coordinates come from the mesh UV (topological), never from world/model position. This keeps
the pattern painted on the surface, so it bends, turns, and rolls WITH the body instead of
sliding (shimmering)."* The operculum belongs here, as a painted marking — not as geometry.

This spec deletes the operculum geometry path entirely and reimplements it as a dedicated
shader feature on the head material, like `lateral_line` and the scale layers.

## Key UV facts (verified)

- Head mesh UV (`deformed_head_mesh`): `UV.x` (= shader `v_long`) runs `0` (snout) →
  `HEAD_U_SPAN = 0.25` (neck). `UV.y` wraps the circumference, seam-duplicated.
- Shader vertical axis: `up = sin(v_circ * TAU)` → `+1` dorsal, `−1` belly, **`0` on BOTH
  flanks** (v_circ ≈ 0 and ≈ 0.5). So a marking centered at `up = 0` paints **both sides at
  once** and excludes back/belly — bilateral with no L/R nodes, no mirroring, no floating.
- The head uses its own `ShaderMaterial` (`head_node.material_override`, a duplicate of the
  body material with `is_head = true`). Gating the operculum block on `is_head` makes it paint
  the head only, never the body shell.
- The operculum sits on the rear flank of the head, roughly `v_long ∈ [0.13, 0.225]`,
  `up ∈ [−0.5, 0.5]`. Final values are tuned by render (see Tuning).

## Shader changes — `shaders/fish_body_toon.gdshader`

### New uniforms (near the lateral_line / scale uniforms)

```glsl
uniform bool  operculum_enabled = false;
uniform vec2  operculum_u   = vec2(0.139, 0.224);   // anterior_u, posterior_u (v_long)
uniform vec2  operculum_up  = vec2(0.0, 0.45);      // center_up, half_height (up axis)
uniform float operculum_open  : hint_range(0.0, 1.0) = 0.0;
uniform float operculum_ridge : hint_range(0.0, 1.0) = 0.45;
uniform vec4  operculum_line_color  : source_color = vec4(0.08, 0.10, 0.11, 1.0);
```

The opercle **plate** is drawn by darkening the *local* surface colour (`col`), not a fixed
plate colour, so the cover follows the countershading gradient and never clashes where it dips
toward the belly tone. Only the hard dark seam/slit needs an explicit colour
(`operculum_line_color`).

### New fragment block

Place it in `fragment()` **after** the species-marking block (so it composites over patterns)
and before the soft top→bottom form shade. Reuses the existing `band_range()` helper.

```glsl
// 2d. Operculum (gill cover). Head-only, painted in UV so it rolls with the head and can
// never float, wing out, z-fight, or bury under the shell. Composites four anatomical reads:
// the opercle plate (soft darken), the preopercle seam (front J), the gill opening (dark rear
// arc = posterior free margin), and an open-pose highlight rim. "open" is a shader pose, not
// geometry: the rear arc darkens/widens and a bright rim hints the lifted free edge.
if (is_head && operculum_enabled) {
    float au = operculum_u.x;
    float pu = operculum_u.y;
    float cup = operculum_up.x;
    float half_up = max(operculum_up.y, 0.001);
    float soft = 0.02;

    // Fan envelope: broad opercle in the middle, narrow at the front hinge and rear margin.
    float ut = clamp((v_long - au) / max(pu - au, 0.001), 0.0, 1.0);
    float env = mix(0.62, 1.0, sin(ut * PI));
    float top = cup + half_up * env;
    float bot = cup - half_up * env;

    float u_mask = band_range(v_long, au, pu, soft);
    float v_mask = smoothstep(top + soft, top - soft, up) * smoothstep(bot - soft, bot + soft, up);
    float plate = u_mask * v_mask;

    // Opercle plate: darken the LOCAL surface so it blends with countershading.
    col = mix(col, col * mix(0.80, 0.58, operculum_ridge), plate);

    // Preopercle seam: soft dark line just behind the front edge.
    float seam_x = au + 0.006;
    float seam_w = 0.010 + 0.010 * operculum_ridge;
    float seam = v_mask * (1.0 - smoothstep(0.0, seam_w, abs(v_long - seam_x)));
    col = mix(col, operculum_line_color.rgb, seam * mix(0.18, 0.45, operculum_ridge));

    // Gill opening (posterior free margin): dark arc at the rear, widening/shifting on open.
    float slit_x = pu + operculum_open * 0.010;
    float slit_w = (0.006 + 0.016 * operculum_ridge) * (1.0 + 0.8 * operculum_open);
    float slit = v_mask * (1.0 - smoothstep(0.0, slit_w, abs(v_long - slit_x)));
    col = mix(col, operculum_line_color.rgb, slit * mix(0.5, 0.85, operculum_ridge));

    // Open-pose highlight rim: a thin bright edge just in front of the opening.
    float rim_x = slit_x - slit_w * 1.8;
    float rim = v_mask * (1.0 - smoothstep(0.0, slit_w * 0.8, abs(v_long - rim_x))) * operculum_open;
    col = mix(col, min(col * 1.6 + 0.10, vec3(1.0)), rim * 0.4);
}
```

No other shader change is required. (Note: the existing `marking_zone_*` uniforms are declared
but unread; that latent gap is out of scope here because the operculum uses its own
`is_head`-gated block, not a generic marking slot.)

## GDScript changes

### `scripts/materials/ToonMaterialFactory.gd` — `make_body_material`

After the existing marking-uniform loop, drive the operculum uniforms from `parameters`
(the same flat dict already holds `gill_mark` and `operculum_*`):

```gdscript
var gill_mark := String(parameters.get("gill_mark", "none"))
var op_on := gill_mark == "operculum"
material.set_shader_parameter("operculum_enabled", op_on)
if op_on:
    var op_size := clampf(float(parameters.get("operculum_size", 1.0)), 0.5, 1.5)
    var op_height := clampf(float(parameters.get("operculum_height", 1.0)), 0.5, 1.5)
    var posterior_u := 0.224
    var anterior_u := posterior_u - 0.085 * op_size
    material.set_shader_parameter("operculum_u", Vector2(anterior_u, posterior_u))
    material.set_shader_parameter("operculum_up", Vector2(0.0, 0.45 * op_height))
    material.set_shader_parameter("operculum_open", clampf(float(parameters.get("operculum_open", 0.0)), 0.0, 1.0))
    var op_ridge := clampf(float(parameters.get("operculum_ridge", 0.45)), 0.0, 1.0)
    material.set_shader_parameter("operculum_ridge", op_ridge)
    material.set_shader_parameter("operculum_line_color", Color.html("#15191b"))
```

`FishRig` already builds the head material as `make_body_material(parameters).duplicate()` with
`is_head = true`, so these uniforms reach the head and the block is gated correctly. No change
needed to the duplication path itself.

### `scripts/creature/FishRig.gd` — delete the geometry path

- In `_add_head_features`: remove the operculum plumbing added in v2/v3 — `head_verts` (if only
  used for the operculum), `operculum_ridge`/`plate_darken`/`opercle_mat`/`opercle_seam_mat`,
  `head_scale_z`/`shell_clear`. Restore `_add_gill_mark` to its simple signature
  `(head, mark, dark_mat)`.
- In `_add_gill_mark`: **remove the `"operculum"` match arm entirely** (the shader now draws
  it; no node is created). Keep `line`, `crescent`, `plate` exactly as they are.
- Delete the now-dead helpers: `_operculum_params`, `_operculum_envelope`, `_operculum_outset`,
  `_operculum_plate_mesh`, `_operculum_ribbon_mesh`, `_add_operculum_side`.
- `_head_mesh_side_z`'s `max_sample_x` parameter (added in v2) may stay; it is harmless and the
  mouth callers use the default. No need to revert.

### UI / data model — unchanged

`gill_mark` keeps `"operculum"` in `GILL_MARKS`; the four `operculum_*` sliders still show only
when `gill_mark == "operculum"` (existing `_should_show_fish_numeric_key`). The keys stay in the
`fin_profile` pick list (they still save/load identically). **No preset migration.** They now
drive the head shader instead of geometry — transparent to the editor and to saved presets.

## Tuning (render, not guesswork)

The defaults above are starting points. Render side / three-quarter / front / open and adjust:

- `posterior_u` (0.224): the gill opening's longitudinal position — move so it sits at the
  rear of the cheek, ahead of the neck seam.
- `0.085 * size`: cover length at default size.
- `0.45 * height`: vertical half-extent on the flank.
- `env` end value (0.62): how much the fan narrows at the hinge/margin.

## Tests

The operculum is no longer geometry, so the node-based assertions in `HeadEditorModelTest.gd`
must be replaced with **material-uniform** assertions. This is the bulk of the test work.

### HeadEditorModelTest.gd — replace the operculum block

Read the head ShaderMaterial. **`set_parameters()` rebuilds the rig and creates a NEW head
material every call, so re-fetch `head`/`head_mat` after each `set_parameters` + frame** — a
reference captured before a rebuild is stale and will read old uniform values:

```gdscript
var head := fish.get_node_or_null("BodyPivot/Head") as MeshInstance3D
var head_mat := head.material_override as ShaderMaterial
```

Assert (default operculum params):

```text
# Enabled only for operculum; no geometry node is created.
assert(bool(head_mat.get_shader_parameter("operculum_enabled")) == true)
assert(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum") == null)

# Size grows the cover forward (anterior_u decreases), rear pinned.
var base_u: Vector2 = head_mat.get_shader_parameter("operculum_u")
... set operculum_size = 1.45, rebuild ...
var big_u: Vector2 = head_mat.get_shader_parameter("operculum_u")
assert(big_u.x < base_u.x - 0.02)        # anterior moved forward
assert(absf(big_u.y - base_u.y) < 0.001) # posterior pinned

# Height grows the vertical half-extent.
... operculum_height = 1.45 ...
assert(Vector2(head_mat.get_shader_parameter("operculum_up")).y > 0.45 * 1.2)

# Open / ridge pass through.
... operculum_open = 1.0 ... assert(float(...operculum_open) > 0.99)
... operculum_ridge = 1.0 ... assert(float(...operculum_ridge) > 0.99)
```

Assert disabling:

```text
# Non-operculum gill marks: shader off, their own nodes still build.
... gill_mark = "line" ...
assert(bool(head_mat.get_shader_parameter("operculum_enabled")) == false)
assert(fish.get_node_or_null("BodyPivot/Head/GillMark_line") != null)
```

Delete all `Opercle*/PreopercleSeam*/GillSlit*/SubopercleSeam*/OpercleRim*` lookups and the
operculum-only mesh helpers (`_mesh_average_x`, `_mesh_rear_edge_*`, `_mesh_min_z/max_z`, etc.)
if nothing else uses them.

### HeadEditorPanelTest.gd / PresetNormalizationTest.gd — unchanged

The option list and the four numeric keys are untouched, so existing visibility and round-trip
tests still pass as-is.

### Manual render check (required — uniforms can't prove it looks right)

Render side, three-quarter, front, and open. Confirm: the cover reads as a gill cover painted
on the cheek; the gill opening is its rear edge; no floating bar, no front-view wings, no
z-fight, no eye overlap artifact; `operculum_open` visibly opens the rear with a highlight rim.

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

## Acceptance Criteria

- The operculum is drawn entirely by the head shader; **no `GillMark_operculum` node exists**.
- Reads as a gill cover on the cheek: opercle plate, front preopercle seam, dark rear gill
  opening, on **both** flanks, excluding back/belly.
- **None** of the old failure classes are possible: no floating, no front-view wings, no
  z-fighting, no shell occlusion, no eye intrusion (it is surface paint, not geometry).
- `operculum_size/height/open/ridge` behave: size grows the cover forward, height grows its
  depth, open lifts/darkens the rear margin with a highlight, ridge raises contrast.
- Existing `line/crescent/plate` gill marks unchanged. Shell, fins, eyes, mouth, export, UI,
  and saved presets unaffected. CLI tests pass; manual render confirms the look.

## Non-Goals

- Do not migrate `line/crescent/plate` to the shader in this pass (separate, optional later).
- No breathing animation beyond the static `operculum_open` pose (shader-driven open can be
  animated later by tweening the uniform).
- Do not fix the unrelated `marking_zone_*` latent gap here.
- Do not move `operculum_*` keys to `visual_profile`; leave them in `fin_profile` (no migration).
- No new gill-mark option, no new numeric control, no head_profile migration.
```
