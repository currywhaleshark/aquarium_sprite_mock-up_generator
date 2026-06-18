# Shark Head Morphology Handoff - 2026-06-18

## Branch

- Current branch: `fix/head-shell-neck-seam`
- Builds on the shark snout sculpt and head-shell neck seam work already on this branch.
- Design spec: `docs/superpowers/specs/2026-06-18-shark-head-morphology-design.md`
- Implementation plan: `docs/superpowers/plans/2026-06-18-shark-head-morphology-controls.md`

## Scope Completed

Added head-only shark morphology controls so the current blacktip-style shark preset can be adjusted toward other head silhouettes without changing the whole creature preset.

Implemented:

- Rear head height and width controls.
- Direct snout tip height control.
- Mouth line angle and mouth arc controls.
- Head-only recipe buttons for:
  - `white_shark_conical`
  - `whale_shark_blunt`
- Recipe application is shark-only and uses an explicit allowlist.
- Recipe application preserves body, fins, colors, motion, tail shape, and shark gill settings.
- Recipe application resets allowlisted head state before applying a recipe, so previous manual edits or another recipe do not leak into the selected form.

## Parameter Model

New shark-specific keys:

- `shark_head_rear_height`
- `shark_head_rear_width`
- `shark_snout_tip_y`
- `shark_mouth_angle`
- `shark_mouth_arc`

All new keys default to neutral `0.0`. Explicit zero values and absent keys produce the same shark head mesh.

Role split:

- `snout_curve`: bends the snout region.
- `shark_snout_tip_y`: raises or lowers the snout endpoint.
- `shark_mouth_curve`: keeps its existing mouth wrap / half-angle role.
- `shark_mouth_angle`: tilts the mouth line in side view.
- `shark_mouth_arc`: changes the seam path bow/U-shape without driving mouth membership.

## Geometry Notes

- Rear height/width flow through `SharkHeadProfile._base_radii()` and fade to zero at the neck rim.
- Snout tip height is shared through `_snout_y_shift()` and consumed by:
  - `_shaped_point()`
  - `surface_z_at()`
  - `mouth_weight()`
- The mouth seam now rides `_base_point()` so it follows the same flatness-adjusted surface as the visible head mesh.
- `mouth_weight()` includes mouth angle so the groove follows tilted mouth lines, but intentionally excludes mouth arc so arc remains a visual seam-path bow.

## UI Notes

- New sliders are exposed in the existing Korean head editor sections:
  - `머리 본체`: rear height/width
  - `주둥이`: snout tip height
  - `입`: mouth angle/arc
- Broad `ParameterPanel` ranges and mode visibility were updated for the new keys.
- Korean labels were added in `UiText.gd`.
- Recipe buttons are compact shark-only controls in `HeadEditorPanel`.

## Files Changed

- `scripts/creature/CreatureParameterSchema.gd`
- `scripts/creature/SharkHeadProfile.gd`
- `scripts/ui/HeadEditorPanel.gd`
- `scripts/ui/ParameterPanel.gd`
- `scripts/ui/UiText.gd`
- `scripts/tools/HeadEditorPanelTest.gd`
- `scripts/tools/ParameterModeVisibilityTest.gd`
- `scripts/tools/PresetNormalizationTest.gd`
- `scripts/tools/SharkHeadMeshTest.gd`
- `scripts/tools/SharkMouthRenderingTest.gd`
- `scripts/tools/SharkMouthShot.gd`
- `docs/superpowers/specs/2026-06-18-shark-head-morphology-design.md`
- `docs/superpowers/plans/2026-06-18-shark-head-morphology-controls.md`

## Tests Verified

Focused Godot CLI tests passed:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalization
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ParameterModeVisibility
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanel
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkHeadMesh
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SharkMouthRendering
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeam
```

Also verified:

- `git diff -- presets/basic_shark.json` produced no output.
- `git diff --check fc62fec..HEAD` was clean before this handoff document.

The Windows `Failed to read the root certificate store` warning appeared during Godot runs and was treated as non-fatal per project test-safety instructions.

## Visual Verification

Manual visual verification is intentionally deferred.

`SharkMouthShot.gd` now includes `white_shark_conical` and `whale_shark_blunt` shot variants. Use this command later for visual QA:

```powershell
& "$env:USERPROFILE\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --disable-crash-handler --path . --log-file tmp\godot-logs\SharkMouthShot-visual.log scenes/SharkMouthShot.tscn
```

Inspect the saved images under `exports/_shots/shark/`:

- `white_shark_conical_*`
- `whale_shark_blunt_*`

Visual QA targets:

- White-shark recipe reads as a short blunt cone with rear head mass.
- Whale-shark recipe reads broader, flatter, and blunter at the front.
- Mouth seam, teeth, and shadow remain attached under strong snout/mouth settings.
- Rear head volume does not reintroduce a neck seam pinch.

## Important Follow-Up

1. Perform the deferred visual review and tune recipe numbers if needed.
2. If full species presets are added later, keep them separate from these head-only recipes.
3. Do not update `basic_shark.json` unless the blacktip-style baseline is intentionally changed.
