# Realistic Fish Swim Motion Design

## Goal

Make fish swim animation feel more believable by turning the swimming-mode research into editable motion presets, while preserving the current ring-based body deformation and manual fine tuning workflow.

## Background

The project already rebuilt FishRig around body rings and shell deformation. Motion is now driven by profile values such as `body_wave_amount`, `body_wave_start`, `body_wave_falloff`, and `tail_sway_multiplier`. The research document `docs/fish_swimming_modes_reference.html` maps real fish locomotion into practical editor controls:

- BCF swimming uses body and caudal fin propulsion.
- MPF swimming uses median and paired fins for propulsion and low-speed control.
- Swimming modes should be treated as art-direction presets, not rigid biological categories.

The current implementation still keeps two important motion gains as constants in `FishRig.gd`:

- `FIN_YAW_FOLLOW_STRENGTH`
- `TAIL_FIN_EXTRA_SWING_STRENGTH`

Those gains need to become motion profile values before swimming modes can produce distinct fish motion.

## Scope

This feature covers FishRig swimming motion only.

In scope:

- Add `swim_mode` to fish `motion_profile`.
- Add swim-mode preset values for `eel`, `general`, `mackerel`, `tuna`, `puffer`, and `boxfish`.
- Move tail-fin extra swing and non-caudal fin yaw-follow strength from constants into motion parameters.
- Add a Motion Settings dropdown for choosing `swim_mode`.
- Preserve existing slider-based fine tuning after a mode is applied.
- Add first-pass dorsal and anal fin phase support for MPF-heavy modes.
- Extend tests for normalization, UI categorization, parameter sync, and rig attachment behavior.

Out of scope:

- RayRig swimming mode redesign.
- 8-direction turning poses.
- Hydrodynamic simulation.
- New mesh or sprite export formats.
- Full visual polish of the editor chrome.

## Design Principles

The editor should expose a small set of meaningful swim modes instead of forcing users to understand every motion parameter first.

`swim_mode` is a starting point. After applying a mode, users can still adjust individual sliders. Saving a preset should persist both the chosen mode and the edited numeric values.

Biological terms guide the defaults, but the output is judged visually. The feature should optimize for a believable sprite animation loop rather than scientific accuracy.

## Swim Modes

The first pass uses six user-facing modes:

| swim_mode | Biological reference | Motion intent |
| --- | --- | --- |
| `eel` | anguilliform | Whole-body wave starts near the head. |
| `general` | subcarangiform | Stable head and front body, stronger rear-body wave. |
| `mackerel` | carangiform | Rear third and caudal peduncle carry propulsion. |
| `tuna` | thunniform | Stiff body, narrow fast caudal-peduncle action. |
| `puffer` | tetraodontiform / MPF-heavy | Body mostly stable, paired and median fins visibly propel. |
| `boxfish` | ostraciiform / MPF-heavy | Rigid body with small tail oscillation and fin-driven control. |

Initial values come from `docs/fish_swimming_modes_reference.html`:

| swim_mode | body_wave_amount | body_wave_start | body_wave_falloff | tail_sway_multiplier | tail_fin_extra_swing | fin_flap_amount | fin_yaw_follow_strength | median_fin_flap_amount | median_fin_flap_phase |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `eel` | 0.90 | 0.02 | 0.35 | 1.05 | 0.35 | 3.0 | 0.15 | 1.0 | 0.50 |
| `general` | 0.35 | 0.16 | 0.75 | 1.20 | 0.45 | 6.0 | 0.25 | 1.5 | 0.50 |
| `mackerel` | 0.26 | 0.36 | 1.05 | 1.35 | 0.50 | 4.5 | 0.20 | 1.0 | 0.50 |
| `tuna` | 0.12 | 0.56 | 1.45 | 1.55 | 0.42 | 2.5 | 0.12 | 0.6 | 0.50 |
| `puffer` | 0.08 | 0.68 | 1.60 | 0.85 | 0.20 | 12.0 | 0.10 | 8.0 | 0.25 |
| `boxfish` | 0.03 | 0.82 | 1.80 | 0.75 | 0.32 | 8.0 | 0.08 | 5.0 | 0.25 |

## Data Model

Fish presets should store the selected mode in `motion_profile`:

