# Plan: Merge shark head mesh + body shell into one continuous surface

## Context

The shark (and every fish) renders its head and its body as **two separate meshes** that meet
at the neck:

- **Head** — a rigid `MeshInstance3D` (`SharkHeadProfile.build_head` for sharks,
  `PF.deformed_head` for fish). Each frame it is moved as a unit: `head_node.position`/`yaw`
  ride the animated neck point (`FishRig._apply_animated_head`, FishRig.gd:1161).
- **Body shell** (`outer_shell`) — a procedural tube **CPU-rebuilt every frame** by sweeping a
  cross-section along a bent centerline (`PF.update_fish_outer_shell_bent` →
  `build_fish_outer_shell_mesh`, PrimitiveFactory.gd:1062/1068), driven by the swim wave.

They are glued at the neck by forcing the shell's first 2 rings onto the head's rigid transform
(FishRig.gd:1080-1090) and by an elaborate enclosure/neck-smoothing layer in the shell builder
(`_apply_head_shell_metrics`, `_smooth_neck_shell_profile`).

Because they are two surfaces with independent normals/UVs, the seam shows a **soft shading
crease**, and because the join is tuned with constants, small parameter edits reopen a step
(seen on user preset `상어2`: wide body 0.5 + small head 0.34). Recent work removed the gross
silhouette step/poke-through and made the neck smoothing proportion-robust, but the *shading
crease* and the *fragility* are inherent to the two-mesh architecture.

---

## Current state & handoff notes (READ FIRST)

**Branch:** `fix/head-shell-neck-seam`. Nothing in this merge plan is implemented yet — the work
below is the *next* step. But several **seam fixes already landed on this branch** in the
current session; the next worker must understand them because Phase 4 may retire them:

1. **Enclosure-floor fix** (`FishRig._apply_head_shell_metrics`): the floor was
   `maxf(target, r_head + exp_offset)` — it re-added the full clearance and spiked one neck ring
   into a proud silhouette shelf. Now `maxf(target, r_head + HEAD_SHELL_ATTACH_EPSILON)`.
2. **Shark neck tuck** (`SharkHeadProfile._base_radii`): added
   `neck_tuck = 1.0 - 0.42*smoothstep(0.74,1.0,u)` so the blunt head rear ducks under the shell.
3. **Robust neck smoothing** (`FishRig._smooth_neck_shell_profile`, rewritten): relaxes the neck
   (snout→front_body) onto a smooth ramp in y, z AND center_y, clamped up to a per-ring head
   floor. To support this, `_apply_head_shell_metrics` now returns `floor_y`/`floor_z`, captured
   into new member arrays `shell_head_floor_y` / `shell_head_floor_z` during the build loop.
   These floor arrays are exactly what Phase 1's "canonical neck ring" should reuse.

These removed the gross silhouette step/poke-through and made the neck *proportion-robust*, but
the **soft two-mesh shading crease** and a mild **collar lip** on extreme proportion mismatch
remain — that is what the full merge is for. Verified state: `basic_shark` and `네온테트라`(fish)
clean; `상어2` shoulder now smooth (was a faceted shelf). Tests green: `HeadShellSeamTest`
(arowana 0.985–0.986), `SharkHeadMeshTest`, `HeadShellAttachmentTest`, `RingHeightDecoupleTest`.
`ShellRigTest` fails pre-existing at line 24 (ring-3 movement) on a clean baseline — unrelated,
ignore.

**New dev tool already added this session:** `scenes/SharkNeckSeamShot.tscn` +
`scripts/tools/SharkNeckSeamShot.gd` — renders the neck via the **real SharkRig** (head mesh +
shell) at side/neck/q34_zoom/top. Accepts `-- preset=<name> tag=<tag>`; default preset is
`res://presets/basic_shark.json`, or pass `preset=상어2` to load a user preset by name. Output:
`exports/_shots/shark_neck/<view>_<tag>.png`. The **top view shows the dorsal collar best.**
`NeonSeamShot` is **FishRig-only** (does NOT exercise the shark head mesh) — use it only for the
fish-regression check, not for sharks.

**Key numbers discovered (for grounding the merge math):**
- Shark `head_scale` from `SharkRig._head_scale_for_shape`: x = head_length·(0.86+snout_length·0.45),
  y = body_height·0.82·(head_size/0.44)·1.06·(1−flatten), z = body_width·0.92·(head_size/0.44)·(1+flatten·0.35).
