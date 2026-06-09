# Regional Color, Scale, and Marking System Research Report

**Date:** 2026-06-09

**Purpose:** Decide how the generator should represent fish whose scale texture,
pigment pattern, color, iridescence, and markings differ by anatomical region.

**Scope:** Research-backed design direction only. This is not the implementation
checklist; it should become the source for a follow-up implementation plan.

---

## Executive Summary

The next color/pattern pass should treat fish appearance as a set of anatomical
modules rather than one global body material with a few overlay markings.

The current system already has a useful base:

- global body colors: `base_color`, `belly_color`, `pattern_color`
- countershading controls: `belly_height`, `belly_slope`
- procedural body patterns: bars, horizontal stripes, spots, marbled,
  reticulated, whale-grid
- scale controls: `scale_type`, `scale_strength`, `scale_size`,
  `pearlscale_strength`, `metallic_scale_strength`
- up to 8 `marking_layers` encoded by `SpeciesMarkingLayer.gd`

The gap is that these controls are mostly global. Real fish often combine
different visual modules: a dark dorsum, pale belly, colored fins, head masks,
caudal spots, iridescent lateral bands, scale-edge reticulation, and localized
sexual or species-recognition markings. The practical solution is not a full
biological pigment simulation. It is a region-aware layer stack:

1. **Base region palette** for dorsum/flank/belly/head/fins.
2. **Region masks** expressed in stable fish coordinates.
3. **Marking layers** with region targeting, blending, and priority.
4. **Scale/structural effects** that can vary per region.
5. **Preset/archetype recipes** that assemble biologically plausible modules.

Recommended first implementation target: extend `marking_layers` into a
region-aware visual layer system, then make body shader evaluation use a shared
region-mask function. This keeps the renderer cheap, preserves existing presets,
and lets biological complexity enter as authorable data instead of hardcoded
species cases.

---

## Existing Project Context

Relevant files after the fin-ray merge:

- `scripts/creature/BodyProfile.gd`
  - owns visual defaults, pattern/scale enums, palette helpers, profile
    splitting/round-trip.
- `scripts/materials/ToonMaterialFactory.gd`
  - maps parameter dictionaries to shader uniforms.
- `shaders/fish_body_toon.gdshader`
  - renders countershading, procedural patterns, iridescence, scale effects,
    marking layers, and operculum markings.
- `scripts/species/SpeciesMarkingLayer.gd`
  - normalizes up to 8 marking layers and encodes them into shader uniforms.
- `scripts/species/SpeciesArchetype.gd`
  - validates archetype marking-layer types.
- `scripts/species/SpeciesArchetypeStore.gd`
  - applies archetype visual profiles and marking layers.
- `scripts/ui/ParameterPanel.gd` / `scripts/ui/UiText.gd`
  - expose visual controls in the general UI.
- `scripts/tools/PatternTest.gd` and `scripts/tools/MarkingLayerTest.gd`
  - current regression coverage for visual material behavior.

The current `SpeciesMarkingLayer` vocabulary already points in the right
direction:

```text
lateral_line, horizontal_band, vertical_bar, caudal_spot, head_mask,
saddle, ocellus, calico_patch, fin_edge, fin_spots, scale_grid,
reticulated_zone
```

But layer zones are coarse: `body`, `head`, `fin`. That is too broad for
species where the dorsal third, ventral belly, caudal peduncle, cheek, operculum,
and individual fins need different visual behavior.

---

## Biological Findings

### 1. Fish color is layered, cellular, and region-specific

Fish coloration is produced by combinations of chromatophores and structural
reflectors. Teleost color commonly involves:

- **melanophores**: black/brown melanin
- **xanthophores / erythrophores**: yellow/orange/red pigments
- **iridophores / leucophores**: reflective or whitish structural colors
- sometimes **cyanophores**: blue coloration in some taxa

Cichlid literature is especially useful for this project because it frames fish
appearance as modular traits: body color, ventral color, dorsal color, bars,
stripes, and fin coloration can vary independently or semi-independently. It
also notes that chromatophores occur in skin, scales, and fins, which justifies
separate controls for body-scale effects and fin-specific markings.

Design implication: one global `base_color` plus one `pattern_color` is too
flat. The data model needs region-specific color modules, but they should
inherit from the global palette by default so simple fish remain simple.

### 2. Countershading is a base layer, not a special case

