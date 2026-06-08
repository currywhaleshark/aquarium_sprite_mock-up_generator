# Fin Ray Structure Design

Date: 2026-06-08

## Purpose

Current fins read mostly as smooth membranes. Some material controls already exist
(`fin_ray_count`, `fin_ray_strength`, `fin_translucency_strength`, `fin_tornness`,
`fin_trailing_threads`), but the ray pattern itself is still a simple parallel UV
stripe. This does not communicate species-specific fin support: dense fan rays in
ornamental fish, sparse strong rays in fast swimmers, or mixed spine/soft-ray
arrangements in perch-like forms.

This spec adds a stylized fin-ray structure layer that fits the current sprite
generator: readable at small size, cheap in the shader, compatible with existing
fin silhouettes, vector editing, softness animation, and archetype defaults.

## Research Basis

The implementation should be biologically inspired, not anatomically exhaustive.
The following facts drive the visual model:

- Ray-finned fish fins are membranes supported by bony rays/spines. The Journal of
  Experimental Biology review describes fish control surfaces as fins with thin
  membrane support from spines and fin rays, and notes the uneven surface created
  by ray-supporting elements between membrane regions:
  https://journals.biologists.com/jeb/article/220/23/4351/33683/Control-surfaces-of-aquatic-vertebrates-active-and

- Actinopterygian fin dermoskeletons include spines and/or soft rays connected by
  interspine/interray tissue. Soft rays are formed from paired hemirays, and the
  lepidotrichia are segmented and can branch along the proximal-distal axis. This
  supports visible controls for ray density, segmentation, branching, and
  soft/spiny style:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3036817/

- Zebrafish fin development/regeneration references describe lepidotrichia as
  segmented structures that periodically bifurcate, with joints contributing to
  ray flexibility. This supports a distal branching and segmented-joint mask rather
  than only straight unbroken lines:
  https://www.ncbi.nlm.nih.gov/books/NBK6368/

- Recent branching-morphogenesis work describes zebrafish as having branched rays
  across paired and unpaired fins, with opposed hemi-rays forming skeletal units.
  This reinforces that paired and median fins should share one common ray system,
  with slot-specific tuning instead of entirely separate implementations:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10802891/

- Adipose fins are a distinct median fin type, usually positioned dorsally between
  the rayed dorsal fin and caudal fin. Britannica summarizes the common anatomical
  read as a small to elongated fleshy/fatty structure without fin-ray supports:
  https://www.britannica.com/animal/ostariophysan/Fin-spines-and-adipose-fin

- Salmonid adipose-fin ultrastructure work found that the fin contains nervous
  tissue and supporting actinotrichia/collagen structures, but neither adipose
  tissue nor fin rays. This supports drawing it as a soft sensory flap rather than
  applying the main fin-ray shader by default:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3234561/

- Mechanosensation research in Corydoras catfish supports the hypothesis that
  adipose fins can act as precaudal flow sensors, so the feature should not be
  treated as a decorative vestigial bump:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC4810852/

- Evolutionary work on adipose fins notes that they occur in roughly one fifth of
  ray-finned fishes, evolved repeatedly, and can have increased complexity in some
  lineages. It also reports fin rays in adipose fins of at least four taxonomically
  distinct fish groups. This justifies keeping a rare "rayed adipose" exception,
  but not making rays the default:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3953844/

- A sun catfish study describes a musculoskeletal linkage in an adipose fin,
  showing that some adipose fins are not purely passive. This belongs as a later
  advanced exception rather than the v1 baseline:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC3574436/

- Finlets are another distinct fin feature, especially associated with scombrid
  fishes such as tuna and mackerel. Nauen and Lauder describe them as small,
  non-retractable fins on the dorsal and ventral body margins between the second
  dorsal/anal fins and the caudal fin, and studied their kinematics in chub
  mackerel:
  https://pubmed.ncbi.nlm.nih.gov/11249216/

- Computational tuna work describes finlets as a dorsal and ventral series on the
  posterior body of yellowfin tuna, with nine dorsal and nine ventral finlets in
  the studied specimens. It frames finlets as flow-control structures that can
  redirect posterior-body crossflow and interact with caudal-fin wake formation:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC7211474/

