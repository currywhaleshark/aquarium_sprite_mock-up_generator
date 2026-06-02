# Fin Softness / Flow Handoff - 2026-06-02

## Branch

- `codex/species-archetype-sprite-system`
- Builds on the species-archetype pack + per-fin material work already on this branch.
- Spec: `docs/superpowers/specs/2026-06-02-species-archetype-sprite-system-design.md`
  (this is an additive feature on top of that pack, not part of its acceptance set).

## Scope Completed

Added per-fin **softness / rigidity** controls that deform every fin into a soft,
flowing membrane that trails the swimming motion and droops under gravity as
softness rises. Started from a review of an earlier single-fin attempt and extended
it to all six fins, then reworked the motion model twice based on visual feedback.

## Parameter Model

- Per-fin keys, one pair per slot: `<slot>_softness`, `<slot>_rigidity` for
  `dorsal_1`, `dorsal_2`, `anal`, `pelvic`, `pectoral`, and `caudal`.
- Global `fin_softness` / `fin_rigidity` act as the **fallback default** when a slot
  has no explicit override (so an archetype can set one global value and every fin
  inherits it; the user can then override any single fin).
- Net softness = `clamp(softness) * (1 - clamp(rigidity))`, computed in
  `FishRig._effective_fin_softness(slot)`. `_effective_caudal_softness()` delegates to
  it with `"caudal"`.
- Round-trip: all new keys added to the `fin_profile` `_pick` list in
  `BodyProfile.split_parameters_into_profiles()`, so user presets save/load them.
- Existing archetype JSONs keep using the global `fin_softness` / `caudal_softness` /
  `fin_rigidity` keys; those still work as the global default + caudal override.
  No JSON changes were needed for the per-fin extension.
- UI: every slot in `FinEditorPanel.NUMERIC_KEYS` exposes softness + rigidity rows
  (each with `fallback_key` to the global). Korean labels in `UiText.PARAMETER_LABELS`
  (`<지느러미> 부드러움 / 빳빳함`). The old confusing standalone `fin_softness` row on
  the caudal slot was replaced with `caudal_softness` + `caudal_rigidity`.

## Animation Model (evolved over 3 passes)

The mesh is re-deformed each frame **only when the fin's net softness > 0.001**;
rigid fins keep the flat base mesh built in `rebuild()` (any parameter change re-runs
`rebuild()`, so a fin can never get stuck deformed). This means default fish (softness
0) are byte-identical to before and cost nothing extra.

1. **Tessellation first.** Coarse fin outlines (caudal ~5-7 pts) can't carry a smooth
   wave, so the soft path subdivides the outline 8× per edge via
   `PrimitiveFactory.subdivide_fin_outline()` before displacing. Rigid meshes are NOT
   subdivided, so their UVs / markings / export framing are unchanged.

2. **Motion-driven trailing, not self-oscillation (important).** The first version
   ran a free sine on `loop_phase` and read as the fin "wriggling on its own". It is
   now a trailing-lag wave locked to the structure's actual motion:
   - `_membrane_trail(drive_phase, tip_t, lag) = sin(φ) - sin(φ - tip_t·lag)` — the
     tip lags the base by `tip_t·lag`, so the membrane bends from the difference
     between the rigid swing and the lagged tip. Max billow as the motion crosses
     center (fastest), eased at the swing extremes, reversing with the swing.
   - `drive_phase` is phase-locked per fin: caudal → the tail swing phase
     (`loop_phase·TAU - phase_delay·2.4`); median (dorsal/anal) → the body wave
     (`loop_phase·TAU - phase_delay`); paired (pectoral/pelvic) → the ~2× scull beat.
   - `lag = 0.6 + softness·2.8` → softer/longer fins lag more and flow bigger.

3. **Amplitude scales with how hard the fish swims** — `_swim_drive_strength()` =
   `clamp(0.12 + |global_sway·tail_multiplier| / 14, 0, 1.3)`. A still fish settles; a
   swimming fish flows. Small floor keeps a gentle drift for hover-y fish (betta sway
   is only 6.0).

4. **Gravity droop** — a static sag toward **world-down** at the free tip, scaled by
   softness: `sag = FIN_SOFT_DROOP · softness · tip^1.3 · size_ref`, offset along
   `node.global_transform.basis.inverse() * Vector3.DOWN` so it hangs truly downward
   regardless of how the fin is rotated. Applied to caudal, paired, and median fins.

