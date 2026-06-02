# Implementation Plan: Fish Patterns and Colors

We will implement procedural fish patterns (stripes, spots, zebra, marbled) and
realistic color controls (back-to-belly countershading) for the procedural fish
rig. The output is a side-view sprite for a 2D aquarium game, so the priority is a
believable, opaque silhouette with continuous color across the head/body seam —
not physically accurate 3D texturing.

This is achieved by (1) generating arc-length UV coordinates on the head and body
meshes, (2) a custom spatial shader that reuses Godot's toon lighting while adding
countershading and seamless procedural patterns, and (3) wiring the new parameters
through the existing preset save/load and UI plumbing.

## Current-State Constraints (read before implementing)

These facts about the existing rig drive several decisions below:

*   **The visible body surface is a single `outer_shell` mesh, and it is currently
    a *transparent* overlay** (`shell_opacity 0.72`, `TRANSPARENCY_ALPHA`) — see
    [FishRig.gd:77](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/FishRig.gd)
    and `ToonMaterialFactory.make_shell`. A patterned transparent body would let
    the background show through the stripes, so **the patterned body must be opaque.**
*   **The head (`head_node`) is a separate mesh drawn with `secondary_color`, and
    the shell uses a `base_color⊗secondary_color` mix** —
    [FishRig.gd:76](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/FishRig.gd),
    [FishRig.gd:112](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/FishRig.gd).
    For a pattern to flow continuously from head to body, **both meshes must share
    the same `base_color` and the same shader material.**
*   **Preset persistence is driven by explicit key lists in
    `BodyProfile.split_parameters_into_profiles()` and
    `make_parameters_from_structured_preset()`**, not by the `visual_profile`
    defaults alone. New parameters must be added to those lists or they will be
    silently dropped on user-preset save/load.
*   **Headless dummy rendering cannot capture shader output** (`ExportSmokeTest`
    already skips for this reason), so visual correctness is verified manually;
    automated tests cover UV presence, uniform population, and shader compilation only.

## Proposed Changes

### 1. Mesh UV Mapping (arc-length, seam-continuous)

To render continuous patterns across the head→body transition, UVs must be
**continuous in physical width**, not just normalized 0..1 per mesh. Because the
head is scaled independently of the body, a naive `i / ring_count` mapping makes
stripe spacing jump at the neck. We therefore map `U` to **cumulative arc length
along the longitudinal axis**, normalized so the head occupies the `[0, head_frac]`
range and the body occupies `[head_frac, 1.0]`, where `head_frac` is the head's
longitudinal length as a fraction of total fish length. `V` wraps the circumference
0..1.

#### [PrimitiveFactory.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/PrimitiveFactory.gd)
*   **Body shell (`build_fish_outer_shell_mesh`)**:
    *   Initialize `uvs := PackedVector2Array()` and populate `arrays[Mesh.ARRAY_TEX_UV]`.
    *   `u` = normalized cumulative distance between successive ring centers along
        X (so non-uniform ring spacing keeps even stripe widths), remapped into the
        body's `[head_frac, 1.0]` sub-range.
    *   `v = float(segment) / float(segments)`.
    *   This function is shared by the static build and the per-frame bent rebuild
        (`update_fish_outer_shell_bent`), so UVs are added in one place and animate
        for free.
*   **Head mesh (`deformed_head_mesh`)**:
    *   Switch from raw `SurfaceTool.add_vertex` to `st.set_uv(Vector2(u, v))` before
        each vertex.
    *   `u` = the head's per-ring X position mapped into `[0, head_frac]` so head
        `u == head_frac` meets body `u == head_frac` at the neck.
    *   `v = float(j) / float(segments)`.
*   Expose `head_frac` (or pass it in) so both meshes agree on the split point.
    Because the absolute scales still differ slightly, a small residual seam is
    acceptable for a side-view sprite; the goal is even stripe spacing, not a
    perfect 3D wrap.

---

### 2. Shader & Material Infrastructure

We create one spatial shader that the body shell **and** the head share, reusing
Godot's toon lighting.

#### [NEW] [fish_body_toon.gdshader](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/shaders/fish_body_toon.gdshader)
*   `render_mode diffuse_toon, specular_schlick_ggx, cull_disabled;` — **opaque**
    (no `blend_mix`/alpha), so the body silhouette is solid.
*   Uniforms:
    *   `base_color` (Color): fish back/dorsal color.
    *   `belly_color` (Color): fish belly/ventral color.
    *   `pattern_color` (Color): pattern overlay color.
    *   `belly_height` (float): object-space vertical center of the back→belly gradient.
    *   `belly_slope` (float): gradient sharpness.
    *   `pattern_type` (int): `0 None, 1 Vertical Stripes, 2 Horizontal Stripes,
        3 Spots, 4 Zebra, 5 Marbled`.
    *   `pattern_scale_x`, `pattern_scale_y` (float): pattern frequency in U / V.
    *   `pattern_intensity` (float): pattern blend opacity.
    *   `highlight_strength`, `rim_strength` (float): toon sheen / Fresnel edge,
        carried over from `make_surface` so patterned fish keep the existing
        aquatic look.
*   **Countershading**: computed from **object-space `VERTEX.y`** (vertical), not UV
    `V`. Use a normalized height so per-ring `y_offset` does not skew the gradient;
    `smoothstep(belly_height - belly_slope, belly_height + belly_slope, y_norm)`
    blends `belly_color` → `base_color`. This single gradient is the largest
    realism lever and is applied even when `pattern_type == 0`.
