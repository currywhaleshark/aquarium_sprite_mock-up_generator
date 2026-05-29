# Procedural Aquarium Sprite Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot 4.x MVP that previews primitive fish/ray rigs and exports transparent animation sprites for the aquarium game.

**Architecture:** A single `Main.tscn` drives a transparent `SubViewport`, camera presets, dynamic parameter UI, rig generation, and export. Creature rigs are code-built `Node3D` hierarchies using primitive meshes and sine pose methods. Export helpers write PNG frames, a one-row sheet, and metadata JSON.

**Tech Stack:** Godot 4.x, GDScript, JSON preset files, SubViewport capture.

---

### Task 1: Project Shell

**Files:**
- Create: `project.godot`
- Create: `scenes/Main.tscn`
- Create: `scripts/ui/Main.gd`

- [x] Create the Godot project config and main scene.
- [x] Add the transparent preview viewport, camera, lights, preset selector, parameter panel, and export controls.

### Task 2: Creature Rigs

**Files:**
- Create: `scripts/creature/CreatureRig.gd`
- Create: `scripts/creature/FishRig.gd`
- Create: `scripts/creature/RayRig.gd`
- Create: `scripts/creature/PrimitiveFactory.gd`
- Create: `scenes/creatures/FishRig.tscn`
- Create: `scenes/creatures/RayRig.tscn`

- [x] Build fish primitives, pivots, and sine tail/flap animation.
- [x] Build ray primitives, wing pivots, and sine wing/tail animation.

### Task 3: Rendering and Export

**Files:**
- Create: `scripts/materials/ToonMaterialFactory.gd`
- Create: `scripts/render/CameraPreset.gd`
- Create: `scripts/render/RenderSettings.gd`
- Create: `scripts/export/SpriteExporter.gd`
- Create: `scripts/export/SpriteSheetBuilder.gd`
- Create: `scripts/export/ExportMetadata.gd`

- [x] Add three orthographic camera presets.
- [x] Capture stable transparent PNG frames, build a one-row sheet, and write metadata.

### Task 4: Presets and UI

**Files:**
- Create: `scripts/presets/PresetStore.gd`
- Create: `scripts/ui/ParameterPanel.gd`
- Create: `scripts/ui/ExportPanel.gd`
- Create: `scripts/ui/PreviewControls.gd`
- Create: `presets/*.json`

- [x] Add six default presets covering the requested fish and ray targets.
- [x] Wire sliders and color pickers to rig rebuilds.

### Task 5: Verify

**Files:**
- Validate all files in the project root.

- [ ] Run Godot project metadata/read check.
- [ ] Launch the project if Godot runtime is available.