Countershading is the common dark-dorsal / light-ventral arrangement that
reduces body relief and silhouette. It often coexists with disruptive patterns.
Britannica also summarizes a practical morphology rule that is already reflected
in this project: deep-bodied schooling fishes often show vertical bands, while
elongated fishes often show horizontal stripes.

Design implication: countershading should stay as the lowest body color layer,
but future region masks must be able to override it locally. For example:

- dark dorsal saddle on top of countershading
- white belly that ignores spots
- red throat or operculum patch
- caudal peduncle spot

### 3. Body and fin patterns can differ

Zebrafish are the clearest model. Adult body stripes involve interactions among
melanophores, xanthophores, and iridophores. Research on zebrafish fin stripes
shows that anal and caudal fin patterns can emerge differently from body
patterns; fin rays, growth direction, and the body-fin boundary may matter.

Design implication: fins should not always inherit body patterns. They need a
separate, lighter-weight visual contract:

- inherit body palette by default
- optional fin edge color
- optional fin spots/bands/rays independent from body pattern
- per-fin overrides later, but start with grouped slots: median fins, paired
  fins, caudal fin, special fins

### 4. Scales are both geometry cues and color carriers

Fish skin protects, senses, and colors the animal; scales vary by group
(cycloid, ctenoid, ganoid, placoid), and color can come from skin/scales plus
reflective guanine structures. Structural coloration can produce blue/green or
metallic effects when melanophores and reflective cells interact.

Design implication: `scale_type` and `scale_strength` should not be just a
global overlay. Scale effects need regional modifiers:

- dorsal metallic sheen stronger than belly
- scale-grid visible only on flank
- reticulated scale edges on body but not head
- pearlscale/goldfish effects as localized scale highlights

### 5. Markings serve different biological functions

Not all markings are camouflage. Region-specific color can signal sex,
territory, schooling, species identity, eyespots, or courtship. Cichlid anal-fin
egg spots are a good example of a localized fin marking with a biological role.
Bright fin colors can be integrated with body modules or vary semi-independently.

Design implication: the system should model visual intent as layer types rather
than only raw textures. A layer type like `ocellus` or `fin_edge` carries useful
semantic constraints: where it belongs, how it falls off, and how it should
compose.

---

## Practical Rendering Model

### Coordinate Model

Use the existing fish UV/body-coordinate approach and define a shared region
space:

```text
u: head -> tail, 0..1
v: ventral -> dorsal, -1..1 or 0..1 depending shader path
side: visible side / dorsal / ventral / fin surface
slot: body, head, dorsal_1, dorsal_2, pectoral, pelvic, anal, caudal,
      adipose_fin, finlet
```

For the first pass, avoid mesh splits. Compute masks procedurally in shader:

```text
dorsal_band       v above threshold, with soft falloff
ventral_belly     v below threshold, with soft falloff
flank             middle v range
head              u before head/body boundary
caudal_peduncle   u near tail stem
saddle            dorsal-local oval/stripe by u range
```

### Layer Stack

Recommended fragment composition order:

1. **Base palette:** global base + countershading.
2. **Region color overrides:** dorsal/flank/belly/head/caudal-peduncle
   palette modules.
3. **Procedural global pattern:** current `pattern_type`, still useful for
   whole-body species.
4. **Regional marking layers:** extended `marking_layers`.
5. **Scale/structural effects:** scale grid, reticulation, metallic/pearl,
   iridescence.
6. **Anatomical overlays:** operculum, lateral line, eye/head details.

This order keeps large color masses stable and lets small markings sit on top.
Scale/iridescence should usually modulate rather than replace color, because in
real fish structural color often depends on underlying pigment context.

### Data Model Proposal

Keep the global controls as defaults and add optional region modules.

```gdscript
"region_palette": {
  "dorsal": {"color": "#233845", "blend": 0.8},
  "flank": {"color": "#46c6cf", "blend": 0.0},
  "belly": {"color": "#d6fbff", "blend": 1.0},
  "head": {"color": "#335a62", "blend": 0.4},
  "caudal_peduncle": {"color": "#1f3038", "blend": 0.3}
}
```

For shader uniform limits, do not pass arbitrary dictionaries directly. Normalize
into a bounded array like `marking_layers`:

```gdscript
const MAX_REGION_COLOR_LAYERS := 6
region_color_count
region_color_type_0       # dorsal, ventral, flank, head, caudal_peduncle...
region_color_value_0
region_color_rect_0       # u_start, u_end, v_center, thickness
region_color_params_0     # blend, softness, mode, seed
```

Extend `marking_layers` similarly:

```gdscript
{
  "type": "saddle",
  "region": "dorsal",
  "slot": "body",
  "color": "#17242b",
  "x_start": 0.45,
  "x_end": 0.72,
  "y": 0.75,
  "thickness": 0.18,
  "blend_mode": "multiply",
  "scale_follow": 0.4,
  "softness": 0.04,
  "intensity": 0.8
}
```

Add `region` while keeping the existing `zone` field for backward
compatibility:

```text
zone   = body/head/fin, broad shader target
slot   = body slot or fin slot, optional
region = dorsal/flank/ventral/head/cheek/operculum/caudal_peduncle/fin_tip...
```

### Blend Modes

Start with a small set:

- `normal`: mix color over base by alpha
- `multiply`: darken saddles/bars/reticulation
- `screen`: pale spots, reflective marks
- `add`: emissive/photophore-like accents, used sparingly
- `mask_only`: drives scale/iridescence modifiers without adding color

Keep defaults no-op. Existing `marking_layers` without `blend_mode` should use
the current behavior.

### Scale and Structural Regional Controls

Add region-aware scale modifiers rather than duplicating every scale parameter:

```gdscript
"scale_region_layers": [
  {
    "region": "flank",
    "scale_strength": 0.75,
    "scale_size": 18.0,
    "reticulation": 0.25,
    "metallic": 0.4,
    "iridescence": 0.2
  },
  {
    "region": "belly",
    "scale_strength": 0.15,
    "metallic": 0.05
  }
]
```

For v1, this can be folded into marking layers by adding layer types:

- `scale_region`
- `reticulation_region`
- `iridescence_region`

This avoids building a second layer system before we know the UI shape.

---

## UI/Authoring Proposal

### Visual Panel

Keep simple users in the current panel:

- global palette
- belly/countershade controls
- global pattern
- global scale controls

Add a new advanced section:

```text
Regional Appearance
```

Rows:

- region selector: dorsal / flank / belly / head / caudal peduncle / fins
- color override
- blend strength
- softness
- scale strength override
- iridescence override

### Marking Layer Editor

The project already has `marking_layers` as data but not a rich editor. The next
real UI investment should be a small layer-list editor:

- add/remove/reorder layer
- type dropdown
- region dropdown
- slot dropdown when zone is `fin`
- color picker
- x range sliders
- y/thickness sliders
- intensity/softness/blend mode

This gives the most value because species archetypes and manual editing share
the same data model.

### Preset/Archetype Authoring

Archetypes should use visual recipes, not shader-specific jargon. Examples:

```json
{
  "name": "neon_tetra",
  "marking_layers": [
    {
      "type": "horizontal_band",
      "region": "flank",
      "color": "#32d7ff",
      "x_start": 0.16,
      "x_end": 0.92,
      "y": 0.20,
      "thickness": 0.06,
      "blend_mode": "screen",
      "iridescence": 0.75
    },
    {
      "type": "horizontal_band",
      "region": "ventral_flank",
      "color": "#d93434",
      "x_start": 0.48,
      "x_end": 0.94,
      "y": -0.22,
      "thickness": 0.08
    }
  ]
}
```

---

## Recommended Implementation Phases

### Phase 1: Region Masks and Layer Schema

Goal: make the renderer understand regional targets without changing visuals.

- Add `region` and `blend_mode` to `SpeciesMarkingLayer` normalization.
- Add stable enum IDs for common regions.
- Encode region IDs into existing marking uniform params if space allows, or add
  `marking_region_%d`.
- Add shader helper `region_mask(region_id, u, v)`.
- Keep all existing layers visually unchanged.

Acceptance:

- legacy marking layers produce identical uniforms except default region/body.
- a test layer with `region = "dorsal"` affects only dorsal mask in shader
  contract tests.

### Phase 2: Regional Color Override Layers

Goal: allow body regions to have distinct colors.

- Add layer type `region_color`.
- Add blend modes `normal`, `multiply`, `screen`.
- Add tests for dorsal/ventral/head/caudal-peduncle masks.
- Add at least one archetype using region color, e.g. corydoras saddle or
  neon-tetra flank band.

