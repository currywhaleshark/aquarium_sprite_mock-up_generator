extends Node

const FinEditorPanelScript := preload("res://scripts/ui/FinEditorPanel.gd")

func _ready() -> void:
	var panel := FinEditorPanelScript.new()
	add_child(panel)
	var seen_parameters := [{}]
	var seen_vector_slot := [""]
	panel.parameters_changed.connect(func(parameters: Dictionary) -> void:
		seen_parameters[0] = parameters
	)
	panel.vector_edit_target_changed.connect(func(slot: String) -> void:
		seen_vector_slot[0] = slot
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
	panel.set("selected_slot", "caudal")
	panel.set_numeric_parameter("tail_fin_size", 0.62)
	panel.set_numeric_parameter("caudal_softness", 0.78)
	panel.set("selected_slot", "dorsal_1")
	panel.set_numeric_parameter("dorsal_1_softness", 0.46)
	panel.set("selected_slot", "pectoral")
	panel.set_numeric_parameter("pectoral_rigidity", 0.6)
	panel.set("selected_slot", "dorsal_1")
	panel.set_numeric_parameter("dorsal_1_height", 0.33)
	panel.set_slot_shape("dorsal_1", "custom")
	assert(seen_vector_slot[0] == "dorsal_1")
	panel.set_slot_shape("dorsal_1", "single")
	assert(seen_vector_slot[0] == "")
	panel.set("selected_slot", "adipose_fin")
	panel.set_slot_enabled("adipose_fin", true)
	panel.set_slot_attach("adipose_fin", 0.84)
	panel.set_slot_shape("adipose_fin", "custom")
	assert(seen_vector_slot[0] == "adipose_fin")
	panel.set_numeric_parameter("adipose_fin_size", 0.31)
	panel.set("selected_slot", "finlet")
	panel.set_slot_enabled("finlet", true)
	panel.set_slot_shape("finlet", "rounded")
	panel.set_numeric_parameter("finlet_dorsal_count", 6.0)
	panel.set_numeric_parameter("finlet_spacing", 0.82)

	assert(float(seen_parameters[0].get("dorsal_2_enabled", 0.0)) == 1.0)
	assert(abs(float(seen_parameters[0].get("dorsal_2_attach_t", 0.0)) - 0.78) < 0.001)
	assert(String(seen_parameters[0].get("caudal_shape", "")) == "thresher")
	assert(abs(float(seen_parameters[0].get("tail_fin_size", 0.0)) - 0.62) < 0.001)
	assert(abs(float(seen_parameters[0].get("caudal_softness", 0.0)) - 0.78) < 0.001)
	assert(abs(float(seen_parameters[0].get("dorsal_1_softness", 0.0)) - 0.46) < 0.001)
	assert(abs(float(seen_parameters[0].get("pectoral_rigidity", 0.0)) - 0.6) < 0.001)
	assert(abs(float(seen_parameters[0].get("dorsal_1_height", 0.0)) - 0.33) < 0.001)
	assert(float(seen_parameters[0].get("adipose_fin_enabled", 0.0)) == 1.0)
	assert(abs(float(seen_parameters[0].get("adipose_fin_position", 0.0)) - 0.84) < 0.001)
	assert(String(seen_parameters[0].get("adipose_fin_shape", "")) == "custom")
	assert(abs(float(seen_parameters[0].get("adipose_fin_size", 0.0)) - 0.31) < 0.001)
	assert(float(seen_parameters[0].get("finlet_enabled", 0.0)) == 1.0)
	assert(String(seen_parameters[0].get("finlet_shape", "")) == "rounded")
	assert(abs(float(seen_parameters[0].get("finlet_dorsal_count", 0.0)) - 6.0) < 0.001)
	assert(abs(float(seen_parameters[0].get("finlet_spacing", 0.0)) - 0.82) < 0.001)

	panel.set_parameters({
		"creature_type": "ray",
		"cephalic_horns": "rolled",
		"pelvic_length": 0.24,
		"pelvic_height": 0.12
	})
	var slot_option := panel.get("slot_option") as OptionButton
	assert(slot_option.item_count == 2)
	assert(slot_option.get_item_text(0) == "두흉엽")
	assert(slot_option.get_item_text(1) == "골반엽")
	assert(panel.get("selected_slot") == "cephalic")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://exports/test_results"))
	var file := FileAccess.open("res://exports/test_results/fin_editor_panel.ok", FileAccess.WRITE)
	file.store_string("fin editor panel parameters emitted")
	file.close()
	print("FIN_EDITOR_PANEL_TEST_OK")
	get_tree().quit(0)
