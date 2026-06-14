extends Node

const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")
const UiText := preload("res://scripts/ui/UiText.gd")

func _ready() -> void:
	await _test_editor_emits_layer_changes()
	await _test_editor_defaults_fin_zone_to_fin_region()
	await _test_editor_adds_safe_editable_layer()
	await _test_editor_removes_layer()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/marking_layer_editor.ok", FileAccess.WRITE)
	file.store_string("marking layer editor emits layer changes")
	file.close()
	print("MARKING_LAYER_EDITOR_TEST_OK")
	get_tree().quit(0)

func _test_editor_emits_layer_changes() -> void:
	var editor := MarkingLayerEditorScript.new()
	add_child(editor)
	var seen := [[]]
	editor.layers_changed.connect(func(layers: Array) -> void:
		seen[0] = layers
	)
	editor.set_layers([
		{"type": "region_color", "region": "dorsal", "blend_mode": "multiply", "color": "#223344", "intensity": 0.5}
	])
	await get_tree().process_frame
	assert(editor.get_child_count() > 0)
	editor.call("_set_layer_field", 0, "region", "flank")
	await get_tree().process_frame
	assert((seen[0] as Array).size() == 1)
	assert(String(((seen[0] as Array)[0] as Dictionary).get("region", "")) == "flank")
	editor.queue_free()
	await get_tree().process_frame

func _test_editor_defaults_fin_zone_to_fin_region() -> void:
	var editor := MarkingLayerEditorScript.new()
	add_child(editor)
	var seen := [[]]
	editor.layers_changed.connect(func(layers: Array) -> void:
		seen[0] = layers
	)
	editor.set_layers([
		{"type": "fin_edge", "zone": "fin", "color": "#223344", "intensity": 0.5}
	])
	await get_tree().process_frame
	editor.call("_set_layer_field", 0, "blend_mode", "screen")
	await get_tree().process_frame
	assert(String(((seen[0] as Array)[0] as Dictionary).get("region", "")) == "fin")
	editor.queue_free()
	await get_tree().process_frame

func _test_editor_adds_safe_editable_layer() -> void:
	var editor := MarkingLayerEditorScript.new()
	add_child(editor)
	var seen := [[]]
	editor.layers_changed.connect(func(layers: Array) -> void:
		seen[0] = layers
	)
	editor.set_layers([])
	await get_tree().process_frame
	var add_button := editor.get_child(editor.get_child_count() - 1) as Button
	add_button.pressed.emit()
	await get_tree().process_frame
	assert((seen[0] as Array).size() == 1)
	var layer := (seen[0] as Array)[0] as Dictionary
	assert(String(layer.get("type", "")) == "horizontal_band")
	assert(String(layer.get("region", "")) == "flank")
	assert(abs(float(layer.get("intensity", 1.0))) < 0.001)
	assert(layer.has("color"))
	assert(layer.has("x_start"))
	assert(layer.has("x_end"))
	assert(layer.has("thickness"))
	editor.queue_free()
	await get_tree().process_frame

func _test_editor_removes_layer() -> void:
	var editor := MarkingLayerEditorScript.new()
	add_child(editor)
	var seen := [[]]
	editor.layers_changed.connect(func(layers: Array) -> void:
		seen[0] = layers
	)
	editor.set_layers([
		{"type": "horizontal_band", "region": "flank", "color": "#ffffff"},
		{"type": "region_color", "region": "dorsal", "color": "#223344"}
	])
	await get_tree().process_frame
	var row := editor.get_node("Layer_0") as HBoxContainer
	var remove_button := _find_button_by_tooltip(row, UiText.remove_marking_layer_tooltip())
	assert(remove_button != null)
	remove_button.pressed.emit()
	await get_tree().process_frame
	assert((seen[0] as Array).size() == 1)
	assert(String(((seen[0] as Array)[0] as Dictionary).get("type", "")) == "region_color")
	editor.queue_free()
	await get_tree().process_frame

func _find_button_by_tooltip(root: Node, tooltip: String) -> Button:
	for child in root.get_children():
		if child is Button and String((child as Button).tooltip_text) == tooltip:
			return child as Button
		var nested := _find_button_by_tooltip(child, tooltip)
		if nested != null:
			return nested
	return null
