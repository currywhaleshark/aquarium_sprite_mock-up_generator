# Shark Head Morphology Controls Design

Date: 2026-06-18

## Goal

Expand the shark head editor so the current shark rig can produce multiple shark head silhouettes without changing the whole body preset. The blacktip-style base preset should remain valid, while users can apply head-only starting shapes such as a white-shark conical head and a whale-shark blunt head, then refine them with sliders.

This work is head-scoped. It must not turn into full species presets that alter body profile, fins, patterning, color, or motion.

## User Flow

Add a head-only recipe section to the shark head editor. This is not a new full-preset mechanism. It is a small editor action that applies a named dictionary of parameter values to the current parameter set.

Use compact buttons in a new shark-only "head recipe" row near the top of `HeadEditorPanel`, rather than `PresetStore.gd` or full creature presets. The first buttons are:

- White shark conical head: short blunt cone snout, forward eye and mouth placement, and rear-heavy head height/width.
- Whale shark blunt head: broad rounded front, fuller head volume, wider and more forward mouth.

Activating a recipe updates only head, snout, eye, mouth, and shark-head support parameters. Existing body, fin, color, marking, and motion values stay unchanged. After a recipe is applied, all values remain ordinary editable parameters.

Recipe application must use an explicit allowlist, because many head keys such as `head_size`, `head_length`, `head_offset`, `snout_length`, `forehead_slope`, and `eye_*` are common parameters rather than `shark_`-prefixed keys. The recipe allowlist is:

- Head body: `head_size`, `head_length`, `head_offset`, `head_flattening`, `shark_head_rear_height`, `shark_head_rear_width`
- Snout: `snout_length`, `snout_base`, `snout_thickness`, `snout_taper`, `snout_curve`, `shark_snout_tip_y`
- Dorsal/belly profile: `forehead_slope`, `head_top_curve`, `head_top_peak`, `head_belly_curve`
- Bump and flatness: `head_bump_height`, `head_bump_pos`, `head_bump_width`, `head_bump_angle`, `head_bump_round`, `head_top_flatness`, `head_bottom_flatness`, `head_left_flatness`, `head_right_flatness`
- Eyes: `eye_size`, `eye_position_x`, `eye_position_y`, `eye_bulge`, `eye_pupil_scale`
- Shark mouth: `shark_mouth_profile`, `shark_mouth_position_x`, `shark_mouth_position_y`, `shark_mouth_width`, `shark_mouth_curve`, `shark_mouth_angle`, `shark_mouth_arc`, `shark_mouth_gape`, `shark_jaw_projection`, `shark_lower_jaw_drop`, `shark_tooth_visible_count`, `shark_tooth_size`, `shark_tooth_angle`, `shark_labial_furrow_length`

Do not include body profile, fin profile, color, marking layers, motion, export, camera, or shark gill keys in the recipe allowlist in this pass.

## Parameter Model

Reuse existing shark head controls where possible:

- `snout_length`
- `snout_base`
- `snout_thickness`
- `snout_taper`
- `snout_curve`
- `head_top_curve`
- `head_belly_curve`
- `head_*_flatness`
- `shark_mouth_position_x`
- `shark_mouth_position_y`
- `shark_mouth_width`
- `shark_mouth_curve`

Add the following shark-specific controls:

- `shark_head_rear_height`: increases or reduces head height in the rear 60-90% region.
- `shark_head_rear_width`: increases or reduces head width in the rear 60-90% region.
- `shark_snout_tip_y`: directly raises or lowers the snout tip. This differs from `snout_curve`, which bends the whole snout.
- `shark_mouth_angle`: tilts the visible mouth line up or down in side view.
- `shark_mouth_arc`: controls the U-shaped versus drooping character of the mouth line.

The split between `snout_curve` and `shark_snout_tip_y` is intentional: curve changes the bend, while tip height changes the endpoint.

The split between `shark_mouth_curve` and `shark_mouth_arc` must also remain clear. Keep `shark_mouth_curve` as the existing backwards-compatible wrap/half-angle control for how far the mouth band spreads around the lower cross-section. Add `shark_mouth_arc` as a new line-shape control along the seam path itself: positive values produce a stronger U-shaped bow and negative values produce a flatter or drooping line. `shark_mouth_angle` then applies an overall side-view tilt to that path.

All new parameters must default to neutral no-op values:

- `shark_head_rear_height = 0.0`
- `shark_head_rear_width = 0.0`
- `shark_snout_tip_y = 0.0`
- `shark_mouth_angle = 0.0`
- `shark_mouth_arc = 0.0`

The defaults used in UI range definitions and every `parameters.get(key, default)` fallback must match these neutral values so `basic_shark` is unchanged when the new keys are absent.

## Geometry Behavior

The shark head mesh should apply the new rear height and rear width as smooth longitudinal weights that peak around the gill/rear-head zone and fade toward the rostrum tip and neck. This gives white-shark rear mass and whale-shark blunt fullness without breaking the existing blacktip-style preset.

The rear-volume weight must fade back to zero at the neck rim (`u = 1.0`). It should not inflate the final neck cap or the shell join, because the head/shell seam relies on the current de-pinch and enclosure behavior near the neck.

The snout-tip height should be applied near the rostrum tip and fade out before the snout base, so it does not move the whole head.

The mouth seam, mouth interior shadow, teeth, labial furrow, and eye surface depth must follow the same deformed surface used by the visible head mesh. This includes existing flatness controls and the new rear-volume and snout-tip controls, so attachments do not float or bury when users sculpt strongly.

Implement snout tip height through one shared helper used by all surface paths, not only the visible mesh. The helper should be composed with `_snout_curve_y_shift` semantics and consumed by `_shaped_point`, `surface_z_at`, and `mouth_weight` so the head mesh, eye depth, mouth seam, teeth, and mouth membership agree near the rostrum.

Rear height and rear width may flow through `_base_radii`, as long as all code paths that sample radii receive the same values and the neck-rim fade is enforced.

## UI

Expose the head-only recipes in `HeadEditorPanel` for shark mode. Insert new controls into the existing Korean `FISH_SECTIONS` layout rather than inventing separate English sections:

- `머리 본체`: `shark_head_rear_height`, `shark_head_rear_width`
- `주둥이`: `shark_snout_tip_y`
- `입`: `shark_mouth_angle`, `shark_mouth_arc`

Labels should be added to `UiText.gd` in Korean, matching the current UI style. Slider ranges must be defined in the same place as the existing shark-specific numeric ranges and must match the runtime clamps. Suggested initial ranges:

- `shark_head_rear_height`: -0.4 to 0.8
- `shark_head_rear_width`: -0.4 to 1.0
- `shark_snout_tip_y`: -0.35 to 0.35
- `shark_mouth_angle`: -45 to 45 degrees
- `shark_mouth_arc`: -1.0 to 1.0

If implementation chooses tighter clamps after visual tests, update the UI ranges and clamps together.

## Schema and Persistence

Register all new keys in `CreatureParameterSchema.gd` as shark-visible parameters, preferably in a dedicated `SHARK_HEAD_KEYS` group. `is_parameter_visible()` must return true for shark mode and false for ray mode. This is required so `BodyProfile.sanitize_parameters_for_mode()` does not strip the values on save/load.

The head recipe allowlist is separate from schema visibility. Schema answers "can this key exist for shark mode"; the recipe allowlist answers "may this button overwrite this key."

## Tests

Add or update focused Godot CLI tests:

- Shark head mesh: rear height, rear width, snout tip height, mouth angle, and mouth arc visibly affect stable vertex-order geometry.
- Mouth attachment: mouth path, teeth, and shadow stay near the deformed head surface under flatness and new controls.
- Eye attachment: shark eyes remain near the deformed surface under strong head controls.
- Head editor UI: shark mode shows recipe controls and new sliders.
- Mode visibility: new shark controls appear for shark mode and are hidden for ray mode.
- Preset normalization: new parameters survive sanitize/save/load for shark mode.
- Recipe application: head recipes change only head-related parameters and leave body/fins/colors/motion untouched.
- Basic shark no-op: loading the current `basic_shark` without the new keys produces unchanged neutral geometry for the existing shark head path.
- Neck seam regression: run or extend `HeadShellSeamTest`/related shell seam coverage to ensure rear height/width do not reintroduce the head-shell neck pinch or shell rim mismatch.

Use `tools/run_godot_cli_tests.ps1 -Filter <test_name>` for focused verification, then broaden only as touched surface warrants.

## Non-Goals

- Do not change `basic_shark` from its current blacktip-style intent.
- Do not add full shark species presets in this pass.
- Do not build whale-shark body patterning, full body proportions, or species archetype support for shark mode yet.
- Do not rewrite unrelated fish or ray head behavior.
