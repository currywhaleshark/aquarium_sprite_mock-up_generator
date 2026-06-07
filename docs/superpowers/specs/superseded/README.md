# Superseded operculum specs

These documents are kept for history only. They describe the **geometry-decal** approach to the
operculum (separate outset meshes pasted on the head surface), which was abandoned because it
inherently floats, wings out in front view, z-fights, buries under the body shell, and intrudes
on the eye — all artifacts of the wrong representation.

**Live spec:** [`../2026-06-07-operculum-shader-marking-refactor.md`](../2026-06-07-operculum-shader-marking-refactor.md)
reimplements the operculum as a UV-driven shader marking on the head material, matching how
stylized fish are actually built (ABZU, PolyStyle, Substance-textured fish) and reusing the
project's own `fish_body_toon.gdshader` marking engine.

History:

- `2026-06-07-operculum-anatomical-revision.md` (v2) — fan silhouette, J preopercle, rear-edge
  gill slit. Still geometry.
- `2026-06-07-operculum-shell-clearance-fix.md` (v3) — shared shell-clearing outset so parts sit
  on the visible body. Fixed the detached-slit look but introduced front-view wings.
- `2026-06-07-operculum-geometry-hinge-plan.md` (v4 draft) — hinge-pivot open + eye-aware margin
  + tighter outset. Not adopted: had an eye-layout ordering bug, broke v3's coplanarity tests,
  and its outset tightening re-risked the v3 burial.

The foundational `../2026-06-07-operculum-gill-cover-design.md` (v1) remains in place as the
original feature design; its data-model / UI / parameter decisions still hold, but its node
structure is superseded by the shader approach.