- Hydrodynamic work on tuna median fins and yaw/C-turn behavior reinforces that
  posterior median-fin morphology matters for high-performance swimming and
  maneuvering. Finlets should therefore be tied to streamlined fast-swimmer
  archetypes, not exposed as a generic ornamental fin pattern:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC7801062/

## Current Project Context

Existing support:

- `shaders/fish_fin_toon.gdshader` already receives UVs where `UV.x` is root to
  tip and `UV.y` is lower to upper. It has material uniforms for ray count,
  strength, edge, translucency, tearing, and trailing threads.
- `PrimitiveFactory.build_polygon_fin_mesh()` and `oval_fin()` already generate UVs,
  so a shader-only first pass can work on custom, preset, oval, and caudal fins.
- `BodyProfile.split_parameters_into_profiles()` already round-trips fin material
  detail fields.
- `FishRig` currently creates one `ToonMaterialFactory.make_fin_material()` result
  and shares it across all ordinary fin meshes. That is fine for the existing
  global fin controls, but adipose fins and finlets introduce explicit ray-mask
  opt-outs, so v1 must add dedicated material instances for those special slots.
- Per-fin softness/rigidity already affects motion and membrane deformation. The
  ray structure must not force mesh subdivision or additional per-frame rebuilds.

Gap:

- Current `fin_ray_count` is a parallel `sin(v_uv.y * count)` mask. It does not
  radiate from the fin base, cannot distinguish spines from soft rays, cannot show
  distal branching, and has no controlled irregularity for dense vs sparse species.

## Design Goals

1. Make fins read as membrane stretched over structural rays, not flat smooth cards.
2. Support species variation without requiring hand-edited geometry per species.
3. Keep default fins visually close to current output unless ray controls are set.
4. Work on dorsal, anal, pectoral, pelvic, caudal, oval, and custom vector fins.
5. Remain cheap enough for editor preview and export.
6. Preserve existing fin softness, tornness, trailing threads, and custom point editing.

## Non-Goals

- No physical skeleton simulation.
- No actual ray mesh bones in the first pass.
- No per-ray collision, selection, or vector editing.
- No automatic ray count inference from arbitrary custom outlines in v1.
- No replacement of the existing fin silhouette presets.
- No active adipose-fin musculoskeletal simulation in v1.
- No default ray pattern on adipose fins; rare rayed adipose fins remain an
  explicit exception.
- No independent physics simulation for each finlet in v1.
- No finlets on generic ornamental or slow-body archetypes unless a specific
  species calls for them.

## Parameter Model

Add global fin ray parameters first. Per-slot overrides can be a follow-up if visual
tuning proves that global settings are too blunt.

```text
fin_ray_style           string: none | soft | spiny | mixed | fan | threaded
fin_ray_count           float: existing, 0..48 after expansion
fin_ray_strength        float: existing, 0..1
fin_ray_root_bias       float: -1..1, shifts the fan origin along UV.y
fin_ray_spread          float: 0..1, controls radial vs parallel layout
fin_spine_count         float: 0..12, thick anterior/leading support rays
fin_spine_strength      float: 0..1
fin_ray_branching       float: 0..1, distal bifurcation
fin_ray_segmentation    float: 0..1, soft-ray joint bands
fin_ray_irregularity    float: 0..1, nonuniform spacing/thickness
```

Add adipose-fin parameters as a separate small feature group, not as part of the
main ray-count system:

```text
adipose_fin_enabled     bool/string: false by default
adipose_fin_size        float: 0..1, scales the small dorsal flap
adipose_fin_position    float: 0..1, dorsal-to-caudal placement along the back
adipose_fin_height      float: 0..1, vertical rise of the flap
adipose_fin_roundness   float: 0..1, soft nub vs longer triangular flap
adipose_fin_opacity     float: 0..1, usually slightly translucent
adipose_fin_rayed       float: 0..1, rare exception only
```

Add finlet parameters as a separate posterior-body array feature:

```text
finlet_enabled          bool/string: false by default
finlet_dorsal_count     float: 0..12
finlet_ventral_count    float: 0..12
finlet_size             float: 0..1, base scale for each small finlet
finlet_taper            float: 0..1, smaller toward caudal end when high
finlet_spacing          float: 0..1, distribution between posterior dorsal/anal and caudal
finlet_pitch            float: -1..1, backward/forward lean
finlet_color_blend      float: 0..1, body-color vs fin-color blend
```

Defaults:

```text
fin_ray_style = "none"
fin_ray_count = existing default, currently 0
fin_ray_strength = existing default, currently 0
fin_ray_root_bias = 0
fin_ray_spread = 0.75
fin_spine_count = 0
fin_spine_strength = 0
fin_ray_branching = 0
fin_ray_segmentation = 0
fin_ray_irregularity = 0

adipose_fin_enabled = false
adipose_fin_size = 0
adipose_fin_position = 0.82
adipose_fin_height = 0.18
adipose_fin_roundness = 0.75
adipose_fin_opacity = 0.72
adipose_fin_rayed = 0

finlet_enabled = false
finlet_dorsal_count = 0
finlet_ventral_count = 0
finlet_size = 0.25
finlet_taper = 0.35
finlet_spacing = 0.72
finlet_pitch = 0.25
finlet_color_blend = 0.5
```

Implementation note:

- Add these defaults before shader or archetype tuning. Either extend
  `VISUAL_PATTERN_DEFAULTS` or add a dedicated `FIN_RAY_DEFAULTS` dictionary and
  inject it from `BodyProfile.ensure_visual_parameters()`.
- This default injection is a prerequisite for Phase 1 shader/UI work and Phase 2
  archetype tuning. Without it, older presets can miss the new fields, the UI may
  hide controls, and archetype defaults may not round-trip consistently.

Rationale:

- `style` gives archetypes a semantic knob.
- `count` and `strength` preserve existing behavior and user familiarity.
- `root_bias` and `spread` make rays feel anchored instead of screen-parallel.
- `spine_count` and `spine_strength` represent stiff leading rays separately from
  soft membrane rays.
- `branching` and `segmentation` are the key biological cues from the research.
- `irregularity` prevents synthetic perfect combs and helps dense/loose species read.
- Adipose-fin controls stay separate because the research basis points to a
  soft, mostly non-rayed sensory flap rather than another membrane supported by
  lepidotrichia.
- Finlet controls stay separate because they are repeated posterior-body
  appendages related to high-speed caudal flow, not a texture pattern within one
  large fin membrane.

## Adipose Fin Design

The adipose fin should be modeled as a small unpaired dorsal appendage between the
main dorsal fin and caudal fin. Its default shape should be a soft rounded flap or
low triangular nub, with no visible rays, no segmentation bands, and no strong edge
spines.

Visual rules:

- Default rendering should reuse the fin membrane material colors, but suppress
  `fin_ray_strength`, branching, segmentation, and spine masks.
- The silhouette should read as fleshy/soft: rounded base, rounded tip, low height,
  and slightly translucent fill.
- It should be optional and archetype-driven. Do not show it globally on every fish.
- `adipose_fin_rayed > 0` is reserved for rare catfish/characiform-like exceptions
  and should use very low ray density with subtle strength.
- The feature should use the existing fin mesh path where possible, but should be
  treated as its own slot so it does not inherit dorsal-fin ray defaults by accident.
- `adipose_fin_position` defaults near the posterior body (`0.82`) and must be
  clamped behind the last enabled dorsal fin by a minimum spacing. If
  `dorsal_2_enabled` is true, the effective adipose attach position should be at
  least `dorsal_2_attach_t + 0.08`, capped before the caudal base.

Suggested v1 species mapping:

```text
salmonid/trout-like:
  adipose_fin_enabled true
  size medium
  roundness high
  rayed false

catfish-like:
  adipose_fin_enabled true for species/archetypes that conventionally show it
  size small-medium
  roundness medium
  rayed optional, low strength

characin/tetra-like:
  adipose_fin_enabled true
  size small
  roundness high
  rayed optional only for specific archetypes

betta/guppy/goldfish/tuna/mackerel/perch/cichlid:
  adipose_fin_enabled false by default
```

Implementation consequence:

- Fin-ray work should not simply apply the new ray shader globally to every fin
  mesh. Adipose fins need an explicit opt-out from ray masks unless
  `adipose_fin_rayed` is enabled.
- The adipose slot needs its own material instance. Either clone the ordinary
  `fin_mat` and override ray/spine/branch/segment uniforms to zero, or add a
  small `make_adipose_fin_material()`/`make_fin_material(parameters, overrides)`
  helper. Do not share the global `fin_mat` when global `fin_ray_*` controls are
  active.
- If the project does not yet have a dedicated adipose-fin slot, add it as a
  small dorsal slot after the primary dorsal fins and before the caudal fin.
