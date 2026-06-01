# Fish Patterns, Colors & GIF Export Handoff - 2026-06-02

## Branch

- Current branch: `feature/turning-motion-refinement`
- Builds on the patterns/colors implementation plan committed in `fc9a6d7`.

## Scope Completed

This pass implemented procedural fish patterns + countershading colors, fixed a
turn-time pattern shimmer, added animated GIF export alongside PNG, and fixed a
GIF LZW desync bug.

## Patterns & Colors

- New shared opaque toon material for the body shell **and** head so color and
  pattern flow continuously across the neck:
  - `shaders/fish_body_toon.gdshader` (new).
  - `ToonMaterialFactory.make_body_material(parameters)` (new).
  - `FishRig` now uses this material for `outer_shell` and `head_node`;
    `secondary_color` is demoted to head-appendage / eye-stalk accent only.
- Pattern types (stored as a string key, mapped to a shader int):
  `none, stripes, horizontal_stripes, spots, zebra, marbled`.
- Countershading (back→belly gradient) is always applied, independent of pattern.
- Parameters added to `visual_profile`: `pattern_type, pattern_color,
  pattern_scale_x, pattern_scale_y, pattern_intensity, belly_height`.
  - `BodyProfile.ensure_visual_parameters()` injects defaults so older presets
    expose the controls.
  - Added to the `visual_profile` `_pick` list in
    `split_parameters_into_profiles()` so user-preset save/load round-trips them.
  - `PresetStore.normalize_preset()` calls `ensure_visual_parameters()` on BOTH
    load paths (the pre-baked `parameters` path previously skipped it, which hid
    the controls for some presets).
- UI: `무늬 설정` (Pattern Settings) section, `무늬 종류` dropdown, Korean labels in
  `UiText.gd`; `ParameterPanel` marks `pattern_type` as an option and fixes the
  slider ranges for `pattern_scale_x/y` (the `_x/_y` suffix was being treated as a
  signed parameter).

## UV Mapping

- `PrimitiveFactory.build_fish_outer_shell_mesh()` now emits `ARRAY_TEX_UV` with a
  **duplicated seam column** (`segments + 1` verts per ring) so circumferential
  patterns wrap with no seam. NOTE: this changed the shell vertex count/index
  layout; nothing depended on the old indexing (ShellRigTest still passes).
- `PrimitiveFactory.deformed_head_mesh()` sets per-vertex UVs; head U is compressed
  into `[0, 0.25]` so stripe density on the head matches the body shell.

## Turn-Time Shimmer Fix (important)

- Symptom: during turning the pattern did not follow the body — it shimmered.
- Cause: the shader sampled the longitudinal coordinate from WORLD position
  (`MODEL_MATRIX * VERTEX`), so rotating/rolling the fish slid the pattern through
  world space.
- Fix: the shader is now **fully UV/topological** — no world or model position is
  used:
  - longitudinal = `UV.x`, circumference = `UV.y`.
  - countershading "up" is derived from `sin(UV.y * TAU)` (+1 dorsal, -1 belly),
    so the gradient rolls with the body instead of staying world-vertical.
- Result: the pattern is painted on the surface and follows bend / turn / roll.
- Removed now-unused shader uniforms `body_length`, `body_half_height` and their
  setters in `make_body_material`.

## GIF Export

- `scripts/export/GifEncoder.gd` (new): self-contained animated GIF89a encoder.
  Godot has no built-in GIF export.
  - Median-cut global palette (255 colors + index 0 transparent).
  - 1-bit transparency (alpha < 128 → transparent), disposal "restore to bg".
  - LZW compression, Netscape looping extension.
- `SpriteExporter.export_preset()` collects the primary direction's frame images
  and writes `exports/<preset>/<preset>.gif` next to the PNG frames / sheet /
  metadata. Frame delay derives from `frame_rate` (default 12 fps). GIF failure is
  non-fatal (PNGs are the primary deliverable; it pushes a warning).
  - For 8-direction export, only the FIRST direction is turned into a GIF today.

## GIF LZW Desync Bug Fix (important)

- Symptom: the first real exported fish GIF decoded to a thin band of garbage at
  the top, then transparency ("지지직" static), while the source PNGs were fine.
- Cause: LZW code-size growth was one step late — it incremented `code_size` AFTER
  `next_code++` using `== (1 << code_size)`. The decoder learns each dictionary
  entry one step later, so the streams desynced around the 512th code (the 9→10
  bit boundary). Small test frames never reach that boundary, so the first test
  missed it.
- Fix: match the canonical (omggif) encoder — grow `code_size` BEFORE assigning the
  new code, using `next_code >= (1 << code_size)`, with the 4096 dictionary reset
  handled as an explicit branch.
- Verified: a 128×128 busy frame (exercises code-size growth AND the 4096 reset)
  encoded, then decoded with a real Windows GIF decoder (System.Drawing) and
  compared to a reference PNG: **alpha mask 100% match, 0 color mismatches**
  (max per-pixel color delta 74 = palette quantization only).

## Tests

- New `scenes/PatternTest.tscn` + `scripts/tools/PatternTest.gd`: UV presence
  (static + bent rebuild), shader compiles, `make_body_material` uniforms, preset
  round-trip, legacy-default injection.
- New `scenes/GifEncoderTest.tscn` + `scripts/tools/GifEncoderTest.gd`: GIF89a
  header/size/trailer, Netscape signature, empty-input rejection, and a large busy
  frame to exercise LZW growth/reset (with a reference PNG for external decode).
- Full suite: `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`
  → 29 scene tests pass (ExportSmokeTest skips under headless dummy rendering).

## Manual Verification Still Needed

Headless dummy rendering cannot capture shader output, so visual confirmation is
manual:
- Open the editor, pick each pattern, confirm opaque body, back→belly gradient,
  even stripe density across the neck seam, no circumference seam, and that the
  pattern follows turning/roll without shimmer.
- The existing `exports/an/an.gif` was produced BEFORE the LZW fix and is still
  broken — re-export to get a correct GIF.

## Next Work

1. **8-direction sequential GIF export.** Produce a single GIF that steps through
   all 8 directions in sequence (e.g., east → north_east → ... → south_east), not
   just the first direction. Decide ordering and per-direction frame handling:
   - Option A: one GIF cycling directions, each direction holding its animation
     frames before advancing.
   - Option B: a separate GIF per direction plus one combined "turntable" GIF.
   - `SpriteExporter.export_preset()` already renders every direction's frames in
     `frame_rows`; currently only `direction_index == 0` images are kept for the
     GIF (`gif_images`). Extend to collect/sequence all directions.
2. Consider exposing GIF options in the Export panel (loop, fps already implied by
   `frame_rate`, include-directions toggle).
3. Optional polish: fin edge/accent coloring and extending body patterns onto fins
   (out of scope this pass; fins remain single `fin_color` + `secondary_color`).
