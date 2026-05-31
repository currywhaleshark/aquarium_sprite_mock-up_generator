# Turn Preview Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a visible 45-degree left/right turn preview motion to the fish sprite editor.

**Architecture:** `FishRig` receives a small transient turn pose layer driven by parameters. `Main.gd` owns preview-only direction state and buttons that set those parameters while interpolating rig heading. Export remains untouched in this pass.

**Tech Stack:** Godot 4.6 GDScript, existing scene-based CLI tests.

---

### Task 1: Fish Turn Pose Layer

**Files:**
- Modify: `scripts/creature/FishRig.gd`
- Create: `scripts/tools/TurnPoseTest.gd`
- Create: `scenes/TurnPoseTest.tscn`

- [ ] Write failing test that applies normal pose and turn pose, then asserts shell yaw/pectoral rotations change.
- [ ] Add turn parameter helpers and turn yaw distribution in `_deform_shell()`.
- [ ] Add pectoral asymmetry in `_apply_animated_fins()`.
- [ ] Run focused Godot CLI test with `-Filter TurnPoseTest`.

### Task 2: Preview Turn Controls

**Files:**
- Modify: `scripts/ui/Main.gd`
- Create: `scripts/tools/TurnPreviewControlsTest.gd`
- Create: `scenes/TurnPreviewControlsTest.tscn`

- [ ] Write failing test that finds left/right turn buttons and checks a right turn advances direction state.
- [ ] Add preview direction state and turn buttons near the lower preview row.
- [ ] Implement `_start_preview_turn()` and `_update_preview_turn()`.
- [ ] Run focused Godot CLI test with `-Filter TurnPreviewControlsTest`.

### Task 3: Verification

**Files:**
- Modify: `docs/2026-05-31-motion-handoff.md`

- [ ] Document the turn preview feature.
- [ ] Run focused tests for turn pose and preview controls.
- [ ] Run full Godot CLI suite.
- [ ] Run `git diff --check`.
