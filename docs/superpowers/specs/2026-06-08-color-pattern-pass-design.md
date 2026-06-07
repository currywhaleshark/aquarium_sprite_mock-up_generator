# Color & Pattern Pass

## Goal

Body shape and fins already have good authoring freedom; **color and pattern are the remaining
gap** for making readable, distinct aquarium fish sprites. This pass builds the color/pattern
system on top of the existing UV toon shader, and is validated against the **whale shark** —
the project's must-have large species, whose pale spot-and-bar grid on a dark countershaded
body is the stress test for "enough detail at large display size."

Design is grounded in fish-coloration biology (two orthogonal axes: countershading + disruptive
pattern) and reuses the existing `fish_body_toon.gdshader` pattern/marking pipeline. No new
geometry. Existing presets stay visually unchanged (every new control is a no-op at its
default).

## Background (the model we borrow)

Real fish coloration decomposes into two independent axes; we already have the first and
partially the second:

- **Countershading** — dark dorsal → light belly. The primary form cue. We have it
  (`belly_color`, `belly_height`, `belly_slope`).
- **Disruptive pattern** — marks that break the outline: **bars** (dorsoventral, our "stripes"
  kind 1), **stripes** (longitudinal, our "horizontal_stripes" kind 2), **spots** (light-on-dark
  or dark-on-light). We have stripes/spots/zebra/marbled/reticulated.

Two practical rules from the biology that the generator should exploit:

1. **Shape predicts pattern**: deep-bodied fish carry vertical bars; elongated fish carry
   horizontal stripes. So a sensible default pattern can be derived from the body silhouette.
2. **Polarity matters**: "light marks on dark" vs "dark marks on light" is a first-class toggle
   (whale shark = pale marks on dark).

Pattern math (reaction–diffusion / Turing) is the "true" generator of spots↔stripes and gives
per-individual uniqueness from a seed. Full reaction–diffusion is a multi-pass simulation; since
we are an **offline sprite generator**, it can be baked at export later (see Non-Goals). This
pass uses the existing cheap procedural patterns plus one new whale-shark grid, with a seed for
per-individual variation.