- This slot should participate in save/load and archetype defaults, but it does
  not need vector-edit controls in v1.

## Finlet Design

Finlets should be modeled as a small repeated array of posterior body appendages,
not as a shader pattern. They sit between the rear dorsal/anal fin region and the
caudal fin, mirrored across the dorsal and ventral margins when both counts are
nonzero.

Visual rules:

- Each finlet is a small triangular or swept teardrop mesh with a short attached
  base and a free posterior edge.
- Finlets should be non-retractable in v1. They should inherit body sway by being
  updated from animated surface anchors every frame, with only a tiny optional
  local lean from `finlet_pitch`.
- The dorsal array follows the back line from the rear dorsal/second dorsal region
  toward the caudal peduncle.
- The ventral array follows the belly/anal line from the rear anal region toward
  the caudal peduncle.
- Count and spacing should be mirrored by default for tuna/mackerel-like forms,
  but dorsal and ventral counts remain separate because silhouettes and camera
  angles can hide one side more than the other.
- Do not apply the main `fin_ray_*` structure inside finlets in v1. Finlets should
  read as small solid control surfaces, with color blended between body and fin
  colors.

Suggested v1 species mapping:

```text
tuna/mackerel/bonito-like:
  finlet_enabled true
  dorsal_count 7..10
  ventral_count 7..10
  size small-medium
  taper medium
  pitch slightly backward

salmonid/trout-like:
  finlet_enabled false
  use adipose fin instead

betta/guppy/goldfish/perch/cichlid/catfish:
  finlet_enabled false by default
```

Implementation consequence:

- Finlets should be generated by `FishRig` as repeated child meshes or repeated
  fin-slot descriptors, not as a new shader mask.
- The placement algorithm should sample along the posterior body top/bottom shell
  profile rather than using fixed screen-space offsets. The project already has
  `_surface_position()`, `_animated_surface_position()`, and `_sample_shell_profile()`
  paths, so v1 should use real outline anchors from the start.
- Finlet transforms must be recomputed in the same frame update path as dorsal and
  anal fins. Parenting them under `body_pivot` is not sufficient because caudal
  peduncle bending will otherwise make the array drift away from the body during
  tail beats.
- Finlets need their own material instance or material override. They should force
  ray/spine/branch/segment uniforms to zero and apply the `finlet_color_blend`
  body/fin color mix instead of inheriting the global fin-ray material.
- Finlet arrays should be excluded from vector editing in v1. A later pass can add
  per-array editing if users need exaggerated fantasy silhouettes.

## Shader Design

The fin shader should compute a ray coordinate from UV:

- `x = v_uv.x`: root to tip.
- `y = v_uv.y`: lower to upper.
- Root/fan origin: `root = vec2(0.0, 0.5 + root_bias * 0.35)`.
- Radial angle coordinate:
  `angle = atan(y - root.y, max(x, 0.001))`.
- Normalize the angle coordinate into a stable ray field before repetition:
  `radial_coord = clamp((angle / PI) + 0.5, 0.0, 1.0)`.
- Keep a denominator-style fallback such as
  `(y - root.y) / max(x * spread + 0.08, 0.08)` only as a cheaper approximation if
  `atan` proves too costly or visually unstable on the target renderer.
- Blend between current parallel rays and radial fan rays:
  `ray_coord = mix(y, radial_coord, fin_ray_spread)`.

Anti-aliasing:

- Ray masks must use derivative-aware smoothing, not only high-power sine masks.
- Compute line distance within each repeated ray cell, then use `fwidth()` to widen
  the smoothstep edge at high ray counts and small export sizes.
- The practical shape should be:
  `aa = max(fwidth(ray_coord * fin_ray_count), 0.001)`;
  `ray = 1.0 - smoothstep(width, width + aa, distance_to_ray)`.
- Apply the same AA approach to branch masks and segmentation bands so dense fan
  fins do not shimmer or collapse into moire during editor preview.

Ray masks:

- Soft rays: narrow lines repeating along `ray_coord * fin_ray_count`, fading in
  from the base and strongest through the middle/tip.
- Spines: fewer, thicker leading rays, mostly near the front edge of the fin or the
  anterior side of the ray coordinate field.
