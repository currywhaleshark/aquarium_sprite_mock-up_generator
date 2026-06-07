# Operculum Gill Cover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `gill_mark = "operculum"` option that renders an anatomical bony-fish gill cover with editable size, height, opening, and ridge strength.

**Architecture:** Keep the feature inside the existing fish head feature path. The UI exposes the new option and four conditional sliders, `BodyProfile` persists the new keys in `fin_profile`, and `FishRig` renders a custom head-surface-following opercle plate plus seam ribbons under `BodyPivot/Head/GillMark_operculum`.

**Tech Stack:** Godot 4 GDScript, `ArrayMesh`, `SurfaceTool`, existing `PrimitiveFactory` and `TextureMaterialFactory`, PowerShell Godot CLI test runner.

---

## File Structure

- Modify `scripts/ui/HeadEditorPanel.gd`: add the `operculum` gill mark option, numeric slider config, fish section, conditional visibility, and defaults.
- Modify `scripts/ui/UiText.gd`: add Korean labels for the option and four numeric controls.
- Modify `scripts/creature/BodyProfile.gd`: add operculum numeric keys to the fish `fin_profile` split list.
- Modify `scripts/creature/FishRig.gd`: update `_add_gill_mark()` plumbing, add an operculum-safe side sampler, and generate opercle plate and seam/slit ribbon meshes.
- Modify `scripts/tools/HeadEditorPanelTest.gd`: cover slider visibility and emitted values.
- Modify `scripts/tools/PresetNormalizationTest.gd`: cover profile split/rebuild for the new keys.
- Modify `scripts/tools/HeadEditorModelTest.gd`: cover generated nodes, mirror geometry, parameter effects, and inactive behavior.
- Verify `scripts/tools/HeadDiagnosticTraitTest.gd`: run it in the focused regression sweep because `_add_gill_mark()` plumbing changes existing gill mark behavior.

---

### Task 1: UI Controls and Preset Persistence

**Files:**
- Modify: `scripts/tools/HeadEditorPanelTest.gd`
- Modify: `scripts/tools/PresetNormalizationTest.gd`
- Modify: `scripts/ui/HeadEditorPanel.gd`
- Modify: `scripts/ui/UiText.gd`
- Modify: `scripts/creature/BodyProfile.gd`

- [ ] **Step 1: Write failing UI slider assertions**

In `scripts/tools/HeadEditorPanelTest.gd`, add `gill_mark` to the initial `panel.set_parameters()` dictionary:

```gdscript
		"gill_mark": "none",
```

Insert these assertions after the existing lower-jaw slider visibility assertions:

```gdscript
	assert(not _has_numeric_slider(panel, "operculum_size"))
	assert(not _has_numeric_slider(panel, "operculum_height"))
	assert(not _has_numeric_slider(panel, "operculum_open"))
	assert(not _has_numeric_slider(panel, "operculum_ridge"))
	panel.set_option_parameter("gill_mark", "operculum")
	assert(_has_numeric_slider(panel, "operculum_size"))
	assert(_has_numeric_slider(panel, "operculum_height"))
	assert(_has_numeric_slider(panel, "operculum_open"))
	assert(_has_numeric_slider(panel, "operculum_ridge"))
	panel.set_numeric_parameter("operculum_size", 1.25)
	panel.set_numeric_parameter("operculum_height", 1.35)
	panel.set_numeric_parameter("operculum_open", 0.6)
	panel.set_numeric_parameter("operculum_ridge", 0.8)
	assert(abs(float(seen[0].get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(seen[0].get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(seen[0].get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(seen[0].get("operculum_ridge", 0.0)) - 0.8) < 0.001)
	panel.set_option_parameter("gill_mark", "line")
	assert(not _has_numeric_slider(panel, "operculum_size"))
	assert(not _has_numeric_slider(panel, "operculum_height"))
	assert(not _has_numeric_slider(panel, "operculum_open"))
	assert(not _has_numeric_slider(panel, "operculum_ridge"))
```

- [ ] **Step 2: Write failing profile round-trip assertions**