- Head mesh local x runs `front_x(=ROSTRUM_FRONT_X −snout_length·0.35) .. NECK_X(0.50)`; rear cap
  at `NECK_X+0.003`. `contour_radius_at_x` maps shell world-x → head u via this span.
- Shell ring world-x = `lerp(start_x, end_x, ring.x)` where `start_x = head_offset − head_scale.x·0.22`,
  `end_x = body_length·0.48`. For basic_shark the shell's first ring (snout) lands near head
  **u≈0.73**, so the shell only wraps the head's rear quarter; everything forward is exposed face.
- Why `상어2` reopened the step: `body_width 0.5` (≈2× basic's 0.26) + `head_size 0.34` (< 0.48) →
  wide body, small head → body shoulder looms over the head. The earlier per-preset constants
  didn't adapt; the rewritten smoothing does.

**Memory:** project memory `head-shell-neck-seam.md` has the full seam history and gotchas
(shell is opaque; `shell_opacity` is a dead no-op; enclosure floors on BOTH y and z; etc.).

---

**Goal:** Build the head and body as **one continuous ArrayMesh** with shared normals and
continuous UVs, deforming correctly (rigid head + waving body, smooth neck), so the seam
crease disappears and the junction is robust by construction. **Generic across head types**
(shark / fish / cephalofoil) — not a shark-only hack.

**Non-goals:** Changing head/body *shapes* or controls; changing fins/markings appearance;
GPU/skeleton rewrite (we keep the existing CPU per-frame rebuild model).

## Recommended approach: concatenate + weld into one ArrayMesh ("Strategy 2")

Reuse both existing cross-section samplers; do **not** reduce the head to the shell's egg
model (the head needs snout taper, dorsal/ventral asymmetry, the crown bump's x-shift, the
mouth seam, and the rear cap, which the egg model can't express). Instead:

1. Build the **head section grid** once (rest pose) from the existing head sampler
   (`SharkHeadProfile._build_head_mesh` / `deformed_head_mesh`), and the **body section grid**
   from the existing sweep — but emit **both into a single `ArrayMesh`** (one vertex/normal/UV/
   index buffer).
2. **Share one canonical "neck ring"** so the weld is seamless: over a blend band the head's
   rear rings and the body's front rings both converge to the same cross-section, and the two
   sections literally share that boundary ring's vertices. One `generate_normals()` (or a weld +
   normal-average) across the whole surface removes the shading crease.
3. **Continuous UVs:** drive *both* sections from the shell longitudinal map `u(x)`
   (`_shell_longitudinal_uv_map`, FishRig.gd:637; consumed via `_long_u_for_world_x`,
   PrimitiveFactory.gd). The fish head already does this (`deformed_head_mesh` long_map params);
   extend the shark head builder to consume the same map instead of its private `HEAD_U_SPAN`.
4. **Per-frame deformation:** the head shape does not change with the swim wave, only its
   placement. So build the head grid once and each frame **rigidly transform** the head vertex
   block (head position+yaw, already computed), **morph the neck band** from rigid→wave, and
   rebuild the body block with the existing sweep — all written into the same mesh. This matches
   today's behavior (rigid head, waving body) and avoids re-sampling the head every frame.

### Why this over the alternative
A "single pluggable cross-section sweep" (one engine, head rings provide egg-equivalent radii)
is cleaner in theory but cannot represent the bump's x-shift or the mouth seam within a
fixed-x ring, and would force a rewrite of both samplers. Strategy 2 keeps both samplers,
builds the head once, and localizes the new work to *mesh emission + seam welding + attachment
re-anchoring*.

## Phases (each independently shippable / reversible)

**Phase 0 — Safety net (do first). Concrete spec:**
- New files: `scripts/tools/SharkHeadShellSeamTest.gd` (+ `.gd.uid`) and
  `scenes/SharkHeadShellSeamTest.tscn`. Model the scene 1:1 on `scenes/HeadShellSeamTest.tscn`
  (a single `Node` with the script as `ExtResource`, `path=`-based like
  `scenes/SharkNeckSeamShot.tscn`).
- Mirror `HeadShellSeamTest._max_escape` (FishRig.gd:13) exactly: get `BodyPivot/Head` verts,
  transform by `head.transform`, skip verts with `w.x <= shell_profile[0].x` (exposed snout) or
  `w.x >= shell_profile[last].x` (past head); for each remaining vert compute
  `t = fish._shell_attach_t_for_x(w.x)`, `prof = fish._sample_shell_profile(t)`,
  `cy = fish._sample_shell_center_y(t)`, `worst = max(worst, sqrt(ny²+nz²))` with
  `ny=(w.y−cy)/prof.y`, `nz=w.z/prof.z`. These FishRig helpers are inherited by SharkRig.
- Instantiate **`SharkRig`** (not FishRig). Build three cases, assert `worst <= 1.02` each
  (1.02 = the established `HeadShellSeamTest` tolerance):
  1. `basic_shark` params (load `res://presets/basic_shark.json`).
  2. high rear volume: `shark_head_rear_height = 0.8`, `shark_head_rear_width = 1.0`.
  3. wide-body/small-head (the `상어2` failure shape): `body_width = 0.5`, `head_size = 0.34`,
     `head_flattening = 0.11` (other keys from basic_shark).
- Pattern for build+probe: `shark = SharkRig.new(); add_child(shark); shark.set_parameters(p);
  await get_tree().process_frame` then probe. End with `print("SHARK_HEAD_SHELL_SEAM_TEST_OK");
  get_tree().quit(0)`. `*Test`-named scenes are auto-discovered by the CLI suite.
- Capture `before` shots (these are the merge baseline): `SharkNeckSeamShot` with
  `tag=premerge_basic` (basic_shark) and `preset=상어2 tag=premerge_s2`; `NeonSeamShot` with
  `preset=네온테트라 tag=premerge_neon` for the fish-regression baseline.

**Phase 1 — Static unified mesh (no animation change).**
- New `PrimitiveFactory.build_unified_creature_mesh(head_grid, body_profile, …)` that emits the
  head sampler grid + the body sweep into one `ArrayMesh`, sharing the neck ring, with one
  normal pass. Head section still built from the existing sampler.
- Define the **neck blend band**: a small u-range at the head rear and the first body rings
  where both cross-sections interpolate to a shared canonical neck ring (reuse the geometry of
  the current `_smooth_neck_shell_profile` ramp + `shell_head_floor_*`).
- Wire `FishRig.rebuild()` to produce the unified mesh into `outer_shell` (the head becomes part
  of it). Keep `head_node` as an **invisible transform-only anchor** (no mesh) so attachments
  keep working unchanged this phase.
- Validate: static (rest-pose) seam crease gone on all four presets; silhouette unchanged.

**Phase 2 — Animated unified mesh.**
- Replace the separate head-node transform + shell sweep with a single per-frame update of the
  unified mesh: body block via existing sweep; head block rigid-transformed by the head
  kinematics (`_apply_animated_head` math); neck band morphs rigid→wave so the shared ring
  matches the body's first ring exactly. Remove the "force first 2 rings" hack (1080-1090) — the
  morph band replaces it.
- Validate: swim/turn/death-pose animations keep the head rigid and the body waving with no
  seam tearing (`SharkNeckSeamShot` + manual `apply_pose` sweep; `TurnPoseTest`, death-pose
  scenes).

**Phase 3 — Re-anchor attachments to the head transform.**
- Eyes (`_add_eyes`/`_apply_animated_eyes`), shark mouth markings (`SharkMouthMarking`), gill
  slits (`SharkGillSlitMarking`), and the operculum (`_apply_animated_operculum`) currently key
  off `head_node`. Point them at the computed head transform (the same centers/yaws) so they
  ride the head identically. Keep `head_node` as a zero-mesh `Node3D` anchor if simplest.
- Validate: `EyeAttachmentTest`, `SharkGillSlitRenderingTest`, `SharkMouthRenderingTest`,
  `operculum` D-key debug, plus visual.

**Phase 4 — Generalize + retire crutches.**
- Make the unified builder head-type agnostic: shark uses `SharkHeadProfile`, fish uses
  `deformed_head_mesh`, cephalofoil its variant — selected the way `_create_head_node` is
  overridden today (`SharkRig._create_head_node`).
- Once the surface is continuous, the enclosure-floor / neck-smoothing layer
  (`_apply_head_shell_metrics` floors, `_smooth_neck_shell_profile`,
  `SharkHeadProfile` `neck_tuck`) is largely redundant. Simplify or keep a thin floor as a
  guardrail — decide after Phase 2 measurements. Do NOT delete until the unified path is proven
  on all presets.

**Phase 5 — Validation + regression lock-in.**
- All seam/head tests green; extend `SharkHeadShellSeamTest` to assert seam continuity (no
  duplicate-but-offset boundary verts).
- Visual before/after on basic_shark, `상어2`, neon, arowana.

## Critical files

- `scripts/creature/PrimitiveFactory.gd` — `build_fish_outer_shell_mesh` (1068),
  `deformed_head_mesh` (322), `_long_u_for_world_x`; **new** `build_unified_creature_mesh`.
- `scripts/creature/FishRig.gd` — `rebuild` (107), `_build_shell_profile_from_rings` (427),
  `_deform_shell` (1023), `_apply_animated_head` (1161), `apply_pose` (962), `_apply_head_shell_metrics`,
  `_smooth_neck_shell_profile`, `shell_head_floor_*`, `_shell_longitudinal_uv_map` (637),
  `_add_eyes`, `_apply_animated_eyes`.
- `scripts/creature/SharkRig.gd` — `_create_head_node` (34), `_get_head_contour_radius` (37),
  `_eye_layout`, `rebuild` (gill/mouth markings).
- `scripts/creature/SharkHeadProfile.gd` — `build_head`/`_build_head_mesh` (197), `point_at`,
  `_base_radii`, `_add_rear_cap` (rear cap becomes internal/removed once welded), consume
  long_map UV.
- `scripts/creature/HeadProfile.gd` — shared cross-section helpers (flat caps, offsets).
- Tests/tools: `scripts/tools/SharkNeckSeamShot.gd`, `HeadShellSeamTest.gd`,
  `SharkHeadMeshTest.gd`, **new** `SharkHeadShellSeamTest`.

## Key risks

- **Seam ring agreement:** head-rear and body-front cross-sections must produce identical
  boundary vertices or the weld re-cracks. Mitigation: compute one canonical neck ring and have
  both sides converge to it (reuse existing ramp/floor geometry).
- **Per-frame cost:** unified mesh is bigger; head is rebuilt only at `rebuild()`, per-frame is a
  rigid transform of the cached head block + body sweep, so cost ≈ today.
- **Attachment regressions:** eyes/mouth/gill/operculum re-anchoring touches several systems;
  Phase 3 is isolated and test-covered.
- **Shared FishRig path:** every fish uses this; gate with `HeadShellSeamTest` + neon visual at
  each phase.
- **Death pose / turn:** `_apply_death_pose` (180° flip) and turn kinematics must still place the
  head block correctly.

## Environment & quick start (cold-start ready)

- **Godot exe (non-headless / GPU):** `C:/Users/USER/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`
- **Shell:** Git Bash tool available; project root `C:/Users/USER/Documents/Projects/fish_sprite`.
- **GOTCHA — editor:** never run headless import/tests while the Godot editor is open. Check
  first: `tasklist | grep -i godot`. The visual shot scenes are GPU/non-headless and launch a
  separate window; still close the editor first to avoid import-cache races.
- **User presets on disk** (load by NAME via `PresetStore.load_all`, not path):
  `%APPDATA%/Godot/app_userdata/Procedural Aquarium Sprite Generator/presets/*.json` —
  includes `상어2.json`, `네온테트라.json`, `아로와나.json`, etc.
- **Run a test (headless):**
  `"$GODOT" --headless --path . scenes/SharkHeadShellSeamTest.tscn` → expect an `_OK` line.
- **Render a shark neck shot (non-headless):**
  `"$GODOT" --path . scenes/SharkNeckSeamShot.tscn -- "preset=상어2" tag=mytag` →
  `exports/_shots/shark_neck/*_mytag.png` (read the PNGs to inspect the seam).
- Inspect `MEMORY.md` → `head-shell-neck-seam.md` before touching the neck code.

## Verification

- Tests (headless, editor closed): `HeadShellSeamTest`, `SharkHeadMeshTest`,
  `HeadShellAttachmentTest`, `RingHeightDecoupleTest`, `EyeAttachmentTest`,
  `SharkGillSlitRenderingTest`, `SharkMouthRenderingTest`, new `SharkHeadShellSeamTest`.
  Godot: `C:/Users/USER/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe --headless --path . scenes/<Test>.tscn`.
- Visual (non-headless): `scenes/SharkNeckSeamShot.tscn -- preset=<name> tag=<tag>` for
  basic_shark, `상어2`; `scenes/NeonSeamShot.tscn` for fish; compare before/after in
  `exports/_shots/`. Sweep `apply_pose` phases to confirm the seam holds while swimming/turning.
- Never run headless while the Godot editor is open (check `tasklist | grep -i godot` first).

## Estimate

Multi-session. Phase 0–1 deliver the static seam fix and de-risk; Phase 2 is the core
deformation work; Phases 3–4 are breadth (attachments + generality). Each phase is reversible
and independently verifiable.
