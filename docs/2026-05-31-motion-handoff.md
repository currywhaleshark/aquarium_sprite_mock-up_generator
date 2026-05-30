# Fish Sprite Motion Handoff - 2026-05-31

## Branch

- Current branch: `refactor/rig-type-safety`
- Previous pushed commit before this handoff: `9b0fcc1 Rebuild fish sprite editor around body rings`

## Scope Completed After Ring Editor Rebuild

This handoff covers the motion refinement work done after the ring-based editor rebuild.

## Motion Distribution

- Added profile-driven body wave controls:
  - `body_wave_amount`
  - `body_wave_start`
  - `body_wave_falloff`
- These values control how much of the shell bends, where bending starts from head to tail, and how strongly the wave concentrates toward the rear.
- `BodyProfile.normalize_motion_parameters()` now injects defaults for legacy presets based on body profile shape and slenderness.
- Presets now carry explicit motion distribution values:
  - `default_fish`
  - `round_chubby_fish`
  - `slender_fish`
  - `tall_flat_fish`
  - `bottom_dweller_fish`

## Head Stability

- Removed whole `BodyPivot` yaw sway from `FishRig.apply_pose()`.
- The fish no longer turns the head and all child parts as one rigid object during normal swimming.
- Body motion now comes from shell ring deformation instead of global body rotation.

## Animated Shell Attachments

- Shell deformation now preserves animated ring centers and yaws:
  - `animated_shell_centers`
  - `animated_shell_yaws`
- Non-caudal fins are reattached every pose update to the currently deformed shell.
- Tail pivots are reanchored to animated `rear_body` and `tail_stem` ring centers.
- This prevents fins and tail from visually separating when `body_wave_amount` is increased.

## Motion Damping

- Non-caudal fin yaw follows shell yaw with a reduced gain:
  - `FIN_YAW_FOLLOW_STRENGTH := 0.25`
- Tail fin extra swing is reduced:
  - `TAIL_FIN_EXTRA_SWING_STRENGTH := 0.55`
- Intent:
  - body silhouette carries the main wave;
  - fins follow attachment points but do not rotate more dramatically than the body;
  - caudal fin remains attached to the tail stem while avoiding excessive extra flap.

## Swimming Mode Research

- Added HTML reference document:
  - `docs/fish_swimming_modes_reference.html`
- Covers:
  - BCF vs MPF locomotion
  - anguilliform, subcarangiform, carangiform, thunniform, ostraciiform
  - tetraodontiform and ray-like MPF movement
  - parameter mapping for the current editor
  - proposed `swim_mode` presets
  - inline SVG diagrams for wave distribution and propulsion regions

## Tests Run

Fresh verification during this handoff:

- `FinEditorModelTest.tscn`
  - `FIN_EDITOR_MODEL_TEST_OK`
- `ShellRigTest.tscn`
  - `SHELL_RIG_TEST_OK`
- `BodyEditorModelTest.tscn`
  - `BODY_EDITOR_MODEL_TEST_OK`
- `FinDragTest.tscn`
  - `FIN_DRAG_TEST_OK`
- `git diff --check`
  - no whitespace errors

Additional related tests that passed earlier in this motion pass:

- `HeadEditorModelTest.tscn`
- `EditorParameterSyncTest.tscn`
- `PresetNormalizationTest.tscn`
- `ParameterPanelCategoryTest.tscn`
- JSON preset parse check

## Important Notes

- The latest motion gains are intentionally conservative. If the fish feels too stiff, tune `FIN_YAW_FOLLOW_STRENGTH` and `TAIL_FIN_EXTRA_SWING_STRENGTH` carefully before increasing `global_sway_amount`.
- `FIN_YAW_FOLLOW_STRENGTH` and `TAIL_FIN_EXTRA_SWING_STRENGTH` are currently constants in `FishRig.gd`.
- A logical next step is to move them into `motion_profile` as:
  - `fin_yaw_follow_strength`
  - `tail_fin_extra_swing`
- The research document recommends adding a `swim_mode` selector instead of adding more loose sliders.

## Suggested Next Work

1. Add `swim_mode` to `motion_profile`.
2. Add Motion Settings dropdown for:
   - eel
   - general
   - mackerel
   - tuna
   - puffer
   - boxfish
3. Apply grouped motion values from the dropdown while preserving manual fine tuning.
4. Add dorsal/anal fin-specific flap phase for puffer/boxfish-like MPF motion.
5. Later, design a pose layer for 8-direction sprites and turning poses:
   - `turn_amount`
   - `turn_direction`
   - `turn_radius`
   - inside/outside fin response

## Process Cleanup

- Headless Godot test processes were cleaned up after verification.
- Normal Godot editor windows were intentionally left running.