In `scripts/tools/PresetNormalizationTest.gd`, insert this block before the final `DirAccess.make_dir_recursive_absolute(...)` call:

```gdscript
	var operculum_split := BodyProfileScript.split_parameters_into_profiles({
		"gill_mark": "operculum",
		"operculum_size": 1.25,
		"operculum_height": 1.35,
		"operculum_open": 0.6,
		"operculum_ridge": 0.8
	}, {"name": "operculum_roundtrip", "type": "fish"})
	var operculum_fin_profile: Dictionary = operculum_split.get("fin_profile", {})
	assert(String(operculum_fin_profile.get("gill_mark", "")) == "operculum")
	assert(abs(float(operculum_fin_profile.get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(operculum_fin_profile.get("operculum_ridge", 0.0)) - 0.8) < 0.001)
	var rebuilt_operculum := BodyProfileScript.make_parameters_from_structured_preset(operculum_split)
	assert(String(rebuilt_operculum.get("gill_mark", "")) == "operculum")
	assert(abs(float(rebuilt_operculum.get("operculum_size", 0.0)) - 1.25) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_height", 0.0)) - 1.35) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_open", 0.0)) - 0.6) < 0.001)
	assert(abs(float(rebuilt_operculum.get("operculum_ridge", 0.0)) - 0.8) < 0.001)
```

- [ ] **Step 3: Run focused UI and profile tests to verify they fail**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Expected:

```text
HeadEditorPanelTest fails because operculum_* sliders are not registered or visible.
PresetNormalizationTest fails because operculum_* keys are not copied into fin_profile.
```

- [ ] **Step 4: Implement the UI option and numeric controls**

In `scripts/ui/HeadEditorPanel.gd`, update the gill mark list:

```gdscript
const GILL_MARKS := ["none", "line", "crescent", "plate", "operculum"]
```

Add these entries to `NUMERIC_KEYS`:

```gdscript
	"operculum_size": {"min": 0.5, "max": 1.5, "step": 0.01},
	"operculum_height": {"min": 0.5, "max": 1.5, "step": 0.01},
	"operculum_open": {"min": 0.0, "max": 1.0, "step": 0.01},
	"operculum_ridge": {"min": 0.0, "max": 1.0, "step": 0.01},
```

Add this fish section after the `"입"` section and before the `"눈"` section:

```gdscript
	{"title": "아가미", "keys": ["operculum_size", "operculum_height", "operculum_open", "operculum_ridge"]},
```

Add this branch in `_should_show_fish_numeric_key()` before `return true`:

```gdscript
	if key.begins_with("operculum_"):
		return String(parameters.get("gill_mark", "none")) == "operculum"
```

Add these defaults in `_default_numeric()`:

```gdscript
		"operculum_size":
			return 1.0
		"operculum_height":
			return 1.0
		"operculum_open":
			return 0.0
		"operculum_ridge":
			return 0.45
```

- [ ] **Step 5: Implement UI text labels**

In `scripts/ui/UiText.gd`, add the option label near the existing gill labels:

```gdscript
	"operculum": "아가미덮개",
```

Add these parameter labels near `"gill_mark"`:

```gdscript
	"operculum_size": "아가미덮개 길이",
	"operculum_height": "아가미덮개 높이",
	"operculum_open": "아가미덮개 열림",
	"operculum_ridge": "아가미덮개 경계",
```

- [ ] **Step 6: Implement profile persistence**

In `scripts/creature/BodyProfile.gd`, extend the fish `fin_profile` key list next to `"gill_mark"`:

```gdscript
		"head_ornament", "gill_mark", "operculum_size", "operculum_height", "operculum_open", "operculum_ridge",
		"barbel_style", "eye_style", "mouth_detail",
```

