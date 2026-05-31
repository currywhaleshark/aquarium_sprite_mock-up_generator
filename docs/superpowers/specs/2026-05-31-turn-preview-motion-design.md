# Turn Preview Motion Design

## Goal

Add a first playable preview of 45-degree left/right fish turning so the editor can visually validate transition motion before building full transition sprite export.

## Scope

In scope:

- Add left/right turn buttons near the lower-left preview area.
- Maintain a preview direction index from 0 to 7.
- Each button starts a 45-degree turn transition to the adjacent direction.
- During the transition, the rig heading interpolates and a turn pose layer is applied.
- After the transition, the fish returns to normal swimming in the new direction.
- First pass targets fish rigs. Ray rigs can rotate heading but do not need special turn deformation yet.

Out of scope:

- Exporting transition sprite sheets.
- C-start or emergency turns.
- 90/135/180 direct transition assets.
- UI for tuning all turn parameters.

## Turn Pose Layer

The first pass uses these transient parameters:

- `turn_amount`: 0 to 1 transition intensity.
- `turn_direction`: -1 for left, 1 for right.
- `turn_tail_lag`: how much the tail trails the heading.
- `inside_pectoral_fold`: how strongly the inside pectoral fin folds/braces.

`FishRig.apply_pose()` continues to build the normal swim pose, then `_deform_shell()` adds direction-biased turn yaw and pectoral asymmetry when `turn_amount > 0`.

## Preview Flow

`Main.gd` owns preview direction state:

1. Button press calls `_start_preview_turn(-1)` or `_start_preview_turn(1)`.
2. The target direction index is one step away modulo 8.
3. `_process(delta)` advances a short transition timer.
4. Rig yaw interpolates from the old direction to the new direction.
5. `turn_amount` uses a sine ease curve so it peaks mid-turn and fades out.
6. At the end, the new direction remains and `turn_amount` resets to 0.

## Testing

- `TurnPoseTest.tscn` verifies the fish shell and pectoral fins respond to turn parameters.
- `TurnPreviewControlsTest.tscn` verifies the left/right buttons exist and a right turn moves the direction index by one 45-degree step.
