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
  into `[0, HEAD_U_SPAN]` so stripe density on the head matches the body shell.
  `HEAD_U_SPAN` (= 0.25) is now a single module-level constant in `PrimitiveFactory`
  documenting that it must equal the head's physical fraction of total fish length;
  the body shell maps U over `[0, 1]` and relies on this for neck-seam continuity.

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
- `SpriteExporter.export_preset()` collects every rendered frame image (in render
  order) and writes `exports/<preset>/<preset>.gif` next to the PNG frames / sheet /
  metadata. Frame delay derives from `frame_rate` (default 12 fps). GIF failure is
  non-fatal (PNGs are the primary deliverable; it pushes a warning).
  - Single-direction export → a one-direction swim loop.
  - 8-direction export → a single turntable GIF that steps through all directions
    in sequence (east → north_east → … → south_east), each holding its swim
    animation before the fish turns to the next, then loops (Option A).

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

## Color/Pattern Realism Additions (follow-up pass)

Driven by two references: a fish-color research note (color layers + pattern masks +
procedural rules + material layers) and a Godot 4 fish-shader guide (thin-film
iridescence, clearcoat wetness, fin backlight, underwater scene). Only the parts that
fit this procedural real-time toon side-view sprite generator were taken; the
photo-based PBR pipeline (photogrammetry, normal/AO bake, RAW+CIELAB capture,
Substance projection, metallic maps) and the underwater scene parts (volumetric fog,
coloured background, caustics, schooling/LOD) were skipped as out-of-architecture —
note the background must stay transparent for sprite cutout (`default_clear_color`
alpha 0), which directly rules out the guide's underwater environment.

- **Iridescence sheen (iridophores)** — `fish_body_toon.gdshader`: an oil-slick hue
  shift added as `EMISSION`. IMPORTANT: the hue phase is driven by the SURFACE
  (`v_long` along the body + the seamless `up = sin(v_circ*TAU)` belly→back term),
  NOT by view/fresnel alone. A pure fresnel term lands only on the rounded head and
  silhouette edges, because the broad side-view flank faces the camera at ~0 fresnel
  (this was an actual reported bug: "sheen only on the head"). Fresnel is kept as an
  edge accent + a 0.45 floor so the whole flank shimmers and it rolls with the body.
  Uniforms `iridescence_strength` (default 0.0 → existing presets unchanged),
  `iridescence_color` (`#bfe9ff`), `iridescence_frequency` (bands along the body).
- **Wetness (`wetness`, clearcoat + broad wet cues)** — a sharp specular highlight
  alone barely changes a toon flank, so wetness leans on broad cues: it darkens the
  albedo (`×mix(1.0, 0.74, wetness)`), lowers `ROUGHNESS`, lifts `SPECULAR`, adds a
  fresnel grazing sheen, and a `CLEARCOAT` lobe. Forward+ only; default 0.0.
- **`belly_slope` exposed** — the back→belly gradient sharpness was a hardcoded 0.22
  in `make_body_material`; now a parameter (clamped 0.02–1.0).
- **Reticulated pattern** — new pattern type `reticulated` (shader int 6): a periodic
  Voronoi cell-edge net (`pvoronoi_edge`), seam-free in V. For moray/pufferfish nets.
- Plumbing followed the existing pattern path: `BodyProfile` `VISUAL_PATTERN_DEFAULTS`
  + `visual_profile` `_pick` list (round-trips on save/load), `UiText` Korean labels
  (`망상무늬`, `배 색 경계 부드러움`, `무지개빛 광택`, `무지개빛 색`, `무지개빛 빈도`,
  `젖은 광택`), `ParameterPanel` category + slider ranges. `PatternTest` extended to
  cover all of the above (uniforms, preset round-trip, legacy default injection).
- Caveat: shader VISUAL correctness (iridescence/wetness/reticulated look) cannot be
  checked under headless dummy rendering — verified manually in the editor.

## Next Work

1. ~~**8-direction sequential GIF export.**~~ DONE — `SpriteExporter.export_preset()`
   now collects every direction's frames in render order, so an 8-direction export
   produces one turntable GIF cycling all directions (Option A). Still needs manual
   visual confirmation (headless can't capture shader output).
2. Consider exposing GIF options in the Export panel (loop, fps already implied by
   `frame_rate`, include-directions toggle).
3. Optional polish: fin edge/accent coloring and extending body patterns onto fins
   (out of scope this pass; fins remain single `fin_color` + `secondary_color`).
