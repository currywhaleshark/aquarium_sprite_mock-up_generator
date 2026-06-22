extends Node

const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")
const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")
const FishRigScript := preload("res://scripts/creature/FishRig.gd")
const ParameterPanelScript := preload("res://scripts/ui/ParameterPanel.gd")
const PresetStoreScript := preload("res://scripts/presets/PresetStore.gd")

var _failed := false

func _ready() -> void:
	_test_fin_thickness_extrudes_polygon_mesh()
	if _failed:
		return
	_test_zero_fin_thickness_preserves_flat_mesh()
	if _failed:
		return
	_test_fin_thickness_round_trips_through_fin_profile()
	if _failed:
		return
	_test_fin_editor_exposes_fin_thickness()
	if _failed:
		return
	_test_fin_thickness_uses_fine_control_range()
	if _failed:
		return
	_test_general_parameter_panel_hides_fin_thickness()
	if _failed:
		return
	_test_fin_thickness_clamps_before_it_gets_blocky()
	if _failed:
		return
	_test_basic_shark_defaults_fin_thickness()
	if _failed:
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_thickness.ok", FileAccess.WRITE)
	file.store_string("fin thickness mesh, UI, and preset behavior verified")
	file.close()
	print("FIN_THICKNESS_TEST_OK")
	get_tree().quit(0)

func _test_fin_thickness_extrudes_polygon_mesh() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.015,
		"dorsal_1_shape": "single",
		"caudal_shape": "forked_shallow"
	})
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	if not _require(dorsal != null, "dorsal fin should exist for thickness test"):
		return
	var z_span := _mesh_local_z_span(dorsal.mesh)
	if not _require(z_span >= 0.014 and z_span <= 0.016, "fin_thickness should map to a subtle dorsal fin z span"):
		return
	fish.queue_free()

func _test_zero_fin_thickness_preserves_flat_mesh() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.0,
		"dorsal_1_shape": "single"
	})
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	if not _require(dorsal != null, "flat dorsal fin should exist"):
		return
	if not _require(_mesh_local_z_span(dorsal.mesh) <= 0.001, "zero fin_thickness should keep fins flat"):
		return
	fish.queue_free()

func _test_fin_thickness_round_trips_through_fin_profile() -> void:
	var split := BodyProfileScript.split_parameters_into_profiles({
		"creature_type": "shark",
		"fin_thickness": 0.018
	}, {
		"name": "fin_thickness_round_trip",
		"creature_type": "shark"
	})
	var fin_profile: Dictionary = split.get("fin_profile", {})
	if not _require(abs(float(fin_profile.get("fin_thickness", 0.0)) - 0.018) < 0.001, "fin_profile should retain fin_thickness"):
		return
	var rebuilt := BodyProfileScript.make_parameters_from_structured_preset(split)
	if not _require(abs(float(rebuilt.get("fin_thickness", 0.0)) - 0.018) < 0.001, "structured preset rebuild should retain fin_thickness"):
		return

func _test_fin_editor_exposes_fin_thickness() -> void:
	var panel := FinEditorPanelScript.new()
	add_child(panel)
	var seen_parameters := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen_parameters[0] = parameters
	)
	panel.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.012
	})
	panel.select_slot("pectoral")
	var numeric_sliders: Dictionary = panel.get("numeric_sliders")
	if not _require(numeric_sliders.has("fin_thickness"), "fin editor should expose fin_thickness for shark fins"):
		return
	panel.set_numeric_parameter("fin_thickness", 0.018)
	if not _require(abs(float(seen_parameters[0].get("fin_thickness", 0.0)) - 0.018) < 0.001, "fin editor should emit fin_thickness changes"):
		return
	panel.queue_free()

func _test_fin_thickness_uses_fine_control_range() -> void:
	var panel := FinEditorPanelScript.new()
	add_child(panel)
	panel.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.012
	})
	panel.select_slot("pectoral")
	var numeric_sliders: Dictionary = panel.get("numeric_sliders")
	if not _require(numeric_sliders.has("fin_thickness"), "fin editor should expose fin_thickness slider"):
		return
	var widgets: Dictionary = numeric_sliders["fin_thickness"]
	var slider := widgets["slider"] as HSlider
	if not _require(slider != null, "fin_thickness slider should be an HSlider"):
		return
	if not _require(slider.max_value <= 0.03, "fin_thickness editor max should stay in subtle mesh-thickness range"):
		return
	if not _require(slider.step <= 0.001, "fin_thickness editor step should allow fine adjustment"):
		return
	panel.queue_free()

func _test_general_parameter_panel_hides_fin_thickness() -> void:
	var panel := ParameterPanelScript.new()
	add_child(panel)
	panel.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.1
	})
	var sliders: Dictionary = panel.get("sliders")
	if not _require(not sliders.has("fin_thickness"), "general parameter panel should not expose coarse fin_thickness slider"):
		return
	panel.queue_free()

func _test_fin_thickness_clamps_before_it_gets_blocky() -> void:
	var fish := FishRigScript.new()
	add_child(fish)
	fish.auto_animate = false
	fish.set_parameters({
		"creature_type": "shark",
		"fin_thickness": 0.1,
		"dorsal_1_shape": "single"
	})
	var dorsal := fish.get_node_or_null("BodyPivot/DorsalFin1") as MeshInstance3D
	if not _require(dorsal != null, "clamped dorsal fin should exist"):
		return
	if not _require(_mesh_local_z_span(dorsal.mesh) <= 0.031, "fin_thickness should clamp before fins become blocky"):
		return
	fish.queue_free()

func _test_basic_shark_defaults_fin_thickness() -> void:
	var default_shark := PresetStoreScript.find_default_for_mode("shark")
	var parameters: Dictionary = default_shark.get("parameters", {})
	var thickness := float(parameters.get("fin_thickness", 0.0))
	if not _require(thickness >= 0.008 and thickness <= 0.016, "basic shark preset should default to subtle fin thickness"):
		return

func _mesh_local_z_span(mesh: Mesh) -> float:
	if mesh == null or mesh.get_surface_count() <= 0:
		return 0.0
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return 0.0
	var min_z := vertices[0].z
	var max_z := vertices[0].z
	for vertex in vertices:
		min_z = minf(min_z, vertex.z)
		max_z = maxf(max_z, vertex.z)
	return max_z - min_z

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	get_tree().quit(1)
	return false