```json
{
  "motion_profile": {
    "swim_mode": "general",
    "swim_speed": 1.0,
    "global_sway_amount": 10.0,
    "phase_delay": 0.62,
    "body_wave_amount": 0.35,
    "body_wave_start": 0.16,
    "body_wave_falloff": 0.75,
    "tail_sway_multiplier": 1.2,
    "tail_fin_extra_swing": 0.45,
    "fin_flap_amount": 6.0,
    "fin_yaw_follow_strength": 0.25,
    "median_fin_flap_amount": 1.5,
    "median_fin_flap_phase": 0.5,
    "idle_bob_amount": 0.025
  }
}
```

Legacy presets without `swim_mode` should normalize to `general` unless their existing shape-derived defaults clearly imply an eel-like or stiff-bodied mode. Numeric legacy values must be preserved when present.

Normalization should guarantee these keys exist for fish presets:

- `swim_mode`
- `body_wave_amount`
- `body_wave_start`
- `body_wave_falloff`
- `tail_sway_multiplier`
- `tail_fin_extra_swing`
- `fin_flap_amount`
- `fin_yaw_follow_strength`
- `median_fin_flap_amount`
- `median_fin_flap_phase`

## Runtime Behavior

`FishRig.apply_pose()` and helper methods should read motion gains from parameters:

- `_fin_follow_yaw()` uses `fin_yaw_follow_strength`.
- `_apply_animated_tail()` uses `tail_fin_extra_swing`.
- Pectoral flap continues to use `fin_flap_amount`.

For MPF-heavy modes, dorsal and anal fins need their own small flap phases. These should be parameter-driven and conservative:

- `median_fin_flap_amount`
- `median_fin_flap_phase`

If these values are missing, normalization should default them from `swim_mode`. BCF-heavy modes should keep median fin motion subtle. `puffer` and `boxfish` should make dorsal and anal fins visibly participate without making the fins detach from the shell.

## UI Behavior

The Motion Settings section should include a `swim_mode` dropdown above the numeric motion sliders.

Changing the dropdown applies the mode's grouped values immediately:

- `body_wave_amount`
- `body_wave_start`
- `body_wave_falloff`
- `tail_sway_multiplier`
- `tail_fin_extra_swing`
- `fin_flap_amount`
- `fin_yaw_follow_strength`
- `median_fin_flap_amount`
- `median_fin_flap_phase`

After applying a mode, numeric sliders remain editable. The editor does not need a separate "custom" mode in the first pass. If a user edits sliders after selecting `tuna`, the preset can still show `tuna` while storing the edited values.

## Testing

Automated tests should cover:

- Preset normalization adds all new motion keys.
- Existing legacy motion keys are still removed.
- Existing explicit numeric motion values are not overwritten by `swim_mode`.
- Applying each swim mode returns the expected grouped values.
- Motion settings categorizes `swim_mode`, fin yaw follow, tail fin swing, and median fin controls correctly.
- Editor parameter sync emits updated parameters when `swim_mode` changes.
- FishRig can rebuild and apply poses for each swim mode without detaching animated fins or tail.

Manual verification should compare at least these modes in the Godot preview:

- `eel`: full-body wave is obvious and starts forward.
- `general`: head/front body stay calmer than the rear body.
- `tuna`: body is stiff and tail action carries motion.
- `puffer`: body is stiff while fins visibly flap.
- `boxfish`: body remains rigid with restrained tail and fin-driven control.

## Risks

The initial numeric values may look too stiff or too exaggerated in the actual camera projection. The implementation should keep values data-driven so tuning does not require more rig code changes.

Adding dorsal and anal flap can create visual noise if it competes with shell deformation. MPF fin motion should start conservative and be tuned in preview.

The dropdown must not hide or overwrite manual tuning unexpectedly. Presets need to save the final numeric values, not only the named mode.

## Implementation Sequence

1. Move `tail_fin_extra_swing` and `fin_yaw_follow_strength` into normalized motion parameters.
2. Add a swim-mode preset table and helper to apply grouped values.
3. Extend preset normalization and saving so `swim_mode` and new motion keys persist.
4. Add Motion Settings dropdown support for string option parameters.
5. Wire dropdown changes to apply grouped swim-mode values.
6. Add conservative median fin flap support for dorsal and anal fins.
7. Extend automated tests.
8. Run Godot preview checks and tune first-pass values.
