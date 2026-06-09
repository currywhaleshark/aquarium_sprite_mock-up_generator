extends Node

const MarkingLayerEditorScript := preload("res://scripts/ui/MarkingLayerEditor.gd")

func _ready() -> void:
	await _test_editor_emits_layer_changes()

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