*   **Patterns** — all must be **seamless across the V (circumference) wrap**:
    *   **Vertical stripes**: `sin(U * scale_x * TAU)` with a low-amplitude hash
        wobble on V for organic waviness.
    *   **Horizontal stripes**: periodic in V using `sin(2π·V·scale_y)` so the
        V=0/V=1 seam matches exactly.
    *   **Spots / Zebra / Marbled**: build a **periodic** value-noise/FBM by hashing
        on `(U, cos(2π·V), sin(2π·V))` instead of `fract(V*scale)` — this removes
        the vertical seam a naive cellular grid would produce. Zebra = thresholded
        high-frequency periodic noise; Marbled = multi-octave periodic FBM.
*   Pattern result modulates albedo: `albedo = mix(countershaded, pattern_color, pattern_mask * pattern_intensity)`.

#### [ToonMaterialFactory.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/materials/ToonMaterialFactory.gd)
*   Add `make_body_material(parameters: Dictionary) -> ShaderMaterial` that loads
    `fish_body_toon.gdshader`, instances a `ShaderMaterial`, and sets every color
    and pattern uniform from the rig parameters (including `highlight_strength`,
    `shadow_strength`, `rim`).
*   **Used for both the shell and the head**, replacing the current `shell_mat`
    (transparent mix) and `secondary_mat` head material in
    [FishRig.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/FishRig.gd).
*   `make_shell` is retained only for the legacy/transparent path; if a future
    "glass" look is wanted it stays available, but the default body is now opaque.

#### Color-role cleanup
*   `base_color` = back, `belly_color` = belly, `pattern_color` = pattern.
*   `secondary_color` currently triple-duties as head color + shell mix + fin
    highlight. After this change the head uses `base_color`, so secondary_color's
    head/shell roles disappear. **Keep `secondary_color` only as the fin
    highlight/accent** and document that; do not introduce a redundant fourth body
    color in the UI.
*   **Out of scope (note as follow-up):** fin edge/accent coloring and extending
    body patterns onto fins. Fins remain a single `fin_color` (+ `secondary_color`
    accent) this pass.

---

### 3. Parameters, Presets & UI Panel Integration

#### [BodyProfile.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/BodyProfile.gd)
*   Add defaults for `pattern_type`, `pattern_color`, `pattern_scale_x`,
    `pattern_scale_y`, `pattern_intensity`, `belly_height` (and `belly_slope` if
    exposed) to the `visual_profile` defaults.
*   **Critical (was missing): add the same keys to the `visual_profile` `_pick`
    list in [`split_parameters_into_profiles()`](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/BodyProfile.gd)**
    so user-preset save/load round-trips the pattern settings. Confirm
    `make_parameters_from_structured_preset()` merges `visual_profile` (it already
    does) so loading restores them.

#### [UiText.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/ui/UiText.gd)
*   Parameter labels:
    *   `"pattern_type": "무늬 종류"`, `"pattern_color": "무늬 색"`,
        `"pattern_scale_x": "무늬 가로 크기"`, `"pattern_scale_y": "무늬 세로 크기"`,
        `"pattern_intensity": "무늬 진하기"`, `"belly_height": "배 색 영역 높이"`.
*   Pattern option labels:
    *   `"none": "없음"`, `"stripes": "세로 줄무늬"`,
        `"horizontal_stripes": "가로 줄무늬"`, `"spots": "점무늬"`,
        `"zebra": "얼룩말무늬"`, `"marbled": "대리석무늬"`.

#### [ParameterPanel.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/ui/ParameterPanel.gd)
*   Categorize the new keys under a `"무늬 설정"` (Pattern Settings) section in
    `_category_for_key()`; keep `belly_height`/colors under the existing `색상 설정`.
*   Mark `pattern_type` as an option parameter in `_is_option_parameter()`.
*   Return the pattern option keys from `_options_for_key()`.

---

## Verification Plan

### Automated Tests
*   New `PatternTest.gd`:
    *   Outer-shell and deformed-head meshes expose non-empty, correctly sized
        `ARRAY_TEX_UV` arrays after generation (static and bent rebuild paths).
    *   **Shader compiles**: `load("res://shaders/fish_body_toon.gdshader")` is a
        valid `Shader` and `make_body_material()` returns a non-null `ShaderMaterial`
        with all pattern/color uniforms populated. (Catches shader-compile errors
        that headless rendering cannot surface visually.)
    *   **Preset round-trip**: `split_parameters_into_profiles()` →
        `make_parameters_from_structured_preset()` preserves every pattern/belly
        parameter (guards against the save/load drop bug).
*   Run the full suite to check for regressions:
    `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`

### Manual Verification (only place visuals can be confirmed)
*   Launch the editor; switch each pattern (Stripes, Spots, Zebra, Marbled) and
    tune scale/intensity/color.
*   Confirm the body is **opaque** (no background bleed through patterns).
*   Confirm the back→belly gradient reads correctly and is independent of pattern.
*   Confirm stripe spacing stays even across the **head→body neck seam** and that
    spots/marbled show **no vertical seam** at the circumference wrap (V=0/V=1).
*   Confirm head and body share base color (head no longer renders as
    `secondary_color`).
