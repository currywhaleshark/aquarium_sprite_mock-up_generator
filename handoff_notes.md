# Handoff Notes - Ray Model Redesign & Sub-Editor Integration

This document outlines the changes made to transition the ray anatomy from a legacy flat model to a high-fidelity, poseable, and customizable 3D model with integrated sub-editors.

---

## 1. Unified 3D Solid Ray Geometry (`RayRig.gd` & `PrimitiveFactory.gd`)
- **Grid Mesh Construction**: Created a single seamless double-sided grid mesh of $17 \times 17$ resolution via `PrimitiveFactory.build_ray_grid_mesh()`. Left and right wing edges pinch to zero thickness, eliminating Z-fighting.
- **Removed Mantle Shell**: Eliminated the legacy translucent `MantleShell` geometry.
- **Cephalic Horns & Pelvic Lobes**:
  - Cephalic horns are spawned at the front snout and support `"none"`, `"rolled"` (open cylinders), and `"unfolded"` (flat foils) states.
  - Pelvic lobes are spawned at the posterior tail margins, scaling dynamically with the `"pelvic_length"` and `"pelvic_height"` parameters.

---

## 2. Ray Locomotion Modes (`RayRig.gd` & `BodyProfile.gd`)
Added the `"ray_locomotion_mode"` option parameter to support diverse movements:
- **물결파 (Rajiform)**: Bottom-dwelling stingray style (high wave ripples, standard amplitude).
- **날개짓 (Mobuliform)**: Manta ray style (low wave ripples, large wing-flapping amplitude).
- **바닥 보행 (Punting)**: Skate style (pectoral wings stationary; pelvic lobes execute alternating rowing/walking animation).
- **Pectoral Flap Sync (`pectoral_flap_sync`)**: Control for alternating vs. synchronous wing flaps, categorized under the "Motion Settings" tab.

---

## 3. Sub-Editors Integration (`Main.gd` & Panel Scripts)
- **Body Edit (몸통 링 편집)**:
  - Enabled full body ring edits for rays.
  - Samples the body rings at each grid section of the ray body (`BodyProfile.sample_rings()`) to scale the wing span (`width`), thickness (`upper_height`/`lower_height`), and vertical center offset (`y_offset`).
  - Unified the 3D ring visualizers and drag-handles click input to support any rig with `get_body_ring_global_points()`.
- **Head Edit (머리 형태 편집)**:
  - Added `"ray_head_shape"` options: `"manta"` (wide/flat), `"eagle"` (pointed spade), and `"cownose"` (grooved double-lobe).
  - The snout deforms dynamically based on the shape and scales with the `"snout_length"` slider.
  - Restricts controls for rays to `"ray_head_shape"`, `"eye_size"`, and `"eye_spacing"`.
- **Fin Edit (지느러미 편집)**:
  - Added slot `"cephalic"` (cephalic horns).
  - Rebuilds slots dropdown dynamically: if ray, only show `"cephalic"` and `"pelvic"` slots.
  - Hides attachment positioning sliders and pelvic shape dropdowns (pelvic fins are ellipsoids).

---

## 4. Verification & Testing
- Updated `ShellRigTest.gd` to test wingtip vertex deformation and verify the presence of `BodyMesh` instead of `MantleShell`.
- Ran the full Godot CLI test suite: **all 35 tests passed successfully**.

---

## 5. Branch Status
- All changes are implemented using static typing rules and compile cleanly.
- Presets (`basic_ray.json` and `manta_ray.json`) are updated with the new configuration parameters.
