# Species Archetype Sprite System Design

## Goal

Shift the project from a quick sprite mock-up generator to a small but production-oriented fish sprite generator for a 2D isometric aquarium game. The generator should create sprites that are not large or hyper-realistic, but are visually specific enough that each fish reads as a recognizable species or breed archetype.

## Design Thesis

The current generator already has a useful base: ring-based body profiles, head and mouth controls, fin editing, procedural color and pattern controls, swim modes, 8-direction export, and GIF preview export. What is missing is not simply more sliders. The missing layer is a species-level visual grammar.

Fish identity should be built from four readable axes:

1. Silhouette: body depth, compression, tail-stem thickness, dorsal/anal outline.
2. Head traits: mouth direction, eye size and placement, barbels, snout, wen, hump, gill marks.
3. Fin and tail traits: caudal shape, fin length, fin rays, edge color, transparency, trailing filaments.
4. Zone-based markings: lateral stripe, vertical bars, caudal spot, head mask, fin edge, calico patch, reticulation.

This matches common fish identification practice: body form is the first broad discriminator, then mouth form, color, tail and fin traits, and smaller morphological details. For a small isometric sprite, these same traits matter more than fine texture.

## Scope Tiers

The document includes both the first shippable species-archetype system and several later ideas. Keep them separated during implementation.

```text
Core v1:
  SpeciesArchetype data layer, ten archetypes, body/head/fin/profile overrides,
  body/head marking layers, fin UVs, fin detail, QA contact sheets.

Post-v1 polish:
  gill breathing, independent eye tracking, hover fin flutter, isometric scale bias,
  optional separate shadow exports.

Special-rig future:
  flatfish, stingray, seahorse, glass catfish interiors, complex asymmetric body plans.
```

Unless an implementation plan says otherwise, the acceptance criteria at the end of this document apply to Core v1 only.

## Research Notes

- FISHBIO's morphology overview frames species identification around body and mouth forms, color, tail, and fin characteristics. It also notes that body shape is often the simplest first distinction between families, while mouth orientation indicates ecological role.
- Virginia Tech's freshwater fish morphology notes organize exterior identification around the head, body, tail, fin locations, color, countershading, and fin control.
- FISHMORPH describes side-view morphological traits from head, eyes, mouth, pectoral fins, and caudal fins, which maps well to this generator's side/isometric sprite workflow.
- A caudal-fin morphology review emphasizes that rounded/truncate tails often support maneuverability, while forked/lunate tails are associated with faster, more efficient cruising. Tail shape should therefore influence both silhouette and motion defaults.
- Fish-Vista treats visual traits as an image-understanding problem with trait identification and segmentation, reinforcing that this generator should store visual traits explicitly rather than hiding them in opaque presets.
- Betta references, including International Betta Congress material, list many recognizable tail and fin forms. For this generator, betta archetypes should therefore treat fin form as a separate design axis from color.
- Neon tetra references consistently identify the slender body, blue-green iridescent lateral stripe, and red posterior lower band as the species' core visual signature.
- Fancy goldfish references distinguish varieties by round/egg body, double tail, wen/head growth, telescope eyes, dorsal-fin presence, and scale texture. These are structural traits, not surface colors alone.

Primary sources:

