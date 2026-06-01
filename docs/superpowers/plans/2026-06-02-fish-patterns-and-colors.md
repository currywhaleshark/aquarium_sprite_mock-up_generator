# Implementation Plan: Fish Patterns and Colors

We will implement procedural fish patterns (such as stripes, spots, zebra, and marbled) and advanced color controls (belly-to-back blending) for the procedural fish rig. This will be achieved by adding proper UV coordinates to the generated meshes and creating a custom spatial shader that preserves Godot's built-in toon lighting.

## Proposed Changes

### 1. Mesh UV Mapping Configuration

To apply textures or shaders to procedural meshes, we must generate UV coordinates. We will map longitudinal $(U)$ and circumferential $(V)$ dimensions on both the head and body meshes so that shaders can render continuous patterns across the head-body transition.

#### [PrimitiveFactory.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/PrimitiveFactory.gd)
*   **Body Shell Mesh UVs (`build_fish_outer_shell_mesh`)**:
    *   Initialize `uvs := PackedVector2Array()` array.
    *   For each vertex at ring index `i` and segment index `j`, compute:
        *   `u = float(i) / float(profile.size() - 1)` (runs from 0.0 at the snout/neck to 1.0 at the tail).
        *   `v = float(j) / float(segments)` (runs from 0.0 to 1.0 around the cylindrical circumference).
    *   Add UVs to `arrays[Mesh.ARRAY_TEX_UV]`.
*   **Head Mesh UVs (`deformed_head_mesh`)**:
    *   For each vertex at ring index `i` and segment index `j`, compute:
        *   `u = float(i) / float(rings)` (runs from 0.0 at the snout tip to 1.0 at the neck boundary).
        *   `v = float(j) / float(segments)` (runs from 0.0 to 1.0 around the head circumference).
    *   Call `st.set_uv(Vector2(u, v))` right before adding the vertex inside `deformed_head_mesh()`.
    *   This ensures that $U$ remains continuous at the neck boundary (where head $U=1.0$ matches body $U=0.0$), allowing seamless pattern propagation.

---

### 2. Shader & Material Infrastructure

We will create a custom spatial shader that blends base colors, belly gradients, and procedural patterns, while reusing Godot's high-quality built-in toon lighting renderer.

#### [NEW] [fish_body_toon.gdshader](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/shaders/fish_body_toon.gdshader)
*   Create a Spatial Shader with `render_mode diffuse_toon, specular_schlick_ggx, cull_disabled;`.
*   Define uniforms:
    *   `base_color` (Color): The main color of the fish back.
    *   `belly_color` (Color): The color of the fish belly.
    *   `pattern_color` (Color): The color of the procedural pattern.
    *   `belly_height` (float): The vertical position of the belly-to-back gradient transition.
    *   `belly_slope` (float): The sharpness of the gradient blend.
    *   `pattern_type` (int): `0: None`, `1: Vertical Stripes`, `2: Horizontal Stripes`, `3: Spots`, `4: Zebra`, `5: Marbled`.
    *   `pattern_scale_x` (float), `pattern_scale_y` (float): Scaling factors for the pattern.
    *   `pattern_intensity` (float): Blending opacity of the pattern.
    *   Toon visual settings: `highlight_strength` and `rim_strength`.
*   Implement procedural pattern algorithms:
    *   **Stripes**: Sinusoidal waves over $U$ (vertical) or $V$ (horizontal) modulated by a simple pseudo-random noise function for natural organic waviness.
    *   **Spots**: A cellular grid calculation in UV space that outputs smooth circles.
    *   **Zebra**: Modulated high-frequency wave patterns using noise.
    *   **Marbled**: Multi-octave fractional brownian motion (FBM) or turbulence noise to create organic marbled textures.

#### [ToonMaterialFactory.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/materials/ToonMaterialFactory.gd)
*   Add a function `make_body_material(parameters: Dictionary) -> ShaderMaterial` that loads `fish_body_toon.gdshader`, instances a `ShaderMaterial`, and synchronizes all color and pattern uniforms from the rig parameters.
*   Update `make_shell` if needed to support transparent overlays with pattern matching.

---

### 3. Parameters, Presets & UI Panel Integration

We will register the new customization variables into the parameter parser, define localized display texts, and expose them as controls in the editor.

#### [BodyProfile.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/BodyProfile.gd)
*   Add pattern parameters (`pattern_type`, `pattern_color`, `pattern_scale_x`, `pattern_scale_y`, `pattern_intensity`, `belly_height`) with default values to the `visual_profile` mapping.

#### [UiText.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/ui/UiText.gd)
*   Add translations for parameters:
    *   `"pattern_type": "무늬 종류"`
    *   `"pattern_color": "무늬 색"`
    *   `"pattern_scale_x": "무늬 가로 크기"`
    *   `"pattern_scale_y": "무늬 세로 크기"`
    *   `"pattern_intensity": "무늬 진하기"`
    *   `"belly_height": "배 색 영역 높이"`
*   Add translations for pattern options:
    *   `"none": "없음"`, `"stripes": "세로 줄무늬"`, `"horizontal_stripes": "가로 줄무늬"`, `"spots": "점무늬"`, `"zebra": "얼룩말무늬"`, `"marbled": "대리석무늬"`

#### [ParameterPanel.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/ui/ParameterPanel.gd)
*   Categorize new parameters under `"Color Settings"` or a new `"Pattern Settings"` section inside `_category_for_key()`.
*   Mark `pattern_type` as an option parameter in `_is_option_parameter()`.
*   Return the array of pattern option keys in `_options_for_key()`.

---

## Verification Plan

### Automated Tests
*   Create a new test file `PatternTest.gd` to verify:
    *   Outer shell mesh and deformed head mesh have valid UV arrays after generation.
    *   `ToonMaterialFactory.make_body_material()` correctly instantiates a `ShaderMaterial` and populates all pattern uniforms.
*   Run the entire Godot CLI test suite to ensure zero regressions:
    `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1`

### Manual Verification
*   Launch the editor and modify color presets.
*   Select different patterns (Stripes, Spots, Zebra, Marbled) and tweak their scale, intensity, and color.
*   Verify that patterns connect smoothly and wrap seamlessly around the boundary where the body shell meets the head mesh.