- [ ] **Step 7: Run focused UI and profile tests to verify they pass**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
```

Expected:

```text
HEAD_EDITOR_PANEL_TEST_OK
PRESET_NORMALIZATION_TEST_OK
```

- [ ] **Step 8: Commit Task 1**

Run:

```powershell
git add scripts\tools\HeadEditorPanelTest.gd scripts\tools\PresetNormalizationTest.gd scripts\ui\HeadEditorPanel.gd scripts\ui\UiText.gd scripts\creature\BodyProfile.gd
git commit -m "Add operculum editor controls"
```

---

### Task 2: Operculum Rig Geometry

**Files:**
- Modify: `scripts/tools/HeadEditorModelTest.gd`
- Modify: `scripts/creature/FishRig.gd`

- [ ] **Step 1: Write failing node and geometry assertions**

In `scripts/tools/HeadEditorModelTest.gd`, insert this block after the initial `assert(mouth != null)` assertion:

```gdscript
	var operculum_base := {
		"shell_enabled": 1.0,
		"base_color": "#46c6cf",
		"secondary_color": "#d6fbff",
		"head_shape": "rounded",
		"mouth_type": "terminal",
		"snout_length": 0.0,
		"gill_mark": "operculum",
		"operculum_size": 1.0,
		"operculum_height": 1.0,
		"operculum_open": 0.0,
		"operculum_ridge": 0.45
	}
	fish.set_parameters(operculum_base)
	await get_tree().process_frame
	await get_tree().process_frame
	var operculum_root := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum") as Node3D
	assert(operculum_root != null)
	var opercle_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D
	var opercle_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleR") as MeshInstance3D
	var pre_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/PreopercleSeamL") as MeshInstance3D
	var pre_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/PreopercleSeamR") as MeshInstance3D
	var slit_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/GillSlitL") as MeshInstance3D
	var slit_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/GillSlitR") as MeshInstance3D
	var sub_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/SubopercleSeamL") as MeshInstance3D
	var sub_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/SubopercleSeamR") as MeshInstance3D
	assert(opercle_l != null)
	assert(opercle_r != null)
	assert(pre_l != null)
	assert(pre_r != null)
	assert(slit_l != null)
	assert(slit_r != null)
	assert(sub_l != null)
	assert(sub_r != null)
	var opercle_l_extent := _mesh_extent(opercle_l)
	assert(opercle_l_extent.x > 0.16)
	assert(opercle_l_extent.y > 0.24)
	assert(opercle_l_extent.z > 0.01)
	assert(_mesh_average_z(opercle_l) < -0.05)
	assert(_mesh_average_z(opercle_r) > 0.05)
	assert(absf(_mesh_average_z(opercle_l) + _mesh_average_z(opercle_r)) < 0.025)
	var line_params := operculum_base.duplicate(true)
	line_params["gill_mark"] = "line"
	fish.set_parameters(line_params)
	await get_tree().process_frame
	assert(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum") == null)
	assert(fish.get_node_or_null("BodyPivot/Head/GillMark_line") != null)
```

Add this helper near the existing `_mesh_extent()` helper:

```gdscript
func _mesh_average_z(node: MeshInstance3D) -> float:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var total := 0.0
	for v in verts:
		total += v.z
	return total / float(maxi(verts.size(), 1))
```

- [ ] **Step 2: Run model test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
```

Expected:

```text
HeadEditorModelTest fails at operculum_root != null because FishRig has no operculum branch.
```

- [ ] **Step 3: Update FishRig gill mark plumbing**

In `scripts/creature/FishRig.gd`, replace the `_add_gill_mark()` call inside `_add_head_features()` with:

```gdscript
	var head_verts: PackedVector3Array = head.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var operculum_ridge := clampf(param_float("operculum_ridge", 0.45), 0.0, 1.0)
	var plate_darken := lerpf(0.04, 0.18, operculum_ridge)
	var opercle_mat := TMF.make_surface(parameters.get("base_color", "#46c6cf"))
	opercle_mat.albedo_color = opercle_mat.albedo_color.darkened(plate_darken)
	_add_gill_mark(head, String(parameters.get("gill_mark", "none")), dark_mat, opercle_mat, head_verts)
```

Change the helper signature from:

```gdscript
func _add_gill_mark(head: MeshInstance3D, mark: String, material: Material) -> void:
```

to:

```gdscript
func _add_gill_mark(head: MeshInstance3D, mark: String, seam_mat: Material, opercle_mat: Material, head_verts: PackedVector3Array) -> void:
```

Inside existing `"line"`, `"crescent"`, and `"plate"` branches, replace `material` with `seam_mat` so legacy gill marks keep their dark material behavior.

- [ ] **Step 4: Make the side sampler operculum-safe**

Replace `_head_mesh_side_z()` with this compatible version. Existing callers keep the old cutoff through the default argument; operculum callers pass `0.42`.

```gdscript
func _head_mesh_side_z(verts: PackedVector3Array, x: float, y: float, side: float, outset: float, max_sample_x: float = 0.25) -> float:
	var best_d := INF
	var best_z := 0.0
	for v in verts:
		if side > 0.0 and v.z < 0.0:
			continue
		if side < 0.0 and v.z > 0.0:
			continue
		if v.x > max_sample_x:
			continue
		var dx := v.x - x
		var dy := v.y - y
		var d := dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best_z = v.z
	if best_d == INF:
		return side * _head_side_surface_z(x, y, outset)
	return best_z + side * outset
```

- [ ] **Step 5: Add operculum parameter and mesh helpers**

Add these helpers above `_add_gill_mark()` in `scripts/creature/FishRig.gd`:

```gdscript
func _operculum_params() -> Dictionary:
	var size := clampf(param_float("operculum_size", 1.0), 0.5, 1.5)
	var height := clampf(param_float("operculum_height", 1.0), 0.5, 1.5)
	var open := clampf(param_float("operculum_open", 0.0), 0.0, 1.0)
	var ridge := clampf(param_float("operculum_ridge", 0.45), 0.0, 1.0)
	var center_x := 0.18
	var half_len := 0.11 * size
	return {
		"size": size,
		"height": height,
		"open": open,
		"ridge": ridge,
		"anterior_x": center_x - half_len,
		"posterior_x": center_x + half_len,
		"top_y": 0.16 * height,
		"bottom_y": -0.18 * height,
		"seam_width": lerpf(0.004, 0.014, ridge),
		"slit_width": lerpf(0.008, 0.024, ridge),
		"subopercle_width": lerpf(0.003, 0.010, ridge)
	}

func _operculum_plate_mesh(side: float, head_verts: PackedVector3Array, cfg: Dictionary, rows: int = 6, cols: int = 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var index := 0
	for row in range(rows + 1):
		var v_t := float(row) / float(rows)
		var edge_t := absf(v_t * 2.0 - 1.0)
		var anterior_x := float(cfg["anterior_x"]) + 0.035 * edge_t
		var posterior_x := float(cfg["posterior_x"]) - 0.015 * edge_t
		var y := lerpf(float(cfg["top_y"]), float(cfg["bottom_y"]), v_t)
		for col in range(cols + 1):
			var u_t := float(col) / float(cols)
			var x := lerpf(anterior_x, posterior_x, u_t)
			var open_weight := smoothstep(0.35, 1.0, u_t)
			var z := _head_mesh_side_z(head_verts, x, y, side, 0.026, 0.42)
			z += side * float(cfg["open"]) * 0.035 * open_weight
			x += float(cfg["open"]) * 0.015 * open_weight
			st.add_vertex(Vector3(x, y, z))
			index += 1
	for row in range(rows):
		for col in range(cols):
			var a := row * (cols + 1) + col
			var b := a + 1
			var c := a + (cols + 1)
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	return st.commit()

func _operculum_ribbon_mesh(side: float, head_verts: PackedVector3Array, points: PackedVector2Array, width: float, cfg: Dictionary, apply_open: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := width * 0.5
	for i in range(points.size()):
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var tangent := next - prev
		if tangent.length() < 0.001:
			tangent = Vector2(0.0, 1.0)
		tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x) * half_width
		for sign in [-1.0, 1.0]:
			var x := points[i].x + normal.x * sign
			var y := points[i].y + normal.y * sign
			var local_u := clampf((x - float(cfg["anterior_x"])) / maxf(float(cfg["posterior_x"]) - float(cfg["anterior_x"]), 0.001), 0.0, 1.0)
			var open_weight := smoothstep(0.35, 1.0, local_u) if apply_open else 0.0
			var z := _head_mesh_side_z(head_verts, x, y, side, 0.036, 0.42)
			z += side * float(cfg["open"]) * 0.035 * open_weight
			x += float(cfg["open"]) * 0.015 * open_weight
			st.add_vertex(Vector3(x, y, z))
	for i in range(points.size() - 1):
		var a := i * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)
		st.add_index(b)
		st.add_index(c)
		st.add_index(d)
	st.generate_normals()
	return st.commit()

func _add_operculum_side(root: Node3D, side: float, seam_mat: Material, opercle_mat: Material, head_verts: PackedVector3Array) -> void:
	var suffix := "L" if side < 0.0 else "R"
	var cfg := _operculum_params()
	var opercle := MeshInstance3D.new()
	opercle.name = "Opercle%s" % suffix
	opercle.mesh = _operculum_plate_mesh(side, head_verts, cfg)
	opercle.material_override = opercle_mat
	root.add_child(opercle)

	var anterior_x := float(cfg["anterior_x"])
	var posterior_x := float(cfg["posterior_x"])
	var top_y := float(cfg["top_y"])
	var bottom_y := float(cfg["bottom_y"])

	var preopercle := MeshInstance3D.new()
	preopercle.name = "PreopercleSeam%s" % suffix
	preopercle.mesh = _operculum_ribbon_mesh(side, head_verts, PackedVector2Array([
		Vector2(anterior_x + 0.032, top_y * 0.92),
		Vector2(anterior_x + 0.006, top_y * 0.35),
		Vector2(anterior_x, -0.02 * float(cfg["height"])),
		Vector2(anterior_x + 0.024, bottom_y * 0.86)
	]), float(cfg["seam_width"]), cfg, false)
	preopercle.material_override = seam_mat
	root.add_child(preopercle)

	var slit := MeshInstance3D.new()
	slit.name = "GillSlit%s" % suffix
	slit.mesh = _operculum_ribbon_mesh(side, head_verts, PackedVector2Array([
		Vector2(posterior_x - 0.006, top_y * 0.72),
		Vector2(posterior_x + 0.012, 0.0),
		Vector2(posterior_x - 0.004, bottom_y * 0.62)
	]), float(cfg["slit_width"]), cfg, true)
	slit.material_override = seam_mat
	root.add_child(slit)

	var subopercle := MeshInstance3D.new()
	subopercle.name = "SubopercleSeam%s" % suffix
	subopercle.mesh = _operculum_ribbon_mesh(side, head_verts, PackedVector2Array([
		Vector2(anterior_x + 0.060, bottom_y + 0.060),
		Vector2((anterior_x + posterior_x) * 0.52, bottom_y + 0.030),
		Vector2(posterior_x - 0.040, bottom_y + 0.085)
	]), float(cfg["subopercle_width"]), cfg, true)
	subopercle.material_override = seam_mat
	root.add_child(subopercle)
```

- [ ] **Step 6: Add the operculum branch**

In `_add_gill_mark()`, add the new branch after `"plate"`:

```gdscript
		"operculum":
			var ribbon_mat := seam_mat
			if seam_mat is BaseMaterial3D:
				ribbon_mat = seam_mat.duplicate()
				(ribbon_mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
			for side in [-1.0, 1.0]:
				_add_operculum_side(root, side, ribbon_mat, opercle_mat, head_verts)
```

- [ ] **Step 7: Run model test to verify it passes**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
```

Expected:

```text
HEAD_EDITOR_MODEL_TEST_OK
```

- [ ] **Step 8: Commit Task 2**

Run:

```powershell
git add scripts\tools\HeadEditorModelTest.gd scripts\creature\FishRig.gd
git commit -m "Render operculum gill cover"
```

---

### Task 3: Parameter Effects and Open-Flare Sign

**Files:**
- Modify: `scripts/tools/HeadEditorModelTest.gd`
- Modify: `scripts/creature/FishRig.gd` only if the new assertions expose geometry issues.

- [ ] **Step 1: Write failing parameter-effect assertions**

In `scripts/tools/HeadEditorModelTest.gd`, insert this block after the Task 2 operculum node assertions and before `line_params` switches the mark to `"line"`:

```gdscript
	var small_operculum := operculum_base.duplicate(true)
	small_operculum["operculum_size"] = 0.55
	fish.set_parameters(small_operculum)
	await get_tree().process_frame
	var small_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)

	var large_operculum := operculum_base.duplicate(true)
	large_operculum["operculum_size"] = 1.45
	fish.set_parameters(large_operculum)
	await get_tree().process_frame
	var large_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)
	assert(large_plate_extent.x > small_plate_extent.x + 0.14)

	var short_operculum := operculum_base.duplicate(true)
	short_operculum["operculum_height"] = 0.55
	fish.set_parameters(short_operculum)
	await get_tree().process_frame
	var short_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)

	var tall_operculum := operculum_base.duplicate(true)
	tall_operculum["operculum_height"] = 1.45
	fish.set_parameters(tall_operculum)
	await get_tree().process_frame
	var tall_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)
	assert(tall_plate_extent.y > short_plate_extent.y + 0.22)

	var closed_operculum := operculum_base.duplicate(true)
	closed_operculum["operculum_open"] = 0.0
	fish.set_parameters(closed_operculum)
	await get_tree().process_frame
	var closed_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D
	var closed_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleR") as MeshInstance3D
	var closed_l_rear_z := _mesh_rear_edge_average_z(closed_l)
	var closed_r_rear_z := _mesh_rear_edge_average_z(closed_r)
	var closed_l_front_abs_z := _mesh_front_edge_abs_z(closed_l)

	var open_operculum := operculum_base.duplicate(true)
	open_operculum["operculum_open"] = 1.0
	fish.set_parameters(open_operculum)
	await get_tree().process_frame
	var open_l := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D
	var open_r := fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleR") as MeshInstance3D
	assert(_mesh_rear_edge_average_z(open_l) < closed_l_rear_z - 0.025)
	assert(_mesh_rear_edge_average_z(open_r) > closed_r_rear_z + 0.025)
	assert(absf(_mesh_front_edge_abs_z(open_l) - closed_l_front_abs_z) < 0.014)

	var low_ridge := operculum_base.duplicate(true)
	low_ridge["operculum_ridge"] = 0.0
	fish.set_parameters(low_ridge)
	await get_tree().process_frame
	var low_slit_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/GillSlitL") as MeshInstance3D)
	var low_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)

	var high_ridge := operculum_base.duplicate(true)
	high_ridge["operculum_ridge"] = 1.0
	fish.set_parameters(high_ridge)
	await get_tree().process_frame
	var high_slit_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/GillSlitL") as MeshInstance3D)
	var high_plate_extent := _mesh_extent(fish.get_node_or_null("BodyPivot/Head/GillMark_operculum/OpercleL") as MeshInstance3D)
	assert(high_slit_extent.x > low_slit_extent.x + 0.010)
	assert(absf(high_plate_extent.x - low_plate_extent.x) < 0.012)
	assert(absf(high_plate_extent.y - low_plate_extent.y) < 0.012)