- Mixed: spines near one edge plus soft rays through the rest.
- Fan: high spread, high count, high branching support.
- Threaded: rays continue into `fin_trailing_threads`, with visible distal strands.

Branching:

- Branching should start only after `x > 0.55`.
- Use two offset ray masks that diverge as `x` approaches the tip.
- Blend with `fin_ray_branching`.
- At small sprites this should read as a split at the distal third, not as noisy stripes.

Segmentation:

- Add short cross-bands along the ray direction using `x`.
- Only visible when `fin_ray_segmentation > 0`.
- Should modulate/darken the ray color, not cut alpha.
- Segment length should get slightly shorter toward the tip for a natural cue.

Irregularity:

- Apply a low-amplitude hash/noise offset to `ray_coord` and ray thickness.
- Keep it deterministic from UV, no runtime seed required in v1.
- Clamp strongly; a high value should feel organic, not broken.

Composition order in `fragment()`:

1. Existing base gradient.
2. Existing edge color.
3. New spine/ray structure.
4. Existing translucency/backlight.
5. Existing trailing threads and torn alpha.

This order keeps rays visible inside the membrane but lets torn/thread effects affect
the final silhouette.

## UI Design

Add these controls under fin visual/material detail, not under fin shape editing:

- 기조 스타일 (`fin_ray_style`)
- 기조 개수 (`fin_ray_count`)
- 기조 선명도 (`fin_ray_strength`)
- 기조 중심 (`fin_ray_root_bias`)
- 기조 펼침 (`fin_ray_spread`)
- 가시 기조 수 (`fin_spine_count`)
- 가시 기조 선명도 (`fin_spine_strength`)
- 기조 갈라짐 (`fin_ray_branching`)
- 기조 마디 (`fin_ray_segmentation`)
- 기조 불규칙성 (`fin_ray_irregularity`)

Keep these in the existing parameter panels first. Do not add a new editor tab in v1.

Add adipose-fin controls near fin slot/detail controls, not inside the ray-style
group:

- 기름지느러미 (`adipose_fin_enabled`)
- 기름지느러미 크기 (`adipose_fin_size`)
- 기름지느러미 위치 (`adipose_fin_position`)
- 기름지느러미 높이 (`adipose_fin_height`)
- 기름지느러미 둥글기 (`adipose_fin_roundness`)
- 기름지느러미 투명도 (`adipose_fin_opacity`)
- 기름지느러미 기조 예외 (`adipose_fin_rayed`)

Add finlet controls near posterior fin/detail controls:

- 토막지느러미 (`finlet_enabled`)
- 등쪽 토막 개수 (`finlet_dorsal_count`)
- 배쪽 토막 개수 (`finlet_ventral_count`)
- 토막 크기 (`finlet_size`)
- 토막 작아짐 (`finlet_taper`)
- 토막 간격 (`finlet_spacing`)
- 토막 기울기 (`finlet_pitch`)
- 토막 색 섞임 (`finlet_color_blend`)

## Archetype Defaults

Initial archetype mapping should be conservative:

```text
betta/fancy guppy:
  style fan or threaded
  count high
  branching high
  segmentation medium
  translucency high

goldfish:
  style fan
  count medium-high
  branching medium
  segmentation low-medium

tuna/mackerel:
  style soft
  count low-medium
  strength low
  branching low
  segmentation low
  finlet_enabled true
  dorsal_count 7..10
  ventral_count 7..10

perch/cichlid-like:
  style mixed
  spine_count medium
  spine_strength medium-high
  soft ray count medium

catfish-like:
  style spiny or mixed
  spine_count low
  spine_strength high
  soft ray count low-medium
  adipose_fin_enabled true where the archetype represents adipose-fin catfish
  adipose_fin_rayed optional low

ray/skate:
  leave disabled in v1 unless a separate ray-wing striation design is written

salmonid/trout-like:
  ray style soft or sparse
  adipose_fin_enabled true
  adipose_fin_rayed false

characin/tetra-like:
  ray style soft or fan depending on body/fin shape
  adipose_fin_enabled true
  adipose_fin_rayed false by default
```

## Data Flow

1. Add the ray defaults to `VISUAL_PATTERN_DEFAULTS` or a dedicated
   `FIN_RAY_DEFAULTS` dictionary.
2. `BodyProfile.ensure_visual_parameters()` should inject defaults for older presets.
3. Preset/archetype parameters carry the new ray fields.
4. `BodyProfile.split_parameters_into_profiles()` should preserve fields in
   `fin_profile`.
