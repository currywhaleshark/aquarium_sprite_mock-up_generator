# Handoff: Head Shell Neck Seam / Unified Surface

Date: 2026-06-19
Branch: fix/head-shell-neck-seam
Plan copy: docs/plans/majestic-plotting-nygaard.md

## What changed in this handoff

- Added shark seam regression coverage and visual shot tooling for the real SharkRig neck seam.
- Added a unified creature mesh builder that emits head rings and body rings into one ArrayMesh with shared boundary vertices and generated normals.
- Added opt-in `unified_surface_enabled` support for FishRig and SharkRig.
- Kept `BodyPivot/Head` as a meshless attachment anchor when unified surface is enabled.
- Extended unified surface tests so rest pose and `apply_pose()` both preserve head geometry in `BodyPivot/OuterShell`.
- Added `unified=1` support to shark/neon shot scripts for visual validation.
- Fixed the turn-pose verification blocker by raising the head turn yaw cap from 24 to 28 degrees, restoring the existing early-turn head-yaw contract.

## Current implementation state

- Phase 0 safety net is in place.
- Phase 1 static opt-in unified surface is in place for fish and shark.
- Phase 2 first slice is in place: `apply_pose()` no longer overwrites the opt-in unified mesh with the old body-only shell.
- The old non-unified path remains the default unless `unified_surface_enabled` is set.
- Phase 3 is not done yet. Attachments still rely on `head_node`; because it remains as a transform anchor, current tests are protected, but the next deeper step is to explicitly route eyes, shark mouth/gills, and operculum to the computed head transform contract.

## Verification run before handoff

Focused passing tests:

- UnifiedCreatureMeshTest
- UnifiedFishRigSurfaceTest
- UnifiedSharkRigSurfaceTest
- HeadShellSeamTest, including SharkHeadShellSeamTest
- HeadShellAttachmentTest
- SharkHeadMeshTest
- RingHeightDecoupleTest
- TurnPoseTest

Visual shot generation completed for unified mode:

- basic_shark: `exports/_shots/shark_neck/*_unified_basic.png`
- 상어2: `exports/_shots/shark_neck/*_unified_s2.png`
- 네온테트라: `exports/_shots/neon_*_unified_neon.png`
- 아로와나: `exports/_shots/neon_*_unified_arowana.png`

PNG dimensions and sampled color counts were checked to guard against blank renders.

## Notes for the next worker

- Run Godot CLI tests through `tools/run_godot_cli_tests.ps1`; do not use raw headless commands for routine tests.
- Treat `Failed to read the root certificate store` as non-fatal per AGENTS.md.
- Do not delete the old seam enclosure / neck smoothing code yet. Phase 4 decides what to retire after the unified path is proven on presets and animation.
- Next likely step: Phase 3 attachment re-anchoring. Start with tests for EyeAttachmentTest, SharkGillSlitRenderingTest, SharkMouthRenderingTest, and an operculum-focused probe before changing attachment code.
- `ShellRigTest` was noted in the plan as pre-existing unrelated failure on a clean baseline; it was not part of this verification sweep.