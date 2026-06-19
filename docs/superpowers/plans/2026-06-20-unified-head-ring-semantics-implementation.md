# Unified Head Ring Semantics Implementation Plan

Date: 2026-06-20

## Goal

Make unified-mode `snout` and `head` ring handles represent actual head/snout surface locations while keeping the visible body weld on the editable `front_body` boundary.

## Architecture

Saved `BodyProfile` data remains unchanged. `FishRig` adds a unified-only interpretation layer:

- `snout` and `head` handles are sampled from the current head surface.
- The unified mesh weld starts at the editable `front_body` ring so hidden `__neck_fill_*` support rings cannot create visible hollows.
- Existing generated `__neck_fill_*` support rings remain hidden from the editor and are not used as unified weld owners.
- Legacy non-unified shell behavior keeps its previous ring interpretation.

`SharkRig` overrides the head-ring sampler with `SharkHeadProfile.point_at()` so shark handles follow the shark-specific rostrum/head shape.

## Completed Tasks

- [x] Added fish regression coverage proving unified `snout`/`head` handles sit before the editable `front_body` weld boundary.
- [x] Added shark regression coverage with the same semantic assertions.
- [x] Reworked unified body-start selection so the weld boundary is editable `front_body`, not logical `snout` or hidden generated support.
- [x] Reused the new handle positions for ring guides, drag planes, world points, and slider indicators.
- [x] Covered unified `snout`/`head` center drags so profile x edits move the sampled head handle.
- [x] Updated unified mesh/seam tests to match the selected boundary ring by vertex distance instead of assuming `shell_profile[0]`.
- [x] Removed the closed rear fish-head cap from the unified weld path so the `front_body` boundary connects to an open head ring.
- [x] Skipped rear-half fish head rings that are too pinched relative to the body boundary, preventing a visually separated neck/body join.
- [x] Replaced repeated full fish head-grid generation for handles with single-ring sampling.

## Verification Run

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UnifiedFishRigSurface
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UnifiedSharkRigSurface
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BodyRingDrag
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SliderIndicator
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadShellSeam
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter TurnPose
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter BasicSharkHeadVisual
git diff --check
```

All listed checks pass. `Failed to read the root certificate store` appears in Godot output and is non-fatal per `AGENTS.md`.

## Commit Scope

Intentional files:

- `docs/superpowers/plans/2026-06-20-unified-head-ring-semantics-implementation.md`
- `scripts/creature/FishRig.gd`
- `scripts/creature/SharkRig.gd`
- `scripts/creature/PrimitiveFactory.gd`
- `scripts/tools/UnifiedFishRigSurfaceTest.gd`
- `scripts/tools/UnifiedSharkRigSurfaceTest.gd`
- `scripts/tools/SharkHeadShellSeamTest.gd`

Pre-existing dirty file left unstaged:

- `scripts/tools/PresetStoreModeFilterTest.gd`
