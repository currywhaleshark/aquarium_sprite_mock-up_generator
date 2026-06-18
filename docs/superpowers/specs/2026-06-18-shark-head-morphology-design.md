# Shark Head Morphology Controls Design

Date: 2026-06-18

## Goal

Expand the shark head editor so the current shark rig can produce multiple shark head silhouettes without changing the whole body preset. The blacktip-style base preset should remain valid, while users can apply head-only starting shapes such as a white-shark conical head and a whale-shark blunt head, then refine them with sliders.

This work is head-scoped. It must not turn into full species presets that alter body profile, fins, patterning, color, or motion.

## User Flow

Add a head-only recipe section to the shark head editor. The first recipes are:

- White shark conical head: short blunt cone snout, forward eye and mouth placement, and rear-heavy head height/width.
- Whale shark blunt head: broad rounded front, fuller head volume, wider and more forward mouth.

Activating a recipe updates only head, snout, eye, mouth, and shark-head support parameters. Existing body, fin, color, marking, and motion values stay unchanged. After a recipe is applied, all values remain ordinary editable parameters.

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

## Geometry Behavior

The shark head mesh should apply the new rear height and rear width as smooth longitudinal weights that peak around the gill/rear-head zone and fade toward the rostrum tip and neck. This gives white-shark rear mass and whale-shark blunt fullness without breaking the existing blacktip-style preset.

The snout-tip height should be applied near the rostrum tip and fade out before the snout base, so it does not move the whole head.

The mouth seam, mouth interior shadow, teeth, labial furrow, and eye surface depth must follow the same deformed surface used by the visible head mesh. This includes existing flatness controls and the new rear-volume and snout-tip controls, so attachments do not float or bury when users sculpt strongly.

## UI

Expose the head-only recipes in `HeadEditorPanel` for shark mode. Group controls as:

- Head body: size, length, offset, flattening, rear height, rear width.
- Snout: length, base, thickness, taper, curve, snout tip height.
- Dorsal/belly profile: top curve, top peak, belly curve, forehead slope.
- Bump and flatness: existing bump and flat-cap controls.
- Mouth: position, width, angle, arc, gape, projection, jaw drop, teeth.

Labels should be added to `UiText.gd` in Korean, matching the current UI style.

## Tests

Add or update focused Godot CLI tests:

- Shark head mesh: rear height, rear width, snout tip height, mouth angle, and mouth arc visibly affect stable vertex-order geometry.
- Mouth attachment: mouth path, teeth, and shadow stay near the deformed head surface under flatness and new controls.
- Eye attachment: shark eyes remain near the deformed surface under strong head controls.
- Head editor UI: shark mode shows recipe controls and new sliders.
- Mode visibility: new shark controls appear for shark mode and are hidden for ray mode.
- Preset normalization: new parameters survive sanitize/save/load for shark mode.
- Recipe application: head recipes change only head-related parameters and leave body/fins/colors/motion untouched.

Use `tools/run_godot_cli_tests.ps1 -Filter <test_name>` for focused verification, then broaden only as touched surface warrants.

## Non-Goals

- Do not change `basic_shark` from its current blacktip-style intent.
- Do not add full shark species presets in this pass.
- Do not build whale-shark body patterning, full body proportions, or species archetype support for shark mode yet.
- Do not rewrite unrelated fish or ray head behavior.