```

Add these helpers near `_mesh_average_z()`:

```gdscript
func _mesh_rear_edge_average_z(node: MeshInstance3D) -> float:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_x := -INF
	for v in verts:
		max_x = maxf(max_x, v.x)
	var total := 0.0
	var count := 0
	for v in verts:
		if v.x >= max_x - 0.018:
			total += v.z
			count += 1
	assert(count > 0)
	return total / float(count)

func _mesh_front_edge_abs_z(node: MeshInstance3D) -> float:
	var verts: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var min_x := INF
	for v in verts:
		min_x = minf(min_x, v.x)
	var max_abs_z := 0.0
	for v in verts:
		if v.x <= min_x + 0.018:
			max_abs_z = maxf(max_abs_z, absf(v.z))
	return max_abs_z
```

- [ ] **Step 2: Run model test to verify the new assertions fail against incomplete geometry**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
```

Expected if Task 2 has not yet consumed all formulas:

```text
HeadEditorModelTest fails on size, height, open sign, or ridge-width assertions.
```

Expected if Task 2 implementation already follows the formulas:

```text
HEAD_EDITOR_MODEL_TEST_OK
```

- [ ] **Step 3: Fix parameter formula mismatches in FishRig**

If the Task 3 assertions fail, update only these formula points in `scripts/creature/FishRig.gd`:

```gdscript
var half_len := 0.11 * size
var top_y := 0.16 * height
var bottom_y := -0.18 * height
var seam_width := lerpf(0.004, 0.014, ridge)
var slit_width := lerpf(0.008, 0.024, ridge)
var subopercle_width := lerpf(0.003, 0.010, ridge)
var open_weight := smoothstep(0.35, 1.0, local_x_fraction)
z += side * open * 0.035 * open_weight
x += open * 0.015 * open_weight
```

The exact helper fields in Task 2 already use these names: `"anterior_x"`, `"posterior_x"`, `"top_y"`, `"bottom_y"`, `"seam_width"`, `"slit_width"`, and `"subopercle_width"`.

- [ ] **Step 4: Run model test to verify all operculum geometry assertions pass**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
```

Expected:

```text
HEAD_EDITOR_MODEL_TEST_OK
```

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add scripts\tools\HeadEditorModelTest.gd scripts\creature\FishRig.gd
git commit -m "Test operculum parameter effects"
```

---

### Task 4: Regression Sweep

**Files:**
- Verify: `scripts/tools/HeadEditorPanelTest.gd`
- Verify: `scripts/tools/PresetNormalizationTest.gd`
- Verify: `scripts/tools/HeadEditorModelTest.gd`
- Verify: `scripts/tools/HeadDiagnosticTraitTest.gd`