5. `ParameterPanel` should expose `fin_ray_style` as an option and numeric fields as
   sliders.
6. `ToonMaterialFactory.make_fin_material()` should bind all new shader uniforms.
7. `fish_fin_toon.gdshader` computes the stylized ray mask from UV.
8. Add adipose-fin defaults to the same default-injection and round-trip path, but
   keep them separate from the main `fin_ray_*` fields.
9. Add finlet defaults to the same default-injection and round-trip path, but keep
   them separate from both `fin_ray_*` and `adipose_fin_*` fields.
10. Add dedicated material instances for adipose fins and finlets so the current
   shared ordinary-fin material does not leak global ray settings into rayless
   special slots.
11. `FishRig` should add an adipose slot only when `adipose_fin_enabled` is true.
12. `FishRig` should clamp adipose placement behind the last enabled dorsal fin by
   a minimum spacing.
13. `FishRig` should add repeated dorsal/ventral finlet meshes only when
   `finlet_enabled` is true and at least one count is nonzero.
14. `FishRig` should update finlet anchors every frame through the same animated
   surface-position path used by median fins.
15. Existing `FishRig` fin creation remains unchanged unless visual testing reveals
   UV limitations.

## Testing Plan

Focused tests:

- `FinMaterialTest`
  - New uniforms are set on `ShaderMaterial`.
  - Defaults are stable.
  - Round-trip through `fin_profile`.
  - Existing `fin_ray_count`/`fin_ray_strength` behavior remains accepted.
  - `fin_ray_style == "none"` with legacy `fin_ray_count` and
    `fin_ray_strength` preserves the old parallel-ray fallback path.
  - Adipose and finlet material helpers or overrides zero ray/spine/branch/segment
    uniforms when their rayless modes are active.

- `ParameterPanelRangeTest`
  - Numeric ranges for new fields.
  - `fin_ray_style` option list.

- `SpeciesArchetypeVisualSmokeTest`
  - Archetypes with ornamental fins receive nonzero ray settings.
  - Fast-swimmer archetypes do not get heavy fan/branch defaults.
  - Salmonid/characin/catfish-like archetypes that enable adipose fins show the
    slot between dorsal and caudal fins.
  - Betta/guppy/goldfish-like archetypes do not receive adipose fins by default.
  - Tuna/mackerel-like archetypes show posterior dorsal and ventral finlet arrays.
  - Non-scombrid ornamental archetypes do not receive finlets by default.
  - Adipose fins appear behind the last enabled dorsal fin with a visible gap.

- Shader compile coverage through existing material tests.

Manual visual checks:

- Default fish remains nearly smooth.
- Betta/fancy fins show dense fan-supported membranes.
- Salmonid/trout-like fish show a small rayless dorsal adipose flap behind the
  rayed dorsal fin.
- Tuna/mackerel-like fish show small repeated finlets on the posterior dorsal and
  ventral body margins leading into the caudal peduncle.
- Finlets remain attached to the posterior body during tail beats and do not drift
  away from the caudal peduncle.
- `fin_ray_style == "none"` with nonzero legacy `fin_ray_count` still reads like
  the old parallel-ray style.
- Mixed/spiny archetype shows stronger leading support rays.
- Branching is visible only near distal half.
- Segmentation reads as ray joints, not body stripes.
- Softness animation still works without ray masks sliding or flickering.

## Risks and Mitigations

- Risk: radial UV math may look wrong on unusual custom fins.
  - Mitigation: keep spread controllable and allow style `none`.

- Risk: dense rays create moire at small export sizes.
  - Mitigation: clamp practical count per archetype; shader should soften high counts.

- Risk: spines and edge color over-darken fins.
  - Mitigation: spine/ray masks should mix color by strength and respect alpha.

- Risk: existing `fin_ray_count` users see a visual shift.
  - Mitigation: when `fin_ray_style == "none"` and only legacy count/strength are set,
    preserve the old parallel-ray fallback, or migrate default style to `soft` only for
    archetypes.

- Risk: adipose fins accidentally inherit the full ray/spine shader and look like
  a second dorsal fin.
  - Mitigation: give the adipose slot a dedicated material instance with an explicit
    ray-mask opt-out and only enable subtle rays when `adipose_fin_rayed > 0`.

