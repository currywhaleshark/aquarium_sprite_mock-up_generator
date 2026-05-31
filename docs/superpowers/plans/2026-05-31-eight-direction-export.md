# Eight Direction Sprite Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional eight-direction sprite export without breaking the current one-direction sheet export.

**Architecture:** `SpriteExporter` owns capture order and direction folders. `SpriteSheetBuilder` gains a grid builder while preserving the current one-row helper. `ExportMetadata` describes direction layout for downstream game code.

**Tech Stack:** Godot 4.6 GDScript, existing Godot CLI scene tests.

---

### Task 1: Grid Sheet Builder Contract

**Files:**
- Modify: `scripts/export/SpriteSheetBuilder.gd`
- Test: `scripts/tools/ExportGridTest.gd`
- Create: `scenes/ExportGridTest.tscn`

- [ ] Write a failing test that builds a 2-row by 3-column sheet from colored PNGs and asserts final size and sampled cell colors.
- [ ] Add `SpriteSheetBuilder.build_sheet_grid(rows, output_path)`.
- [ ] Keep `build_sheet(frame_paths, output_path)` as a wrapper around one row.
- [ ] Run `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportGridTest`.

### Task 2: Metadata Direction Fields

**Files:**
- Modify: `scripts/export/ExportMetadata.gd`
- Test: `scripts/tools/ExportGridTest.gd`

- [ ] Extend the failing test to call `ExportMetadata.build()` with `direction_count = 8`.
- [ ] Add `direction_count`, `directions`, `sheet_columns`, and `sheet_rows`.
- [ ] Verify default metadata remains one direction when `direction_count` is missing.
- [ ] Run the focused export grid test.

### Task 3: Exporter Direction Loop

**Files:**
- Modify: `scripts/export/SpriteExporter.gd`
- Test: `scripts/tools/ExportGridTest.gd`

- [ ] Add helper functions for direction names, direction yaw, and normalized direction count.
- [ ] For each direction, rotate the rig around Y, capture all animation frames into that direction folder, and collect the row paths.
- [ ] Build a grid sheet from captured rows.
- [ ] Restore original rig rotation and `auto_animate` after success or failure.
- [ ] Run focused export grid and existing export-related tests.

### Task 4: Verification

**Files:**
- No production files.

- [ ] Run `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportGridTest`.
- [ ] Run `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportSmokeTest`.
- [ ] Run `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`.
- [ ] Run `git diff --check`.
