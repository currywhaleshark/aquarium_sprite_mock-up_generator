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

## Swim Mode Implementation Update

- Added `swim_mode` motion presets for:
  - `eel`
  - `general`
  - `mackerel`
  - `tuna`
  - `puffer`
  - `boxfish`
- Moved tail-fin extra swing and fin yaw-follow strength into normalized motion parameters:
  - `tail_fin_extra_swing`
  - `fin_yaw_follow_strength`
- Added conservative dorsal/anal fin flap parameters for MPF-heavy modes:
  - `median_fin_flap_amount`
  - `median_fin_flap_phase`
- Added Motion Settings dropdown behavior that applies grouped swim-mode values while preserving manual slider tuning afterward.
- Added `tools/run_godot_cli_tests.ps1` timeout/log handling so parse-error tests do not leave stuck headless Godot processes.
- Stabilized `FinEditorModelTest.tscn` by disabling auto animation during static fin layout assertions.
- Verified focused Godot tests:
  - `PresetNormalizationTest.tscn`
  - `ParameterPanelCategoryTest.tscn`
  - `EditorParameterSyncTest.tscn`
  - `ShellRigTest.tscn`
  - `FinEditorModelTest.tscn`
  - `BodyEditorModelTest.tscn`
  - `FinDragTest.tscn`
- Ran the full Godot CLI suite through `tools/run_godot_cli_tests.ps1`:
  - 17 scene tests passed.
  - `ExportSmokeTest.tscn` now skips explicitly under headless dummy rendering because SubViewport texture capture is unavailable there.
- Ran `git diff --check` with no whitespace errors.
- Opened the Godot editor for manual preview. No motion tuning values were changed in this pass.

## User Preset Save/Load Update

- Added user preset persistence under `user://presets`.
- Built-in presets from `res://presets` and user presets from `user://presets` now load into the same preset dropdown.
- User presets are labeled with `(사용자)` in the dropdown.
- Added a preset name field and `현재 설정 저장` button below the preset dropdown.
- Saving copies the current edited preset, keeps the current `parameters`, splits them back into structured body/motion/fin/head/visual sections, and writes JSON through `PresetStore.save_user_preset()`.
- Saved Korean preset names keep Hangul characters in the generated filename; spaces become underscores and emoji/punctuation are dropped.
- Added focused tests:
  - `UserPresetStoreTest.tscn`
  - `UserPresetMainTest.tscn`
- These two tests write to Godot `user://`; in this sandbox they need the approved Godot CLI runner outside the workspace sandbox.

## Eight Direction Export Update

- Added optional 8-direction sprite export from the Export panel with the `8방향 추출` toggle.
- One-direction export remains the default and keeps the existing `frames/frame_000.png` layout.
- 8-direction export writes direction folders:
  - `east`
  - `north_east`
  - `north`
  - `north_west`
  - `west`
  - `south_west`
  - `south`
  - `south_east`
- The sprite sheet becomes a grid where rows are directions and columns are animation frames.
- Metadata now includes:
  - `direction_count`
  - `directions`
  - `sheet_columns`
  - `sheet_rows`
- Added focused tests:
  - `ExportGridTest.tscn`
  - `ExportPanelTest.tscn`

## Parameter Panel Cleanup Update

- Fixed color picker rows disappearing after a color change.
  - Root cause: changed colors were emitted as plain hex text without `#`, while panel rebuild only recognized `#`-prefixed color strings.
- Color parameters now stay grouped under `색상 설정`.
- `body_wave_amount`, `body_wave_start`, and `body_wave_falloff` now appear under `움직임 설정`.
- `ParameterPanelCategoryTest.tscn` covers the color-row persistence and section placement behavior.

## Turning Maneuver Research Update

- Added `docs/fish_turning_maneuvers_reference.html`.
- The document summarizes routine yaw turns, C-start escape turns, median-fin torque, and suggested turn pose parameters for future 8-direction transition work.

## Turn Preview Motion Update

- Added first-pass 45-degree left/right turn preview controls near the lower preview area.
- `Main.gd` now tracks an 8-step preview direction index and animates one-step turns with heading interpolation.
- `FishRig.gd` now reads transient turn parameters:
  - `turn_amount`
  - `turn_direction`
  - `turn_tail_lag`
  - `inside_pectoral_fold`
- Turn preview adds a direction-biased shell yaw/offset and asymmetric pectoral fin motion, then resets back to normal swim after the preview transition.
- Added focused tests:
  - `TurnPoseTest.tscn`
  - `TurnPreviewControlsTest.tscn`