- Risk: finlets become visual clutter at sprite scale.
  - Mitigation: cap counts by archetype, taper toward the tail, and allow the
    renderer to merge or hide very small finlets at low export sizes.

- Risk: finlets overlap dorsal/anal/caudal fins on short-bodied fish.
  - Mitigation: keep finlets disabled outside streamlined archetypes and compute
    anchors from sampled posterior shell profile positions with minimum spacing.

- Risk: finlets visually detach from the caudal peduncle during animation.
  - Mitigation: recompute each finlet anchor with `_animated_surface_position()` or
    an equivalent sampled animated surface path every frame.

## Implementation Phases

### Phase 1: Shader and Parameter Contract

- Add fin ray defaults through `VISUAL_PATTERN_DEFAULTS` or a dedicated
  `FIN_RAY_DEFAULTS` dictionary, then inject them from
  `BodyProfile.ensure_visual_parameters()`.
- Add all new fields to the `BodyProfile.split_parameters_into_profiles()`
  `fin_profile` round-trip list.
- Extend `shaders/fish_fin_toon.gdshader` uniforms and `hint_range` values,
  including expanding `fin_ray_count` to the agreed practical max.
- Bind and clamp all new uniforms in `ToonMaterialFactory.make_fin_material()`.
- Add a dedicated material path or override mechanism for adipose fins and finlets,
  because they must suppress ordinary global fin rays even when other fins use
  `fin_ray_*` settings.
- Update `ParameterPanel._min_for_key()` for signed and bounded fin ray controls.
- Update `ParameterPanel._max_for_key()` for `fin_ray_count`, `fin_spine_count`, and
  normalized 0..1 controls.
- Update `ParameterPanel._options_for_key()` and option detection so
  `fin_ray_style` is rendered as a select control.
- Add `UiText.gd` Korean parameter labels and option labels.
- Add shader masks for soft/fan/spiny/mixed/threaded, using normalized angle
  coordinates and `fwidth()`-based AA.
- Add adipose-fin defaults and save/load round-trip fields, but keep actual
  adipose slot geometry in Phase 2 unless a suitable existing fin slot path is
  trivial to reuse.
- Add finlet defaults and save/load round-trip fields, but keep actual repeated
  finlet geometry in Phase 2.
- Add tests for the legacy `fin_ray_style == "none"` fallback so older presets with
  nonzero `fin_ray_count` keep the old parallel-ray appearance.
- Extend tests.

### Phase 2: Archetype Tuning

- Apply conservative ray defaults to representative archetypes.
- Required in Phase 2: `betta` and `guppy` must receive visible new fin-ray defaults
  because they are the primary fan/threaded validation cases.
- Required in Phase 2: add visible rayless adipose-fin defaults to at least one
  salmonid/trout-like archetype if that archetype exists or is added in the same
  pass.
- Required in Phase 2: adipose fins must use a dedicated rayless material by
  default and must be placed behind the last enabled dorsal fin with minimum
  spacing.
- Required in Phase 2: add visible dorsal/ventral finlet arrays to tuna and
  mackerel-like archetypes.
- Required in Phase 2: finlets must use sampled animated surface anchors every
  frame and a dedicated rayless/body-blended material.
- Tune counts and strengths by sprite readability, not anatomical exactness.

### Phase 3: Optional Per-Slot Overrides

Only if global controls are insufficient:

```text
dorsal_1_ray_style / dorsal_1_ray_count / ...
caudal_ray_style / caudal_ray_count / ...
```

Per-slot overrides should inherit from global defaults and only be exposed in
`FinEditorPanel` if needed.

## Acceptance Criteria

- Smooth current fins remain possible and default-safe.
- At least three visibly distinct fin-ray reads are available: soft fan, mixed
  spine/soft ray, sparse streamlined ray.
- Betta and guppy archetypes visibly use the new fin-ray system.
- A salmonid/trout-like archetype can show a small rayless adipose fin between
  the last enabled dorsal fin and caudal fin.
- Tuna/mackerel-like archetypes can show repeated posterior finlets without
  overlapping the caudal fin or detaching during tail beats.
- Rayless adipose fins and finlets do not inherit global fin-ray masks from the
  ordinary shared fin material.
- Fin ray settings save/load through user presets.
- Existing fin softness and vector editing behavior remains intact.
- Full Godot CLI suite passes.