Tunable constants (top of the fin-deform block in `FishRig.gd`):
`FIN_SOFT_AMPLITUDE = 0.44` (flow size), `FIN_SOFT_DROOP = 0.24` (sag), the `lag`
coefficient `2.8`, and the `_swim_drive_strength` normalization (`/14`, floor `0.12`,
cap `1.3`).

## Key Functions (FishRig.gd)

- `_effective_fin_softness(slot)` / `_effective_caudal_softness()` — net softness.
- `_swim_drive_strength()` — motion envelope shared by all fins.
- `_membrane_trail()` — the trailing-lag shape.
- `_membrane_deformed_points(base, softness, drive_phase, drive_strength, phase_offset, size_ref, down_local)`
  — subdivide + trail-displace z + droop; used by caudal and paired fins.
- `_animate_caudal_fin()` — rebuilds the tail mesh (rigid → early return).
- `_animate_blade_fin(node, base_points, loop_phase, phase_offset)` — pectoral/pelvic;
  L/R desynced by passing `phase_offset` 0 / PI.
- Median fins fold the same trail + droop into `_animated_curved_fin_points()`, on top
  of the existing body-wave tilt.
- Paired-fin base outlines are captured at build time into `pectoral_base_points` /
  `pelvic_base_points` (oval shapes via new `PrimitiveFactory.oval_fin_points()`).
- `_animate_caudal_fin` was also de-duplicated: `apply_pose`'s direct branch now only
  deforms the caudal in the shell-less fallback, since `_apply_animated_tail` (driven
  by the body shell) is the authoritative path otherwise.

## Files Changed

- `scripts/creature/FishRig.gd` — all of the above.
- `scripts/creature/PrimitiveFactory.gd` — `subdivide_fin_outline()`,
  `oval_fin_points()`.
- `scripts/creature/BodyProfile.gd` — new per-fin keys in the `fin_profile` `_pick`.
- `scripts/ui/FinEditorPanel.gd` — softness/rigidity rows on all 6 slots.
- `scripts/ui/UiText.gd` — Korean labels for the per-fin keys.
- Tests: `FinEditorPanelTest.gd` (new keys + `pectoral_rigidity`),
  `FinEditorModelTest.gd` (caudal rigid/soft bounds + a pectoral soft/rigid case;
  eel-ripple test zeroes softness to isolate body-wave following).

## Tests

Run individually (the `-ExecutionPolicy Bypass` form is blocked here — call the script
directly instead):

```
& "tools\run_godot_cli_tests.ps1" -Filter FinEditorModelTest
& "tools\run_godot_cli_tests.ps1" -Filter FinEditorPanelTest
& "tools\run_godot_cli_tests.ps1" -Filter FinMaterialTest
& "tools\run_godot_cli_tests.ps1" -Filter CurvedFinTest
& "tools\run_godot_cli_tests.ps1" -Filter SpeciesArchetypeVisualSmokeTest
& "tools\run_godot_cli_tests.ps1" -Filter UserPresetStoreTest
```

All six pass. NOTE: never run the headless runner while the Godot editor is open —
check for `Godot*` processes first.

## Manual Verification Still Needed

Headless dummy rendering can't show the visual, and the deform only runs when posed
(the smoke test uses `auto_animate = false`), so the flow/droop look is unverified
visually. Open the editor, apply the **betta** archetype, and confirm:
- The tail and long fins flow *trailing* the swing (not wriggling independently) and
  settle when the fish is still.
- Higher softness → more billow + more downward droop; rigidity damps both.
- Fins don't clip badly into the body at full softness.

Adjust `FIN_SOFT_AMPLITUDE` / `FIN_SOFT_DROOP` / `lag` if the feel needs tuning.

## Perf Note

Soft fins rebuild an `ArrayMesh` each frame (the subdivided outline → ~50 verts/fin).
For an archetype with a high global softness this is up to ~7 fins/frame; median fins
already rebuilt each frame, so the increment is caudal + paired. Acceptable for this
editor/export tool; rigid fins (softness 0) cost nothing.

## Next Work

1. Visual tuning pass in the editor (above).
2. Optional: expose `FIN_SOFT_AMPLITUDE` / droop as parameters if per-species control
   beyond softness is wanted.
3. Optional: cache the tessellated outline per fin instead of rebuilding indices each
   frame, if profiling ever flags it.