References: [Fish coloration — Wikipedia](https://en.wikipedia.org/wiki/Fish_coloration),
[Countershading](https://en.wikipedia.org/wiki/Countershading),
[Whale shark — Wikipedia](https://en.wikipedia.org/wiki/Whale_shark),
[Body markings of the whale shark (elasmo-research)](http://www.elasmo-research.org/publications/pdfs/whale_shark_pigmentation.pdf),
[Turing morphogenesis](https://cgjennings.ca/articles/turing-morph/).

## Feature A — Pattern polarity + per-individual seed (shader)

`shaders/fish_body_toon.gdshader`.

### New uniforms (near the pattern uniforms)

```glsl
uniform float pattern_invert : hint_range(0.0, 1.0) = 0.0;  // flip mark/background polarity
uniform float pattern_seed = 0.0;                            // per-individual variation
```

### Seed wiring

Make the procedural patterns depend on `pattern_seed` so different individuals differ. Offset
only the **longitudinal** coordinate (keep the circumferential axis periodic so the seam stays
seamless): inside `pattern_mask`, sample with `u + pattern_seed * 0.137` wherever `u` feeds
`pnoise`/`pvoronoi`/`hash21`, and add `pattern_seed` into the whale-grid cell hash (Feature C).

### Invert wiring

In `fragment()`, after computing the pattern mask and **only when a pattern is active**:

```glsl
float mask = pattern_mask(pattern_type, v_long, v_circ);
if (pattern_type != 0) {
    mask = mix(mask, 1.0 - mask, clamp(pattern_invert, 0.0, 1.0));
}
col = mix(col, pattern_color.rgb, mask * pattern_intensity);
```

(`pattern_invert` must not apply to `pattern_type == 0`/none, or the whole body floods with
`pattern_color`.)

## Feature B — Pattern density follows body size (shader uniform wiring)

`scripts/materials/ToonMaterialFactory.gd` — `make_body_material`.

Large species (whale shark) need many small marks; small fish need few large ones. Couple the
pattern repeat count to `body_length` via a new `pattern_size_lock` (0 = ignore size, current
behavior; 1 = full physical lock). Default 0, so existing presets are unchanged.

```gdscript
const PATTERN_REF_LENGTH := 1.45
var size_lock := clampf(float(parameters.get("pattern_size_lock", 0.0)), 0.0, 1.0)
var len_factor := lerpf(1.0, maxf(float(parameters.get("body_length", PATTERN_REF_LENGTH)) / PATTERN_REF_LENGTH, 0.1), size_lock)
material.set_shader_parameter("pattern_scale_x", maxf(float(parameters.get("pattern_scale_x", 6.0)) * len_factor, 0.0))
material.set_shader_parameter("pattern_scale_y", maxf(float(parameters.get("pattern_scale_y", 4.0)) * len_factor, 0.0))
```

Also set the two new shader uniforms here:

```gdscript
material.set_shader_parameter("pattern_invert", clampf(float(parameters.get("pattern_invert", 0.0)), 0.0, 1.0))
material.set_shader_parameter("pattern_seed", float(parameters.get("pattern_seed", 0.0)))
```

(Refinement option: couple `pattern_scale_y` to a body-height factor instead of length; left as
a tuning choice.)

## Feature C — Whale-shark grid pattern (shader)

Add `"whale_grid"` as pattern index 7.

- `scripts/creature/BodyProfile.gd`: append `"whale_grid"` to `PATTERN_TYPE_NAMES` (becomes
  index 7). `pattern_type_index`/`pattern_type_names` and the `ParameterPanel` dropdown pick it
  up automatically.
- `scripts/ui/UiText.gd`: add `"whale_grid": "격자무늬"` to the pattern labels.
- `fish_body_toon.gdshader` — add a `kind == 7` branch to `pattern_mask`: a half-staggered grid
  of soft pale spots with faint thin cross bars/stripes between them, jittered per cell by
  `pattern_seed` (the whale-shark "fingerprint"):

```glsl
if (kind == 7) {
    vec2 g = vec2(u * sx, v * per);
    vec2 cell = floor(g);
    vec2 fr = fract(g);
    float jx = hash21(cell + pattern_seed) - 0.5;
    float jy = hash21(cell + pattern_seed + 7.7) - 0.5;
    vec2 center = vec2(0.5 + jx * 0.5, 0.5 + jy * 0.5);
    float d = length((fr - center) * vec2(1.0, 1.2));
    float spot = 1.0 - smoothstep(0.16, 0.30, d);
    float bx = 1.0 - smoothstep(0.0, 0.06, abs(fr.x - 0.5));
    float by = 1.0 - smoothstep(0.0, 0.06, abs(fr.y - 0.5));
    float lines = max(bx, by) * 0.35;
    float keep = step(0.18, hash21(cell + pattern_seed + 3.3)); // drop some for irregularity
    return clamp(max(spot, lines) * mix(1.0, keep, 0.5), 0.0, 1.0);
}
```

These constants are a starting point; tune by render so the spot size and grid spacing read as a
whale shark at the intended large export size.

## Feature D — Harmonious palette derivation (color system)

Right now every colour (`base/belly/pattern`) is set independently, so random/archetype fish
can look incoherent. Add a single-base → harmonious-set derivation so the generator produces
sensible palettes, while explicit colours still win.

- New `palette_scheme` (string): `"manual"` (default — current behavior, no derivation) |
  `"countershade"` | `"complementary"` | `"analogous"` | `"muted"`.
- `scripts/creature/BodyProfile.gd`: add
  `static func derive_palette(base: Color, scheme: String) -> Dictionary` returning
  `{ "belly": Color, "pattern": Color }`:
  - `countershade`: `belly = base.lightened(0.5)` desaturated ~30%; `pattern = base.darkened(0.32)`.
  - `complementary`: `pattern` = base hue + 0.5 (HSV), moderate value; belly as countershade.
  - `analogous`: `pattern` = base hue ± 0.08; belly as countershade.
  - `muted`: all toward lower saturation; `pattern = base.darkened(0.22)`.
- Apply **at parameter-generation time** (archetype defaults / randomizer / new-fish defaults),
  not in the material factory, so saved presets store concrete colours: when
  `palette_scheme != "manual"` and `belly_color` / `pattern_color` are not explicitly provided,
  fill them from `derive_palette(base_color, palette_scheme)`. The material factory stays a dumb
  mapper. Integration point: wherever `SpeciesArchetype` / preset defaults assemble parameters.

## Feature E — Shape → default pattern (generator helper)

`scripts/creature/BodyProfile.gd`:

```gdscript
static func suggest_pattern(body_length: float, body_height: float) -> String:
    var aspect := body_height / maxf(body_length, 0.001)   # deep body -> high
    if aspect > 0.42: return "stripes"             # deep body -> vertical bars (kind 1)
    if aspect < 0.26: return "horizontal_stripes"  # elongated  -> longitudinal stripes (kind 2)
    return "spots"
```

Use it only as the **default** when an archetype/preset does not specify `pattern_type` (or sets
it to a sentinel `"auto"`). Never override an explicit user choice. This makes generated fish
look plausible for free by coupling the existing body-shape freedom to pattern.

## Whale-shark validation recipe

The acceptance target. With the above, a whale shark is expressed as parameters (no new
geometry needed beyond the existing broad/flattened head + elongated body controls):

```text
base_color        dark blue-grey (e.g. #3b4a57)
belly_color       white (#f2f5f7)   ; strong countershading
belly_height      ~0.62 ; belly_slope ~0.18
pattern_type      whale_grid
pattern_color     pale (#cfe0e6)
pattern_intensity ~0.85
pattern_size_lock ~1.0   ; small dense spots at the whale shark's large body_length
pattern_seed      per individual (fingerprint)
```

The longitudinal body ridges, if wanted, are a separate marking-layer line (or a later subtle
geometry pass) — out of scope here. Because the pattern is procedural in UV, it is
**resolution-independent**: exporting the whale shark at a larger sprite size yields crisp spot
detail with no re-authoring — this is how the system "doesn't ignore detail" for big species.

## Data Model

Add to the `visual_profile` pick list in `BodyProfile.split_parameters_into_profiles` (next to
the existing pattern keys):

```text
pattern_invert
pattern_seed
pattern_size_lock
palette_scheme
```

These round-trip through save/load like the other visual keys. Legacy presets without them use
the runtime defaults (all no-ops), so nothing changes for existing fish.

## UI

- `pattern_type` dropdown gains `"whale_grid"` automatically (it reads `pattern_type_names()`).
- Add controls in the visual/parameter panel: `pattern_invert` (toggle/slider 0–1),
  `pattern_size_lock` (slider 0–1), `pattern_seed` (slider/stepper), and `palette_scheme`
  (option). Labels in `UiText.gd`.
- Keep them in the existing visual section near `pattern_type` / `pattern_color`.

## Testing

### PatternTest.gd (extend)

- `PATTERN_TYPE_NAMES.size()` is now **8**; `pattern_type_index("whale_grid") == 7`.
- A fish with `pattern_type = "whale_grid"` sets the shader `pattern_type` uniform to 7.
- `pattern_invert` / `pattern_seed` / `pattern_size_lock` / `palette_scheme` round-trip through
  `split_parameters_into_profiles` and `make_parameters_from_structured_preset`.
- `pattern_size_lock = 1.0` with a larger `body_length` yields a larger effective
  `pattern_scale_x` uniform than `pattern_size_lock = 0.0` (density follows size).
- `suggest_pattern`: deep body → `"stripes"`, elongated → `"horizontal_stripes"`, mid → `"spots"`.
- `derive_palette`: `countershade` belly is lighter than base, pattern darker than base (luma
  checks); `manual` scheme returns/derives nothing (explicit colours preserved).

### Manual render check (required — patterns are visual)

Render the whale-shark recipe at the intended large export size plus a couple of small species,
side and three-quarter. Confirm: whale-shark pale grid reads against the dark countershaded
body; `pattern_invert` flips polarity; `pattern_seed` changes the pattern without changing its
character; small fish still read with few bold marks.

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

## Acceptance Criteria

- Whale shark reads correctly: dark countershaded body, white belly, pale spot-and-bar grid,
  per-individual variation, crisp at large export resolution.
- `pattern_invert` flips any pattern's polarity; `pattern_seed` varies individuals;
  `pattern_size_lock` keeps mark size sensible across body sizes.
- `palette_scheme` (non-manual) produces coherent base/belly/pattern sets; `manual` preserves
  explicit colours.
- `suggest_pattern` gives shape-appropriate defaults without overriding explicit choices.
- Existing presets/fish are visually unchanged (all new controls default to no-ops). CLI tests
  pass; manual render confirms the look.

## Non-Goals

- **Reaction–diffusion bake** (offline-generated coat textures sampled by a pattern slot) — the
  "true" pattern engine and the path to fully unique coats; deferred to a later pass. Design the
  whale-grid and seed now so RD can slot in later as another `pattern_type`.
- No new body/fin geometry; whale-shark proportions use existing shape controls. Body ridges and
  the ray belly-on-glass pose are separate future work.
- No change to the marking-layer system, the export/8-direction pipeline, or motion.
- Do not auto-apply `palette_scheme` or `suggest_pattern` to existing saved presets (defaults
  keep them manual / explicit).
```
