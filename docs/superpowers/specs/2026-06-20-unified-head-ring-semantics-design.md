# Unified Head Ring Semantics Design

Date: 2026-06-20

## Goal

Reframe the first body-profile rings for the unified surface path so their names match what users edit. With the old separated head mesh, the `snout` and `head` body rings behaved mostly as head-shell junction support: `snout` sat at the neck boundary and `head` was the next transition ring. Now that fish and shark presets default to the unified outer surface, those logical rings should move back to their literal meaning.

In unified mode:

- `snout` represents an actual front snout/head cross-section.
- `head` represents an actual mid or rear head-volume cross-section.
- The neck weld/body boundary is an internal generated boundary, not a user-facing `snout` or `head` ring.
- `front_body` continues to represent the first editable body/shoulder ring behind the head.

Legacy non-unified rendering should keep its current ring interpretation unless a later cleanup explicitly migrates it.

## Current Problem

The current body-profile defaults still start with `snout` at `x = 0.0` and `head` near `x = 0.15`, then `_build_shell_profile_from_rings()` maps those logical x values into the body shell range from the head-shell start to the body end. `_apply_static_unified_surface()` then welds the generated head grid to `shell_profile[body_start_index]`, which is usually the first shell ring. That means the unified mesh still treats the first logical ring as the body boundary instead of a real snout/front-head sample.

This is why the naming now feels wrong: the renderer has become continuous, but the editable ring model is still carrying the old separated-head seam workaround.

## Chosen Approach

Use the visual option A: unified rendering should preserve user-facing `snout` and `head` as real head locations while moving the weld concept into generated/internal data.

The implementation should add a unified-specific mapping layer rather than rewriting every saved profile immediately. The mapping layer can derive unified head-control samples from the existing logical rings, while the body shell starts from the first actual body boundary ring. This keeps saved presets readable and avoids a destructive migration.

Practical shape:

- Build or expose a unified head-ring map that associates logical `snout` and `head` handles with head-surface sample locations.
- Keep generated/interpolated shell support rings hidden from the ring editor, as existing `__neck_fill_*` rings already do.
- Make `_unified_surface_body_start_index()` and the generated boundary ring own the weld point.
- Keep non-unified head-shell crutch behavior isolated behind `not _unified_surface_enabled()`.

## Data Flow

`BodyProfile.ensure_body_profile()` continues to return logical profile rings for presets and editor state. `FishRig` then interprets those rings differently by render mode:

- Legacy path: logical rings feed the body shell profile as they do today, including legacy head-shell crutches and neck smoothing.
- Unified path: logical `snout` and `head` influence head-grid samples; body-shell sampling and fin attachment start from body/shoulder rings and generated boundary data.

The unified mesh builder should still receive one ordered grid: head rings first, then a body boundary ring, then body rings. The difference is semantic ownership: front head rings come from head sampling, and the weld ring is generated from the body boundary, not treated as the user-facing snout.

## Editor Behavior

The ring editor should show handles whose positions match what the ring names imply in unified mode. Users dragging `snout` should affect the front snout/head cross-section; users dragging `head` should affect the head volume. They should not be unknowingly dragging the weld boundary.

If this creates two different display positions for the same saved ring depending on render mode, that is acceptable for this pass because the unified surface is now the default preset path. Legacy behavior remains available through explicit `unified_surface_enabled = 0.0`.

## Testing

Use focused Godot CLI coverage before implementation changes pass:

- A regression test that fails under current behavior: in unified mode, the visible/logical `snout` and `head` ring handles should be positioned before the generated neck/body boundary, not on top of it.
- A unified mesh continuity test proving the generated body boundary remains welded after the logical ring remap.
- Existing `UnifiedFishRigSurface` and `UnifiedSharkRigSurface` tests should still pass.
- Existing `HeadShellSeam` / `SharkHeadShellSeam` should still pass, with legacy cases explicitly forcing `unified_surface_enabled = 0.0` where they inspect legacy head mesh containment.
- Run ring-editor focused tests if handle-position APIs are touched.

Use `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter <test_name>` for each focused check.

## Non-Goals

- Do not perform a destructive preset migration in this pass.
- Do not remove the legacy non-unified path.
- Do not expose generated boundary rings as user-editable handles.
- Do not redesign shark head morphology controls or head-profile sliders here.