Acceptance:

- defaults unchanged.
- a dorsal region color does not tint belly.
- multiple layers compose deterministically by order.

### Phase 3: Scale and Iridescence Regionalization

Goal: let scale grid/iridescence be stronger or weaker by region.

- Add layer types `scale_region`, `reticulation_region`,
  `iridescence_region`.
- Reuse region masks to modulate existing `scale_strength`,
  `metallic_scale_strength`, `pearlscale_strength`, and
  `iridescence_strength`.
- Add visual smoke archetypes for metallic flank / pale belly / reticulated
  dorsal patterns.

Acceptance:

- body-wide `scale_strength` still works.
- flank-only scale layer leaves head and belly subdued.
- scale-grid layer remains stable through body animation.

### Phase 4: Marking Layer Editor

Goal: expose the data model without overwhelming the main panel.

- Create a layer-list UI for `marking_layers`.
- Keep simple global controls where they are.
- Add edit controls only for the selected layer.
- Include presets for common layers: lateral stripe, vertical bars, saddle,
  caudal spot, ocellus, fin edge, scale grid.

Acceptance:

- editing a layer emits `parameters_changed`.
- archetype-loaded layers appear in the editor.
- round-trip through preset save/load preserves layer order and values.

---

## Design Decisions

1. **Use semantic layers, not one giant texture.**
   Procedural sprites need scalable, editable pattern recipes. Texture painting
   can be a later import/export feature.

2. **Region masks should be shader-side functions.**
   This avoids mesh splitting and works with current shell deformation.

3. **Keep global controls as defaults.**
   Existing presets and simple fish remain easy. Region layers only override
   when present.

4. **Treat fins as separate slots.**
   Body and fin patterns can diverge biologically and visually. The next pass
   should not force body stripes onto fins unless explicitly requested.

5. **Represent scale/iridescence as modulation layers.**
   Structural color is not just pigment paint; it should modify lightness,
   sheen, or hue shift over the underlying color.

---

## Risks and Constraints

- **Uniform budget:** Godot shader uniforms are finite. Extending from 8 to many
  layers should be deliberate. Keep v1 at 8 marking layers unless tests show a
  real need.
- **UI complexity:** A full layer editor can get noisy. Keep global controls for
  common cases and hide advanced layer editing in a separate section.
- **Coordinate seams:** Procedural masks must respect existing UV seams and body
  animation. Use current `u/v` conventions and test seam cases.
- **Species realism vs author control:** Biological defaults should suggest, not
  override. Explicit user choices always win.
- **Fin inheritance:** Some species continue body stripes onto fins; others do
  not. The data model needs `inherit_body_pattern` or equivalent later.

---

## Suggested Test Plan

Focused tests:

- `MarkingLayerTest.gd`
  - region/blend fields normalize and clamp.
  - legacy layers without region still encode as body/default.
  - invalid regions fall back safely.
- `PatternTest.gd`
  - region color and scale layer uniforms are set.
  - round-trip through `split_parameters_into_profiles` preserves new fields.
- `SpeciesArchetypeStoreTest.gd`
  - archetypes with regional layers load and preserve layer order.
- Shader contract test
  - a dorsal layer affects dorsal mask, not ventral mask.
  - blend modes map to stable numeric IDs.

Manual visual checks:

- neon tetra: blue flank stripe + red lower rear stripe
- corydoras: dorsal saddle/blotches with pale belly
- angelfish/discus: vertical bars constrained to body/flank
- koi/goldfish: irregular patches that can cross head/body but not fins unless
  requested
- mackerel/tuna: dark dorsal countershade with lateral/flank emphasis

---

## Source Notes

- Britannica, fish skin/scales/coloration:
  https://www.britannica.com/animal/fish/The-skin
- Britannica, coloration/countershading and shape-pattern relation:
  https://www.britannica.com/science/coloration-biology/Countershading
- Maan & Sefc, *Colour variation in cichlid fish*:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3778878/
- Parichy/related zebrafish pigment-pattern work, summarized through Nature
  Communications article on iridophore crystallotypes:
  https://www.nature.com/articles/s41467-020-20088-1
- Volkening et al., *Modeling stripe formation on growing zebrafish tailfins*:
  https://arxiv.org/abs/1911.03758
