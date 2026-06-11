extends Node

const BodyEditorPanelScript := preload("res://scripts/ui/BodyEditorPanel.gd")
const BodyProfileScript := preload("res://scripts/creature/BodyProfile.gd")

func _ready() -> void:
	var panel := BodyEditorPanelScript.new()
	add_child(panel)
	assert(BodyProfileScript.RING_KEY_RANGES.has("upper_height"))
	assert(BodyEditorPanelScript.RING_NUMERIC_KEYS == BodyProfileScript.RING_KEY_RANGES)
	var seen := [{}]
	var selected := [""]
	var emission_count := [0]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen[0] = parameters
		emission_count[0] += 1
	)
	panel.ring_selected.connect(func(ring_id: String) -> void:
		selected[0] = ring_id
	)
	panel.set_parameters({
		"body_profile": {
			"rings": [
				{"id": "snout", "label": "Snout", "x": 0.0, "y_offset": 0.0, "upper_height": 0.24, "lower_height": 0.20, "width": 0.18, "roundness": 0.65, "sway_weight": 0.0},
				{"id": "head", "label": "Head", "x": 0.16, "y_offset": 0.0, "upper_height": 0.42, "lower_height": 0.36, "width": 0.34, "roundness": 0.82, "sway_weight": 0.05},
				{"id": "front_body", "label": "Front Body", "x": 0.36, "y_offset": 0.0, "upper_height": 0.52, "lower_height": 0.48, "width": 0.46, "roundness": 0.9, "sway_weight": 0.15},
				{"id": "mid_body", "label": "Mid Body", "x": 0.58, "y_offset": 0.0, "upper_height": 0.46, "lower_height": 0.42, "width": 0.38, "roundness": 0.86, "sway_weight": 0.35},
				{"id": "rear_body", "label": "Rear Body", "x": 0.78, "y_offset": 0.0, "upper_height": 0.28, "lower_height": 0.26, "width": 0.24, "roundness": 0.78, "sway_weight": 0.65},
				{"id": "tail_stem", "label": "Tail Stem", "x": 1.0, "y_offset": 0.0, "upper_height": 0.12, "lower_height": 0.12, "width": 0.08, "roundness": 0.7, "sway_weight": 1.0}
			]
		}
	})
	panel.select_ring_by_id("mid_body")
	assert(selected[0] == "mid_body")
	var silhouette_editor = panel.get("silhouette_editor")
	assert(silhouette_editor != null)
	assert(panel.get_child(1) == silhouette_editor)
	emission_count[0] = 0
	silhouette_editor.ring_value_changed.emit("mid_body", "upper_height", 0.6)
	assert(emission_count[0] == 1)
	var silhouette_changed_ring := _ring_by_id(_panel_rings(panel), "mid_body")
	assert(abs(float(silhouette_changed_ring.get("upper_height", 0.0)) - 0.6) < 0.001)

	var size_before_add := _panel_rings(panel).size()
	silhouette_editor.ring_add_requested.emit(0.5)
	var rings_after_add := _panel_rings(panel)
	assert(rings_after_add.size() == size_before_add + 1)
	var added_ring := _ring_by_id(rings_after_add, panel.get("selected_ring_id"))
	assert(abs(float(added_ring.get("x", 0.0)) - 0.5) < 0.001)
	silhouette_editor.ring_delete_requested.emit(String(added_ring.get("id", "")))
	assert(_panel_rings(panel).size() == size_before_add)
	panel.select_ring_by_id("mid_body")

	panel.set_ring_parameter("upper_height", 0.72)
	var synced_top: Vector2 = silhouette_editor.handle_norm_position("mid_body", "top")
	assert(abs(synced_top.y - 0.72) < 0.001)
	panel.set_ring_parameter("lower_height", 0.61)
	panel.set_ring_parameter("top_width", 0.71)
	panel.set_ring_parameter("bottom_width", 0.29)
	panel.set_ring_parameter("top_flatness", 0.8)
	panel.set_ring_parameter("right_flatness", 0.55)
	panel.set_ring_parameter("sway_weight", 0.5)

	var body_profile: Dictionary = seen[0].get("body_profile", {})
	var rings: Array = body_profile.get("rings", [])
	assert(rings.size() == 6)
	assert(String(rings[3].get("id", "")) == "mid_body")
	assert(abs(float(rings[3].get("upper_height", 0.0)) - 0.72) < 0.001)
	assert(abs(float(rings[3].get("lower_height", 0.0)) - 0.61) < 0.001)
	assert(abs(float(rings[3].get("top_width", 0.0)) - 0.71) < 0.001)
	assert(abs(float(rings[3].get("bottom_width", 0.0)) - 0.29) < 0.001)
	assert(abs(float(rings[3].get("width", 0.0)) - 0.5) < 0.001)
	assert(abs(float(rings[3].get("top_flatness", 0.0)) - 0.8) < 0.001)
	assert(abs(float(rings[3].get("right_flatness", 0.0)) - 0.55) < 0.001)
	assert(abs(float(rings[3].get("sway_weight", 0.0)) - 0.5) < 0.001)
	assert(panel.is_row_changed("upper_height"))
	var default_mid_body := _default_ring("mid_body")
	panel.set_ring_parameter("upper_height", float(default_mid_body.get("upper_height", 0.0)))
	assert(not panel.is_row_changed("upper_height"))

	panel.select_next_ring()
	assert(selected[0] == "rear_body")
	panel.select_previous_ring()
	assert(selected[0] == "mid_body")
	var min_rings := BodyProfileScript.default_fish_rings().slice(0, BodyProfileScript.MIN_RING_COUNT)
	panel.set_parameters({"body_profile": {"rings": min_rings}})
	panel.select_ring_by_id(String(min_rings[1].get("id", "")))
	var min_count := _panel_rings(panel).size()
	silhouette_editor.ring_delete_requested.emit(String(min_rings[1].get("id", "")))
	assert(_panel_rings(panel).size() == min_count)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/body_editor_panel.ok", FileAccess.WRITE)
	file.store_string("body ring editor parameters emitted")
	file.close()
	print("BODY_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)

func _default_ring(ring_id: String) -> Dictionary:
	for ring in BodyProfileScript.default_fish_rings():
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}

func _panel_rings(panel: Node) -> Array:
	var parameters: Dictionary = panel.get("parameters")
	var body_profile: Dictionary = parameters.get("body_profile", {})
	return body_profile.get("rings", [])

func _ring_by_id(rings: Array, ring_id: String) -> Dictionary:
	for ring in rings:
		if String(ring.get("id", "")) == ring_id:
			return ring
	return {}