- [FISHBIO: From Head to Tail: Using Morphology to Identify Fish Species](https://fishbio.com/from-head-to-tail-fish-identification/)
- [Virginia Tech: Biology, Ecology, and Management of Virginia's Freshwater Fishes](https://www.pubs.ext.vt.edu/CNRE/CNRE-73/CNRE-73.html)
- [FISHMORPH freshwater morphology database](https://freshwaterfish.sedoo.fr/fishmorph/)
- [Form and Function of the Caudal Fin Throughout the Phylogeny of Fishes](https://academic.oup.com/icb/article/61/2/550/6296422)
- [Fish-Vista visual trait dataset](https://arxiv.org/abs/2407.08027)
- [International Betta Congress: About Betta splendens](https://www.ibcbettas.org/about-betta-splendens/)
- [Neon Tetra profile](https://tropicalfreshwaterfish.com/species/Paracheirodon_innesi.html)
- [TFH Magazine: Fancy Goldfish Varieties](https://www.tfhmagazine.com/articles/freshwater/strange-beauty-of-fancy-goldfish-varieties)
- [FishTankWorld: Goldfish varieties](https://www.fishtankworld.com/fish/goldfish/)

## Current System Fit

The existing architecture already points in the right direction:

- `scripts/creature/BodyProfile.gd` stores structured preset conversion, ring profiles, swim modes, and visual pattern defaults.
- `scripts/creature/FishRig.gd` builds the procedural fish rig from profile parameters and handles head, eyes, fins, shell, pose, and motion.
- `scripts/creature/PrimitiveFactory.gd` owns head meshes, fin polygons, caudal shapes, snout appendages, and shell mesh generation.
- `scripts/materials/ToonMaterialFactory.gd` maps visual profile values to shader uniforms.
- `shaders/fish_body_toon.gdshader` handles belly gradient, procedural patterning, iridescence, and wetness.
- `scripts/ui/HeadEditorPanel.gd`, `FinEditorPanel.gd`, and `ParameterPanel.gd` expose manual editing.
- `scripts/presets/PresetStore.gd` round-trips structured preset data.

The new design should reuse these modules instead of replacing them. The main addition is a data-driven species layer above the existing profile system.

## New Concept: Species Archetype

A species archetype is a named bundle of visual traits that applies several existing profile sections at once. It is more structured than a loose preset, but less rigid than a real biological simulation.

An archetype answers:

- What silhouette should this fish have?
- Which head, eye, mouth, and appendage traits make it recognizable?
- Which fin and tail forms are diagnostic?
- Which color and marking zones matter?
- Which motion mode fits the body and tail?
- What export readability corrections are needed at small sprite sizes?

### Storage

Create a new data folder:

```text
data/species_archetypes/
  neon_tetra.json
  angelfish.json
  betta.json
  goldfish_oranda.json
  guppy.json
  discus.json
  corydoras.json
  puffer.json
  eel_loach.json
  koi_carp.json
```

Create new scripts:

```text
scripts/species/SpeciesArchetype.gd
scripts/species/SpeciesArchetypeStore.gd
scripts/species/SpeciesMarkingLayer.gd
```

Responsibilities:

- `SpeciesArchetype.gd`: normalize and validate one archetype dictionary.
- `SpeciesArchetypeStore.gd`: load archetype JSON files, list them for UI, apply one archetype to current parameters.
- `SpeciesMarkingLayer.gd`: validate zone-based marking layer dictionaries and encode them for shader/material use.

## Archetype Schema

Archetypes should preserve the current structured preset vocabulary where possible.

```json
{
  "id": "neon_tetra",
  "label": "Neon Tetra",
  "creature_type": "fish",
  "readability_priority": [
    "slender body",
    "blue lateral stripe",
    "rear red lower band"
  ],
  "profile_overrides": {
    "global": {
      "body_length": 1.55,
      "body_height": 0.34,
      "body_width": 0.24,
      "head_size": 0.32,
      "head_offset": -0.66,
      "eye_size": 0.04,
      "eye_position_x": -0.88,
      "eye_position_y": 0.08
    },
    "body_profile": {
      "shape": "slender_lateral"
    },
    "tail_profile": {
      "tail_length": 0.62,
      "tail_fin_size": 0.28,
      "caudal_shape": "forked_shallow",
      "caudal_height_scale": 0.65
    },
    "fin_profile": {
      "dorsal_1_shape": "single",
      "dorsal_1_length": 0.28,
      "dorsal_1_height": 0.10,
      "anal_shape": "long",
      "anal_length": 0.30,
      "pectoral_fin_size": 0.08,
      "pelvic_enabled": 0.0,
      "mouth_type": "terminal",
      "snout_length": 0.02
    },
    "visual_profile": {
      "base_color": "#7d8f8f",
      "belly_color": "#dfe6dc",
      "fin_color": "#b9d7d4",
      "outline_color": "#162126",
      "iridescence_strength": 0.45,
      "iridescence_color": "#34dfff",
      "wetness": 0.2
    },
    "motion_profile": {
      "swim_mode": "general",
      "global_sway_amount": 10.0,
      "tail_sway_multiplier": 1.15
    }
  },
  "marking_layers": [
    {
      "type": "lateral_line",
      "zone": "body",
      "color": "#22d8ff",
      "x_start": 0.04,
      "x_end": 0.84,
      "y": 0.10,
      "thickness": 0.035,
      "emissive": 0.75
    },
    {
      "type": "horizontal_band",
      "zone": "body",
      "color": "#e93a3a",
      "x_start": 0.48,
      "x_end": 0.96,
      "y": -0.12,
      "thickness": 0.08,
      "emissive": 0.15
    }
  ],
  "variant_controls": {
    "body_depth_variation": 0.08,
    "stripe_bend_variation": 0.04,
    "color_jitter": 0.06
  }
}
```

### Compatibility Rule

For phase 1, `profile_overrides` should map into the existing sections:

- `global`
- `body_profile`
- `tail_profile`
- `fin_profile`
- `visual_profile`
- `motion_profile`

Do not introduce a separate saved `head_profile` yet. Head values currently live across `global` and `fin_profile`; this is awkward but compatible. A later migration can split `head_profile` once archetype behavior is stable.

## Parameter Merge Behavior

Applying an archetype should be controlled, reversible, and compatible with user edits.

```text
base preset parameters
  -> normalize legacy keys
  -> apply archetype profile_overrides
  -> apply archetype marking_layers
  -> apply variant seed jitter
  -> user edits override everything
```

Store these keys in saved presets:

```text
archetype_id
archetype_strength
variant_seed
marking_layers
```

`archetype_strength` blends numeric values between the previous preset and archetype defaults. String/enum values switch when strength is at least `0.5`.

Manual user edits should persist as normal parameters. Reapplying an archetype can either:

- replace all archetype-owned values, or
- preserve user-edited values if a `preserve_manual_edits` option is enabled.

The default should be replace, because it is easier to explain and test.

## Marking Layer System

The current shader has one procedural pattern over the whole body. Species sprites need localized markings.

### Coordinate Model

Use normalized coordinates:

- `x`: snout to tail base, `0.0` to `1.0`
- `y`: visible side flank vertical coordinate, roughly `-1.0` belly to `1.0` back
- `v_circ`: existing circumference UV for cylindrical wrap

For body/head markings, shader masks can use the existing shell/head UVs. For fin markings, fin meshes need UVs added in `PrimitiveFactory.build_polygon_fin_mesh()` and `oval_fin()`.

### Layer Types

Required v1 layer types:

```text
lateral_line      neon tetra, rainbowfish, many schooling fish
horizontal_band   neon/cardinal tetra, pencilfish
vertical_bar      angelfish, tiger barb, discus stress bars
caudal_spot       rasbora, barb, livebearer variants
head_mask         koi, goldfish, cichlid, panda patterns
saddle            corydoras, loach, many catfish
ocellus           eye spot near tail or dorsal fin
calico_patch      goldfish, koi, shubunkin-style patches
fin_edge          betta, angelfish, guppy, barb fin margins
fin_spots         guppy, betta, cichlid fin details
scale_grid        subtle scale readability layer
reticulated_zone  puffer, moray-like netting, ornamental variants
```

### Shader Encoding

Use a small fixed layer budget first:

```text
MAX_MARKING_LAYERS = 8
marking_count
marking_type_0..7
marking_zone_0..7
marking_color_0..7
marking_rect_0..7   x_start, x_end, y_center, thickness
marking_params_0..7 intensity, softness, emissive, seed
```

This keeps material encoding deterministic and avoids a large dynamic rendering system. If the Godot shader path later supports clean uniform arrays in this project, the fixed slot uniforms can be collapsed behind the same `SpeciesMarkingLayer` encoder.

## Morphology Extensions

### Body Archetype Shapes

Add named body profile shapes to `BodyProfile.default_fish_rings()`:

```text
slender_lateral   neon tetra, rasbora, danio
deep_compressed   angelfish, discus, butterflyfish-like forms
round_fancy       goldfish, fancy carp, balloon morphs
round_puffer      puffer, boxfish-like slow swimmers
bottom_flat       corydoras, loach, goby-like bottom dwellers
eel_ribbon        eel, kuhli loach, ropefish-like forms
boxy              boxfish, cowfish-like rigid forms
```

Existing aliases can remain:

```text
deep_compressed -> tall_flat_fish
elongated/eel_like -> slender_fish or eel_ribbon
depressed/broad_head -> bottom_dweller_fish
```

#### 2D Isometric Perspective & Asymmetry
- **Dorsal Width Profile**: In 2.5D/isometric views, top-down width is highly visible. The body ring width (`width` parameter in `BodyProfile`) must be profile-adjustable independently of heights. Flat, wide-headed catfish (e.g. Corydoras) or round puffers require distinct cross-sectional thickness compared to paper-thin angelfish.
- **Asymmetric/Flatfish Body Plans (special-rig future)**: Standard fish rings are bilateral-symmetric side-view cylinders. Flatfishes and rays require horizontal flattened body orientation where eyes, mouth, and fins are placed on a dorsal surface rather than side flanks. Do not force this into `FishRig` v1. Rays should continue through `RayRig`; flatfish and seahorse-like cases should become separate special rigs later.

### Head Traits

Extend the head system around visible traits:

```text
head_ornament: none | wen | nuchal_hump | cheek_pad | forehead_bump
gill_mark: none | line | crescent | plate
barbel_style: none | cory | loach | koi
eye_style: bead | large | telescope | celestial | tiny_puffer
mouth_detail: dot | lip | beak | sucker | downturned
```

Implementation notes:

- `wen` can start as clustered small ellipsoids or a single bumpy cap mesh on the head.
- `gill_mark` can be a thin dark crescent/line attached to the head or a shader mark on the head UV span.
- `barbel_style` should replace the current one-size `barbels` appendage with species-scaled variations.
- `telescope` eyes can reuse existing `eye_bulge` mechanics with stronger protrusion and larger stalk bases.

#### Post-v1 Micro-Animations
- **Gill Operculum Breathing Flare**: Add periodic opening/closing of the gill slits (`gill_flare_amount`, `breathing_frequency`) to imply respiration. This adds visual interest even at standstill or during slow drift.
- **Independent Eye Tracking**: Allow eye rotation angles to shift randomly or track movement targets. For pufferfish, loaches, or predators, this creates key personality cues that break the static side-view feel.

These are not required for the first species-archetype implementation. They should be planned after the archetype and marking systems are stable.

### Tail and Fin Traits

Add caudal forms:

```text
fan
double_fan
halfmoon
veil
crowntail
spade
lyre
top_sword
bottom_sword
double_sword
butterfly
```

Add fin material/detail controls:

```text
fin_opacity
fin_edge_color
fin_edge_width
fin_ray_count
fin_ray_strength
fin_gradient_color
fin_tip_color
fin_tornness
fin_trailing_threads
```

These should live in `fin_profile` first, then be split into `material_profile` later if the visual system grows.

#### Post-v1 Hovering and Pectoral Fin Dynamics
- **Fin Fluttering / Hovering Mode**: Pectoral and dorsal/anal fins must support high-frequency, low-amplitude wave movements (`fin_flutter_amount`, `fin_flutter_speed`) for stationary hovering (typical of puffers, goldfish, bettas) rather than just passive body-wave following.
- **Fleshy/Lobed Fin Bases**: Add thick, muscular bases (`fin_base_thickness`, `fin_base_length`) for pectoral and caudal fins (e.g. fancy goldfish, puffers) to give the attachment points structural weight instead of thin paper-like junctions.
- **Trailing Filaments**: Long thread-like trailing ends on dorsal, pelvic, or caudal fins (`trailing_filament_length`), responding to water resistance with soft lag.

These controls should be treated as phase 6 polish unless a selected v1 archetype cannot read without one of them. For v1, static fin silhouette and fin material detail are higher priority than additional motion systems.

## Material Extensions

The current material system supports belly gradient, pattern color, pattern type, iridescence, and wetness. Add these concepts:

```text
scale_strength
scale_size
lateral_line_strength
fin_translucency
fin_ray_strength
pearlscale_strength
metallic_scale_strength
emissive_marking_strength
```

For small sprites, these should be subtle. The point is not texture realism; it is a controlled read of fish-like surfaces.

#### Advanced Surface Shading & Transparency
- **Fin Translucency & Backlight (fake SSS)**: Real fish fins often look luminous at thin edges. Add a stylized translucency uniform (`fin_translucency_strength`) that brightens thin fin regions and edges. This should be a toon/readability effect, not a physically accurate subsurface simulation.
- **Procedural Scale Textures**:
  - *Metallic Scale*: High specular reflection and gloss (e.g., Arowana, Koi).
  - *Pearlscale*: Raised dome-like scale texture mapped onto the body surface using a normal/bump map shader.
  - *Armored Scutes*: Layered, protective plates along the sides of bottom-dwellers (e.g., Corydoras, Plecos).
- **Body Transparency (special-rig future)**: A checkbox for partial transparency, making the outer shell glass-like, with an optional interior bone/organ primitive visible inside the fish rig (e.g., glass catfish). This is outside Core v1 because it needs a different depth/compositing and interior-primitive contract.

## Species Pack v1

The first species pack should maximize visual diversity. Ten archetypes are enough to prove the system.

| Archetype | Core Read | Required Traits |
| --- | --- | --- |
| `neon_tetra` | Thin schooling fish with blue stripe and rear red band | `slender_lateral`, lateral line, posterior band, small fins |
| `angelfish` | Tall triangular silhouette with black bars | `deep_compressed`, tall dorsal/anal fins, filament pelvic fins, vertical bars |
| `betta` | Small body with oversized ornamental fins | halfmoon/veil/crowntail tail, translucent fins, fin rays, strong fin edge |
| `goldfish_oranda` | Round orange/white fancy goldfish with head growth | `round_fancy`, double tail, wen, metallic/calico patches |
| `guppy` | Small body with large colorful tail | fan/delta/sword tail, tail-only markings, tiny body, bright fin colors |
| `discus` | Round disc body with subtle bars | `deep_compressed`, circular body, small fins, vertical stress bars |
| `corydoras` | Bottom fish with barbels and armor feel | `bottom_flat`, inferior mouth, cory barbels, saddle markings |
| `puffer` | Round body with tiny fins and spots | `round_puffer`, small fins, dot/reticulated markings, tiny mouth |
| `eel_loach` | Long ribbon swimmer | `eel_ribbon`, reduced fins, whole-body wave, banded/saddle pattern |
| `koi_carp` | Carp silhouette with red/black/white patches and barbels | broad body, koi barbels, calico/head patches, scale layer |

### Advanced Species Archetypes (Future Expansion)

| Archetype | Core Read | Required Traits |
| --- | --- | --- |
| `plecostomus` | Bottom sucker mouth with high dorsal fin and armored plates | `bottom_flat`, inferior sucker mouth, armored scutes, high dorsal, dark mottling |
| `stingray` | Flat diamond-shaped body with undulating pectoral wings | `creature_type: ray`, broad diamond profile, undulating pectorals, long whip tail |
| `seahorse` | Vertically oriented body swimming upright | vertical posture rig, tubular snout, prehensile tail, dorsal-only propulsion |

These are deliberately not in the Core v1 species pack. They require either `RayRig` specialization or new rig families rather than only `FishRig` profile overrides.

## UI Design

Add an archetype section above the existing tabs:

```text
Species Archetype
  [OptionButton: Generic Fish / Neon Tetra / Angelfish / ...]
  [Button: Apply Archetype]
  [Slider: Archetype Strength]
  [Button: New Variant]
```

Behavior:

- Choosing an archetype previews its name and short read priority.
- Applying archetype updates the current preset parameters.
- New Variant keeps the same archetype but changes `variant_seed`.
- Manual tabs remain useful for fine tuning.

Avoid burying archetype selection inside the color tab. Species identity affects body, head, fins, color, and motion at once.

## Export and QA

The generator should verify species readability at the sprite scale used by the game.

Add a contact-sheet export mode for QA:

```text
exports/_qa/species_archetypes/
  neon_tetra_contact.png
  angelfish_contact.png
  betta_contact.png
```

Each sheet should include:

- 8 directions
- 4 swim frames per direction
- 64 px preview row
- native export resolution row
- transparent background

Readability rubric:

```text
1-second read: silhouette class is recognizable.
3-second read: head, fin, or tail identity is visible.
Zoom read: species-specific markings are present and correctly placed.
```

#### 2D Isometric Readability Adjustments
- **Angle-based Compensation / Scale Bias**: At high isometric angles, foreshortening compresses vertical/horizontal features. Provide a scale bias parameter (`iso_fin_scale_bias`, `iso_eye_scale_bias`) that automatically scales features depending on the camera angle to preserve their visual volume and signature read. This should be an export/readability option, not a change to canonical body geometry.
- **Ambient Shadow Generation (separate asset only)**: Optional projection of a soft, semi-transparent ground/shadow texture beneath the fish for the aquarium game. Do not bake this into the primary fish sprite; the primary export must remain a transparent fish cutout. If implemented, export it as a separate aligned shadow asset or metadata hint.

## Implementation Roadmap

### Phase 1: Data Layer and Archetype Application

Files:

- Create `scripts/species/SpeciesArchetype.gd`
- Create `scripts/species/SpeciesArchetypeStore.gd`
- Create `data/species_archetypes/*.json`
- Modify `scripts/creature/BodyProfile.gd`
- Modify `scripts/presets/PresetStore.gd`
- Modify `scripts/ui/Main.gd`

Outcome:

- Archetypes load from JSON.
- Applying an archetype updates existing profile parameters.
- Saved user presets round-trip `archetype_id`, `archetype_strength`, `variant_seed`, and `marking_layers`.
- Legacy presets still load with no archetype.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeStoreTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter UserPresetStoreTest
```

### Phase 2: Body Marking Layers

Files:

- Create `scripts/species/SpeciesMarkingLayer.gd`
- Modify `scripts/materials/ToonMaterialFactory.gd`
- Modify `shaders/fish_body_toon.gdshader`
- Modify `scripts/creature/BodyProfile.gd`

Outcome:

- Up to 8 body/head marking layers render through fixed shader slots.
- `lateral_line`, `horizontal_band`, `vertical_bar`, `caudal_spot`, and `head_mask` work first.
- Invalid layer types fall back to no-op and emit a warning.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter MarkingLayerTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PatternTest
```

### Phase 3: Fin UVs and Fin Detail

Files:

- Modify `scripts/creature/PrimitiveFactory.gd`
- Modify `scripts/creature/FishRig.gd`
- Modify `scripts/materials/ToonMaterialFactory.gd`
- Modify `scripts/ui/FinEditorPanel.gd`

Outcome:

- Polygon and oval fins carry UVs.
- Fins support opacity, edge color, ray count, ray strength, and tip/gradient color.
- Betta, guppy, and angelfish fins become readable without changing body geometry.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter CurvedFinTest
```

### Phase 4: Head Ornaments and Diagnostic Face Traits

Files:

- Modify `scripts/creature/FishRig.gd`
- Modify `scripts/creature/PrimitiveFactory.gd`
- Modify `scripts/ui/HeadEditorPanel.gd`
- Modify `scripts/ui/UiText.gd`

Outcome:

- `wen`, `gill_mark`, `barbel_style`, `eye_style`, and `mouth_detail` are exposed.
- Oranda, corydoras, koi, and puffer head traits become archetype-controlled.
- Existing `snout_appendage` remains compatible.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter EyeAttachmentTest
```

### Phase 5: Species Pack and QA Export

Files:

- Create `data/species_archetypes/neon_tetra.json`
- Create `data/species_archetypes/angelfish.json`
- Create `data/species_archetypes/betta.json`
- Create `data/species_archetypes/goldfish_oranda.json`
- Create `data/species_archetypes/guppy.json`
- Create `data/species_archetypes/discus.json`
- Create `data/species_archetypes/corydoras.json`
- Create `data/species_archetypes/puffer.json`
- Create `data/species_archetypes/eel_loach.json`
- Create `data/species_archetypes/koi_carp.json`
- Add QA export helper under `scripts/tools/`

Outcome:

- Ten archetypes generate visibly distinct sprites.
- QA contact sheets show 8 directions and small-size preview rows.
- Species pack becomes the project's baseline visual target.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter SpeciesArchetypeVisualSmokeTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportGridTest
```

### Phase 6: Post-v1 Readability Polish

Files:

- Modify `scripts/creature/FishRig.gd`
- Modify `scripts/creature/PrimitiveFactory.gd`
- Modify `scripts/materials/ToonMaterialFactory.gd`
- Modify `shaders/fish_body_toon.gdshader`
- Modify `scripts/export/SpriteExporter.gd`
- Modify `scripts/ui/HeadEditorPanel.gd`
- Modify `scripts/ui/FinEditorPanel.gd`

Outcome:

- Gill breathing and eye tracking can animate idle fish without changing species silhouette.
- Hover fin flutter supports puffer, goldfish, and betta stationary behavior.
- Isometric scale bias can preserve eye/fin readability at export time.
- Optional shadow export is emitted as a separate asset or metadata hint, never baked into the primary transparent fish sprite.

Focused tests:

```text
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter FinEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter ExportGridTest
```

## Acceptance Criteria

- A user can choose an archetype and immediately get a species-readable fish without manually tuning dozens of parameters.
- Existing presets load and export unchanged unless an archetype is explicitly applied.
- At least ten bundled archetypes produce distinct silhouettes and markings.
- Neon tetra reads through its lateral stripe and red posterior band.
- Angelfish reads through a tall compressed silhouette, long fins, and vertical bars.
- Betta reads through ornamental tail/fin shape independent of body color.
- Oranda-style goldfish reads through round body, double tail, and wen.
- Corydoras reads through bottom-dweller body, inferior mouth, and barbels.
- Exported sprites remain transparent and fit the export frame in all 8 directions.
- Focused Godot CLI tests pass through `tools\run_godot_cli_tests.ps1`.

## Non-Goals

- Do not attempt photorealistic fish rendering.
- Do not import photographic textures or require Blender.
- Do not simulate exact taxonomy, meristics, or species-level biology.
- Do not make every aquarium species in the first pass.
- Do not replace the existing preset system.
- Do not add underwater backgrounds to exported sprites; transparent cutouts remain required.
- Do not bake ground shadows into the primary fish sprite; any shadow export must be separate and optional.
- Do not force flatfish, stingray, seahorse, or glass-catfish interior work into the first `FishRig` species-archetype pass.

## Open Design Decisions

1. Whether archetype UI belongs above all tabs or inside a dedicated `Species` tab.
2. Whether fin material controls remain in `fin_profile` or move to a new `material_profile` after phase 3.
3. Whether `head_profile` should be introduced during phase 1 or deferred until head ornament work.
4. Whether QA contact sheets should be a developer tool only or user-facing export option.

Recommended defaults:

- Put archetype selection above tabs.
- Keep fin material controls in `fin_profile` for phase 1-3.
- Defer `head_profile` until phase 4.
- Start QA contact sheets as a developer tool.
