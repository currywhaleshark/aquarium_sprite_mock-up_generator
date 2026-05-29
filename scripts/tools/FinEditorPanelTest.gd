extends Node

const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")

func _ready() -> void:
	var panel := FinEditorPanelScript.new()
	add_child(panel)
	var seen_parameters := [{}]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen_parameters[0] = parameters
	)
	panel.set_parameters({
		"dorsal_2_enabled": 0.0,
		"dorsal_2_attach_t": 0.65,
		"dorsal_2_shape": "single",
		"caudal_shape": "forked_shallow"
	})
	panel.set_slot_enabled("dorsal_2", true)
	panel.set_slot_attach("dorsal_2", 0.78)
	panel.set_slot_shape("caudal", "thresher")

	assert(float(seen_parameters[0].get("dorsal_2_enabled", 0.0)) == 1.0)
	assert(abs(float(seen_parameters[0].get("dorsal_2_attach_t", 0.0)) - 0.78) < 0.001)
	assert(String(seen_parameters[0].get("caudal_shape", "")) == "thresher")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_editor_panel.ok", FileAccess.WRITE)
	file.store_string("fin editor panel parameters emitted")
	file.close()
	print("FIN_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)