- [ ] **Step 1: Run focused tests touched by the feature**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorPanelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter PresetNormalizationTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadDiagnosticTraitTest
```

Expected:

```text
HEAD_EDITOR_PANEL_TEST_OK
PRESET_NORMALIZATION_TEST_OK
HEAD_EDITOR_MODEL_TEST_OK
HEAD_DIAGNOSTIC_TRAIT_TEST_OK
```

- [ ] **Step 2: Run the full Godot CLI suite**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

Expected:

```text
All Godot CLI tests pass through tools\run_godot_cli_tests.ps1.
```

- [ ] **Step 3: Commit verification-only updates if any files changed during cleanup**

Run this only when `git status --short` shows files changed after the Task 3 commit:

```powershell
git add scripts\tools\HeadEditorPanelTest.gd scripts\tools\PresetNormalizationTest.gd scripts\tools\HeadEditorModelTest.gd scripts\tools\HeadDiagnosticTraitTest.gd scripts\ui\HeadEditorPanel.gd scripts\ui\UiText.gd scripts\creature\BodyProfile.gd scripts\creature\FishRig.gd
git commit -m "Verify operculum gill cover"
```

---

## Self-Review

- Spec coverage: Task 1 covers option, slider visibility, Korean labels, defaults, and profile persistence. Task 2 covers node structure, material plumbing, side-surface sampling beyond `x = 0.25`, and static opercle rendering. Task 3 covers all four numeric mappings, posterior-only flare, side sign, and ridge width without plate-size drift. Task 4 covers focused and full verification.
- Placeholder scan: The plan contains concrete file paths, code snippets, commands, and expected outcomes. It does not rely on unspecified functions outside the helpers defined in the tasks.
- Type consistency: `FishRig._add_gill_mark()` receives `seam_mat: Material`, `opercle_mat: Material`, and `head_verts: PackedVector3Array`; `_operculum_plate_mesh()` and `_operculum_ribbon_mesh()` both consume the same `cfg: Dictionary`; tests read `MeshInstance3D` nodes by the node names required in the spec.
